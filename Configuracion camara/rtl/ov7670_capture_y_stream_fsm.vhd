library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ov7670_capture_y_stream_fsm is
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
end entity;

architecture rtl of ov7670_capture_y_stream_fsm is

    type state_t is (
        DISABLED,
        WAIT_SYNC,
        WAIT_FRAME,
        WAIT_LINE,
        CAPTURE_LINE
    );

    signal state : state_t := DISABLED;

    signal x_count    : integer range 0 to FRAME_WIDTH := 0;
    signal y_count    : integer range 0 to FRAME_HEIGHT := 0;
    signal byte_phase : integer range 0 to 3 := 0;

    signal href_active      : std_logic;
    signal vsync_active     : std_logic;
    signal href_active_prev : std_logic := '0';
    signal frame_active_reg : std_logic := '0';

    signal pixel_y_reg       : std_logic_vector(7 downto 0) := (others => '0');
    signal pixel_valid_reg   : std_logic := '0';
    signal pixel_x_reg       : unsigned(9 downto 0) := (others => '0');
    signal pixel_y_pos_reg   : unsigned(9 downto 0) := (others => '0');
    signal frame_done_reg    : std_logic := '0';
    signal overflow_reg      : std_logic := '0';

begin

    href_active  <= '1' when href = HREF_ACTIVE_LEVEL else '0';
    vsync_active <= '1' when vsync = VSYNC_ACTIVE_LEVEL else '0';

    pixel_y      <= pixel_y_reg;
    pixel_valid  <= pixel_valid_reg;
    pixel_x      <= pixel_x_reg;
    pixel_y_pos  <= pixel_y_pos_reg;
    frame_active <= frame_active_reg;
    frame_done   <= frame_done_reg;
    overflow     <= overflow_reg;

    process(pclk)

        procedure consume_byte is
        begin
            if y_count < FRAME_HEIGHT then
                if byte_phase = 0 or byte_phase = 2 then
                    if x_count < FRAME_WIDTH then
                        pixel_y_reg     <= data;
                        pixel_x_reg     <= to_unsigned(x_count, pixel_x_reg'length);
                        pixel_y_pos_reg <= to_unsigned(y_count, pixel_y_pos_reg'length);
                        pixel_valid_reg <= '1';
                        x_count         <= x_count + 1;
                    else
                        overflow_reg <= '1';
                    end if;
                end if;
            else
                overflow_reg <= '1';
            end if;

            if byte_phase = 3 then
                byte_phase <= 0;
            else
                byte_phase <= byte_phase + 1;
            end if;
        end procedure;

        procedure close_line_if_needed is
        begin
            x_count    <= 0;
            byte_phase <= 0;

            if href_active_prev = '1' then
                if y_count < FRAME_HEIGHT then
                    y_count <= y_count + 1;
                else
                    overflow_reg <= '1';
                end if;
            end if;
        end procedure;

    begin
        if rising_edge(pclk) then

            pixel_valid_reg <= '0';
            frame_done_reg  <= '0';

            if rst = '1' then

                state <= DISABLED;

                x_count <= 0;
                y_count <= 0;
                byte_phase <= 0;
                href_active_prev <= '0';
                frame_active_reg <= '0';

                pixel_y_reg <= (others => '0');
                pixel_x_reg <= (others => '0');
                pixel_y_pos_reg <= (others => '0');
                overflow_reg <= '0';

            elsif enable = '0' then

                state <= DISABLED;

                x_count <= 0;
                y_count <= 0;
                byte_phase <= 0;
                href_active_prev <= href_active;
                frame_active_reg <= '0';

            else

                href_active_prev <= href_active;

                if vsync_active = '1' then

                    state <= WAIT_FRAME;

                    if frame_active_reg = '1' then
                        frame_done_reg <= '1';
                    end if;

                    x_count <= 0;
                    y_count <= 0;
                    byte_phase <= 0;
                    frame_active_reg <= '0';

                else

                    case state is

                        when DISABLED | WAIT_SYNC =>

                            state <= WAIT_SYNC;

                            x_count <= 0;
                            y_count <= 0;
                            byte_phase <= 0;
                            frame_active_reg <= '0';

                        when WAIT_FRAME | WAIT_LINE =>

                            frame_active_reg <= '1';

                            if href_active = '1' then
                                state <= CAPTURE_LINE;
                                consume_byte;
                            else
                                state <= WAIT_LINE;
                                close_line_if_needed;
                            end if;

                        when CAPTURE_LINE =>

                            frame_active_reg <= '1';

                            if href_active = '1' then
                                state <= CAPTURE_LINE;
                                consume_byte;
                            else
                                state <= WAIT_LINE;
                                close_line_if_needed;
                            end if;

                        when others =>

                            state <= DISABLED;

                    end case;

                end if;

            end if;

        end if;
    end process;

end architecture;
