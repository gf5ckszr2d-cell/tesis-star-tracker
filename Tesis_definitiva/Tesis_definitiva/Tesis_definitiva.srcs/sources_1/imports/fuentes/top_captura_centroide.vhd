library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_captura_centroide is
    generic (
        UMBRAL : natural range 0 to 255 := 45;
        AREA_MINIMA : natural range 0 to 76800 := 2;
        AREA_MAXIMA : natural range 0 to 76800 := 500
    );
    port (
        clk, reset, start : in std_logic;
        scl : out std_logic;
        sda : inout std_logic;
        cam_reset, xclk : out std_logic;
        pclk, vsync, href : in std_logic;
        datos : in std_logic_vector(7 downto 0);
        reloj_listo, busy, done, error : out std_logic;
        direccion_externa : in unsigned(16 downto 0);
        dato_externo : out std_logic_vector(7 downto 0);
        indice_estrella : in integer range 0 to 63;
        x_estrella, y_estrella, area_estrella : out unsigned(16 downto 0);
        intensidad_estrella : out unsigned(24 downto 0);
        estrella_valida, resultado_listo, overflow : out std_logic;
        cantidad : out integer range 0 to 64;
        liberar_imagen : in std_logic
    );
end entity;

architecture rtl of top_captura_centroide is
    type estados is (ESPERAR_IMAGEN, ARRANCAR_CENTROIDES,
                     ESPERAR_CENTROIDES, ENTREGAR_RESULTADO);
    signal estado : estados := ESPERAR_IMAGEN;
    signal cambio_imagen, cambio_fin_lectura : std_logic := '0';
    signal imagen_anterior : std_logic := '0';
    signal iniciar_centroides, centroides_listos : std_logic;
    signal direccion_br, direccion_centroide : unsigned(16 downto 0);
    signal dato_br : std_logic_vector(7 downto 0);
begin
    iniciar_centroides <= '1' when estado = ARRANCAR_CENTROIDES else '0';
    resultado_listo <= '1' when estado = ENTREGAR_RESULTADO else '0';
    direccion_br <= direccion_externa when estado = ENTREGAR_RESULTADO else direccion_centroide;
    dato_externo <= dato_br;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                estado <= ESPERAR_IMAGEN;
                imagen_anterior <= '0';
                cambio_fin_lectura <= '0';
            else
                case estado is
                    when ESPERAR_IMAGEN =>
                        if cambio_imagen /= imagen_anterior then
                            imagen_anterior <= cambio_imagen;
                            estado <= ARRANCAR_CENTROIDES;
                        end if;
                    when ARRANCAR_CENTROIDES =>
                        estado <= ESPERAR_CENTROIDES;
                    when ESPERAR_CENTROIDES =>
                        if centroides_listos = '1' then
                            estado <= ENTREGAR_RESULTADO;
                        end if;
                    when ENTREGAR_RESULTADO =>
                        if liberar_imagen = '1' then
                            cambio_fin_lectura <= not cambio_fin_lectura;
                            estado <= ESPERAR_IMAGEN;
                        end if;
                end case;
            end if;
        end if;
    end process;

    camara : entity work.captura
        port map (
            clk => clk, reset => reset, start => start,
            scl => scl, sda => sda, cam_reset => cam_reset, xclk => xclk,
            pclk => pclk, vsync => vsync, href => href, datos => datos,
            direccion_lectura => direccion_br, dato_lectura => dato_br,
            cambio_imagen_lista_clk => cambio_imagen, cambio_fin_lectura => cambio_fin_lectura,
            reloj_listo => reloj_listo, busy => busy, done => done, error => error
        );

    centroides : entity work.deteccion_centroides
        port map (
            clk => clk, reset => reset, start => iniciar_centroides,
            direccion_lectura => direccion_centroide, dato_lectura => dato_br,
            umbral => std_logic_vector(to_unsigned(UMBRAL, 8)),
            area_minima => to_unsigned(AREA_MINIMA, 17), area_maxima => to_unsigned(AREA_MAXIMA, 17),
            indice_estrella => indice_estrella, x_estrella => x_estrella,
            y_estrella => y_estrella, area_estrella => area_estrella,
            intensidad_estrella => intensidad_estrella, estrella_valida => estrella_valida,
            resultado_listo => centroides_listos, overflow => overflow, cantidad => cantidad
        );
end architecture;
