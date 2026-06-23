library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity camera_config_integration_top is
    generic (
        CLK_FREQ_HZ    : integer := 100000000;
        I2C_SCL_HZ     : integer := 100000;
        RESET_DELAY_MS : integer := 1
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        init_start : in std_logic;
        runtime_enable : in std_logic;
        config_btn : in std_logic;
        param_sel : in std_logic_vector(1 downto 0);
        param_value : in std_logic_vector(7 downto 0);
        SDA : inout std_logic;
        SCL : out std_logic;
        init_busy : out std_logic;
        init_done : out std_logic;
        init_error : out std_logic;
        init_current_step : out unsigned(4 downto 0);
        runtime_busy : out std_logic;
        runtime_done : out std_logic;
        runtime_error : out std_logic;
        runtime_active_param : out std_logic_vector(1 downto 0);
        i2c_busy : out std_logic;
        i2c_done : out std_logic;
        i2c_ack_error : out std_logic;
        i2c_runtime_owner : out std_logic
    );
end entity;

architecture rtl of camera_config_integration_top is
    constant OV7670_ADDR : std_logic_vector(6 downto 0) := "0100001";

    signal init_start_i2c, init_rw : std_logic;
    signal init_byte0, init_byte1 : std_logic_vector(7 downto 0);
    signal init_count : unsigned(1 downto 0);

    signal runtime_start_i2c, runtime_rw : std_logic;
    signal runtime_byte0, runtime_byte1 : std_logic_vector(7 downto 0);
    signal runtime_count : unsigned(1 downto 0);

    signal selected_start, selected_rw : std_logic;
    signal selected_byte0, selected_byte1 : std_logic_vector(7 downto 0);
    signal selected_count : unsigned(1 downto 0);

    signal init_done_i, init_done_latched : std_logic := '0';
    signal runtime_busy_i, i2c_busy_i, i2c_done_i, i2c_error_i : std_logic;
    signal runtime_owner_i : std_logic;
    signal rx_unused : std_logic_vector(7 downto 0);
begin
    runtime_owner_i <= init_done_latched and runtime_busy_i;

    selected_start <= runtime_start_i2c when runtime_owner_i = '1' else init_start_i2c;
    selected_rw    <= runtime_rw        when runtime_owner_i = '1' else init_rw;
    selected_byte0 <= runtime_byte0     when runtime_owner_i = '1' else init_byte0;
    selected_byte1 <= runtime_byte1     when runtime_owner_i = '1' else init_byte1;
    selected_count <= runtime_count     when runtime_owner_i = '1' else init_count;

    init_done <= init_done_i;
    runtime_busy <= runtime_busy_i;
    i2c_busy <= i2c_busy_i;
    i2c_done <= i2c_done_i;
    i2c_ack_error <= i2c_error_i;
    i2c_runtime_owner <= runtime_owner_i;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                init_done_latched <= '0';
            elsif init_done_i = '1' then
                init_done_latched <= '1';
            end if;
        end if;
    end process;

    u_init : entity work.ov7670_init_config
        generic map (CLK_FREQ_HZ => CLK_FREQ_HZ, RESET_DELAY_MS => RESET_DELAY_MS)
        port map (
            clk => clk, rst => rst, start => init_start,
            i2c_done => i2c_done_i, i2c_ack_error => i2c_error_i,
            i2c_start => init_start_i2c, i2c_rw => init_rw,
            i2c_tx_byte0 => init_byte0, i2c_tx_byte1 => init_byte1,
            i2c_tx_count => init_count, busy => init_busy,
            done => init_done_i, error => init_error,
            current_step => init_current_step
        );

    u_runtime : entity work.ov7670_runtime_config
        port map (
            clk => clk, rst => rst,
            enable => runtime_enable and init_done_latched,
            config_btn => config_btn, param_sel => param_sel,
            param_value => param_value, i2c_busy => i2c_busy_i,
            i2c_done => i2c_done_i, i2c_ack_error => i2c_error_i,
            i2c_start => runtime_start_i2c, i2c_rw => runtime_rw,
            i2c_tx_byte0 => runtime_byte0, i2c_tx_byte1 => runtime_byte1,
            i2c_tx_count => runtime_count, busy => runtime_busy_i,
            done => runtime_done, error => runtime_error,
            active_param => runtime_active_param
        );

    u_i2c : entity work.i2c_master
        generic map (CLK_FREQ_HZ => CLK_FREQ_HZ, I2C_SCL_HZ => I2C_SCL_HZ)
        port map (
            clk => clk, rst => rst, start => selected_start,
            slave_addr => OV7670_ADDR, rw => selected_rw,
            tx_byte0 => selected_byte0, tx_byte1 => selected_byte1,
            tx_count => selected_count, rx_data => rx_unused,
            SDA => SDA, SCL => SCL, busy => i2c_busy_i,
            done => i2c_done_i, ack_error => i2c_error_i
        );
end architecture;
