library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity frame_uart_dump is
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
end entity;

architecture rtl of frame_uart_dump is

    constant FRAME_PIXELS : integer := FRAME_WIDTH * FRAME_HEIGHT;

    type state_t is (
        IDLE,
        SEND_HEADER,
        WAIT_HEADER,
        SET_PAYLOAD_ADDR,
        WAIT_PAYLOAD_DATA,
        SEND_PAYLOAD,
        WAIT_PAYLOAD,
        SEND_CHECKSUM,
        WAIT_CHECKSUM,
        DONE_STATE
    );

    type header_t is array (0 to 11) of std_logic_vector(7 downto 0);

    constant HEADER : header_t := (
        0  => x"53",
        1  => x"54",
        2  => x"59",
        3  => x"31",
        4  => std_logic_vector(to_unsigned(FRAME_WIDTH mod 256, 8)),
        5  => std_logic_vector(to_unsigned(FRAME_WIDTH / 256, 8)),
        6  => std_logic_vector(to_unsigned(FRAME_HEIGHT mod 256, 8)),
        7  => std_logic_vector(to_unsigned(FRAME_HEIGHT / 256, 8)),
        8  => std_logic_vector(to_unsigned(FRAME_PIXELS mod 256, 8)),
        9  => std_logic_vector(to_unsigned((FRAME_PIXELS / 256) mod 256, 8)),
        10 => std_logic_vector(to_unsigned((FRAME_PIXELS / 65536) mod 256, 8)),
        11 => std_logic_vector(to_unsigned((FRAME_PIXELS / 16777216) mod 256, 8))
    );

    signal state : state_t := IDLE;

    signal ready_toggle_prev : std_logic := '0';

    signal header_index  : integer range 0 to HEADER'length - 1 := 0;
    signal payload_index : integer range 0 to FRAME_PIXELS := 0;

    signal rd_addr_reg : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');

    signal uart_start_reg : std_logic := '0';
    signal uart_data_reg  : std_logic_vector(7 downto 0) := (others => '0');

    signal checksum_reg : unsigned(7 downto 0) := (others => '0');

    signal dump_busy_reg        : std_logic := '0';
    signal dump_done_reg        : std_logic := '0';
    signal dump_done_toggle_reg : std_logic := '0';

begin

    rd_addr <= rd_addr_reg;

    uart_start <= uart_start_reg;
    uart_data  <= uart_data_reg;

    dump_busy        <= dump_busy_reg;
    dump_done        <= dump_done_reg;
    dump_done_toggle <= dump_done_toggle_reg;

    process(clk)
    begin
        if rising_edge(clk) then

            uart_start_reg <= '0';
            dump_done_reg  <= '0';

            if rst = '1' then

                state <= IDLE;

                ready_toggle_prev <= frame_ready_toggle;

                header_index <= 0;
                payload_index <= 0;
                rd_addr_reg <= (others => '0');

                uart_data_reg <= (others => '0');
                checksum_reg <= (others => '0');

                dump_busy_reg <= '0';
                dump_done_toggle_reg <= '0';

            else

                case state is

                    when IDLE =>

                        dump_busy_reg <= '0';

                        if frame_ready_toggle /= ready_toggle_prev then
                            ready_toggle_prev <= frame_ready_toggle;
                            header_index <= 0;
                            payload_index <= 0;
                            checksum_reg <= (others => '0');
                            dump_busy_reg <= '1';
                            state <= SEND_HEADER;
                        end if;

                    when SEND_HEADER =>

                        dump_busy_reg <= '1';

                        if uart_busy = '0' then
                            uart_data_reg <= HEADER(header_index);
                            uart_start_reg <= '1';
                            state <= WAIT_HEADER;
                        end if;

                    when WAIT_HEADER =>

                        dump_busy_reg <= '1';

                        if uart_done = '1' then
                            if header_index = HEADER'length - 1 then
                                payload_index <= 0;
                                state <= SET_PAYLOAD_ADDR;
                            else
                                header_index <= header_index + 1;
                                state <= SEND_HEADER;
                            end if;
                        end if;

                    when SET_PAYLOAD_ADDR =>

                        dump_busy_reg <= '1';
                        rd_addr_reg <= to_unsigned(payload_index, rd_addr_reg'length);
                        state <= WAIT_PAYLOAD_DATA;

                    when WAIT_PAYLOAD_DATA =>

                        dump_busy_reg <= '1';
                        state <= SEND_PAYLOAD;

                    when SEND_PAYLOAD =>

                        dump_busy_reg <= '1';

                        if uart_busy = '0' then
                            uart_data_reg <= rd_data;
                            uart_start_reg <= '1';
                            checksum_reg <= checksum_reg + unsigned(rd_data);
                            state <= WAIT_PAYLOAD;
                        end if;

                    when WAIT_PAYLOAD =>

                        dump_busy_reg <= '1';

                        if uart_done = '1' then
                            if payload_index = FRAME_PIXELS - 1 then
                                state <= SEND_CHECKSUM;
                            else
                                payload_index <= payload_index + 1;
                                state <= SET_PAYLOAD_ADDR;
                            end if;
                        end if;

                    when SEND_CHECKSUM =>

                        dump_busy_reg <= '1';

                        if uart_busy = '0' then
                            uart_data_reg <= std_logic_vector(checksum_reg);
                            uart_start_reg <= '1';
                            state <= WAIT_CHECKSUM;
                        end if;

                    when WAIT_CHECKSUM =>

                        dump_busy_reg <= '1';

                        if uart_done = '1' then
                            state <= DONE_STATE;
                        end if;

                    when DONE_STATE =>

                        dump_busy_reg <= '0';
                        dump_done_reg <= '1';
                        dump_done_toggle_reg <= not dump_done_toggle_reg;
                        state <= IDLE;

                    when others =>

                        state <= IDLE;

                end case;

            end if;

        end if;
    end process;

end architecture;
