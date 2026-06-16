library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_star_tracker_top is
end entity;

architecture sim of tb_star_tracker_top is

    component star_tracker_top is
        generic (
            FRAME_WIDTH    : integer := 160;
            FRAME_HEIGHT   : integer := 120;
            ADDR_WIDTH     : integer := 15;
            UART_BAUD_RATE : integer := 921600;
            SIM_BYPASS_XCLK_LOCK : boolean := false
        );
        port (
            clk : in std_logic;
            rst : in std_logic;

            start_btn : in std_logic;
            btn_config : in std_logic;
            sw : in std_logic_vector(15 downto 0);

            SDA : inout std_logic;
            SCL : out std_logic;

            cam_xclk  : out std_logic;
            cam_pclk  : in std_logic;
            cam_vsync : in std_logic;
            cam_href  : in std_logic;
            cam_data  : in std_logic_vector(7 downto 0);
            cam_pwdn  : out std_logic;
            cam_reset : out std_logic;

            uart_tx : out std_logic;

            pixel_valid : out std_logic;
            frame_done  : out std_logic;

            led_read_data : out std_logic_vector(7 downto 0);
            busy          : out std_logic;
            ok            : out std_logic;
            fail          : out std_logic
        );
    end component;

    type reg_pair_t is record
        reg_addr : std_logic_vector(7 downto 0);
        reg_data : std_logic_vector(7 downto 0);
    end record;

    type config_rom_t is array (natural range <>) of reg_pair_t;

    constant FRAME_WIDTH      : integer := 160;
    constant FRAME_HEIGHT     : integer := 120;
    constant FRAME_PIXELS     : integer := FRAME_WIDTH * FRAME_HEIGHT;
    constant ADDR_WIDTH       : integer := 15;
    constant SIM_UART_BAUD    : integer := 20000000;

    constant CLK_PERIOD       : time := 10 ns;
    constant PCLK_PERIOD      : time := 41.667 ns;
    constant UART_BIT_PERIOD  : time := 50 ns;

    constant EXPECTED_CONFIG : config_rom_t := (
        (reg_addr => x"12", reg_data => x"80"),
        (reg_addr => x"15", reg_data => x"00"),
        (reg_addr => x"40", reg_data => x"C0"),
        (reg_addr => x"13", reg_data => x"8F"),
        (reg_addr => x"11", reg_data => x"01"),
        (reg_addr => x"12", reg_data => x"00"),
        (reg_addr => x"0C", reg_data => x"04"),
        (reg_addr => x"3E", reg_data => x"1A"),
        (reg_addr => x"70", reg_data => x"3A"),
        (reg_addr => x"71", reg_data => x"35"),
        (reg_addr => x"72", reg_data => x"22"),
        (reg_addr => x"73", reg_data => x"F2"),
        (reg_addr => x"A2", reg_data => x"02"),
        (reg_addr => x"3A", reg_data => x"04"),
        (reg_addr => x"3D", reg_data => x"99"),
        (reg_addr => x"03", reg_data => x"03"),
        (reg_addr => x"17", reg_data => x"11"),
        (reg_addr => x"18", reg_data => x"61"),
        (reg_addr => x"19", reg_data => x"03"),
        (reg_addr => x"1A", reg_data => x"7B"),
        (reg_addr => x"32", reg_data => x"80")
    );

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal start_btn : std_logic := '0';
    signal btn_config : std_logic := '0';
    signal sw : std_logic_vector(15 downto 0) := (others => '0');

    signal SDA : std_logic := 'H';
    signal SCL : std_logic;

    signal cam_xclk  : std_logic;
    signal cam_pclk  : std_logic := '0';
    signal cam_vsync : std_logic := '1';
    signal cam_href  : std_logic := '0';
    signal cam_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal cam_pwdn  : std_logic;
    signal cam_reset : std_logic;

    signal uart_tx_line : std_logic;

    signal pixel_valid   : std_logic;
    signal frame_done    : std_logic;
    signal led_read_data : std_logic_vector(7 downto 0);
    signal busy          : std_logic;
    signal ok            : std_logic;
    signal fail          : std_logic;

    signal sda_slave_drive : std_logic := 'Z';
    signal i2c_config_done : std_logic := '0';
    signal runtime_write_count : integer range 0 to 6 := 0;
    signal camera_done     : std_logic := '0';
    signal uart_done_seen  : std_logic := '0';

    signal pixel_count             : integer range 0 to FRAME_PIXELS := 0;
    signal frame_done_before_full  : std_logic := '0';
    signal pixel_after_frame_done  : std_logic := '0';

    function sda_to_bit(signal_value : std_logic) return std_logic is
    begin
        if signal_value = '0' then
            return '0';
        else
            return '1';
        end if;
    end function;

    function expected_y(pixel_index : integer) return std_logic_vector is
        variable value : integer;
    begin
        value := (pixel_index * 5 + 17) mod 256;
        return std_logic_vector(to_unsigned(value, 8));
    end function;

