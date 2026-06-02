library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_capture_store is
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
end entity;

architecture rtl of frame_capture_store is

    type state_t is (
        IDLE,
        CAPTURING,
        READY
    );

    constant FRAME_PIXELS : integer := FRAME_WIDTH * FRAME_HEIGHT;

    signal state : state_t := IDLE;

    signal wr_en_reg   : std_logic := '0';
    signal wr_addr_reg : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
    signal wr_data_reg : std_logic_vector(7 downto 0) := (others => '0');

    signal frame_ready_reg        : std_logic := '0';
    signal frame_ready_toggle_reg : std_logic := '0';
    signal overflow_reg           : std_logic := '0';

    signal dump_done_toggle_prev : std_logic := '0';

begin

    wr_en   <= wr_en_reg;
    wr_addr <= wr_addr_reg;
    wr_data <= wr_data_reg;

    capture_busy       <= '1' when state = CAPTURING else '0';
    frame_ready        <= frame_ready_reg;
    frame_ready_toggle <= frame_ready_toggle_reg;
    overflow           <= overflow_reg;

    process(pclk)
        variable pixel_addr : integer;
    begin
        if rising_edge(pclk) then

            wr_en_reg <= '0';

            if rst = '1' then

                state <= IDLE;

                wr_addr_reg <= (others => '0');
                wr_data_reg <= (others => '0');

                frame_ready_reg        <= '0';
                frame_ready_toggle_reg <= '0';
                overflow_reg           <= '0';
                dump_done_toggle_prev  <= dump_done_toggle;

            else

                if dump_done_toggle /= dump_done_toggle_prev then
                    dump_done_toggle_prev <= dump_done_toggle;
                    state <= IDLE;
                    frame_ready_reg <= '0';
                end if;

                case state is

                    when IDLE =>

                        overflow_reg <= '0';

                        if arm_capture = '1' then
                            state <= CAPTURING;
                        end if;

                    when CAPTURING =>

                        if pixel_valid = '1' then
                            pixel_addr := to_integer(pixel_y_pos) * FRAME_WIDTH + to_integer(pixel_x);

                            if to_integer(pixel_x) < FRAME_WIDTH and
                               to_integer(pixel_y_pos) < FRAME_HEIGHT and
                               pixel_addr < FRAME_PIXELS then

                                wr_en_reg   <= '1';
                                wr_addr_reg <= to_unsigned(pixel_addr, wr_addr_reg'length);
                                wr_data_reg <= pixel_y;

                            else
                                overflow_reg <= '1';
                            end if;
                        end if;

                        if frame_done = '1' then
                            frame_ready_reg        <= '1';
                            frame_ready_toggle_reg <= not frame_ready_toggle_reg;
                            state                  <= READY;
                        end if;

                    when READY =>

                        state <= READY;

                    when others =>

                        state <= IDLE;

                end case;

            end if;

        end if;
    end process;

end architecture;
