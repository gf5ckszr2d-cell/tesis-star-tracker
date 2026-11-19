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
        LEER_RAIZ,
        LEER_GRUPO_UNION,
        UNIR_ETIQUETAS,
        SIGUIENTE_VECINO,
        CREAR_GRUPO,
        CALCULAR_PESO,
        ACUMULAR_DATOS,
        MARCAR_FONDO,
        ACTUALIZAR_LINEA,
        LEER_REVISION,
        CONSOLIDAR_GRUPOS,
        GRUPOS_LISTOS_ESTADO
    );

    subtype etiqueta is integer range 0 to MAX_ETIQUETAS;

    type datos_grupo is record
        area  : unsigned(16 downto 0);
        s0    : unsigned(24 downto 0);
        sx    : unsigned(31 downto 0);
        sy    : unsigned(31 downto 0);
    end record;

    constant GRUPO_VACIO : datos_grupo := (
        area  => (others => '0'),
        s0    => (others => '0'),
        sx    => (others => '0'),
        sy    => (others => '0')
    );

    subtype palabra_grupo is unsigned(105 downto 0);
    type tabla_grupos is array (0 to MAX_ETIQUETAS) of palabra_grupo;
    type tabla_padres is array (0 to MAX_ETIQUETAS) of etiqueta;
    type etiquetas_linea is array (0 to 319) of etiqueta;
    type etiquetas_vecinos is array (0 to 3) of etiqueta;
    type indices_grupos is array (0 to MAX_ETIQUETAS - 1) of etiqueta;

    signal estado : estados := REPOSO;

    signal grupos : tabla_grupos;
    attribute ram_style : string;
    attribute ram_style of grupos : signal is "block";
    signal padres : tabla_padres := (others => 0);
    signal linea  : etiquetas_linea := (others => 0);
    signal vecinos : etiquetas_vecinos := (others => 0);
    signal mapa_grupos : indices_grupos := (others => 0);

    signal izquierda       : etiqueta := 0;
    signal arriba_izquierda : etiqueta := 0;
    signal etiqueta_arriba : etiqueta := 0;
    signal grupo_actual    : etiqueta := 0;
    signal raiz            : etiqueta := 0;
    signal grupo_nuevo     : std_logic := '0';

    signal usadas   : integer range 0 to MAX_ETIQUETAS := 0;
    signal cantidad : integer range 0 to MAX_ETIQUETAS := 0;
    signal vecino_actual : integer range 0 to 3 := 0;
    signal revision : integer range 1 to MAX_ETIQUETAS + 1 := 1;

    signal columna : integer range 0 to 319 := 0;
    signal fila    : integer range 0 to 239 := 0;
    signal valor_y : unsigned(7 downto 0) := (others => '0');
    signal peso_x : unsigned(16 downto 0) := (others => '0');
    signal peso_y : unsigned(15 downto 0) := (others => '0');
    signal es_ultimo : std_logic := '0';
    signal overflow_registro : std_logic := '0';

    signal etiqueta_lectura : etiqueta := 0;
    signal etiqueta_valida  : std_logic := '0';
    signal grupo_leido      : datos_grupo;
    signal datos_raiz       : datos_grupo := GRUPO_VACIO;
    signal leer_grupo       : etiqueta;
    signal guardar_grupo    : etiqueta := 0;
    signal dato_leido       : palabra_grupo;
    signal dato_guardado    : palabra_grupo := (others => '0');
    signal escribir_grupo   : std_logic := '0';

