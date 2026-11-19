library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity calcular_centroides is
    generic (
        MAX_GRUPOS : positive := 64
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;
        start : in std_logic;

        numero_grupos : in integer range 0 to MAX_GRUPOS;
        grupo_valido  : in std_logic;

        area_grupo        : in unsigned(16 downto 0);
        suma_luminancia   : in unsigned(24 downto 0);
        suma_x_luminancia : in unsigned(31 downto 0);
        suma_y_luminancia : in unsigned(31 downto 0);

        area_minima : in unsigned(16 downto 0);
        area_maxima : in unsigned(16 downto 0);

        indice_grupo : out integer range 0 to MAX_GRUPOS - 1;

        listo_lista : in std_logic;

        x_c          : out unsigned(16 downto 0);
        y_c          : out unsigned(16 downto 0);
        area_c       : out unsigned(16 downto 0);
        intensidad_c : out unsigned(24 downto 0);

        centroide_valido : out std_logic;
        fin_centroides  : out std_logic;
        busy            : out std_logic
    );
end entity;

architecture rtl of calcular_centroides is

    type estados is (
        REPOSO,
        PEDIR_GRUPO,
        ESPERAR_GRUPO,
        INICIAR_DIVISION_X,
        DIVIDIR,
        INICIAR_DIVISION_Y,
        ENTREGAR_CENTROIDE,
        SIGUIENTE_GRUPO,
        FIN
    );

    signal estado : estados := REPOSO;

    signal indice : integer range 0 to MAX_GRUPOS - 1 := 0;
    signal total_grupos : integer range 0 to MAX_GRUPOS := 0;

    signal area_registro : unsigned(16 downto 0) := (others => '0');
    signal intensidad_registro : unsigned(24 downto 0) := (others => '0');
    signal suma_x_registro : unsigned(31 downto 0) := (others => '0');
    signal suma_y_registro : unsigned(31 downto 0) := (others => '0');

    signal x_registro : unsigned(16 downto 0) := (others => '0');
    signal y_registro : unsigned(16 downto 0) := (others => '0');

    signal numerador : unsigned(39 downto 0) := (others => '0');
    signal resto     : unsigned(25 downto 0) := (others => '0');
    signal cociente  : unsigned(39 downto 0) := (others => '0');

    signal bit_actual : integer range 0 to 39 := 39;
    signal calculando_y : std_logic := '0';

begin

    indice_grupo <= indice;

    x_c <= x_registro;
    y_c <= y_registro;

    area_c <= area_registro;
    intensidad_c <= intensidad_registro;

    centroide_valido <= '1' when estado = ENTREGAR_CENTROIDE else '0';
    fin_centroides <= '1' when estado = FIN else '0';

    busy <= '0' when estado = REPOSO or estado = FIN else '1';

    process(clk)
        variable nuevo_resto : unsigned(25 downto 0);
        variable nuevo_cociente : unsigned(39 downto 0);
    begin
        if rising_edge(clk) then

            if reset = '1' then

                estado <= REPOSO;
                indice <= 0;
                total_grupos <= 0;

                area_registro <= (others => '0');
                intensidad_registro <= (others => '0');
                suma_x_registro <= (others => '0');
                suma_y_registro <= (others => '0');

                x_registro <= (others => '0');
                y_registro <= (others => '0');

                numerador <= (others => '0');
                resto <= (others => '0');
                cociente <= (others => '0');
                bit_actual <= 39;
                calculando_y <= '0';

            else

                case estado is

                    when REPOSO | FIN =>

                        if start = '1' then

                            indice <= 0;
                            total_grupos <= numero_grupos;

                            estado <= PEDIR_GRUPO;

                        end if;

                    when PEDIR_GRUPO =>

                        if total_grupos = 0 then
                            estado <= FIN;
                        else
                            estado <= ESPERAR_GRUPO;
                        end if;

                    when ESPERAR_GRUPO =>

                        if grupo_valido = '1' then

                            if area_grupo >= area_minima and
                               area_grupo <= area_maxima and
                               suma_luminancia /= 0 then

                                area_registro <= area_grupo;
                                intensidad_registro <= suma_luminancia;
                                suma_x_registro <= suma_x_luminancia;
                                suma_y_registro <= suma_y_luminancia;

                                estado <= INICIAR_DIVISION_X;

                            else

                                estado <= SIGUIENTE_GRUPO;

                            end if;

                        end if;

                    when INICIAR_DIVISION_X =>

                        numerador <= shift_left(
                            resize(suma_x_registro, 40), 8
                        );

                        resto <= (others => '0');
                        cociente <= (others => '0');
                        bit_actual <= 39;
                        calculando_y <= '0';

                        estado <= DIVIDIR;

                    when DIVIDIR =>

                        nuevo_resto := shift_left(resto, 1);
                        nuevo_resto(0) := numerador(bit_actual);

                        nuevo_cociente := cociente;

                        if nuevo_resto >= resize(intensidad_registro, 26) then

                            nuevo_resto := nuevo_resto -
                                resize(intensidad_registro, 26);

                            nuevo_cociente(bit_actual) := '1';

                        else

                            nuevo_cociente(bit_actual) := '0';

                        end if;

                        resto <= nuevo_resto;
                        cociente <= nuevo_cociente;

                        if bit_actual = 0 then

                            if calculando_y = '0' then

                                x_registro <= resize(nuevo_cociente, 17);
                                estado <= INICIAR_DIVISION_Y;

                            else

                                y_registro <= resize(nuevo_cociente, 17);
                                estado <= ENTREGAR_CENTROIDE;

                            end if;

                        else

                            bit_actual <= bit_actual - 1;

                        end if;

                    when INICIAR_DIVISION_Y =>

                        numerador <= shift_left(
                            resize(suma_y_registro, 40), 8
                        );

                        resto <= (others => '0');
                        cociente <= (others => '0');
                        bit_actual <= 39;
                        calculando_y <= '1';

                        estado <= DIVIDIR;

                    when ENTREGAR_CENTROIDE =>

                        if listo_lista = '1' then
                            estado <= SIGUIENTE_GRUPO;
                        end if;

                    when SIGUIENTE_GRUPO =>

                        if indice + 1 < total_grupos then
                            indice <= indice + 1;
                            estado <= PEDIR_GRUPO;
                        else
                            estado <= FIN;
                        end if;

                end case;

            end if;

        end if;
    end process;

end architecture;
