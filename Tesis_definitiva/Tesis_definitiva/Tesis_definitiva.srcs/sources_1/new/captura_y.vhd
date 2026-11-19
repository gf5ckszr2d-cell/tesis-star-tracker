
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity captura_y is
    generic (
        ANCHO_IMAGEN : integer := 320;
        ALTO_IMAGEN  : integer := 240;
        NIVEL_VSYNC  : std_logic := '1';
        NIVEL_HREF   : std_logic := '1'
    );
    port (
        pclk      : in std_logic;
        reset     : in std_logic;
        habilitar : in std_logic;

        vsync : in std_logic;
        href  : in std_logic;
        datos : in std_logic_vector(7 downto 0);

        luminancia     : out std_logic_vector(7 downto 0);
        pixel_valido   : out std_logic;
        posicion_x     : out unsigned(9 downto 0);
        posicion_y     : out unsigned(9 downto 0);
        imagen_activa  : out std_logic;
        fin_imagen     : out std_logic;
        desbordamiento : out std_logic
    );
end entity;

architecture rtl of captura_y is

    type estado_t is (
        DESHABILITADO,
        ESPERAR_SINCRONIA,
        ESPERAR_IMAGEN,
        ESPERAR_LINEA,
        CAPTURAR_LINEA
    );

    signal estado : estado_t := DESHABILITADO;

    signal contador_x : integer range 0 to ANCHO_IMAGEN := 0;
    signal contador_y : integer range 0 to ALTO_IMAGEN := 0;
    signal fase_byte  : integer range 0 to 3 := 0;

    signal href_activo   : std_logic;
    signal vsync_activo  : std_logic;
    signal href_anterior : std_logic := '0';

    signal luminancia_reg : std_logic_vector(7 downto 0)
                            := (others => '0');

    signal posicion_x_reg : unsigned(9 downto 0)
                            := (others => '0');

    signal posicion_y_reg : unsigned(9 downto 0)
                            := (others => '0');

    signal pixel_valido_reg   : std_logic := '0';
    signal imagen_activa_reg  : std_logic := '0';
    signal fin_imagen_reg     : std_logic := '0';
    signal desbordamiento_reg : std_logic := '0';

begin

    href_activo  <= '1' when href = NIVEL_HREF else '0';
    vsync_activo <= '1' when vsync = NIVEL_VSYNC else '0';

    luminancia     <= luminancia_reg;
    pixel_valido   <= pixel_valido_reg;
    posicion_x     <= posicion_x_reg;
    posicion_y     <= posicion_y_reg;
    imagen_activa  <= imagen_activa_reg;
    fin_imagen     <= fin_imagen_reg;
    desbordamiento <= desbordamiento_reg;

    process(pclk)

        procedure recibir_byte is
        begin

            if contador_y < ALTO_IMAGEN then

                if fase_byte = 0 or fase_byte = 2 then

                    if contador_x < ANCHO_IMAGEN then

                        luminancia_reg <= datos;

                        posicion_x_reg <=
                            to_unsigned(
                                contador_x,
                                posicion_x_reg'length
                            );

                        posicion_y_reg <=
                            to_unsigned(
                                contador_y,
                                posicion_y_reg'length
                            );

                        pixel_valido_reg <= '1';
                        contador_x <= contador_x + 1;

                    else

                        desbordamiento_reg <= '1';

                    end if;

                end if;

            else

                desbordamiento_reg <= '1';

            end if;

            if fase_byte = 3 then

                fase_byte <= 0;

            else

                fase_byte <= fase_byte + 1;

            end if;

        end procedure;

        procedure cerrar_linea is
        begin

            contador_x <= 0;
            fase_byte  <= 0;

            if href_anterior = '1' then

                if contador_y < ALTO_IMAGEN then

                    contador_y <= contador_y + 1;

                else

                    desbordamiento_reg <= '1';

                end if;

            end if;

        end procedure;

    begin

        if rising_edge(pclk) then

            pixel_valido_reg <= '0';
            fin_imagen_reg   <= '0';

            if reset = '1' then

                estado <= DESHABILITADO;

                contador_x <= 0;
                contador_y <= 0;
                fase_byte  <= 0;

                href_anterior     <= '0';
                imagen_activa_reg <= '0';

                luminancia_reg <= (others => '0');
                posicion_x_reg <= (others => '0');
                posicion_y_reg <= (others => '0');

                desbordamiento_reg <= '0';

            elsif habilitar = '0' then

                estado <= DESHABILITADO;

                contador_x <= 0;
                contador_y <= 0;
                fase_byte  <= 0;

                href_anterior     <= href_activo;
                imagen_activa_reg <= '0';

            else

                href_anterior <= href_activo;

                if vsync_activo = '1' then

                    estado <= ESPERAR_IMAGEN;

                    if imagen_activa_reg = '1' then
                        fin_imagen_reg <= '1';
                    end if;

                    contador_x <= 0;
                    contador_y <= 0;
                    fase_byte  <= 0;

                    imagen_activa_reg <= '0';

                else

                    case estado is

                        when DESHABILITADO | ESPERAR_SINCRONIA =>

                            estado <= ESPERAR_SINCRONIA;

                            contador_x <= 0;
                            contador_y <= 0;
                            fase_byte  <= 0;

                            imagen_activa_reg <= '0';

                        when ESPERAR_IMAGEN =>

                            desbordamiento_reg <= '0';

                            if href_activo = '1' then

                                imagen_activa_reg <= '1';
                                estado <= CAPTURAR_LINEA;
                                recibir_byte;

                            else

                                estado <= ESPERAR_LINEA;
                                cerrar_linea;

                            end if;

                        when ESPERAR_LINEA =>

                            if href_activo = '1' then

                                imagen_activa_reg <= '1';
                                estado <= CAPTURAR_LINEA;
                                recibir_byte;

                            else

                                estado <= ESPERAR_LINEA;
                                cerrar_linea;

                            end if;

                        when CAPTURAR_LINEA =>

                            if href_activo = '1' then

                                estado <= CAPTURAR_LINEA;
                                recibir_byte;

                            else

                                estado <= ESPERAR_LINEA;
                                cerrar_linea;

                            end if;

                        when others =>

                            estado <= DESHABILITADO;

                    end case;

                end if;

            end if;

        end if;

    end process;

end architecture;