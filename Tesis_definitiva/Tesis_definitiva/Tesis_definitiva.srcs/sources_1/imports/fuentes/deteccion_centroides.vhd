library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity deteccion_centroides is
    port (
        clk, reset, start : in std_logic;
        direccion_lectura : out unsigned(16 downto 0);
        dato_lectura, umbral : in std_logic_vector(7 downto 0);
        area_minima, area_maxima : in unsigned(16 downto 0);
        indice_estrella : in integer range 0 to 63;
        x_estrella, y_estrella, area_estrella : out unsigned(16 downto 0);
        intensidad_estrella : out unsigned(24 downto 0);
        estrella_valida, resultado_listo, overflow : out std_logic;
        cantidad : out integer range 0 to 64
    );
end entity;

architecture rtl of deteccion_centroides is
    type estados is (REPOSO, ESPERAR_GRUPOS, ESPERAR_LISTA, RESULTADO);
    signal estado : estados := REPOSO;
    signal iniciar_lectura, iniciar_calculo : std_logic;
    signal x, y : unsigned(9 downto 0);
    signal luminancia : std_logic_vector(7 downto 0);
    signal brillante, pixel_valido, ultimo_pixel, listo : std_logic;
    signal indice_grupo : integer range 0 to 63;
    signal numero_grupos : integer range 0 to 64;
    signal grupos_listos, grupo_valido : std_logic;
    signal area_grupo : unsigned(16 downto 0);
    signal suma_luminancia : unsigned(24 downto 0);
    signal suma_x_luminancia, suma_y_luminancia : unsigned(31 downto 0);
    signal x_c, y_c, area_c : unsigned(16 downto 0);
    signal intensidad_c : unsigned(24 downto 0);
    signal centroide_valido, fin_centroides, listo_lista, lista_lista : std_logic;
    signal overflow_grupos, overflow_lista, dato_valido : std_logic;
begin
    iniciar_lectura <= start when estado = REPOSO or estado = RESULTADO else '0';
    iniciar_calculo <= '1' when estado = ESPERAR_GRUPOS and grupos_listos = '1' else '0';
    resultado_listo <= '1' when estado = RESULTADO else '0';
    estrella_valida <= dato_valido when estado = RESULTADO else '0';
    overflow <= overflow_grupos or overflow_lista;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                estado <= REPOSO;
            else
                case estado is
                    when REPOSO | RESULTADO =>
                        if start = '1' then
                            estado <= ESPERAR_GRUPOS;
                        end if;
                    when ESPERAR_GRUPOS =>
                        if grupos_listos = '1' then
                            estado <= ESPERAR_LISTA;
                        end if;
                    when ESPERAR_LISTA =>
                        if lista_lista = '1' then
                            estado <= RESULTADO;
                        end if;
                end case;
            end if;
        end if;
    end process;

    clasificar : entity work.umbral_posicion
        port map (
            clk => clk, reset => reset, start => iniciar_lectura,
            dato_lectura => dato_lectura, umbral => umbral, listo => listo,
            direccion_lectura => direccion_lectura, x => x, y => y,
            luminancia => luminancia, brillante => brillante,
            pixel_valido => pixel_valido, ultimo_pixel => ultimo_pixel,
            busy => open, done => open
        );

    agrupar : entity work.agrupar_pixeles
        port map (
            clk => clk, reset => reset, start => iniciar_lectura, x => x, y => y,
            luminancia => luminancia, brillante => brillante, pixel_valido => pixel_valido,
            ultimo_pixel => ultimo_pixel, listo => listo, indice_grupo => indice_grupo,
            area_grupo => area_grupo, suma_luminancia => suma_luminancia,
            suma_x_luminancia => suma_x_luminancia, suma_y_luminancia => suma_y_luminancia,
            grupo_valido => grupo_valido, numero_grupos => numero_grupos,
            grupos_listos => grupos_listos, busy => open, overflow => overflow_grupos
        );

    calcular : entity work.calcular_centroides
        port map (
            clk => clk, reset => reset, start => iniciar_calculo,
            numero_grupos => numero_grupos, grupo_valido => grupo_valido,
            area_grupo => area_grupo, suma_luminancia => suma_luminancia,
            suma_x_luminancia => suma_x_luminancia, suma_y_luminancia => suma_y_luminancia,
            area_minima => area_minima, area_maxima => area_maxima, indice_grupo => indice_grupo,
            listo_lista => listo_lista, x_c => x_c, y_c => y_c, area_c => area_c,
            intensidad_c => intensidad_c, centroide_valido => centroide_valido,
            fin_centroides => fin_centroides, busy => open
        );

    guardar : entity work.lista_estrellas
        port map (
            clk => clk, reset => reset, start => iniciar_calculo,
            x_c => x_c, y_c => y_c, area_c => area_c, intensidad_c => intensidad_c,
            centroide_valido => centroide_valido, fin_centroides => fin_centroides,
            listo_lista => listo_lista, indice_lectura => indice_estrella,
            x_lectura => x_estrella, y_lectura => y_estrella,
            area_lectura => area_estrella, intensidad_lectura => intensidad_estrella,
            dato_valido => dato_valido, cantidad => cantidad,
            lista_lista => lista_lista, overflow => overflow_lista
        );
end architecture;
