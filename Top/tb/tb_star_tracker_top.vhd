library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_star_tracker_top is
end entity;

architecture sim of tb_star_tracker_top is

    component star_tracker_top is
        generic (
            FRAME_WIDTH    : integer := 160;
            FRAME_HEIGHT   : integer := 120;
            ADDR_WIDTH     : integer := 15;
            UART_BAUD_RATE : integer := 921600
        );
        port (
            clk : in std_logic;
            rst : in std_logic;

            start_btn : in std_logic;
            sw        : in std_logic_vector(15 downto 0);

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
    type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

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

    constant TEST_LINE_BYTES : byte_array_t := (
        x"30", x"A0", x"31", x"B0",
        x"32", x"A1", x"33", x"B1"
    );

    constant EXPECTED_UART_BYTES : byte_array_t := (
        x"53", x"54", x"59", x"31",
        x"04", x"00",
        x"01", x"00",
        x"04", x"00", x"00", x"00",
        x"30", x"31", x"32", x"33",
        x"C6"
    );

    constant CLK_PERIOD  : time := 10 ns;
    constant PCLK_PERIOD : time := 40 ns;
    constant UART_BIT_PERIOD : time := 1 us;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal start_btn : std_logic := '0';
    signal sw        : std_logic_vector(15 downto 0) := (others => '0');

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

    signal pixel_valid  : std_logic;
    signal frame_done   : std_logic;
    signal led_read_data : std_logic_vector(7 downto 0);
    signal busy         : std_logic;
    signal ok           : std_logic;
    signal fail         : std_logic;

    signal sda_slave_drive : std_logic := 'Z';
    signal seen_pixels     : integer range 0 to 4 := 0;
    signal i2c_config_done : std_logic := '0';
    signal uart_seen_bytes : integer range 0 to EXPECTED_UART_BYTES'length := 0;

    function sda_to_bit(signal_value : std_logic) return std_logic is
    begin
        if signal_value = '0' then
            return '0';
        else
            return '1';
        end if;
    end function;

begin

    SDA <= 'H';
    SDA <= sda_slave_drive;

    uut : star_tracker_top
        generic map (
            FRAME_WIDTH    => 4,
            FRAME_HEIGHT   => 1,
            ADDR_WIDTH     => 4,
            UART_BAUD_RATE => 1000000
        )
        port map (
            clk => clk,
            rst => rst,

            start_btn => start_btn,
            sw        => sw,

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

        procedure send_camera_line(constant line_bytes : in byte_array_t) is
        begin
            cam_href <= '1';
            for index in line_bytes'range loop
                cam_data <= line_bytes(index);
                wait until rising_edge(cam_pclk);
            end loop;
            cam_href <= '0';
            cam_data <= (others => '0');
            wait until rising_edge(cam_pclk);
            wait until rising_edge(cam_pclk);
        end procedure;

    begin
        report "Inicio de simulacion star_tracker_top con init y captura";

        rst <= '1';
        start_btn <= '0';
        sw <= (others => '0');
        cam_vsync <= '1';
        cam_href <= '0';
        cam_data <= (others => '0');

        wait for 200 ns;

        rst <= '0';
        wait until rising_edge(clk);

        start_btn <= '1';

        wait until i2c_config_done = '1' or fail = '1' for 30 ms;

        assert i2c_config_done = '1'
            report "ERROR: no termino la configuracion I2C"
            severity failure;

        assert fail = '0'
            report "ERROR: fail se activo durante init"
            severity failure;

        assert cam_pwdn = '0'
            report "ERROR: cam_pwdn debe mantener la camara encendida"
            severity failure;

        assert cam_reset = '1'
            report "ERROR: cam_reset debe liberar la camara despues de rst"
            severity failure;

        for index in 0 to 9 loop
            wait until rising_edge(cam_pclk);
        end loop;

        wait until rising_edge(cam_pclk);
        wait until rising_edge(cam_pclk);
        wait until rising_edge(cam_pclk);
        cam_vsync <= '0';
        wait until rising_edge(cam_pclk);

        send_camera_line(TEST_LINE_BYTES);

        cam_vsync <= '1';
        wait until rising_edge(cam_pclk);
        wait for 1 ns;

        assert frame_done = '1'
            report "ERROR: frame_done no se activo"
            severity failure;

        assert led_read_data = x"33"
            report "ERROR: led_read_data no contiene el ultimo Y capturado"
            severity failure;

        assert seen_pixels = 4
            report "ERROR: no se observaron los 4 pixeles Y esperados"
            severity failure;

        assert fail = '0'
            report "ERROR: fail se activo durante captura"
            severity failure;

        wait until ok = '1' or fail = '1' for 1 ms;

        assert ok = '1'
            report "ERROR: ok no se activo despues del dump UART"
            severity failure;

        assert uart_seen_bytes = EXPECTED_UART_BYTES'length
            report "ERROR: no se recibio el paquete UART completo"
            severity failure;

        start_btn <= '0';

        report "Simulacion star_tracker_top finalizada correctamente";

        wait;
    end process;

    i2c_slave_model : process

        procedure wait_start is
        begin
            wait until SDA = '0' and SCL = '1';
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

        variable received_byte : std_logic_vector(7 downto 0);

    begin
        sda_slave_drive <= 'Z';

        wait until rst = '0';

        for index in EXPECTED_CONFIG'range loop

            wait_start;

            receive_master_byte(received_byte);
            assert received_byte = x"42"
                report "ERROR: byte de direccion de escritura no es 0x42"
                severity failure;
            send_ack;

            receive_master_byte(received_byte);
            assert received_byte = EXPECTED_CONFIG(index).reg_addr
                report "ERROR: direccion de registro no coincide"
                severity failure;
            send_ack;

            receive_master_byte(received_byte);
            assert received_byte = EXPECTED_CONFIG(index).reg_data
                report "ERROR: dato de registro no coincide"
                severity failure;
            send_ack;

        end loop;

        i2c_config_done <= '1';

        wait;
    end process;

    pixel_monitor : process(cam_pclk)
    begin
        if rising_edge(cam_pclk) then
            if rst = '1' then
                seen_pixels <= 0;
            elsif pixel_valid = '1' then
                seen_pixels <= seen_pixels + 1;
            end if;
        end if;
    end process;

    uart_monitor : process
        variable rx_byte : std_logic_vector(7 downto 0);
    begin
        wait until rst = '0';

        for byte_index in EXPECTED_UART_BYTES'range loop
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

            assert rx_byte = EXPECTED_UART_BYTES(byte_index)
                report "ERROR: byte UART no coincide"
                severity failure;

            uart_seen_bytes <= byte_index + 1;
        end loop;

        wait;
    end process;

end architecture;
