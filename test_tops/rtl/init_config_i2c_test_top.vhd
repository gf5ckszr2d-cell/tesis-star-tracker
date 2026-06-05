library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity init_config_i2c_test_top is
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
end entity;

architecture rtl of init_config_i2c_test_top is

    constant OV7670_ADDR : std_logic_vector(6 downto 0) := "0100001";

    signal i2c_start    : std_logic;
    signal i2c_rw       : std_logic;
    signal i2c_tx_byte0 : std_logic_vector(7 downto 0);
    signal i2c_tx_byte1 : std_logic_vector(7 downto 0);
    signal i2c_tx_count : unsigned(1 downto 0);
    signal i2c_rx_data  : std_logic_vector(7 downto 0);

    signal i2c_done_sig      : std_logic;
    signal i2c_ack_error_sig : std_logic;

    component ov7670_init_config is
        generic (
            CLK_FREQ_HZ    : integer := 100000000;
            RESET_DELAY_MS : integer := 1
        );
        port (
            clk : in std_logic;
            rst : in std_logic;

            start : in std_logic;

            i2c_done      : in std_logic;
            i2c_ack_error : in std_logic;

            i2c_start    : out std_logic;
            i2c_rw       : out std_logic;
            i2c_tx_byte0 : out std_logic_vector(7 downto 0);
            i2c_tx_byte1 : out std_logic_vector(7 downto 0);
            i2c_tx_count : out unsigned(1 downto 0);

            busy         : out std_logic;
            done         : out std_logic;
            error        : out std_logic;
            current_step : out unsigned(4 downto 0)
        );
    end component;

    component i2c_master is
        generic (
            CLK_FREQ_HZ : integer := 100000000;
            I2C_SCL_HZ  : integer := 100000
        );
        port (
            clk : in std_logic;
            rst : in std_logic;

            start      : in std_logic;
            slave_addr : in std_logic_vector(6 downto 0);
            rw         : in std_logic;

            tx_byte0 : in std_logic_vector(7 downto 0);
            tx_byte1 : in std_logic_vector(7 downto 0);
            tx_count : in unsigned(1 downto 0);

            rx_data : out std_logic_vector(7 downto 0);

            SDA : inout std_logic;
            SCL : out std_logic;

            busy      : out std_logic;
            done      : out std_logic;
            ack_error : out std_logic
        );
    end component;

begin

    i2c_done      <= i2c_done_sig;
    i2c_ack_error <= i2c_ack_error_sig;

    u_init_config : ov7670_init_config
        generic map (
            CLK_FREQ_HZ    => CLK_FREQ_HZ,
            RESET_DELAY_MS => RESET_DELAY_MS
        )
        port map (
            clk => clk,
            rst => rst,

            start => start,

            i2c_done      => i2c_done_sig,
            i2c_ack_error => i2c_ack_error_sig,

            i2c_start    => i2c_start,
            i2c_rw       => i2c_rw,
            i2c_tx_byte0 => i2c_tx_byte0,
            i2c_tx_byte1 => i2c_tx_byte1,
            i2c_tx_count => i2c_tx_count,

            busy         => init_busy,
            done         => init_done,
            error        => init_error,
            current_step => current_step
        );

    u_i2c_master : i2c_master
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ,
            I2C_SCL_HZ  => I2C_SCL_HZ
        )
        port map (
            clk => clk,
            rst => rst,

            start      => i2c_start,
            slave_addr => OV7670_ADDR,
            rw         => i2c_rw,

            tx_byte0 => i2c_tx_byte0,
            tx_byte1 => i2c_tx_byte1,
            tx_count => i2c_tx_count,

            rx_data => i2c_rx_data,

            SDA => SDA,
            SCL => SCL,

            busy      => i2c_busy,
            done      => i2c_done_sig,
            ack_error => i2c_ack_error_sig
        );

end architecture;
