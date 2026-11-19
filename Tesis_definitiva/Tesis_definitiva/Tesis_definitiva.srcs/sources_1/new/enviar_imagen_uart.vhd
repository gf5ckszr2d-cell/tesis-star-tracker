
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity enviar_imagen_uart is
    generic (
        ANCHO_IMAGEN   : integer := 320;
        ALTO_IMAGEN    : integer := 240;
        BITS_DIRECCION : integer := 17
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        cambio_imagen_lista : in std_logic;

        direccion_lectura : out unsigned(BITS_DIRECCION - 1 downto 0);
        dato_lectura      : in std_logic_vector(7 downto 0);

        uart_busy  : in std_logic;
        uart_done  : in std_logic;
        uart_start : out std_logic;
        uart_dato  : out std_logic_vector(7 downto 0);

        envio_ocupado     : out std_logic;
        envio_terminado   : out std_logic;
        cambio_fin_envio : out std_logic
    );
end entity;

architecture rtl of enviar_imagen_uart is

    constant TOTAL_PIXELES : integer := ANCHO_IMAGEN * ALTO_IMAGEN;

    type estado_t is (
        IDLE,
        ENVIAR_CABECERA,
        ESPERAR_CABECERA,
        PONER_DIRECCION,
        ESPERAR_DATO,
        ENVIAR_DATO,
        ESPERAR_ENVIO,
        ENVIAR_CHECKSUM,
        ESPERAR_CHECKSUM,
        TERMINADO
    );

    type cabecera_t is array (0 to 11)
        of std_logic_vector(7 downto 0);

    constant CABECERA : cabecera_t := (
        0  => x"53",
        1  => x"54",
        2  => x"59",
        3  => x"31",
        4  => std_logic_vector(to_unsigned(ANCHO_IMAGEN mod 256, 8)),
        5  => std_logic_vector(to_unsigned(ANCHO_IMAGEN / 256, 8)),
        6  => std_logic_vector(to_unsigned(ALTO_IMAGEN mod 256, 8)),
        7  => std_logic_vector(to_unsigned(ALTO_IMAGEN / 256, 8)),
        8  => std_logic_vector(to_unsigned(TOTAL_PIXELES mod 256, 8)),
        9  => std_logic_vector(to_unsigned((TOTAL_PIXELES / 256) mod 256, 8)),
        10 => std_logic_vector(to_unsigned((TOTAL_PIXELES / 65536) mod 256, 8)),
        11 => std_logic_vector(to_unsigned((TOTAL_PIXELES / 16777216) mod 256, 8))
    );

    signal estado : estado_t := IDLE;

    signal imagen_lista_anterior : std_logic := '0';

    signal indice_cabecera : integer range 0 to CABECERA'length - 1 := 0;
    signal indice_dato : integer range 0 to TOTAL_PIXELES := 0;

    signal direccion_registro : unsigned(BITS_DIRECCION - 1 downto 0)
                                := (others => '0');

    signal uart_start_registro : std_logic := '0';

    signal uart_dato_registro : std_logic_vector(7 downto 0)
                               := (others => '0');

    signal checksum_registro : unsigned(7 downto 0)
                               := (others => '0');

    signal envio_ocupado_registro : std_logic := '0';
    signal envio_terminado_registro : std_logic := '0';
    signal cambio_fin_envio_registro : std_logic := '0';

begin

    direccion_lectura <= direccion_registro;

    uart_start <= uart_start_registro;
    uart_dato  <= uart_dato_registro;

    envio_ocupado     <= envio_ocupado_registro;
    envio_terminado   <= envio_terminado_registro;
    cambio_fin_envio <= cambio_fin_envio_registro;

    process(clk)
    begin

        if rising_edge(clk) then

            uart_start_registro <= '0';
            envio_terminado_registro <= '0';

            if reset = '1' then

                estado <= IDLE;

                imagen_lista_anterior <= cambio_imagen_lista;

                indice_cabecera <= 0;
                indice_dato <= 0;

                direccion_registro <= (others => '0');
                uart_dato_registro <= (others => '0');
                checksum_registro <= (others => '0');

                envio_ocupado_registro <= '0';
                cambio_fin_envio_registro <= '0';

            else

                case estado is

                    when IDLE =>

                        envio_ocupado_registro <= '0';

                        if cambio_imagen_lista /= imagen_lista_anterior then

                            imagen_lista_anterior <= cambio_imagen_lista;

                            indice_cabecera <= 0;
                            indice_dato <= 0;

                            checksum_registro <= (others => '0');

                            envio_ocupado_registro <= '1';
                            estado <= ENVIAR_CABECERA;

                        end if;

                    when ENVIAR_CABECERA =>

                        envio_ocupado_registro <= '1';

                        if uart_busy = '0' then

                            uart_dato_registro <= CABECERA(indice_cabecera);
                            uart_start_registro <= '1';

                            estado <= ESPERAR_CABECERA;

                        end if;

                    when ESPERAR_CABECERA =>

                        envio_ocupado_registro <= '1';

                        if uart_done = '1' then

                            if indice_cabecera = CABECERA'length - 1 then

                                indice_dato <= 0;
                                estado <= PONER_DIRECCION;

                            else

                                indice_cabecera <= indice_cabecera + 1;
                                estado <= ENVIAR_CABECERA;

                            end if;

                        end if;

                    when PONER_DIRECCION =>

                        envio_ocupado_registro <= '1';

                        direccion_registro <=
                            to_unsigned(indice_dato, direccion_registro'length);

                        estado <= ESPERAR_DATO;

                    when ESPERAR_DATO =>

                        envio_ocupado_registro <= '1';

                        estado <= ENVIAR_DATO;

                    when ENVIAR_DATO =>

                        envio_ocupado_registro <= '1';

                        if uart_busy = '0' then

                            uart_dato_registro <= dato_lectura;
                            uart_start_registro <= '1';

                            checksum_registro <=
                                checksum_registro + unsigned(dato_lectura);

                            estado <= ESPERAR_ENVIO;

                        end if;

                    when ESPERAR_ENVIO =>

                        envio_ocupado_registro <= '1';

                        if uart_done = '1' then

                            if indice_dato = TOTAL_PIXELES - 1 then

                                estado <= ENVIAR_CHECKSUM;

                            else

                                indice_dato <= indice_dato + 1;
                                estado <= PONER_DIRECCION;

                            end if;

                        end if;

                    when ENVIAR_CHECKSUM =>

                        envio_ocupado_registro <= '1';

                        if uart_busy = '0' then

                            uart_dato_registro <=
                                std_logic_vector(checksum_registro);

                            uart_start_registro <= '1';

                            estado <= ESPERAR_CHECKSUM;

                        end if;

                    when ESPERAR_CHECKSUM =>

                        envio_ocupado_registro <= '1';

                        if uart_done = '1' then
                            estado <= TERMINADO;
                        end if;

                    when TERMINADO =>

                        envio_ocupado_registro <= '0';
                        envio_terminado_registro <= '1';

                        cambio_fin_envio_registro <=
                            not cambio_fin_envio_registro;

                        estado <= IDLE;

                    when others =>

                        estado <= IDLE;

                end case;

            end if;

        end if;

    end process;

end architecture;
