
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity guardar_imagen is
    generic (
        ANCHO_IMAGEN   : integer := 320;
        ALTO_IMAGEN    : integer := 240;
        BITS_DIRECCION : integer := 17
    );
    port (
        pclk  : in std_logic;
        reset : in std_logic;

        iniciar_captura    : in std_logic;
        cambio_fin_lectura : in std_logic;

        luminancia   : in std_logic_vector(7 downto 0);
        pixel_valido : in std_logic;
        posicion_x   : in unsigned(9 downto 0);
        posicion_y   : in unsigned(9 downto 0);
        fin_imagen   : in std_logic;

        escribir  : out std_logic;
        direccion : out unsigned(BITS_DIRECCION - 1 downto 0);
        dato      : out std_logic_vector(7 downto 0);

        captura_ocupada     : out std_logic;
        imagen_lista        : out std_logic;
        cambio_imagen_lista : out std_logic;
        desbordamiento      : out std_logic
    );
end entity;

architecture rtl of guardar_imagen is

    type estado_t is (
        REPOSO,
        ESPERAR_FIN_IMAGEN,
        CAPTURANDO,
        ESPERANDO_LECTURA
    );

    constant TOTAL_PIXELES : integer := ANCHO_IMAGEN * ALTO_IMAGEN;

    signal estado : estado_t := REPOSO;

    signal escribir_reg : std_logic := '0';

    signal direccion_reg : unsigned(BITS_DIRECCION - 1 downto 0)
                           := (others => '0');

    signal dato_reg : std_logic_vector(7 downto 0)
                      := (others => '0');

    signal imagen_lista_reg        : std_logic := '0';
    signal cambio_imagen_lista_reg : std_logic := '0';
    signal desbordamiento_reg      : std_logic := '0';

    signal contador_pixeles : integer range 0 to TOTAL_PIXELES := 0;

    signal fin_lectura_anterior : std_logic := '0';

begin

    escribir  <= escribir_reg;
    direccion <= direccion_reg;
    dato      <= dato_reg;

    captura_ocupada <= '1' when estado = CAPTURANDO else '0';

    imagen_lista        <= imagen_lista_reg;
    cambio_imagen_lista <= cambio_imagen_lista_reg;
    desbordamiento      <= desbordamiento_reg;

    process(pclk)

        variable direccion_pixel : integer;
        variable contador_actual : integer range 0 to TOTAL_PIXELES;
        variable error_actual    : std_logic;

    begin

        if rising_edge(pclk) then

            escribir_reg <= '0';

            if reset = '1' then

                estado <= REPOSO;

                direccion_reg <= (others => '0');
                dato_reg      <= (others => '0');

                imagen_lista_reg        <= '0';
                cambio_imagen_lista_reg <= '0';
                desbordamiento_reg      <= '0';

                contador_pixeles <= 0;

                fin_lectura_anterior <= cambio_fin_lectura;

            else

                case estado is

                    when REPOSO =>

                        contador_pixeles <= 0;
                        desbordamiento_reg <= '0';

                        if iniciar_captura = '1' then
                            estado <= ESPERAR_FIN_IMAGEN;
                        end if;

                    when ESPERAR_FIN_IMAGEN =>

                        if fin_imagen = '1' then

                            contador_pixeles <= 0;
                            desbordamiento_reg <= '0';

                            estado <= CAPTURANDO;

                        end if;

                    when CAPTURANDO =>

                        contador_actual := contador_pixeles;
                        error_actual := desbordamiento_reg;

                        if pixel_valido = '1' then

                            direccion_pixel :=
                                to_integer(posicion_y) * ANCHO_IMAGEN
                                + to_integer(posicion_x);

                            if to_integer(posicion_x) < ANCHO_IMAGEN and
                               to_integer(posicion_y) < ALTO_IMAGEN and
                               direccion_pixel < TOTAL_PIXELES and
                               contador_actual < TOTAL_PIXELES then

                                escribir_reg <= '1';

                                direccion_reg <= to_unsigned(
                                    direccion_pixel,
                                    direccion_reg'length
                                );

                                dato_reg <= luminancia;

                                contador_actual := contador_actual + 1;
                                contador_pixeles <= contador_actual;

                            else

                                error_actual := '1';
                                desbordamiento_reg <= '1';

                            end if;

                        end if;

                        if fin_imagen = '1' then

                            if contador_actual = TOTAL_PIXELES and
                               error_actual = '0' then

                                imagen_lista_reg <= '1';

                                cambio_imagen_lista_reg <=
                                    not cambio_imagen_lista_reg;

                                estado <= ESPERANDO_LECTURA;

                            else

                                desbordamiento_reg <= '1';
                                contador_pixeles <= 0;

                                estado <= ESPERAR_FIN_IMAGEN;

                            end if;

                        end if;

                    when ESPERANDO_LECTURA =>

                        if cambio_fin_lectura /= fin_lectura_anterior then

                            fin_lectura_anterior <= cambio_fin_lectura;

                            imagen_lista_reg <= '0';

                            estado <= REPOSO;

                        end if;

                    when others =>

                        estado <= REPOSO;

                end case;

            end if;

        end if;

    end process;

end architecture;