begin

    listo <= '1' when estado = ESPERAR_PIXEL else '0';

    grupos_listos <= '1' when estado = GRUPOS_LISTOS_ESTADO else '0';

    busy <= '0' when estado = REPOSO or
                     estado = GRUPOS_LISTOS_ESTADO else '1';

    numero_grupos <= cantidad;
    overflow <= overflow_registro;

    leer_grupo <= raiz when estado = LEER_RAIZ else
                  grupo_actual when estado = LEER_GRUPO_UNION or estado = CALCULAR_PESO else
                  revision when estado = LEER_REVISION and revision <= usadas else
                  etiqueta_lectura when estado = GRUPOS_LISTOS_ESTADO else
                  0;

    grupo_leido.area <= dato_leido(105 downto 89);
    grupo_leido.s0   <= dato_leido(88 downto 64);
    grupo_leido.sx   <= dato_leido(63 downto 32);
    grupo_leido.sy   <= dato_leido(31 downto 0);

    area_grupo        <= grupo_leido.area;
    suma_luminancia   <= grupo_leido.s0;
    suma_x_luminancia <= grupo_leido.sx;
    suma_y_luminancia <= grupo_leido.sy;

    process(clk)
    begin
        if rising_edge(clk) then
            if escribir_grupo = '1' then
                grupos(guardar_grupo) <= dato_guardado;
            end if;
            dato_leido <= grupos(leer_grupo);
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            etiqueta_lectura <= mapa_grupos(indice_grupo);

            if reset = '0' and start = '0' and estado = GRUPOS_LISTOS_ESTADO then
                if indice_grupo < cantidad then
                    etiqueta_valida <= '1';
                else
                    etiqueta_valida <= '0';
                end if;

                grupo_valido <= etiqueta_valida;
            else
                etiqueta_valida <= '0';
                grupo_valido <= '0';
            end if;
        end if;
    end process;

    process(clk)
        variable anterior : datos_grupo;
        variable nuevo    : datos_grupo;
    begin
        if rising_edge(clk) then

            escribir_grupo <= '0';

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
                            grupo_nuevo <= '0';
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

                        elsif padres(raiz) /= raiz then

                            raiz <= padres(raiz);

                        elsif grupo_actual = 0 then

                            grupo_actual <= raiz;
                            estado <= SIGUIENTE_VECINO;

                        elsif raiz = grupo_actual then

                            estado <= SIGUIENTE_VECINO;

                        else

                            estado <= LEER_RAIZ;

                        end if;

                    when LEER_RAIZ =>

                        estado <= LEER_GRUPO_UNION;

                    when LEER_GRUPO_UNION =>

                        datos_raiz <= grupo_leido;
                        estado <= UNIR_ETIQUETAS;

                    when UNIR_ETIQUETAS =>

                        padres(raiz) <= grupo_actual;
                        nuevo.area := grupo_leido.area + datos_raiz.area;
                        nuevo.s0 := grupo_leido.s0 + datos_raiz.s0;
                        nuevo.sx := grupo_leido.sx + datos_raiz.sx;
                        nuevo.sy := grupo_leido.sy + datos_raiz.sy;
                        dato_guardado <= nuevo.area & nuevo.s0 & nuevo.sx & nuevo.sy;
                        guardar_grupo <= grupo_actual;
                        escribir_grupo <= '1';

                        estado <= SIGUIENTE_VECINO;

                    when SIGUIENTE_VECINO =>

                        if vecino_actual = 3 then

                            if grupo_actual = 0 then
                                estado <= CREAR_GRUPO;
                            else
                                estado <= CALCULAR_PESO;
                            end if;

                        else

                            vecino_actual <= vecino_actual + 1;
                            estado <= REVISAR_VECINOS;

                        end if;

                    when CREAR_GRUPO =>

                        if usadas < MAX_ETIQUETAS then

                            usadas <= usadas + 1;
                            grupo_actual <= usadas + 1;
                            padres(usadas + 1) <= usadas + 1;
                            grupo_nuevo <= '1';

                            estado <= CALCULAR_PESO;

                        else

                            overflow_registro <= '1';
                            grupo_actual <= 0;
                            estado <= ACTUALIZAR_LINEA;

                        end if;

                    when CALCULAR_PESO =>

                        peso_x <= to_unsigned(columna, 9) * valor_y;
                        peso_y <= to_unsigned(fila, 8) * valor_y;
                        estado <= ACUMULAR_DATOS;

                    when ACUMULAR_DATOS =>

                        anterior := grupo_leido;
                        if grupo_nuevo = '1' then
                            anterior := GRUPO_VACIO;
                        end if;

                        nuevo.area := anterior.area + 1;
                        nuevo.s0 := anterior.s0 + resize(valor_y, 25);
                        nuevo.sx := anterior.sx + resize(peso_x, 32);
                        nuevo.sy := anterior.sy + resize(peso_y, 32);
                        dato_guardado <= nuevo.area & nuevo.s0 & nuevo.sx & nuevo.sy;
                        guardar_grupo <= grupo_actual;
                        escribir_grupo <= '1';

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
                            estado <= LEER_REVISION;
                        else
                            estado <= ESPERAR_PIXEL;
                        end if;

                    when LEER_REVISION =>

                        if revision > usadas then

                            estado <= GRUPOS_LISTOS_ESTADO;

                        else

                            estado <= CONSOLIDAR_GRUPOS;

                        end if;

                    when CONSOLIDAR_GRUPOS =>

                        if padres(revision) = revision and grupo_leido.area /= 0 then
                            mapa_grupos(cantidad) <= revision;
                            cantidad <= cantidad + 1;
                        end if;

                        revision <= revision + 1;
                        estado <= LEER_REVISION;

                    when GRUPOS_LISTOS_ESTADO =>

                        if start = '1' then
                            estado <= PREPARAR_ETIQUETAS;
                        end if;

                end case;

            end if;

        end if;
    end process;

end architecture;
