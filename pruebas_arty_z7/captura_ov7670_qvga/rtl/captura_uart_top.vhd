library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Hito 1 independiente. No depende del top Nexys ni de etapas estelares.
entity captura_uart_top is
    generic (
        FRAME_WIDTH : positive := 320;
        FRAME_HEIGHT : positive := 240;
        ADDR_WIDTH : positive := 17;
        CLK_FREQ_HZ : positive := 100000000;
        UART_BAUD_RATE : positive := 921600;
        DEBOUNCE_CYCLES : positive := 2000000;
        STAGE_TIMEOUT_CYCLES : positive := 400000000;
        POWERUP_CYCLES : positive := 1000000;
        CAMERA_SETTLE_CYCLES : positive := 30000000;
        SCCB_RESET_DELAY_MS : positive := 10
    );
    port (
        clk, rst, start : in std_logic;
        reset_btn : in std_logic := '0';
        diag_led : out std_logic_vector(3 downto 0);
        capture_status : out std_logic_vector(63 downto 0);
        software_control : in std_logic_vector(63 downto 0) := (others=>'0');
        tx : out std_logic;
        sda_i : in std_logic;
        sda_t : out std_logic;
        SCL   : out std_logic;
        cam_xclk : out std_logic;
        cam_pclk, cam_vsync, cam_href : in std_logic;
        cam_data : in std_logic_vector(7 downto 0);
        cam_pwdn, cam_reset : out std_logic
    );
end entity;
architecture rtl of captura_uart_top is
    type state_t is (IDLE, WAIT_LOCK, START_INIT, WAIT_INIT, WAIT_SETTLE, ARM_FRAME,
                     WAIT_DUMP, WAIT_RELEASE, ERROR_STOP);
    signal error_pixel : std_logic := '0';
    signal startup_ready, dump_busy : std_logic;
    signal reset_meta, reset_sync : std_logic := '0';
    signal startup_count : natural range 0 to POWERUP_CYCLES := 0;
    signal settle_count : natural range 0 to CAMERA_SETTLE_CYCLES := 0;
    signal stage_count : natural range 0 to STAGE_TIMEOUT_CYCLES := 0;
    signal blink_count : unsigned(25 downto 0) := (others => '0');
    signal frame_seen, tx_seen : std_logic := '0';
    signal fault_code : std_logic_vector(2 downto 0) := "000";
    signal state : state_t := IDLE;
    signal sys_reset_pipe, pixel_reset_pipe : std_logic_vector(1 downto 0) := "11";
    signal sys_rst, pixel_rst, capture_rst : std_logic;
    signal button_meta, button_sync, button_level, press : std_logic := '0';
    signal debounce_count : natural range 0 to DEBOUNCE_CYCLES-1 := 0;
    signal locked, init_start, init_done, init_error : std_logic;
    signal configured : std_logic := '0';
    signal i2c_start, i2c_rw, i2c_done, i2c_error : std_logic;
    signal byte0, byte1 : std_logic_vector(7 downto 0);
    signal byte_count : unsigned(1 downto 0);
    signal request_toggle : std_logic := '0';
    signal request_meta, request_sync, request_seen, arm : std_logic := '0';
    signal dump_done_toggle, dump_done : std_logic;
    signal done_meta, done_sync, released_toggle : std_logic := '0';
    signal released_meta, released_sync : std_logic := '0';
    signal frame_ready, capture_busy, capture_done : std_logic;
    signal ready_toggle, ready_meta, ready_sync : std_logic := '0';
    signal pixel_y, wr_data, rd_data, uart_data : std_logic_vector(7 downto 0);
    signal pixel_valid, wr_en, uart_start, uart_busy, uart_done : std_logic;
    signal x, y : unsigned(9 downto 0);
    signal wr_addr, rd_addr : unsigned(ADDR_WIDTH-1 downto 0);
    signal capture_error, store_error, error_meta, error_sync : std_logic := '0';
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of sys_reset_pipe, pixel_reset_pipe : signal is "TRUE";
    attribute ASYNC_REG of reset_meta, reset_sync : signal is "TRUE";
    attribute ASYNC_REG of button_meta, button_sync : signal is "TRUE";
    attribute ASYNC_REG of request_meta, request_sync : signal is "TRUE";
    attribute ASYNC_REG of done_meta, done_sync : signal is "TRUE";
    attribute ASYNC_REG of ready_meta, ready_sync : signal is "TRUE";
    attribute ASYNC_REG of released_meta, released_sync : signal is "TRUE";
    attribute ASYNC_REG of error_meta, error_sync : signal is "TRUE";
