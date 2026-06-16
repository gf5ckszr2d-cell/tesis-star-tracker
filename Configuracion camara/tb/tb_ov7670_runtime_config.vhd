library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_ov7670_runtime_config is
end entity;

architecture sim of tb_ov7670_runtime_config is

    component ov7670_runtime_config
        port (
            clk : in std_logic;
            rst : in std_logic;

            enable      : in std_logic;
            config_btn  : in std_logic;
            param_sel   : in std_logic_vector(1 downto 0);
            param_value : in std_logic_vector(7 downto 0);

            i2c_busy      : in std_logic;
            i2c_done      : in std_logic;
            i2c_ack_error : in std_logic;

            i2c_start    : out std_logic;
            i2c_rw       : out std_logic;
            i2c_tx_byte0 : out std_logic_vector(7 downto 0);
            i2c_tx_byte1 : out std_logic_vector(7 downto 0);
            i2c_tx_count : out unsigned(1 downto 0);

            busy  : out std_logic;
            done  : out std_logic;
            error : out std_logic;
            active_param : out std_logic_vector(1 downto 0)
        );
    end component;

    constant CLK_PERIOD : time := 10 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal enable      : std_logic := '0';
    signal config_btn  : std_logic := '0';
    signal param_sel   : std_logic_vector(1 downto 0) := (others => '0');
    signal param_value : std_logic_vector(7 downto 0) := (others => '0');

    signal i2c_busy      : std_logic := '0';
    signal i2c_done      : std_logic := '0';
    signal i2c_ack_error : std_logic := '0';

    signal i2c_start    : std_logic;
    signal i2c_rw       : std_logic;
    signal i2c_tx_byte0 : std_logic_vector(7 downto 0);
    signal i2c_tx_byte1 : std_logic_vector(7 downto 0);
    signal i2c_tx_count : unsigned(1 downto 0);

    signal busy : std_logic;
    signal done : std_logic;
    signal error : std_logic;
    signal active_param : std_logic_vector(1 downto 0);

    signal write_count : integer := 0;

begin

    uut : ov7670_runtime_config
        port map (
            clk => clk,
            rst => rst,

            enable      => enable,
            config_btn  => config_btn,
            param_sel   => param_sel,
            param_value => param_value,

            i2c_busy      => i2c_busy,
            i2c_done      => i2c_done,
            i2c_ack_error => i2c_ack_error,

            i2c_start    => i2c_start,
            i2c_rw       => i2c_rw,
            i2c_tx_byte0 => i2c_tx_byte0,
            i2c_tx_byte1 => i2c_tx_byte1,
            i2c_tx_count => i2c_tx_count,

            busy => busy,
            done => done,
            error => error,
            active_param => active_param
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
        variable total_writes : integer := 0;

        procedure wait_clocks(constant count : in integer) is
        begin
            for index in 1 to count loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        procedure pulse_config(
            constant sel : in std_logic_vector(1 downto 0);
            constant value : in std_logic_vector(7 downto 0);
            constant gate_enable : in std_logic
        ) is
        begin
            enable <= gate_enable;
            param_sel <= sel;
            param_value <= value;
            wait_clocks(2);
            config_btn <= '1';
            wait_clocks(3);
            config_btn <= '0';
            wait_clocks(1);
        end procedure;

        procedure expect_write(
            constant expected_addr : in std_logic_vector(7 downto 0);
            constant expected_data : in std_logic_vector(7 downto 0)
        ) is
        begin
            wait until i2c_start = '1';
            wait for 1 ns;

            assert i2c_rw = '0'
                report "ERROR: runtime_config solicito lectura; se esperaba escritura"
                severity failure;

            assert i2c_tx_count = to_unsigned(2, 2)
                report "ERROR: runtime_config debe enviar dos bytes"
                severity failure;

            assert i2c_tx_byte0 = expected_addr
                report "ERROR: direccion de registro runtime incorrecta"
                severity failure;

            assert i2c_tx_byte1 = expected_data
                report "ERROR: dato de registro runtime incorrecto"
                severity failure;

            wait until rising_edge(clk);
            i2c_busy <= '1';
            wait_clocks(4);
            i2c_done <= '1';
            i2c_ack_error <= '0';
            wait_clocks(1);
            i2c_done <= '0';
            i2c_busy <= '0';
            wait_clocks(2);

            total_writes := total_writes + 1;
            write_count <= total_writes;
        end procedure;

    begin
        report "Inicio tb_ov7670_runtime_config";

        rst <= '1';
        wait_clocks(5);
        rst <= '0';
        wait_clocks(5);

        pulse_config("00", x"60", '0');
        wait_clocks(20);

        assert write_count = 0
            report "ERROR: btn_config no debe funcionar con enable=0"
            severity failure;

        pulse_config("00", x"60", '1');
        expect_write(x"56", x"60");

        pulse_config("01", x"12", '1');
        expect_write(x"13", x"8B");
        expect_write(x"00", x"12");

        pulse_config("10", x"34", '1');
        expect_write(x"13", x"8E");
        expect_write(x"10", x"34");

        pulse_config("11", x"90", '1');
        expect_write(x"55", x"90");

        assert error = '0'
            report "ERROR: runtime_config marco error sin ack_error"
            severity failure;

        assert total_writes = 6
            report "ERROR: cantidad total de escrituras runtime incorrecta"
            severity failure;

        report "PASS_OV7670_RUNTIME_CONFIG: contraste, ganancia, exposicion y brillo verificados";
        finish;
    end process;

    watchdog : process
    begin
        wait for 2 ms;
        assert false
            report "ERROR: timeout tb_ov7670_runtime_config"
            severity failure;
    end process;

end architecture;
