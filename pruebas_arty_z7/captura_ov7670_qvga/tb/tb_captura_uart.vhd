library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity tb_captura_uart is
    generic (CLK_FREQ_HZ : positive := 100000000; TEST_RUNTIME : boolean := false);
end entity;
architecture sim of tb_captura_uart is
    constant CLK_PERIOD : time := 1 sec / CLK_FREQ_HZ;
    constant BIT_PERIOD : time := 2 * CLK_PERIOD;
    constant PCLK_PERIOD : time := 41.667 ns;
    type reg_pair_t is record
        reg_addr, reg_data : std_logic_vector(7 downto 0);
    end record;
    type config_rom_t is array(natural range <>) of reg_pair_t;
    constant EXPECTED_CONFIG : config_rom_t := (
        (reg_addr => x"12", reg_data => x"80"),
        (reg_addr => x"15", reg_data => x"00"),
        (reg_addr => x"40", reg_data => x"C0"),
        (reg_addr => x"13", reg_data => x"8F"),
        (reg_addr => x"11", reg_data => x"01"),
        (reg_addr => x"12", reg_data => x"00"),
        (reg_addr => x"0C", reg_data => x"04"),
        (reg_addr => x"3E", reg_data => x"19"),
        (reg_addr => x"70", reg_data => x"3A"),
        (reg_addr => x"71", reg_data => x"35"),
        (reg_addr => x"72", reg_data => x"11"),
        (reg_addr => x"73", reg_data => x"F1"),
        (reg_addr => x"A2", reg_data => x"02"),
        (reg_addr => x"3A", reg_data => x"04"),
        (reg_addr => x"3D", reg_data => x"99"),
        (reg_addr => x"03", reg_data => x"00"),
        (reg_addr => x"17", reg_data => x"15"),
        (reg_addr => x"18", reg_data => x"03"),
        (reg_addr => x"19", reg_data => x"03"),
        (reg_addr => x"1A", reg_data => x"7B"),
        (reg_addr => x"32", reg_data => x"80")
    );


    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal start, tx, SCL, cam_xclk, cam_reset, cam_pwdn : std_logic := '0';
    signal SDA : std_logic := 'H';
    signal sda_t : std_logic;
    signal leds : std_logic_vector(3 downto 0);
    signal status : std_logic_vector(63 downto 0);
    signal software_control : std_logic_vector(63 downto 0) := (others=>'0');
    signal sda_slave_drive : std_logic := 'Z';
    signal cam_pclk, cam_href : std_logic := '0';
    signal cam_vsync : std_logic := '1';
    signal cam_data : std_logic_vector(7 downto 0) := (others => '0');
    signal i2c_config_done : std_logic := '0';
    signal packets : natural := 0;
    signal writes : natural := 0;
    function sda_to_bit(v : std_logic) return std_logic is
    begin
        if v = '0' then return '0'; else return '1'; end if;
    end function;
    function expected_y(i, frame : natural) return std_logic_vector is
    begin return std_logic_vector(to_unsigned((i*5+17+frame*73) mod 256,8)); end function;
