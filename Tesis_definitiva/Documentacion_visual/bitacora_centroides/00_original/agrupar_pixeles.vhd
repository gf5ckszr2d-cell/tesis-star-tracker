library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity agrupar_pixeles is
    generic (
        MAX_ETIQUETAS : positive := 64
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;
        start : in std_logic;

        x            : in unsigned(9 downto 0);
        y            : in unsigned(9 downto 0);
        luminancia   : in std_logic_vector(7 downto 0);
        brillante    : in std_logic;
        pixel_valido : in std_logic;
        ultimo_pixel : in std_logic;

        listo : out std_logic;

        indice_grupo : in integer range 0 to MAX_ETIQUETAS - 1;

        area_grupo       : out unsigned(16 downto 0);
        suma_luminancia  : out unsigned(24 downto 0);
        suma_x_luminancia : out unsigned(31 downto 0);
        suma_y_luminancia : out unsigned(31 downto 0);
        grupo_valido     : out std_logic;

        numero_grupos : out integer range 0 to MAX_ETIQUETAS;
        grupos_listos : out std_logic;
        busy          : out std_logic;
        overflow      : out std_logic
    );
end entity;

architecture rtl of agrupar_pixeles is

    type estados is (
        REPOSO,
        PREPARAR_ETIQUETAS,
        ESPERAR_PIXEL,
        REVISAR_VECINOS,
        BUSCAR_RAIZ,
        UNIR_ETIQUETAS,
        SIGUIENTE_VECINO,
        CREAR_GRUPO,
        ACUMULAR_DATOS,
        MARCAR_FONDO,
        ACTUALIZAR_LINEA,
        CONSOLIDAR_GRUPOS,
        GRUPOS_LISTOS_ESTADO
    );

    subtype etiqueta is integer range 0 to MAX_ETIQUETAS;

    type datos_grupo is record
        padre : etiqueta;
        area  : unsigned(16 downto 0);
        s0    : unsigned(24 downto 0);
        sx    : unsigned(31 downto 0);
        sy    : unsigned(31 downto 0);
    end record;

    constant GRUPO_VACIO : datos_grupo := (
        padre => 0,
        area  => (others => '0'),
        s0    => (others => '0'),
        sx    => (others => '0'),
        sy    => (others => '0')
    );

    type tabla_grupos is array (0 to MAX_ETIQUETAS) of datos_grupo;
    type etiquetas_linea is array (0 to 319) of etiqueta;
    type etiquetas_vecinos is array (0 to 3) of etiqueta;
    type indices_grupos is array (0 to MAX_ETIQUETAS - 1) of etiqueta;

    signal estado : estados := REPOSO;

    signal grupos : tabla_grupos := (others => GRUPO_VACIO);
    signal linea  : etiquetas_linea := (others => 0);
    signal vecinos : etiquetas_vecinos := (others => 0);
    signal mapa_grupos : indices_grupos := (others => 0);

    signal izquierda       : etiqueta := 0;
    signal arriba_izquierda : etiqueta := 0;
    signal etiqueta_arriba : etiqueta := 0;
    signal grupo_actual    : etiqueta := 0;
    signal raiz            : etiqueta := 0;

    signal usadas   : integer range 0 to MAX_ETIQUETAS := 0;
    signal cantidad : integer range 0 to MAX_ETIQUETAS := 0;
    signal vecino_actual : integer range 0 to 3 := 0;
    signal revision : integer range 1 to MAX_ETIQUETAS + 1 := 1;

    signal columna : integer range 0 to 319 := 0;
    signal fila    : integer range 0 to 239 := 0;
    signal valor_y : unsigned(7 downto 0) := (others => '0');
    signal es_ultimo : std_logic := '0';
    signal overflow_registro : std_logic := '0';

    signal grupo_lectura : datos_grupo;

