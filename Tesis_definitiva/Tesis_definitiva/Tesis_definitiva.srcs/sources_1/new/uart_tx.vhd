
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic (
        FRECUENCIA_CLK : integer := 125000000;
        BAUD_RATE      : integer := 921600
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        tx_start : in std_logic;
        tx_data  : in std_logic_vector(7 downto 0);

        tx_line : out std_logic;
        busy    : out std_logic;
        done    : out std_logic
    );
end entity;

architecture rtl of uart_tx is

    constant DIVISOR_BAUD : integer := FRECUENCIA_CLK / BAUD_RATE;
    constant MAX_BAUD     : integer := DIVISOR_BAUD - 1;

    type state_t is (
        IDLE,
        START_BIT,
        BITS_DATO,
        STOP_BIT
    );

    signal state : state_t := IDLE;

    signal cuenta_baud : integer range 0 to MAX_BAUD := 0;
    signal indice_bit  : integer range 0 to 7 := 0;

    signal dato_envio_registro : std_logic_vector(7 downto 0)
                                := (others => '0');

    signal tx_registro   : std_logic := '1';
    signal busy_registro : std_logic := '0';
    signal done_registro : std_logic := '0';

begin

    tx_line <= tx_registro;
    busy    <= busy_registro;
    done    <= done_registro;

    process(clk)
    begin
        if rising_edge(clk) then

            done_registro <= '0';

            if reset = '1' then

                state <= IDLE;

                cuenta_baud <= 0;
                indice_bit  <= 0;

                dato_envio_registro <= (others => '0');

                tx_registro   <= '1';
                busy_registro <= '0';

            else

                case state is

                    when IDLE =>

                        tx_registro   <= '1';
                        busy_registro <= '0';

                        cuenta_baud <= 0;
                        indice_bit  <= 0;

                        if tx_start = '1' then

                            dato_envio_registro <= tx_data;

                            tx_registro   <= '0';
                            busy_registro <= '1';

                            state <= START_BIT;

                        end if;

                    when START_BIT =>

                        busy_registro <= '1';

                        if cuenta_baud = MAX_BAUD then

                            cuenta_baud <= 0;

                            tx_registro <= dato_envio_registro(0);
                            indice_bit  <= 0;

                            state <= BITS_DATO;

                        else

                            cuenta_baud <= cuenta_baud + 1;

                        end if;

                    when BITS_DATO =>

                        busy_registro <= '1';

                        if cuenta_baud = MAX_BAUD then

                            cuenta_baud <= 0;

                            if indice_bit = 7 then

                                tx_registro <= '1';
                                state <= STOP_BIT;

                            else

                                indice_bit <= indice_bit + 1;

                                tx_registro <=
                                    dato_envio_registro(indice_bit + 1);

                            end if;

                        else

                            cuenta_baud <= cuenta_baud + 1;

                        end if;

                    when STOP_BIT =>

                        busy_registro <= '1';

                        if cuenta_baud = MAX_BAUD then

                            cuenta_baud <= 0;

                            tx_registro   <= '1';
                            busy_registro <= '0';
                            done_registro <= '1';

                            state <= IDLE;

                        else

                            cuenta_baud <= cuenta_baud + 1;

                        end if;

                    when others =>

                        state <= IDLE;

                end case;

            end if;

        end if;
    end process;

end architecture;
