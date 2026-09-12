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
    constant STAR_THRESHOLD : std_logic_vector(7 downto 0) := x"2D";
    constant STAR_MAX_LABELS : integer := 64;
    constant STAR_MAX_STARS : integer := 64;
    constant STAR_MIN_AREA : integer := 2;
    constant STAR_MAX_AREA : integer := 500;

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
    signal start_btn_sys_meta : std_logic := '0';
    signal start_btn_sys      : std_logic := '0';

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
    signal uart_fb_rd_addr : unsigned(ADDR_WIDTH - 1 downto 0);
    signal detector_fb_rd_addr : unsigned(ADDR_WIDTH - 1 downto 0);

    signal store_capture_busy       : std_logic;
    signal store_frame_ready        : std_logic;
    signal store_frame_ready_toggle : std_logic;
    signal store_overflow           : std_logic;

    signal frame_ready_toggle_meta : std_logic := '0';
    signal frame_ready_toggle_sys  : std_logic := '0';
    signal frame_ready_toggle_prev_sys : std_logic := '0';
    signal uart_frame_ready_toggle : std_logic := '0';
    signal detector_frame_ready_toggle : std_logic := '0';

    signal sw8_pclk_meta : std_logic := '0';
    signal sw8_pclk_sync : std_logic := '0';
    signal capture_diag_mode_pclk : std_logic := '0';
    signal capture_diag_mode_meta : std_logic := '0';
    signal capture_diag_mode_sys : std_logic := '0';

    signal dump_done_toggle      : std_logic;
    signal dump_busy             : std_logic;
    signal dump_done             : std_logic;
    signal pipeline_done_latched : std_logic := '0';
    signal consumer_done_toggle_sys : std_logic := '0';
    signal consumer_done_toggle_meta : std_logic := '0';
    signal consumer_done_toggle_pclk : std_logic := '0';

    signal detector_busy : std_logic;
    signal detector_done : std_logic;
    signal detector_done_toggle : std_logic;
    signal detector_overflow : std_logic;
    signal detector_star_valid : std_logic;
    signal detector_star_index : unsigned(7 downto 0);
    signal detector_centroid_x_q8_8 : unsigned(17 downto 0);
    signal detector_centroid_y_q8_8 : unsigned(17 downto 0);
    signal detector_star_area : unsigned(14 downto 0);
    signal detector_star_intensity : unsigned(23 downto 0);
    signal detector_star_count : unsigned(7 downto 0);

    signal list_rd_index : unsigned(7 downto 0) := (others => '0');
    signal list_rd_valid : std_logic;
    signal list_centroid_x_q8_8 : unsigned(17 downto 0);
    signal list_centroid_y_q8_8 : unsigned(17 downto 0);
    signal list_star_area : unsigned(14 downto 0);
    signal list_star_intensity : unsigned(23 downto 0);
    signal list_star_count : unsigned(7 downto 0);
    signal list_ready : std_logic;
    signal list_overflow : std_logic;

    signal uart_start : std_logic;
    signal uart_data  : std_logic_vector(7 downto 0);
    signal uart_busy  : std_logic;
    signal uart_done  : std_logic;
    signal uart_tx_line : std_logic;

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of start_btn_sys_meta : signal is "TRUE";
    attribute ASYNC_REG of start_btn_sys : signal is "TRUE";
    attribute ASYNC_REG of init_done_pclk_meta : signal is "TRUE";
    attribute ASYNC_REG of init_done_pclk : signal is "TRUE";
    attribute ASYNC_REG of start_btn_pclk_meta : signal is "TRUE";
    attribute ASYNC_REG of start_btn_pclk : signal is "TRUE";
    attribute ASYNC_REG of sw8_pclk_meta : signal is "TRUE";
    attribute ASYNC_REG of sw8_pclk_sync : signal is "TRUE";
    attribute ASYNC_REG of capture_diag_mode_meta : signal is "TRUE";
    attribute ASYNC_REG of capture_diag_mode_sys : signal is "TRUE";
    attribute ASYNC_REG of consumer_done_toggle_meta : signal is "TRUE";
    attribute ASYNC_REG of consumer_done_toggle_pclk : signal is "TRUE";
    attribute ASYNC_REG of frame_ready_toggle_meta : signal is "TRUE";
    attribute ASYNC_REG of frame_ready_toggle_sys : signal is "TRUE";

    -- Los resultados permanecen dentro del FPGA hasta integrar la siguiente
    -- etapa del star tracker. MARK_DEBUG evita que síntesis los elimine y deja
    -- disponible una verificación con ILA sin reutilizar ni ampliar el UART.
    attribute MARK_DEBUG : string;
    attribute MARK_DEBUG of detector_star_valid : signal is "TRUE";
    attribute MARK_DEBUG of detector_star_index : signal is "TRUE";
    attribute MARK_DEBUG of detector_centroid_x_q8_8 : signal is "TRUE";
    attribute MARK_DEBUG of detector_centroid_y_q8_8 : signal is "TRUE";
    attribute MARK_DEBUG of detector_star_area : signal is "TRUE";
    attribute MARK_DEBUG of detector_star_intensity : signal is "TRUE";
    attribute MARK_DEBUG of detector_star_count : signal is "TRUE";
    attribute MARK_DEBUG of list_rd_index : signal is "TRUE";
    attribute MARK_DEBUG of list_rd_valid : signal is "TRUE";
    attribute MARK_DEBUG of list_centroid_x_q8_8 : signal is "TRUE";
    attribute MARK_DEBUG of list_centroid_y_q8_8 : signal is "TRUE";
    attribute MARK_DEBUG of list_star_area : signal is "TRUE";
    attribute MARK_DEBUG of list_star_intensity : signal is "TRUE";
    attribute MARK_DEBUG of list_star_count : signal is "TRUE";
    attribute MARK_DEBUG of list_ready : signal is "TRUE";
    attribute MARK_DEBUG of list_overflow : signal is "TRUE";

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

    component frame_star_centroid
        generic (
            FRAME_WIDTH  : positive := 160;
            FRAME_HEIGHT : positive := 120;
            ADDR_WIDTH   : positive := 15;
            MAX_LABELS   : positive := 64;
            MIN_AREA     : positive := 2;
            MAX_AREA     : positive := 500
        );
        port (
            clk : in std_logic;
            rst : in std_logic;

            frame_ready_toggle : in std_logic;
            threshold          : in std_logic_vector(7 downto 0);

            rd_addr : out unsigned(ADDR_WIDTH - 1 downto 0);
            rd_data : in std_logic_vector(7 downto 0);

            star_valid      : out std_logic;
            star_index      : out unsigned(7 downto 0);
            centroid_x_q8_8 : out unsigned(17 downto 0);
            centroid_y_q8_8 : out unsigned(17 downto 0);
            star_area       : out unsigned(14 downto 0);
            star_intensity  : out unsigned(23 downto 0);
            star_count      : out unsigned(7 downto 0);

            process_busy        : out std_logic;
            process_done        : out std_logic;
            process_done_toggle : out std_logic;
            overflow            : out std_logic
        );
    end component;

    component star_list_buffer
        generic (
            MAX_STARS : positive := 64
        );
        port (
            clk : in std_logic;
            rst : in std_logic;
            frame_start_toggle : in std_logic;
            frame_done : in std_logic;
            star_valid : in std_logic;
            centroid_x_q8_8 : in unsigned(17 downto 0);
            centroid_y_q8_8 : in unsigned(17 downto 0);
            star_area : in unsigned(14 downto 0);
            star_intensity : in unsigned(23 downto 0);
            rd_index : in unsigned(7 downto 0);
            rd_valid : out std_logic;
            rd_centroid_x_q8_8 : out unsigned(17 downto 0);
            rd_centroid_y_q8_8 : out unsigned(17 downto 0);
            rd_star_area : out unsigned(14 downto 0);
            rd_star_intensity : out unsigned(23 downto 0);
            star_count : out unsigned(7 downto 0);
            list_ready : out std_logic;
            overflow : out std_logic
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
    fb_rd_addr <= uart_fb_rd_addr when capture_diag_mode_sys = '1' else detector_fb_rd_addr;

    xclk_ready <= '1' when SIM_BYPASS_XCLK_LOCK else xclk_locked;
    init_start <= start_btn_sys and xclk_ready and not init_done_latched;
    capture_rst <= rst or not init_done_pclk or not store_capture_busy;
    i2c_runtime_owner <= init_done_latched and runtime_busy;

    i2c_start    <= runtime_i2c_start    when i2c_runtime_owner = '1' else init_i2c_start;
    i2c_rw       <= runtime_i2c_rw       when i2c_runtime_owner = '1' else init_i2c_rw;
    i2c_tx_byte0 <= runtime_i2c_tx_byte0 when i2c_runtime_owner = '1' else init_i2c_tx_byte0;
    i2c_tx_byte1 <= runtime_i2c_tx_byte1 when i2c_runtime_owner = '1' else init_i2c_tx_byte1;
    i2c_tx_count <= runtime_i2c_tx_count when i2c_runtime_owner = '1' else init_i2c_tx_count;

    led_read_data <= capture_pixel_y;
    busy          <= init_busy or runtime_busy or i2c_busy or store_capture_busy or
                     dump_busy or uart_busy or detector_busy;
    ok            <= init_done_latched and pipeline_done_latched and
                     (capture_diag_mode_sys or list_ready);
    fail          <= init_error_latched or runtime_error_latched or capture_overflow or
                     store_overflow or detector_overflow or list_overflow;
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
                start_btn_sys_meta <= '0';
                start_btn_sys      <= '0';
                init_done_latched  <= '0';
                init_error_latched <= '0';
                runtime_error_latched <= '0';
                pipeline_done_latched <= '0';
                consumer_done_toggle_sys <= '0';
            else
                start_btn_sys_meta <= start_btn;
                start_btn_sys      <= start_btn_sys_meta;

                if init_done = '1' then
                    init_done_latched <= '1';
                end if;

                if init_error = '1' then
                    init_error_latched <= '1';
                end if;

                if runtime_error = '1' then
                    runtime_error_latched <= '1';
                end if;

                if dump_done = '1' or detector_done = '1' then
                    pipeline_done_latched <= '1';
                    consumer_done_toggle_sys <= not consumer_done_toggle_sys;
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
                sw8_pclk_meta <= '0';
                sw8_pclk_sync <= '0';
                capture_diag_mode_pclk <= '0';
                consumer_done_toggle_meta <= '0';
                consumer_done_toggle_pclk <= '0';
            else
                init_done_pclk_meta <= init_done_latched;
                init_done_pclk      <= init_done_pclk_meta;
                init_done_pclk_prev <= init_done_pclk;

                start_btn_pclk_meta <= start_btn;
                start_btn_pclk      <= start_btn_pclk_meta;
                start_btn_pclk_prev <= start_btn_pclk;

                sw8_pclk_meta <= sw(8);
                sw8_pclk_sync <= sw8_pclk_meta;

                consumer_done_toggle_meta <= consumer_done_toggle_sys;
                consumer_done_toggle_pclk <= consumer_done_toggle_meta;

                if capture_arm_pulse = '1' then
                    capture_diag_mode_pclk <= sw8_pclk_sync;
                end if;

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
            dump_done_toggle => consumer_done_toggle_pclk,

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
                frame_ready_toggle_prev_sys <= '0';
                capture_diag_mode_meta <= '0';
                capture_diag_mode_sys <= '0';
                uart_frame_ready_toggle <= '0';
                detector_frame_ready_toggle <= '0';
            else
                frame_ready_toggle_meta <= store_frame_ready_toggle;
                frame_ready_toggle_sys  <= frame_ready_toggle_meta;
                capture_diag_mode_meta <= capture_diag_mode_pclk;
                capture_diag_mode_sys <= capture_diag_mode_meta;

                if frame_ready_toggle_sys /= frame_ready_toggle_prev_sys then
                    frame_ready_toggle_prev_sys <= frame_ready_toggle_sys;
                    if capture_diag_mode_sys = '1' then
                        uart_frame_ready_toggle <= not uart_frame_ready_toggle;
                    else
                        detector_frame_ready_toggle <= not detector_frame_ready_toggle;
                    end if;
                end if;
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

            frame_ready_toggle => uart_frame_ready_toggle,

            rd_addr => uart_fb_rd_addr,
            rd_data => fb_rd_data,

            uart_busy  => uart_busy,
            uart_done  => uart_done,
            uart_start => uart_start,
            uart_data  => uart_data,

            dump_busy        => dump_busy,
            dump_done        => dump_done,
            dump_done_toggle => dump_done_toggle
        );

    u_frame_star_centroid : frame_star_centroid
        generic map (
            FRAME_WIDTH => FRAME_WIDTH,
            FRAME_HEIGHT => FRAME_HEIGHT,
            ADDR_WIDTH => ADDR_WIDTH,
            MAX_LABELS => STAR_MAX_LABELS,
            MIN_AREA => STAR_MIN_AREA,
            MAX_AREA => STAR_MAX_AREA
        )
        port map (
            clk => clk,
            rst => rst,
            frame_ready_toggle => detector_frame_ready_toggle,
            threshold => STAR_THRESHOLD,
            rd_addr => detector_fb_rd_addr,
            rd_data => fb_rd_data,
            star_valid => detector_star_valid,
            star_index => detector_star_index,
            centroid_x_q8_8 => detector_centroid_x_q8_8,
            centroid_y_q8_8 => detector_centroid_y_q8_8,
            star_area => detector_star_area,
            star_intensity => detector_star_intensity,
            star_count => detector_star_count,
            process_busy => detector_busy,
            process_done => detector_done,
            process_done_toggle => detector_done_toggle,
            overflow => detector_overflow
        );

    u_star_list_buffer : star_list_buffer
        generic map (
            MAX_STARS => STAR_MAX_STARS
        )
        port map (
            clk => clk,
            rst => rst,
            frame_start_toggle => detector_frame_ready_toggle,
            frame_done => detector_done,
            star_valid => detector_star_valid,
            centroid_x_q8_8 => detector_centroid_x_q8_8,
            centroid_y_q8_8 => detector_centroid_y_q8_8,
            star_area => detector_star_area,
            star_intensity => detector_star_intensity,
            rd_index => list_rd_index,
            rd_valid => list_rd_valid,
            rd_centroid_x_q8_8 => list_centroid_x_q8_8,
            rd_centroid_y_q8_8 => list_centroid_y_q8_8,
            rd_star_area => list_star_area,
            rd_star_intensity => list_star_intensity,
            star_count => list_star_count,
            list_ready => list_ready,
            overflow => list_overflow
        );

    -- Recorre continuamente las entradas validas para dejarlas observables
    -- en ILA y conservar una interfaz RTL real para la siguiente etapa.
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or list_ready = '0' or list_star_count = 0 then
                list_rd_index <= (others => '0');
            elsif to_integer(list_rd_index) + 1 < to_integer(list_star_count) then
                list_rd_index <= list_rd_index + 1;
            else
                list_rd_index <= (others => '0');
            end if;
        end if;
    end process;

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