begin

    listo <= '1' when estado = ESPERAR_PIXEL else '0';

    grupos_listos <= '1' when estado = GRUPOS_LISTOS_ESTADO else '0';

    busy <= '0' when estado = REPOSO or
                     estado = GRUPOS_LISTOS_ESTADO else '1';

    numero_grupos <= cantidad;
    overflow <= overflow_registro;

    grupo_lectura <= grupos(mapa_grupos(indice_grupo));

    area_grupo        <= grupo_lectura.area;
    suma_luminancia   <= grupo_lectura.s0;
    suma_x_luminancia <= grupo_lectura.sx;
    suma_y_luminancia <= grupo_lectura.sy;

    grupo_valido <= '1' when estado = GRUPOS_LISTOS_ESTADO and
                             indice_grupo < cantidad else '0';

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then

                estado <= REPOSO;
                cantidad <= 0;
                overflow_registro <= '0';

            else

                case estado is

                    when REPOSO =>

                        if start = '1' then
                            estado <= PREPARAR_ETIQUETAS;
                        end if;

                    when PREPARAR_ETIQUETAS =>

                        grupos <= (others => GRUPO_VACIO);
                        linea <= (others => 0);
                        vecinos <= (others => 0);
                        mapa_grupos <= (others => 0);

                        izquierda <= 0;
                        arriba_izquierda <= 0;
                        grupo_actual <= 0;

                        usadas <= 0;
                        cantidad <= 0;
                        overflow_registro <= '0';

                        estado <= ESPERAR_PIXEL;

                    when ESPERAR_PIXEL =>

                        if pixel_valido = '1' then

                            columna <= to_integer(x);
                            fila <= to_integer(y);
                            valor_y <= unsigned(luminancia);
                            es_ultimo <= ultimo_pixel;

                            etiqueta_arriba <= linea(to_integer(x));
                            vecinos <= (others => 0);

                            if x > 0 then
                                vecinos(0) <= izquierda;
                            end if;

                            if y > 0 then

                                vecinos(2) <= linea(to_integer(x));

                                if x > 0 then
                                    vecinos(1) <= arriba_izquierda;
                                end if;

                                if x < 319 then
                                    vecinos(3) <= linea(to_integer(x) + 1);
                                end if;

                            end if;

                            grupo_actual <= 0;
                            vecino_actual <= 0;

                            if brillante = '1' then
                                estado <= REVISAR_VECINOS;
                            else
                                estado <= MARCAR_FONDO;
                            end if;

                        end if;

                    when REVISAR_VECINOS =>

                        raiz <= vecinos(vecino_actual);
                        estado <= BUSCAR_RAIZ;

                    when BUSCAR_RAIZ =>

                        if raiz = 0 then

                            estado <= SIGUIENTE_VECINO;

                        elsif grupos(raiz).padre /= raiz then

                            raiz <= grupos(raiz).padre;

                        elsif grupo_actual = 0 then

                            grupo_actual <= raiz;
                            estado <= SIGUIENTE_VECINO;

                        elsif raiz = grupo_actual then

                            estado <= SIGUIENTE_VECINO;

                        else

                            estado <= UNIR_ETIQUETAS;

                        end if;

                    when UNIR_ETIQUETAS =>

                        grupos(raiz).padre <= grupo_actual;

                        grupos(grupo_actual).area <=
                            grupos(grupo_actual).area + grupos(raiz).area;

                        grupos(grupo_actual).s0 <=
                            grupos(grupo_actual).s0 + grupos(raiz).s0;

                        grupos(grupo_actual).sx <=
                            grupos(grupo_actual).sx + grupos(raiz).sx;

                        grupos(grupo_actual).sy <=
                            grupos(grupo_actual).sy + grupos(raiz).sy;

                        estado <= SIGUIENTE_VECINO;

                    when SIGUIENTE_VECINO =>

                        if vecino_actual = 3 then

                            if grupo_actual = 0 then
                                estado <= CREAR_GRUPO;
                            else
                                estado <= ACUMULAR_DATOS;
                            end if;

                        else

                            vecino_actual <= vecino_actual + 1;
                            estado <= REVISAR_VECINOS;

                        end if;

                    when CREAR_GRUPO =>

                        if usadas < MAX_ETIQUETAS then

                            usadas <= usadas + 1;
                            grupo_actual <= usadas + 1;
                            grupos(usadas + 1).padre <= usadas + 1;

                            estado <= ACUMULAR_DATOS;

                        else

                            overflow_registro <= '1';
                            grupo_actual <= 0;
                            estado <= ACTUALIZAR_LINEA;

                        end if;

                    when ACUMULAR_DATOS =>

                        grupos(grupo_actual).area <=
                            grupos(grupo_actual).area + 1;

                        grupos(grupo_actual).s0 <=
                            grupos(grupo_actual).s0 + resize(valor_y, 25);

                        grupos(grupo_actual).sx <=
                            grupos(grupo_actual).sx +
                            to_unsigned(columna * to_integer(valor_y), 32);

                        grupos(grupo_actual).sy <=
                            grupos(grupo_actual).sy +
                            to_unsigned(fila * to_integer(valor_y), 32);

                        estado <= ACTUALIZAR_LINEA;

                    when MARCAR_FONDO =>

                        grupo_actual <= 0;
                        estado <= ACTUALIZAR_LINEA;

                    when ACTUALIZAR_LINEA =>

                        linea(columna) <= grupo_actual;

                        if columna = 319 then
                            izquierda <= 0;
                            arriba_izquierda <= 0;
                        else
                            izquierda <= grupo_actual;
                            arriba_izquierda <= etiqueta_arriba;
                        end if;

                        if es_ultimo = '1' then
                            revision <= 1;
                            estado <= CONSOLIDAR_GRUPOS;
                        else
                            estado <= ESPERAR_PIXEL;
                        end if;

                    when CONSOLIDAR_GRUPOS =>

                        if revision > usadas then

                            estado <= GRUPOS_LISTOS_ESTADO;

                        else

                            if grupos(revision).padre = revision and
                               grupos(revision).area /= 0 then

                                mapa_grupos(cantidad) <= revision;
                                cantidad <= cantidad + 1;

                            end if;

                            revision <= revision + 1;

                        end if;

                    when GRUPOS_LISTOS_ESTADO =>

                        if start = '1' then
                            estado <= PREPARAR_ETIQUETAS;
                        end if;

                end case;

            end if;

        end if;
    end process;

end architecture;
