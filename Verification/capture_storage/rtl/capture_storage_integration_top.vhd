library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity capture_storage_integration_top is
    generic (
        FRAME_WIDTH : integer := 160;
        FRAME_HEIGHT : integer := 120;
        ADDR_WIDTH : integer := 15
    );
    port (
        pclk : in std_logic;
        rst : in std_logic;
        enable : in std_logic;
        arm_capture : in std_logic;
        dump_done_toggle : in std_logic;
        cam_vsync : in std_logic;
        cam_href : in std_logic;
        cam_data : in std_logic_vector(7 downto 0);
        rd_clk : in std_logic;
        rd_addr : in unsigned(ADDR_WIDTH - 1 downto 0);
        rd_data : out std_logic_vector(7 downto 0);
        pixel_y : out std_logic_vector(7 downto 0);
        pixel_valid : out std_logic;
        pixel_x : out unsigned(9 downto 0);
        pixel_y_pos : out unsigned(9 downto 0);
        frame_active : out std_logic;
        frame_done : out std_logic;
        wr_en : out std_logic;
        wr_addr : out unsigned(ADDR_WIDTH - 1 downto 0);
        wr_data : out std_logic_vector(7 downto 0);
        capture_busy : out std_logic;
        frame_ready : out std_logic;
        frame_ready_toggle : out std_logic;
        capture_overflow : out std_logic;
        store_overflow : out std_logic
    );
end entity;

architecture rtl of capture_storage_integration_top is
    signal pixel_y_i : std_logic_vector(7 downto 0);
    signal pixel_valid_i : std_logic;
    signal pixel_x_i, pixel_y_pos_i : unsigned(9 downto 0);
    signal frame_active_i, frame_done_i, capture_overflow_i : std_logic;
    signal wr_en_i : std_logic;
    signal wr_addr_i : unsigned(ADDR_WIDTH - 1 downto 0);
    signal wr_data_i : std_logic_vector(7 downto 0);
begin
    pixel_y <= pixel_y_i;
    pixel_valid <= pixel_valid_i;
    pixel_x <= pixel_x_i;
    pixel_y_pos <= pixel_y_pos_i;
    frame_active <= frame_active_i;
    frame_done <= frame_done_i;
    capture_overflow <= capture_overflow_i;
    wr_en <= wr_en_i;
    wr_addr <= wr_addr_i;
    wr_data <= wr_data_i;

    u_capture : entity work.ov7670_capture_y_stream
        generic map (
            FRAME_WIDTH => FRAME_WIDTH, FRAME_HEIGHT => FRAME_HEIGHT,
            VSYNC_ACTIVE_LEVEL => '1', HREF_ACTIVE_LEVEL => '1'
        )
        port map (
            pclk => pclk, rst => rst, enable => enable,
            vsync => cam_vsync, href => cam_href, data => cam_data,
            pixel_y => pixel_y_i, pixel_valid => pixel_valid_i,
            pixel_x => pixel_x_i, pixel_y_pos => pixel_y_pos_i,
            frame_active => frame_active_i, frame_done => frame_done_i,
            overflow => capture_overflow_i
        );

    u_store : entity work.frame_capture_store
        generic map (
            FRAME_WIDTH => FRAME_WIDTH, FRAME_HEIGHT => FRAME_HEIGHT,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            pclk => pclk, rst => rst, arm_capture => arm_capture,
            dump_done_toggle => dump_done_toggle, pixel_y => pixel_y_i,
            pixel_valid => pixel_valid_i, pixel_x => pixel_x_i,
            pixel_y_pos => pixel_y_pos_i, frame_done => frame_done_i,
            wr_en => wr_en_i, wr_addr => wr_addr_i, wr_data => wr_data_i,
            capture_busy => capture_busy, frame_ready => frame_ready,
            frame_ready_toggle => frame_ready_toggle, overflow => store_overflow
        );

    u_bram : entity work.framebuffer_y_bram
        generic map (
            ADDR_WIDTH => ADDR_WIDTH, DATA_WIDTH => 8,
            FRAME_PIXELS => FRAME_WIDTH * FRAME_HEIGHT
        )
        port map (
            wr_clk => pclk, wr_en => wr_en_i, wr_addr => wr_addr_i,
            wr_data => wr_data_i, rd_clk => rd_clk,
            rd_addr => rd_addr, rd_data => rd_data
        );
end architecture;