begin
    startup_ready <= '1' when startup_count = POWERUP_CYCLES else '0';
    process(clk)
    begin
        if rising_edge(clk) then
            if sys_rst = '1' then
                startup_count <= 0; blink_count <= (others => '0');
                frame_seen <= '0'; tx_seen <= '0';
            else
                blink_count <= blink_count + 1;
                if locked = '0' then startup_count <= 0;
                elsif startup_ready = '0' then startup_count <= startup_count + 1; end if;
                if state = ARM_FRAME then frame_seen <= '0'; tx_seen <= '0';
                elsif dump_busy = '1' then frame_seen <= '1'; end if;
                if dump_done = '1' then tx_seen <= '1'; end if;
            end if;
        end if;
    end process;
    -- Errors: LED0 blinks, LED3..1 show the binary fault code.
    process(blink_count, configured, frame_seen, tx_seen, state, dump_busy, fault_code)
    begin
        diag_led <= "0000";
        diag_led(0) <= blink_count(25);
        diag_led(1) <= configured;
        diag_led(2) <= frame_seen;
        diag_led(3) <= tx_seen;
        if state = WAIT_INIT or state = START_INIT or state = WAIT_LOCK or state = WAIT_SETTLE then
            diag_led(1) <= blink_count(23);
        end if;
        if state = WAIT_DUMP and frame_seen = '0' then diag_led(2) <= blink_count(23); end if;
        if dump_busy = '1' then diag_led(3) <= blink_count(23); end if;
        if state = ERROR_STOP then diag_led <= fault_code & blink_count(23); end if;
    end process;
    -- Reset activo alto, asercion asincrona y liberacion sincronizada por dominio.
    
    -- Registrar los errores en el dominio PCLK
    process(cam_pclk)
    begin
        if rising_edge(cam_pclk) then
            if pixel_rst = '1' then
                error_pixel <= '0';
    
            elsif capture_error = '1' or store_error = '1' then
                error_pixel <= '1';
            end if;
        end if;
    end process;
    
    process(clk, rst)
    begin
        if rst = '1' then reset_meta <= '0'; reset_sync <= '0';
        elsif rising_edge(clk) then reset_meta <= reset_btn; reset_sync <= reset_meta; end if;
    end process;
    process(clk, rst)
    begin
        if rst = '1' then sys_reset_pipe <= "11";
        elsif rising_edge(clk) then
            if reset_sync = '1' then sys_reset_pipe <= "11";
            else sys_reset_pipe <= sys_reset_pipe(0) & '0'; end if;
        end if;
    end process;
    process(cam_pclk, sys_rst)
    begin
        if sys_rst = '1' then pixel_reset_pipe <= "11";
        elsif rising_edge(cam_pclk) then pixel_reset_pipe <= pixel_reset_pipe(0) & '0'; end if;
    end process;
    sys_rst <= sys_reset_pipe(1); pixel_rst <= pixel_reset_pipe(1);
    cam_pwdn <= '0'; cam_reset <= not sys_rst and locked;
    capture_rst <= pixel_rst or not capture_busy;
    init_start <= '1' when state = START_INIT else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            press <= '0';
            if sys_rst = '1' then
                button_meta <= '0'; button_sync <= '0'; button_level <= '0'; debounce_count <= 0;
            else
                button_meta <= start or software_control(0); button_sync <= button_meta;
                if button_sync = button_level then debounce_count <= 0;
                elsif debounce_count = DEBOUNCE_CYCLES-1 then
                    debounce_count <= 0; button_level <= button_sync;
                    if button_sync = '1' then press <= '1'; end if;
                else debounce_count <= debounce_count+1; end if;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if sys_rst = '1' then
                state <= IDLE; configured <= '0'; request_toggle <= '0';
                stage_count <= 0; fault_code <= "000";
                settle_count <= 0;
                ready_meta <= '0'; ready_sync <= '0'; released_meta <= '0'; released_sync <= '0';
                error_meta <= '0'; error_sync <= '0';
            else
                ready_meta <= ready_toggle; ready_sync <= ready_meta;
                released_meta <= released_toggle; released_sync <= released_meta;
                error_meta <= error_pixel; error_sync <= error_meta;
                if state = IDLE or state = ARM_FRAME or state = START_INIT then stage_count <= 0;
                elsif stage_count < STAGE_TIMEOUT_CYCLES then stage_count <= stage_count+1; end if;
                case state is
                    when IDLE =>
                        if press = '1' then
                            if configured = '1' then state <= ARM_FRAME;
                            else state <= WAIT_LOCK; end if;
                        end if;
                    when WAIT_LOCK => if startup_ready = '1' then state <= START_INIT; end if;
                    when START_INIT => state <= WAIT_INIT;
                    when WAIT_INIT =>
                        if init_error = '1' then state <= ERROR_STOP; fault_code <= "001";
                        elsif init_done = '1' then
                            configured <= '1'; settle_count <= 0; state <= WAIT_SETTLE;
                        end if;
                    when WAIT_SETTLE =>
                        if settle_count = CAMERA_SETTLE_CYCLES then state <= ARM_FRAME;
                        else settle_count <= settle_count + 1; end if;
                    when ARM_FRAME => request_toggle <= not request_toggle; state <= WAIT_DUMP;
                    when WAIT_DUMP =>
                        if error_sync = '1' then state <= ERROR_STOP; fault_code <= "010";
                        elsif dump_done = '1' then state <= WAIT_RELEASE; end if;
                    when WAIT_RELEASE =>
                        if released_sync = dump_done_toggle then state <= IDLE; end if;
                    when ERROR_STOP => null; -- Recuperar con rst.
                end case;
                if stage_count = STAGE_TIMEOUT_CYCLES and state /= IDLE and state /= ERROR_STOP then
                    state <= ERROR_STOP;
                    if state = WAIT_LOCK then fault_code <= "101";
                    elsif state = WAIT_INIT then fault_code <= "001";
                    elsif state = WAIT_RELEASE then fault_code <= "110";
                    elsif frame_seen = '0' then fault_code <= "011";
                    else fault_code <= "100"; end if;
                end if;
            end if;
        end if;
    end process;

    process(cam_pclk)
    begin
        if rising_edge(cam_pclk) then
            arm <= '0';
            if pixel_rst = '1' then
                request_meta <= '0'; request_sync <= '0'; request_seen <= '0';
                done_meta <= '0'; done_sync <= '0'; released_toggle <= '0';
            else
                request_meta <= request_toggle; request_sync <= request_meta;
                done_meta <= dump_done_toggle; done_sync <= done_meta;
                if request_sync /= request_seen and capture_busy = '0' and frame_ready = '0' then
                    request_seen <= request_sync; arm <= '1';
                end if;
                -- Confirmar liberacion de BRAM antes de aceptar otra captura.
                if frame_ready = '0' and capture_busy = '0' then released_toggle <= done_sync; end if;
            end if;
        end if;
    end process;

    xclk_gen : entity work.captura_xclk
        generic map (CLK_FREQ_HZ => CLK_FREQ_HZ)
        port map (clk => clk, rst => sys_rst, xclk => cam_xclk, locked => locked);
    init : entity work.ov7670_init_config
        generic map (CLK_FREQ_HZ => CLK_FREQ_HZ, RESET_DELAY_MS => SCCB_RESET_DELAY_MS)
        port map (clk => clk, rst => sys_rst, start => init_start,
            i2c_done => i2c_done, i2c_ack_error => i2c_error,
            i2c_start => i2c_start, i2c_rw => i2c_rw,
            i2c_tx_byte0 => byte0, i2c_tx_byte1 => byte1, i2c_tx_count => byte_count,
            busy => open, done => init_done, error => init_error, current_step => open);
    sccb : entity work.i2c_master
        generic map (CLK_FREQ_HZ => CLK_FREQ_HZ)
        port map (clk => clk, rst => sys_rst, start => i2c_start, slave_addr => "0100001",
            rw => i2c_rw, tx_byte0 => byte0, tx_byte1 => byte1, tx_count => byte_count,
            rx_data => open,
            sda_i   => sda_i,
            sda_t   => sda_t,
            SCL     => SCL,
            busy    => open,
            done    => i2c_done,
            ack_error => i2c_error);
    capture : entity work.ov7670_capture_y_stream
        generic map (FRAME_WIDTH=>FRAME_WIDTH, FRAME_HEIGHT=>FRAME_HEIGHT)
        port map (pclk => cam_pclk, rst => capture_rst, enable => capture_busy,
            vsync => cam_vsync, href => cam_href, data => cam_data,
            pixel_y => pixel_y, pixel_valid => pixel_valid, pixel_x => x, pixel_y_pos => y,
            frame_active => open, frame_done => capture_done, overflow => capture_error);
    diagnostics : entity work.capture_frame_diag
        generic map (FRAME_WIDTH=>FRAME_WIDTH, FRAME_HEIGHT=>FRAME_HEIGHT)
        port map(pclk=>cam_pclk, rst=>pixel_rst, enable=>capture_busy,
            vsync=>cam_vsync, href=>cam_href, pixel_valid=>pixel_valid,
            frame_done=>capture_done, capture_error=>capture_error,
            store_error=>store_error, status=>capture_status);
    store : entity work.frame_capture_store
        generic map (FRAME_WIDTH=>FRAME_WIDTH, FRAME_HEIGHT=>FRAME_HEIGHT, ADDR_WIDTH=>ADDR_WIDTH)
        port map (pclk => cam_pclk, rst => pixel_rst, arm_capture => arm,
            dump_done_toggle => done_sync, pixel_y => pixel_y, pixel_valid => pixel_valid,
            pixel_x => x, pixel_y_pos => y, frame_done => capture_done, capture_invalid => capture_error,
            wr_en => wr_en, wr_addr => wr_addr, wr_data => wr_data,
            capture_busy => capture_busy, frame_ready => frame_ready,
            frame_ready_toggle => ready_toggle, overflow => store_error);
    memory : entity work.framebuffer_y_bram
        generic map (FRAME_PIXELS=>FRAME_WIDTH*FRAME_HEIGHT, ADDR_WIDTH=>ADDR_WIDTH)
        port map (wr_clk => cam_pclk, wr_en => wr_en, wr_addr => wr_addr, wr_data => wr_data,
            rd_clk => clk, rd_addr => rd_addr, rd_data => rd_data);
    dump : entity work.frame_uart_dump
        generic map (FRAME_WIDTH=>FRAME_WIDTH, FRAME_HEIGHT=>FRAME_HEIGHT, ADDR_WIDTH=>ADDR_WIDTH)
        port map (clk => clk, rst => sys_rst, frame_ready_toggle => ready_sync,
            rd_addr => rd_addr, rd_data => rd_data, uart_busy => uart_busy, uart_done => uart_done,
            uart_start => uart_start, uart_data => uart_data,
            dump_busy => dump_busy, dump_done => dump_done, dump_done_toggle => dump_done_toggle);
    serial_tx : entity work.uart_tx
        generic map (CLK_FREQ_HZ => CLK_FREQ_HZ, BAUD_RATE => UART_BAUD_RATE)
        port map (clk => clk, rst => sys_rst, tx_start => uart_start, tx_data => uart_data,
            tx_line => tx, busy => uart_busy, done => uart_done);
end architecture;
