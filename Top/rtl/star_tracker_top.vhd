library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity star_tracker_top is
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
end entity;

architecture rtl of star_tracker_top is

    constant OV7670_ADDR  : std_logic_vector(6 downto 0) := "0100001";
    constant FRAME_PIXELS : integer := FRAME_WIDTH * FRAME_HEIGHT;

    signal i2c_start    : std_logic;
    signal i2c_rw       : std_logic;
    signal i2c_tx_byte0 : std_logic_vector(7 downto 0);
    signal i2c_tx_byte1 : std_logic_vector(7 downto 0);
    signal i2c_tx_count : unsigned(1 downto 0);

    signal i2c_rx_data   : std_logic_vector(7 downto 0);
    signal i2c_done      : std_logic;
    signal i2c_ack_error : std_logic;
    signal i2c_busy      : std_logic;

    signal init_i2c_start    : std_logic;
    signal init_i2c_rw       : std_logic;
    signal init_i2c_tx_byte0 : std_logic_vector(7 downto 0);
    signal init_i2c_tx_byte1 : std_logic_vector(7 downto 0);
    signal init_i2c_tx_count : unsigned(1 downto 0);

    signal runtime_i2c_start    : std_logic;
    signal runtime_i2c_rw       : std_logic;
    signal runtime_i2c_tx_byte0 : std_logic_vector(7 downto 0);
    signal runtime_i2c_tx_byte1 : std_logic_vector(7 downto 0);
    signal runtime_i2c_tx_count : unsigned(1 downto 0);
    signal runtime_busy         : std_logic;
    signal runtime_done         : std_logic;
    signal runtime_error        : std_logic;
    signal runtime_error_latched : std_logic := '0';
    signal runtime_active_param : std_logic_vector(1 downto 0);
    signal i2c_runtime_owner    : std_logic;

    signal xclk_locked : std_logic;
    signal xclk_ready  : std_logic;

    signal init_busy          : std_logic;
    signal init_done          : std_logic;
    signal init_error         : std_logic;
    signal init_done_latched  : std_logic := '0';
    signal init_error_latched : std_logic := '0';
    signal init_current_step  : unsigned(4 downto 0);
    signal init_start         : std_logic;

    signal capture_rst          : std_logic;
    signal capture_pixel_y      : std_logic_vector(7 downto 0);
    signal capture_pixel_valid  : std_logic;
    signal capture_pixel_x      : unsigned(9 downto 0);
    signal capture_pixel_y_pos  : unsigned(9 downto 0);
    signal capture_frame_active : std_logic;
    signal capture_frame_done   : std_logic;
    signal capture_overflow     : std_logic;
    signal init_done_pclk_meta  : std_logic := '0';
    signal init_done_pclk       : std_logic := '0';
    signal init_done_pclk_prev  : std_logic := '0';

    signal start_btn_pclk_meta : std_logic := '0';
    signal start_btn_pclk      : std_logic := '0';
    signal start_btn_pclk_prev : std_logic := '0';
    signal capture_arm_pulse   : std_logic := '0';

    signal fb_wr_en   : std_logic;
    signal fb_wr_addr : unsigned(ADDR_WIDTH - 1 downto 0);
    signal fb_wr_data : std_logic_vector(7 downto 0);
    signal fb_rd_addr : unsigned(ADDR_WIDTH - 1 downto 0);
    signal fb_rd_data : std_logic_vector(7 downto 0);

    signal store_capture_busy       : std_logic;
    signal store_frame_ready        : std_logic;
    signal store_frame_ready_toggle : std_logic;
    signal store_overflow           : std_logic;

    signal frame_ready_toggle_meta : std_logic := '0';
    signal frame_ready_toggle_sys  : std_logic := '0';

    signal dump_done_toggle      : std_logic;
    signal dump_done_toggle_meta : std_logic := '0';
    signal dump_done_toggle_pclk : std_logic := '0';
    signal dump_busy             : std_logic;
    signal dump_done             : std_logic;
    signal dump_done_latched     : std_logic := '0';

    signal uart_start : std_logic;
    signal uart_data  : std_logic_vector(7 downto 0);
    signal uart_busy  : std_logic;
    signal uart_done  : std_logic;
    signal uart_tx_line : std_logic;

    component ov7670_xclk_gen
        port (
            clk_100mhz : in std_logic;
            rst        : in std_logic;

            xclk   : out std_logic;
            locked : out std_logic
        );
    end component;

    component ov7670_init_config
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

    component ov7670_capture_y_stream
        generic (
            FRAME_WIDTH        : integer := 160;
            FRAME_HEIGHT       : integer := 120;
            VSYNC_ACTIVE_LEVEL : std_logic := '1';
            HREF_ACTIVE_LEVEL  : std_logic := '1'
        );
        port (
            pclk   : in std_logic;
            rst    : in std_logic;
            enable : in std_logic;

            vsync : in std_logic;
            href  : in std_logic;
            data  : in std_logic_vector(7 downto 0);

            pixel_y      : out std_logic_vector(7 downto 0);
            pixel_valid  : out std_logic;
            pixel_x      : out unsigned(9 downto 0);
            pixel_y_pos  : out unsigned(9 downto 0);
            frame_active : out std_logic;
            frame_done   : out std_logic;
            overflow     : out std_logic
        );
    end component;

    component frame_capture_store
        generic (
            FRAME_WIDTH  : integer := 160;
            FRAME_HEIGHT : integer := 120;
            ADDR_WIDTH   : integer := 15
        );
        port (
            pclk : in std_logic;
            rst  : in std_logic;

            arm_capture      : in std_logic;
            dump_done_toggle : in std_logic;

            pixel_y      : in std_logic_vector(7 downto 0);
            pixel_valid  : in std_logic;
            pixel_x      : in unsigned(9 downto 0);
            pixel_y_pos  : in unsigned(9 downto 0);
            frame_done   : in std_logic;

            wr_en   : out std_logic;
            wr_addr : out unsigned(ADDR_WIDTH - 1 downto 0);
            wr_data : out std_logic_vector(7 downto 0);

            capture_busy       : out std_logic;
            frame_ready        : out std_logic;
            frame_ready_toggle : out std_logic;
            overflow           : out std_logic
        );
    end component;

    component framebuffer_y_bram
        generic (
            ADDR_WIDTH   : integer := 15;
            DATA_WIDTH   : integer := 8;
            FRAME_PIXELS : integer := 19200
        );
        port (
            wr_clk  : in std_logic;
            wr_en   : in std_logic;
            wr_addr : in unsigned(ADDR_WIDTH - 1 downto 0);
            wr_data : in std_logic_vector(DATA_WIDTH - 1 downto 0);

            rd_clk  : in std_logic;
            rd_addr : in unsigned(ADDR_WIDTH - 1 downto 0);
            rd_data : out std_logic_vector(DATA_WIDTH - 1 downto 0)
        );
    end component;

    component frame_uart_dump
        generic (
            FRAME_WIDTH  : integer := 160;
            FRAME_HEIGHT : integer := 120;
            ADDR_WIDTH   : integer := 15
        );
        port (
            clk : in std_logic;
            rst : in std_logic;

            frame_ready_toggle : in std_logic;

            rd_addr : out unsigned(ADDR_WIDTH - 1 downto 0);
            rd_data : in std_logic_vector(7 downto 0);

            uart_busy  : in std_logic;
            uart_done  : in std_logic;
            uart_start : out std_logic;
            uart_data  : out std_logic_vector(7 downto 0);

            dump_busy        : out std_logic;
            dump_done        : out std_logic;
            dump_done_toggle : out std_logic
        );
    end component;

    component i2c_master
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