begin

    SDA <= 'H';
    SDA <= sda_slave_drive;

    uut : star_tracker_top
        generic map (
            FRAME_WIDTH    => FRAME_WIDTH,
            FRAME_HEIGHT   => FRAME_HEIGHT,
            ADDR_WIDTH     => ADDR_WIDTH,
            UART_BAUD_RATE => SIM_UART_BAUD,
            SIM_BYPASS_XCLK_LOCK => true
        )
        port map (
            clk => clk,
            rst => rst,

            start_btn => start_btn,
            btn_config => btn_config,
            sw => sw,

            SDA => SDA,
            SCL => SCL,

            cam_xclk  => cam_xclk,
            cam_pclk  => cam_pclk,
            cam_vsync => cam_vsync,
            cam_href  => cam_href,
            cam_data  => cam_data,
            cam_pwdn  => cam_pwdn,
            cam_reset => cam_reset,

            uart_tx => uart_tx_line,

            pixel_valid => pixel_valid,
            frame_done  => frame_done,

            led_read_data => led_read_data,
            busy          => busy,
            ok            => ok,
            fail          => fail
        );

    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    cam_pclk_process : process
    begin
        while true loop
            cam_pclk <= '0';
            wait for PCLK_PERIOD / 2;
            cam_pclk <= '1';
            wait for PCLK_PERIOD / 2;
        end loop;
    end process;

    stimulus : process

        procedure send_byte(constant value : in std_logic_vector(7 downto 0)) is
        begin
            cam_data <= value;
            wait until rising_edge(cam_pclk);
        end procedure;

        procedure send_line(constant row_index : in integer) is
            variable pixel_index : integer;
        begin
            cam_href <= '1';

            for column_index in 0 to FRAME_WIDTH - 1 loop
                pixel_index := row_index * FRAME_WIDTH + column_index;

                if (column_index mod 2) = 0 then
                    send_byte(expected_y(pixel_index));
                    send_byte(x"A5");
                else
                    send_byte(expected_y(pixel_index));
                    send_byte(x"5A");
                end if;
            end loop;

            cam_href <= '0';
            cam_data <= (others => '0');
            wait until rising_edge(cam_pclk);
            wait until rising_edge(cam_pclk);
        end procedure;

        procedure pulse_config_button is
        begin
            wait until rising_edge(clk);
            btn_config <= '1';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            btn_config <= '0';
            wait until rising_edge(clk);
        end procedure;

    begin
        report "Inicio de simulacion top completo OV7670 -> BRAM -> UART";

        rst <= '1';
        start_btn <= '0';
        btn_config <= '0';
        sw <= (others => '0');
        cam_vsync <= '1';
        cam_href <= '0';
        cam_data <= (others => '0');

        wait for 500 ns;

        rst <= '0';
        wait until rising_edge(clk);
        start_btn <= '1';

        wait until i2c_config_done = '1' or fail = '1' for 40 ms;

        assert i2c_config_done = '1'
            report "ERROR: no termino la configuracion SCCB/I2C"
            severity failure;

        assert fail = '0'
            report "ERROR: fail se activo durante init"
            severity failure;

        assert cam_pwdn = '0'
            report "ERROR: cam_pwdn debe mantener la camara encendida"
            severity failure;

        assert cam_reset = '1'
            report "ERROR: cam_reset debe liberar la camara despues del reset"
            severity failure;

        report "Init SCCB/I2C completa; iniciando frame QQVGA";

        sw <= (others => '0');
        sw(14 downto 13) <= "00";
        sw(7 downto 0) <= x"60";
        pulse_config_button;

        wait for 500 us;
        assert runtime_write_count = 0
            report "ERROR: btn_config genero escritura con SW15=0"
            severity failure;

        sw(15) <= '1';

        sw(14 downto 13) <= "00";
        sw(7 downto 0) <= x"60";
        pulse_config_button;
        wait until runtime_write_count = 1 for 5 ms;
        assert runtime_write_count = 1
            report "ERROR: no se escribio contraste runtime"
            severity failure;
        wait for 500 us;

        sw(14 downto 13) <= "01";
        sw(7 downto 0) <= x"12";
        pulse_config_button;
        wait until runtime_write_count = 3 for 5 ms;
        assert runtime_write_count = 3
            report "ERROR: no se escribio secuencia de ganancia runtime"
            severity failure;
        wait for 500 us;

        sw(14 downto 13) <= "10";
        sw(7 downto 0) <= x"34";
        pulse_config_button;
        wait until runtime_write_count = 5 for 5 ms;
        assert runtime_write_count = 5
            report "ERROR: no se escribio secuencia de exposicion runtime"
            severity failure;
        wait for 500 us;

        sw(14 downto 13) <= "11";
        sw(7 downto 0) <= x"90";
        pulse_config_button;
        wait until runtime_write_count = 6 for 5 ms;
        assert runtime_write_count = 6
            report "ERROR: no se escribio brillo runtime"
            severity failure;

        report "Configuracion runtime verificada: contraste, ganancia, exposicion y brillo";

        for index in 0 to 19999 loop
            wait until rising_edge(cam_pclk);
        end loop;

        cam_vsync <= '0';
        wait until rising_edge(cam_pclk);

        for row_index in 0 to FRAME_HEIGHT - 1 loop
            send_line(row_index);
        end loop;

        cam_vsync <= '1';
        wait until rising_edge(cam_pclk);
        wait for 1 ns;
        camera_done <= '1';

        assert frame_done = '1'
            report "ERROR: frame_done no se activo al cerrar el frame"
            severity failure;

        assert pixel_count = FRAME_PIXELS
            report "ERROR: no se capturaron exactamente 19200 pixeles Y"
            severity failure;

        assert frame_done_before_full = '0'
            report "ERROR: frame_done se activo antes de completar el frame"
            severity failure;

        assert fail = '0'
            report "ERROR: fail se activo durante captura"
            severity failure;

        wait until ok = '1' or fail = '1' for 60 ms;

        assert fail = '0'
            report "ERROR: fail se activo durante dump UART"
            severity failure;

        assert ok = '1'
            report "ERROR: ok no se activo despues del dump UART"
            severity failure;

        assert uart_done_seen = '1'
            report "ERROR: no se recibio el paquete UART completo"
            severity failure;

        assert pixel_after_frame_done = '0'
            report "ERROR: se observaron pixeles validos despues de frame_done"
            severity failure;

        report "PASS_TOP_UART_FULL: init, captura QQVGA, BRAM, UART, payload y checksum correctos";
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

        receive_expected_write(x"56", x"60", "contraste");
        runtime_write_count <= 1;
        report "SCCB runtime contraste verificado";

        receive_expected_write(x"13", x"8B", "ganancia modo manual");
        runtime_write_count <= 2;
        receive_expected_write(x"00", x"12", "ganancia valor");
        runtime_write_count <= 3;
        report "SCCB runtime ganancia verificada";

        receive_expected_write(x"13", x"8E", "exposicion modo manual");
        runtime_write_count <= 4;
        receive_expected_write(x"10", x"34", "exposicion valor");
        runtime_write_count <= 5;
        report "SCCB runtime exposicion verificada";

        receive_expected_write(x"55", x"90", "brillo");
        runtime_write_count <= 6;
        report "SCCB runtime brillo verificado";

        wait;
    end process;

    pixel_monitor : process
        variable expected_pixel : std_logic_vector(7 downto 0);
    begin
        wait until rst = '0';

        while true loop
            wait until rising_edge(cam_pclk);
            wait for 1 ns;

            if pixel_valid = '1' then
                assert pixel_count < FRAME_PIXELS
                    report "ERROR: se emitieron mas de 19200 pixeles Y"
                    severity failure;

                expected_pixel := expected_y(pixel_count);

                assert led_read_data = expected_pixel
                    report "ERROR: pixel Y capturado no coincide. index=" &
                           integer'image(pixel_count) &
                           " expected=" & integer'image(to_integer(unsigned(expected_pixel))) &
                           " actual=" & integer'image(to_integer(unsigned(led_read_data)))
                    severity failure;

                assert frame_done = '0'
                    report "ERROR: pixel_valid y frame_done activos simultaneamente"
                    severity failure;

                pixel_count <= pixel_count + 1;
            end if;

            if frame_done = '1' then
                if pixel_count /= FRAME_PIXELS then
                    frame_done_before_full <= '1';
                end if;
            end if;

            if camera_done = '1' and pixel_valid = '1' then
                pixel_after_frame_done <= '1';
            end if;
        end loop;
    end process;

    uart_monitor : process

        procedure receive_uart_byte(variable rx_byte : out std_logic_vector(7 downto 0)) is
        begin
            wait until uart_tx_line = '0';
            wait for UART_BIT_PERIOD / 2;

            assert uart_tx_line = '0'
                report "ERROR: start bit UART incorrecto"
                severity failure;

            for bit_index in 0 to 7 loop
                wait for UART_BIT_PERIOD;
                rx_byte(bit_index) := uart_tx_line;
            end loop;

            wait for UART_BIT_PERIOD;
            assert uart_tx_line = '1'
                report "ERROR: stop bit UART incorrecto"
                severity failure;
        end procedure;

        variable rx_byte          : std_logic_vector(7 downto 0);
        variable payload_checksum : unsigned(7 downto 0) := (others => '0');
        variable width_value      : integer;
        variable height_value     : integer;
        variable length_value     : integer;
        variable expected_byte    : std_logic_vector(7 downto 0);

    begin
        wait until rst = '0';

        receive_uart_byte(rx_byte);
        assert rx_byte = x"53" report "ERROR: UART magic[0] incorrecto" severity failure;

        receive_uart_byte(rx_byte);
        assert rx_byte = x"54" report "ERROR: UART magic[1] incorrecto" severity failure;

        receive_uart_byte(rx_byte);
        assert rx_byte = x"59" report "ERROR: UART magic[2] incorrecto" severity failure;

        receive_uart_byte(rx_byte);
        assert rx_byte = x"31" report "ERROR: UART magic[3] incorrecto" severity failure;

        receive_uart_byte(rx_byte);
        width_value := to_integer(unsigned(rx_byte));
        receive_uart_byte(rx_byte);
        width_value := width_value + 256 * to_integer(unsigned(rx_byte));
        assert width_value = FRAME_WIDTH
            report "ERROR: UART width no es 160"
            severity failure;

        receive_uart_byte(rx_byte);
        height_value := to_integer(unsigned(rx_byte));
        receive_uart_byte(rx_byte);
        height_value := height_value + 256 * to_integer(unsigned(rx_byte));
        assert height_value = FRAME_HEIGHT
            report "ERROR: UART height no es 120"
            severity failure;

        receive_uart_byte(rx_byte);
        length_value := to_integer(unsigned(rx_byte));
        receive_uart_byte(rx_byte);
        length_value := length_value + 256 * to_integer(unsigned(rx_byte));
        receive_uart_byte(rx_byte);
        length_value := length_value + 65536 * to_integer(unsigned(rx_byte));
        receive_uart_byte(rx_byte);
        length_value := length_value + 16777216 * to_integer(unsigned(rx_byte));
        assert length_value = FRAME_PIXELS
            report "ERROR: UART payload length no es 19200"
            severity failure;

        report "UART header correcto: STY1 160x120 payload=19200";

        for pixel_index in 0 to FRAME_PIXELS - 1 loop
            receive_uart_byte(rx_byte);
            expected_byte := expected_y(pixel_index);

            assert rx_byte = expected_byte
                report "ERROR: payload UART Y no coincide"
                severity failure;

            payload_checksum := payload_checksum + unsigned(rx_byte);
        end loop;

        receive_uart_byte(rx_byte);
        assert rx_byte = std_logic_vector(payload_checksum)
            report "ERROR: checksum UART no coincide"
            severity failure;

        uart_done_seen <= '1';
        report "UART payload completo y checksum correcto";

        wait;
    end process;

    watchdog : process
    begin
        wait for 80 ms;
        assert false
            report "ERROR: timeout de simulacion top completo"
            severity failure;
    end process;

end architecture;
