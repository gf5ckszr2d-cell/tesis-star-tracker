library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
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
end entity;

architecture rtl of uart_tx is

    constant BAUD_DIVIDER : integer := CLK_FREQ_HZ / BAUD_RATE;
    constant BAUD_MAX     : integer := BAUD_DIVIDER - 1;

    type state_t is (
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    );

    signal state : state_t := IDLE;

    signal baud_counter : integer range 0 to BAUD_MAX := 0;
    signal bit_index    : integer range 0 to 7 := 0;

    signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_reg    : std_logic := '1';
    signal busy_reg  : std_logic := '0';
    signal done_reg  : std_logic := '0';

begin

    tx_line <= tx_reg;
    busy    <= busy_reg;
    done    <= done_reg;

    process(clk)
    begin
        if rising_edge(clk) then

            done_reg <= '0';

            if rst = '1' then

                state <= IDLE;
                baud_counter <= 0;
                bit_index <= 0;
                shift_reg <= (others => '0');
                tx_reg <= '1';
                busy_reg <= '0';

            else

                case state is

                    when IDLE =>

                        tx_reg <= '1';
                        busy_reg <= '0';
                        baud_counter <= 0;
                        bit_index <= 0;

                        if tx_start = '1' then
                            shift_reg <= tx_data;
                            tx_reg <= '0';
                            busy_reg <= '1';
                            state <= START_BIT;
                        end if;

                    when START_BIT =>

                        busy_reg <= '1';

                        if baud_counter = BAUD_MAX then
                            baud_counter <= 0;
                            tx_reg <= shift_reg(0);
                            bit_index <= 0;
                            state <= DATA_BITS;
                        else
                            baud_counter <= baud_counter + 1;
                        end if;

                    when DATA_BITS =>

                        busy_reg <= '1';

                        if baud_counter = BAUD_MAX then
                            baud_counter <= 0;

                            if bit_index = 7 then
                                tx_reg <= '1';
                                state <= STOP_BIT;
                            else
                                bit_index <= bit_index + 1;
                                tx_reg <= shift_reg(bit_index + 1);
                            end if;
                        else
                            baud_counter <= baud_counter + 1;
                        end if;

                    when STOP_BIT =>

                        busy_reg <= '1';

                        if baud_counter = BAUD_MAX then
                            baud_counter <= 0;
                            tx_reg <= '1';
                            busy_reg <= '0';
                            done_reg <= '1';
                            state <= IDLE;
                        else
                            baud_counter <= baud_counter + 1;
                        end if;

                    when others =>

                        state <= IDLE;

                end case;

            end if;

        end if;
    end process;

end architecture;
