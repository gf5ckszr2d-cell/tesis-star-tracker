library ieee;
use ieee.std_logic_1164.all;

entity star_tracker_top_arty_z7_10 is
    port (
        clk_125mhz : in std_logic;
        rst_btn    : in std_logic;
        start_btn  : in std_logic;

        SDA : inout std_logic;
        SCL : out std_logic;

        cam_xclk  : out std_logic;
        cam_pclk  : in std_logic;
        cam_vsync : in std_logic;
        cam_href  : in std_logic;
        cam_data  : in std_logic_vector(7 downto 0);
        cam_pwdn  : out std_logic;
        cam_reset : out std_logic;

        uart_tx_pl : out std_logic;

        led : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of star_tracker_top_arty_z7_10 is

    signal clk_100mhz : std_logic;
    signal clk_locked : std_logic;
    signal core_rst   : std_logic;

    signal pixel_valid_s  : std_logic;
    signal frame_done_s   : std_logic;
    signal led_read_data_s : std_logic_vector(7 downto 0);
    signal busy_s         : std_logic;
    signal ok_s           : std_logic;
    signal fail_s         : std_logic;

    component artyz7_clk_125_to_100
        port (
            clk_125mhz : in std_logic;
            rst        : in std_logic;

            clk_100mhz : out std_logic;
            locked     : out std_logic
        );
    end component;

    component star_tracker_top
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

begin

    core_rst <= rst_btn or not clk_locked;

    led(0) <= busy_s;
    led(1) <= ok_s;
    led(2) <= fail_s;
    led(3) <= frame_done_s;

    u_clk_125_to_100 : artyz7_clk_125_to_100
        port map (
            clk_125mhz => clk_125mhz,
            rst        => rst_btn,
            clk_100mhz => clk_100mhz,
            locked     => clk_locked
        );

    u_star_tracker_top : star_tracker_top
        port map (
            clk => clk_100mhz,
            rst => core_rst,

            start_btn => start_btn,

            SDA => SDA,
            SCL => SCL,

            cam_xclk  => cam_xclk,
            cam_pclk  => cam_pclk,
            cam_vsync => cam_vsync,
            cam_href  => cam_href,
            cam_data  => cam_data,
            cam_pwdn  => cam_pwdn,
            cam_reset => cam_reset,

            uart_tx => uart_tx_pl,

            pixel_valid => pixel_valid_s,
            frame_done  => frame_done_s,

            led_read_data => led_read_data_s,
            busy          => busy_s,
            ok            => ok_s,
            fail          => fail_s
        );

end architecture;

