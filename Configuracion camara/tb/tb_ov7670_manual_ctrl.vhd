library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ov7670_manual_ctrl is
end entity;

architecture sim of tb_ov7670_manual_ctrl is

    component ov7670_manual_ctrl is
        port (
            clk : in std_logic;
            rst : in std_logic;

            start_btn : in std_logic;
            sw        : in std_logic_vector(15 downto 0);

            i2c_done      : in std_logic;
            i2c_ack_error : in std_logic;
            i2c_rx_data   : in std_logic_vector(7 downto 0);

            i2c_start    : out std_logic;
            i2c_rw       : out std_logic;
            i2c_tx_byte0 : out std_logic_vector(7 downto 0);
            i2c_tx_byte1 : out std_logic_vector(7 downto 0);
            i2c_tx_count : out unsigned(1 downto 0);

            led_read_data : out std_logic_vector(7 downto 0);
            busy          : out std_logic;
            ok            : out std_logic;
            fail          : out std_logic
        );
    end component;

    constant CLK_PERIOD : time := 10 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal start_btn : std_logic := '0';
    signal sw        : std_logic_vector(15 downto 0) := (others => '0');

    signal i2c_done      : std_logic := '0';
    signal i2c_ack_error : std_logic := '0';
    signal i2c_rx_data   : std_logic_vector(7 downto 0) := (others => '0');

    signal i2c_start    : std_logic;
    signal i2c_rw       : std_logic;
    signal i2c_tx_byte0 : std_logic_vector(7 downto 0);
    signal i2c_tx_byte1 : std_logic_vector(7 downto 0);
    signal i2c_tx_count : unsigned(1 downto 0);

    signal led_read_data : std_logic_vector(7 downto 0);
    signal busy          : std_logic;
    signal ok            : std_logic;
    signal fail          : std_logic;

begin

    uut : ov7670_manual_ctrl
        port map (
            clk => clk,
            rst => rst,

            start_btn => start_btn,
            sw        => sw,

            i2c_done      => i2c_done,
            i2c_ack_error => i2c_ack_error,
            i2c_rx_data   => i2c_rx_data,

            i2c_start    => i2c_start,
            i2c_rw       => i2c_rw,
            i2c_tx_byte0 => i2c_tx_byte0,
            i2c_tx_byte1 => i2c_tx_byte1,
            i2c_tx_count => i2c_tx_count,

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

    stimulus : process

        procedure check_i2c_order(
            constant exp_rw       : in std_logic;
            constant exp_tx_byte0 : in std_logic_vector(7 downto 0);
            constant exp_tx_byte1 : in std_logic_vector(7 downto 0);
            constant exp_tx_count : in unsigned(1 downto 0)
        ) is
        begin
            wait until i2c_start = '1';
            wait for 1 ns;

            assert i2c_rw = exp_rw
                report "ERROR: i2c_rw no coincide"
                severity failure;

            assert i2c_tx_byte0 = exp_tx_byte0
                report "ERROR: i2c_tx_byte0 no coincide"
                severity failure;

            assert i2c_tx_byte1 = exp_tx_byte1
                report "ERROR: i2c_tx_byte1 no coincide"
                severity failure;

            assert i2c_tx_count = exp_tx_count
                report "ERROR: i2c_tx_count no coincide"
                severity failure;

            wait until rising_edge(clk);
        end procedure;

        procedure send_i2c_done(
            constant rx_value  : in std_logic_vector(7 downto 0);
            constant ack_value : in std_logic
        ) is
        begin
            wait until rising_edge(clk);
            i2c_rx_data   <= rx_value;
            i2c_ack_error <= ack_value;
            i2c_done      <= '1';

            wait until rising_edge(clk);
            i2c_done      <= '0';
            i2c_ack_error <= '0';
        end procedure;

    begin

        report "Inicio de simulacion ov7670_manual_ctrl";

        rst <= '1';
        start_btn <= '0';
        sw <= (others => '0');
        i2c_done <= '0';
        i2c_ack_error <= '0';
        i2c_rx_data <= (others => '0');

        wait for 5 * CLK_PERIOD;

        rst <= '0';
        wait until rising_edge(clk);

        sw <= x"1502";
        wait until rising_edge(clk);

        start_btn <= '1';

        check_i2c_order('0', x"15", x"02", to_unsigned(2, 2));
        send_i2c_done(x"00", '0');

        check_i2c_order('0', x"15", x"00", to_unsigned(1, 2));
        send_i2c_done(x"00", '0');

        check_i2c_order('1', x"00", x"00", to_unsigned(0, 2));
        send_i2c_done(x"02", '0');

        wait for 4 * CLK_PERIOD;

        assert led_read_data = x"02"
            report "ERROR: led_read_data no coincide con el dato leido"
            severity failure;

        assert ok = '1'
            report "ERROR: ok no se activo en verificacion correcta"
            severity failure;

        assert fail = '0'
            report "ERROR: fail se activo en verificacion correcta"
            severity failure;

        assert busy = '0'
            report "ERROR: busy no regreso a 0"
            severity failure;

        start_btn <= '0';
        wait for 3 * CLK_PERIOD;

        sw <= x"1234";
        wait until rising_edge(clk);

        start_btn <= '1';

        check_i2c_order('0', x"12", x"34", to_unsigned(2, 2));
        send_i2c_done(x"00", '0');

        check_i2c_order('0', x"12", x"00", to_unsigned(1, 2));
        send_i2c_done(x"00", '0');

        check_i2c_order('1', x"00", x"00", to_unsigned(0, 2));
        send_i2c_done(x"35", '0');

        wait for 4 * CLK_PERIOD;

        assert led_read_data = x"35"
            report "ERROR: led_read_data no coincide en prueba fallida"
            severity failure;

        assert ok = '0'
            report "ERROR: ok se activo cuando no debia"
            severity failure;

        assert fail = '1'
            report "ERROR: fail no se activo cuando el dato no coincide"
            severity failure;

        start_btn <= '0';
        wait for 3 * CLK_PERIOD;

        report "Simulacion ov7670_manual_ctrl finalizada correctamente";

        wait;

    end process;

end architecture;