begin

    cam_pwdn  <= '0';
    cam_reset <= not rst;
    uart_tx   <= uart_tx_line;

    xclk_ready <= '1' when SIM_BYPASS_XCLK_LOCK else xclk_locked;
    init_start <= start_btn and xclk_ready and not init_done_latched;
    capture_rst <= rst or not init_done_pclk or not store_capture_busy;
    i2c_runtime_owner <= init_done_latched and runtime_busy;

    i2c_start    <= runtime_i2c_start    when i2c_runtime_owner = '1' else init_i2c_start;
    i2c_rw       <= runtime_i2c_rw       when i2c_runtime_owner = '1' else init_i2c_rw;
    i2c_tx_byte0 <= runtime_i2c_tx_byte0 when i2c_runtime_owner = '1' else init_i2c_tx_byte0;
    i2c_tx_byte1 <= runtime_i2c_tx_byte1 when i2c_runtime_owner = '1' else init_i2c_tx_byte1;
    i2c_tx_count <= runtime_i2c_tx_count when i2c_runtime_owner = '1' else init_i2c_tx_count;

    led_read_data <= capture_pixel_y;
    busy          <= init_busy or runtime_busy or i2c_busy or store_capture_busy or dump_busy or uart_busy;
    ok            <= init_done_latched and dump_done_latched;
    fail          <= init_error_latched or runtime_error_latched or capture_overflow or store_overflow;
    pixel_valid   <= capture_pixel_valid;
    frame_done    <= capture_frame_done;

    u_xclk_gen : ov7670_xclk_gen
        port map (
            clk_100mhz => clk,
            rst        => rst,
            xclk       => cam_xclk,
            locked     => xclk_locked
        );

    u_init_config : ov7670_init_config
        port map (
            clk => clk,
            rst => rst,

            start => init_start,

            i2c_done      => i2c_done,
            i2c_ack_error => i2c_ack_error,

            i2c_start    => init_i2c_start,
            i2c_rw       => init_i2c_rw,
            i2c_tx_byte0 => init_i2c_tx_byte0,
            i2c_tx_byte1 => init_i2c_tx_byte1,
            i2c_tx_count => init_i2c_tx_count,

            busy         => init_busy,
            done         => init_done,
            error        => init_error,
            current_step => init_current_step
        );

    u_runtime_config : ov7670_runtime_config
        port map (
            clk => clk,
            rst => rst,

            enable      => sw(15),
            config_btn  => btn_config,
            param_sel   => sw(14 downto 13),
            param_value => sw(7 downto 0),

            i2c_busy      => i2c_busy,
            i2c_done      => i2c_done,
            i2c_ack_error => i2c_ack_error,

            i2c_start    => runtime_i2c_start,
            i2c_rw       => runtime_i2c_rw,
            i2c_tx_byte0 => runtime_i2c_tx_byte0,
            i2c_tx_byte1 => runtime_i2c_tx_byte1,
            i2c_tx_count => runtime_i2c_tx_count,

            busy  => runtime_busy,
            done  => runtime_done,
            error => runtime_error,
            active_param => runtime_active_param
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                init_done_latched  <= '0';
                init_error_latched <= '0';
                runtime_error_latched <= '0';
                dump_done_latched  <= '0';
            else
                if init_done = '1' then
                    init_done_latched <= '1';
                end if;

                if init_error = '1' then
                    init_error_latched <= '1';
                end if;

                if runtime_error = '1' then
                    runtime_error_latched <= '1';
                end if;

                if dump_done = '1' then
                    dump_done_latched <= '1';
                end if;
            end if;
        end if;
    end process;

    u_i2c_master : i2c_master
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
            done      => i2c_done,
            ack_error => i2c_ack_error
        );

    process(cam_pclk)
    begin
        if rising_edge(cam_pclk) then
            if rst = '1' then
                init_done_pclk_meta <= '0';
                init_done_pclk      <= '0';
                init_done_pclk_prev <= '0';
                start_btn_pclk_meta <= '0';
                start_btn_pclk      <= '0';
                start_btn_pclk_prev <= '0';
                capture_arm_pulse   <= '0';
                dump_done_toggle_meta <= '0';
                dump_done_toggle_pclk <= '0';
            else
                init_done_pclk_meta <= init_done_latched;
                init_done_pclk      <= init_done_pclk_meta;
                init_done_pclk_prev <= init_done_pclk;

                start_btn_pclk_meta <= start_btn;
                start_btn_pclk      <= start_btn_pclk_meta;
                start_btn_pclk_prev <= start_btn_pclk;

                dump_done_toggle_meta <= dump_done_toggle;
                dump_done_toggle_pclk <= dump_done_toggle_meta;

                capture_arm_pulse <= '0';

                if init_done_pclk = '1' and store_frame_ready = '0' and store_capture_busy = '0' then
                    if init_done_pclk_prev = '0' or
                       (start_btn_pclk = '1' and start_btn_pclk_prev = '0') then
                        capture_arm_pulse <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    u_capture_y_stream : ov7670_capture_y_stream
        generic map (
            FRAME_WIDTH  => FRAME_WIDTH,
            FRAME_HEIGHT => FRAME_HEIGHT
        )
        port map (
            pclk   => cam_pclk,
            rst    => capture_rst,
            enable => store_capture_busy,

            vsync => cam_vsync,
            href  => cam_href,
            data  => cam_data,

            pixel_y      => capture_pixel_y,
            pixel_valid  => capture_pixel_valid,
            pixel_x      => capture_pixel_x,
            pixel_y_pos  => capture_pixel_y_pos,
            frame_active => capture_frame_active,
            frame_done   => capture_frame_done,
            overflow     => capture_overflow
        );

    u_frame_capture_store : frame_capture_store
        generic map (
            FRAME_WIDTH  => FRAME_WIDTH,
            FRAME_HEIGHT => FRAME_HEIGHT,
            ADDR_WIDTH   => ADDR_WIDTH
        )
        port map (
            pclk => cam_pclk,
            rst  => rst,

            arm_capture      => capture_arm_pulse,
            dump_done_toggle => dump_done_toggle_pclk,

            pixel_y      => capture_pixel_y,
            pixel_valid  => capture_pixel_valid,
            pixel_x      => capture_pixel_x,
            pixel_y_pos  => capture_pixel_y_pos,
            frame_done   => capture_frame_done,

            wr_en   => fb_wr_en,
            wr_addr => fb_wr_addr,
            wr_data => fb_wr_data,

            capture_busy       => store_capture_busy,
            frame_ready        => store_frame_ready,
            frame_ready_toggle => store_frame_ready_toggle,
            overflow           => store_overflow
        );

    u_framebuffer_y_bram : framebuffer_y_bram
        generic map (
            ADDR_WIDTH   => ADDR_WIDTH,
            DATA_WIDTH   => 8,
            FRAME_PIXELS => FRAME_PIXELS
        )
        port map (
            wr_clk  => cam_pclk,
            wr_en   => fb_wr_en,
            wr_addr => fb_wr_addr,
            wr_data => fb_wr_data,

            rd_clk  => clk,
            rd_addr => fb_rd_addr,
            rd_data => fb_rd_data
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                frame_ready_toggle_meta <= '0';
                frame_ready_toggle_sys  <= '0';
            else
                frame_ready_toggle_meta <= store_frame_ready_toggle;
                frame_ready_toggle_sys  <= frame_ready_toggle_meta;
            end if;
        end if;
    end process;

    u_frame_uart_dump : frame_uart_dump
        generic map (
            FRAME_WIDTH  => FRAME_WIDTH,
            FRAME_HEIGHT => FRAME_HEIGHT,
            ADDR_WIDTH   => ADDR_WIDTH
        )
        port map (
            clk => clk,
            rst => rst,

            frame_ready_toggle => frame_ready_toggle_sys,

            rd_addr => fb_rd_addr,
            rd_data => fb_rd_data,

            uart_busy  => uart_busy,
            uart_done  => uart_done,
            uart_start => uart_start,
            uart_data  => uart_data,

            dump_busy        => dump_busy,
            dump_done        => dump_done,
            dump_done_toggle => dump_done_toggle
        );

    uart_tx_block : block
        component uart_tx
            generic (
                CLK_FREQ_HZ : integer := 100000000;
                BAUD_RATE   : integer := 921600
            );
            port (
                clk : in std_logic;
                rst : in std_logic;

                tx_start : in std_logic;
                tx_data  : in std_logic_vector(7 downto 0);

                tx_line : out std_logic;
                busy    : out std_logic;
                done    : out std_logic
            );
        end component;
    begin
        u_uart_tx : uart_tx
            generic map (
                CLK_FREQ_HZ => 100000000,
                BAUD_RATE   => UART_BAUD_RATE
            )
            port map (
                clk => clk,
                rst => rst,

                tx_start => uart_start,
                tx_data  => uart_data,

                tx_line => uart_tx_line,
                busy    => uart_busy,
                done    => uart_done
            );
    end block;

end architecture;
