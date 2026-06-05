library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_init_config_i2c_test_top is
end entity;

architecture sim of tb_init_config_i2c_test_top is

    component init_config_i2c_test_top is
        generic (
            CLK_FREQ_HZ    : integer := 100000000;
            I2C_SCL_HZ     : integer := 100000;
            RESET_DELAY_MS : integer := 1
        );
        port (
            clk : in std_logic;
            rst : in std_logic;

            start : in std_logic;

            SDA : inout std_logic;
            SCL : out std_logic;

            init_busy    : out std_logic;
            init_done    : out std_logic;
            init_error   : out std_logic;
            current_step : out unsigned(4 downto 0);

            i2c_busy      : out std_logic;
            i2c_done      : out std_logic;
            i2c_ack_error : out std_logic
        );
    end component;

    type reg_pair_t is record
        reg_addr : std_logic_vector(7 downto 0);
        reg_data : std_logic_vector(7 downto 0);
    end record;

    type config_rom_t is array (natural range <>) of reg_pair_t;

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

    constant CLK_PERIOD : time := 10 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal start : std_logic := '0';

    signal SDA : std_logic := 'H';
    signal SCL : std_logic;

    signal init_busy    : std_logic;
    signal init_done    : std_logic;
    signal init_error   : std_logic;
    signal current_step : unsigned(4 downto 0);

    signal i2c_busy      : std_logic;
    signal i2c_done      : std_logic;
    signal i2c_ack_error : std_logic;

    signal sda_slave_drive : std_logic := 'Z';
    signal received_count  : integer range 0 to EXPECTED_CONFIG'length := 0;

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

    uut : init_config_i2c_test_top
        generic map (
            CLK_FREQ_HZ    => 100000000,
            I2C_SCL_HZ     => 100000,
            RESET_DELAY_MS => 1
        )
        port map (
            clk => clk,
            rst => rst,

            start => start,

            SDA => SDA,
            SCL => SCL,

            init_busy    => init_busy,
            init_done    => init_done,
            init_error   => init_error,
            current_step => current_step,

            i2c_busy      => i2c_busy,
            i2c_done      => i2c_done,
            i2c_ack_error => i2c_ack_error
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
    begin
        report "Inicio test_top: ov7670_init_config + i2c_master";

        rst <= '1';
        start <= '0';

        wait for 5 * CLK_PERIOD;

        rst <= '0';
        wait until rising_edge(clk);

        start <= '1';

        wait until init_done = '1' or init_error = '1' for 20 ms;

        assert init_done = '1'
            report "ERROR: timeout esperando init_done"
            severity failure;

        assert init_error = '0'
            report "ERROR: init_error activo"
            severity failure;

        assert i2c_ack_error = '0'
            report "ERROR: i2c_ack_error activo"
            severity failure;

        assert received_count = EXPECTED_CONFIG'length
            report "ERROR: no se recibieron todos los registros esperados"
            severity failure;

        start <= '0';
        wait for 5 * CLK_PERIOD;

        assert init_busy = '0'
            report "ERROR: init_busy debe quedar en 0"
            severity failure;

        report "PASS_TEST_TOP_INIT_CONFIG_I2C: init_config + i2c_master correctos";

        finish;
    end process;

    slave_model : process

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
                report "ERROR: byte de direccion SCCB no es 0x42"
                severity failure;
            send_ack;

            receive_master_byte(received_byte);
            assert received_byte = EXPECTED_CONFIG(index).reg_addr
                report "ERROR: registro OV7670 no coincide"
                severity failure;
            send_ack;

            receive_master_byte(received_byte);
            assert received_byte = EXPECTED_CONFIG(index).reg_data
                report "ERROR: dato OV7670 no coincide"
                severity failure;
            send_ack;

            assert current_step = to_unsigned(index, current_step'length)
                report "ERROR: current_step no coincide con el registro enviado"
                severity failure;

            received_count <= index + 1;
            report "Registro OV7670 verificado en test_top: index=" & integer'image(index);

        end loop;

        wait;
    end process;

    watchdog : process
    begin
        wait for 25 ms;
        assert false
            report "ERROR: timeout test_top init_config_i2c"
            severity failure;
    end process;

end architecture;