begin
    clk <= not clk after CLK_PERIOD/2;
    cam_pclk <= not cam_pclk after PCLK_PERIOD/2;
    SDA <= 'H'; SDA <= sda_slave_drive;
    SDA <= '0' when sda_t = '0' else 'Z';
    dut : entity work.captura_uart_top
        generic map (CLK_FREQ_HZ => CLK_FREQ_HZ,
            UART_BAUD_RATE => CLK_FREQ_HZ/2, DEBOUNCE_CYCLES => 4,
            POWERUP_CYCLES => 100, CAMERA_SETTLE_CYCLES => 100, SCCB_RESET_DELAY_MS => 1)
        port map (clk => clk, rst => rst, start => start, tx => tx,
            sda_i => to_x01(SDA), sda_t => sda_t, diag_led => leds,
            capture_status => status,
            software_control => software_control,
            SCL => SCL, cam_xclk => cam_xclk,
            cam_pclk => cam_pclk, cam_vsync => cam_vsync, cam_href => cam_href,
            cam_data => cam_data, cam_reset => cam_reset, cam_pwdn => cam_pwdn);
    count_sccb : process
    begin
        wait until falling_edge(SDA);
        if SCL = '1' then writes <= writes+1; end if;
    end process;
    stimulus : process
        procedure send_byte(v : std_logic_vector(7 downto 0)) is
        begin
            cam_data <= v; wait until rising_edge(cam_pclk);
        end procedure;
        procedure send_frame(frame : natural) is
        begin
            wait until falling_edge(cam_pclk);
            cam_vsync <= '1'; cam_href<='1'; wait for 20*PCLK_PERIOD;
            cam_href<='0'; -- dummy HREF inside VSYNC must not become an image row
            cam_vsync <= '0'; wait until rising_edge(cam_pclk);
            for row in 0 to 239 loop
                cam_href <= '1';
                for col in 0 to 319 loop
                    send_byte(expected_y(row*320+col,frame));
                    send_byte(x"A5");
                end loop;
                cam_href <= '0'; cam_data <= x"00";
                wait until rising_edge(cam_pclk); wait until rising_edge(cam_pclk);
            end loop;
            cam_vsync <= '1'; wait for 10*PCLK_PERIOD;
        end procedure;
        variable t : time;
    begin
        wait for 500 ns; rst <= '0'; wait for 20 us;
        assert tx = '1' and SCL = '1' and writes = 0
            report "Actividad no solicitada antes de start" severity failure;
        -- Rechazar rebote menor que el filtro.
        start <= '1'; wait for CLK_PERIOD; start <= '0'; wait for 2 us;
        assert writes = 0 report "Rebote inicio SCCB" severity failure;
        start <= '1'; -- Mantener pulsado hasta despues del envio.
        wait until i2c_config_done = '1' for 40 ms;
        assert i2c_config_done = '1' report "Timeout SCCB" severity failure;
        wait for 100 us;
        assert cam_reset = '1' and cam_pwdn = '0' severity failure;
        wait until rising_edge(cam_xclk); t := now;
        wait until rising_edge(cam_xclk);
        assert abs((now-t)-41.667 ns) < 10 ps report "XCLK no es 24 MHz" severity failure;
        send_frame(0);
        wait until packets = 1 for 60 ms;
        assert packets = 1 report "No llego la primera captura" severity failure;
        wait for 10 us;
        -- Otro frame con start mantenido no debe producir otra captura.
        send_frame(9);
        wait for 2 ms;
        assert packets = 1 and tx = '1' report "Captura repetida al mantener start" severity failure;
        start <= '0'; wait for 2 us;
        start <= '1'; wait for 2 us; start <= '0'; wait for 10 us;
        send_frame(1);
        -- Pulsaciones durante UART se descartan, no quedan en cola.
        start <= '1'; wait for 2 us; start <= '0';
        wait until packets = 2 for 60 ms;
        assert packets = 2 report "No se pudo rearmar la captura" severity failure;
        wait for 10 us;
        send_frame(9); wait for 2 ms;
        assert packets = 2 and tx = '1' report "Start ocupado dejo una captura pendiente" severity failure;
        assert writes = 21 report "Se modifico o repitio la ROM SCCB" severity failure;
        assert status(63)='1' and status(3 downto 0)="0000"
            and unsigned(status(11 downto 4))=240
            and unsigned(status(22 downto 12))=640
            and unsigned(status(35 downto 24))=640
            and unsigned(status(51 downto 36))=11264 and status(23)='1'
            report "Frame diagnostic counters incorrect for two full images" severity failure;
        if TEST_RUNTIME then
            software_control(3)<='1'; wait for 1 us;
            assert status(31 downto 24)=x"D3" and status(33 downto 32)="11"
                report "Runtime status page/configured/idle mapping" severity failure;
            software_control(15 downto 8)<=x"10";
            software_control(23 downto 16)<=x"A5"; software_control(1)<='1';
            wait until status(0)='1' for 1 ms;
            assert status(0)='1' and status(3 downto 1)="000" and status(15 downto 8)=x"A5"
                report "Runtime write through top failed" severity failure;
            wait for 400 us;
            assert writes=22 report "Runtime held command repeated" severity failure;
            software_control(2)<='1'; software_control(1)<='0';
            wait until status(0)='0' for 1 ms;
            assert status(0)='0' and status(3 downto 1)="000" and status(15 downto 8)=x"A5"
                report "Runtime pointer/read through top failed" severity failure;
            software_control(3)<='0'; wait for 1 us;
            assert status(63)='1' and unsigned(status(11 downto 4))=240
                and status(3 downto 0)="0000" and writes=24
                report "Runtime changed latched image diagnostic" severity failure;
            report "PASS_TOP_RUNTIME: two QVGA frames, EMIO page, actual SCCB write/pointer/read, preserved image diagnostic";
        end if;
        rst <= '1'; wait for 1 us; rst <= '0'; wait for 10 us;
        assert tx = '1' report "UART no vuelve a idle con reset" severity failure;
        report "PASS_CAPTURA_UART: 21 registros, XCLK 24 MHz, dos STY1 320x240, payload y checksum, botones y reset";
        finish;
    end process;
    i2c_slave_model : process

        procedure wait_start is
        begin
            wait until sda_to_bit(SDA) = '0' and sda_to_bit(SCL) = '1';
        end procedure;

        procedure receive_master_byte(
            variable received_byte : out std_logic_vector(7 downto 0)
        ) is
        begin
            received_byte := (others => '0');

            for bit_index in 7 downto 0 loop
                wait until rising_edge(SCL);
                received_byte(bit_index) := sda_to_bit(SDA);
            end loop;
        end procedure;

        procedure send_ack is
        begin
            wait until falling_edge(SCL);
            sda_slave_drive <= '0';

            wait until rising_edge(SCL);
            wait until falling_edge(SCL);

            sda_slave_drive <= 'Z';
        end procedure;

        procedure receive_expected_write(
            constant expected_reg : in std_logic_vector(7 downto 0);
            constant expected_data : in std_logic_vector(7 downto 0);
            constant label_text : in string
        ) is
            variable runtime_byte : std_logic_vector(7 downto 0);
        begin
            wait_start;

            receive_master_byte(runtime_byte);
            assert runtime_byte = x"42"
                report "ERROR: byte de direccion SCCB runtime no es 0x42 en " & label_text
                severity failure;
            send_ack;

            receive_master_byte(runtime_byte);
            assert runtime_byte = expected_reg
                report "ERROR: direccion de registro runtime no coincide en " & label_text
                severity failure;
            send_ack;

            receive_master_byte(runtime_byte);
            assert runtime_byte = expected_data
                report "ERROR: dato de registro runtime no coincide en " & label_text
                severity failure;
            send_ack;
        end procedure;

        variable received_byte : std_logic_vector(7 downto 0);

    begin
        sda_slave_drive <= 'Z';

        wait until rst = '0';

        for index in EXPECTED_CONFIG'range loop

            wait_start;

            receive_master_byte(received_byte);
            assert received_byte = x"42"
                report "ERROR: byte de direccion SCCB de escritura no es 0x42"
                severity failure;
            send_ack;

            receive_master_byte(received_byte);
            assert received_byte = EXPECTED_CONFIG(index).reg_addr
                report "ERROR: direccion de registro OV7670 no coincide"
                severity failure;
            send_ack;

            receive_master_byte(received_byte);
            assert received_byte = EXPECTED_CONFIG(index).reg_data
                report "ERROR: dato de registro OV7670 no coincide"
                severity failure;
            send_ack;

            report "SCCB registro " & integer'image(index) & " verificado";

        end loop;

        i2c_config_done <= '1';
        report "Modelo SCCB/I2C recibio toda la configuracion esperada";

        if TEST_RUNTIME then
            receive_expected_write(x"10",x"A5","DOE runtime");
            wait_start;
            receive_master_byte(received_byte);
            assert received_byte=x"42" report "Runtime pointer address" severity failure;
            send_ack;
            receive_master_byte(received_byte);
            assert received_byte=x"10" report "Runtime pointer register" severity failure;
            send_ack;
            wait_start;
            receive_master_byte(received_byte);
            assert received_byte=x"43" report "Runtime read address" severity failure;
            send_ack;
            received_byte:=x"A5";
            for i in 7 downto 0 loop
                wait for 100 ns;
                if received_byte(i)='0' then sda_slave_drive<='0'; else sda_slave_drive<='Z'; end if;
                wait until rising_edge(SCL); wait until falling_edge(SCL);
            end loop;
            sda_slave_drive<='Z'; wait until rising_edge(SCL);
            assert sda_to_bit(SDA)='1' report "Runtime read missing final NACK" severity failure;
        end if;

        wait;
    end process;

    uart_monitor : process
        procedure receive_byte(variable v : out std_logic_vector(7 downto 0)) is
        begin
            wait until tx = '0'; wait for BIT_PERIOD/2;
            assert tx = '0' report "Start UART incorrecto" severity failure;
            for bit_index in 0 to 7 loop
                wait for BIT_PERIOD; v(bit_index) := tx;
            end loop;
            wait for BIT_PERIOD;
            assert tx = '1' report "Stop UART incorrecto" severity failure;
        end procedure;
        type bytes_t is array(natural range <>) of std_logic_vector(7 downto 0);
        constant HEADER : bytes_t := (x"53",x"54",x"59",x"31",x"40",x"01",
            x"F0",x"00",x"00",x"2C",x"01",x"00");
        variable b : std_logic_vector(7 downto 0);
        variable checksum : unsigned(7 downto 0);
    begin
        wait until rst = '0';
        for frame in 0 to 1 loop
            checksum := (others => '0');
            for i in HEADER'range loop
                receive_byte(b);
                assert b = HEADER(i) report "Cabecera STY1 incorrecta" severity failure;
            end loop;
            for i in 0 to 76799 loop
                receive_byte(b);
                assert b = expected_y(i,frame)
                    report "Payload Y incorrecto en " & integer'image(i) severity failure;
                checksum := checksum+unsigned(b);
            end loop;
            receive_byte(b);
            assert b = std_logic_vector(checksum) report "Checksum incorrecto" severity failure;
            packets <= frame+1;
        end loop;
        -- Cualquier nueva transmision es una captura no solicitada.
        wait until falling_edge(tx);
        assert false report "UART transmitio un tercer paquete no solicitado" severity failure;
    end process;
    watchdog : process
    begin
        wait for 160 ms;
        assert false report "Timeout captura UART" severity failure;
    end process;
end architecture;

entity tb_captura_uart_125 is end entity;
architecture sim of tb_captura_uart_125 is
begin
    test : entity work.tb_captura_uart generic map (CLK_FREQ_HZ => 125000000);
end architecture;
