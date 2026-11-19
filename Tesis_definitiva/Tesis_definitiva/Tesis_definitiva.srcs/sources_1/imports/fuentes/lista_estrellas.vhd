library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lista_estrellas is
    generic (
        MAX_ESTRELLAS : positive := 64
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;
        start : in std_logic;

        x_c          : in unsigned(16 downto 0);
        y_c          : in unsigned(16 downto 0);
        area_c       : in unsigned(16 downto 0);
        intensidad_c : in unsigned(24 downto 0);

        centroide_valido : in std_logic;
        fin_centroides  : in std_logic;

        listo_lista : out std_logic;

        indice_lectura : in integer range 0 to MAX_ESTRELLAS - 1;

        x_lectura          : out unsigned(16 downto 0);
        y_lectura          : out unsigned(16 downto 0);
        area_lectura       : out unsigned(16 downto 0);
        intensidad_lectura : out unsigned(24 downto 0);
        dato_valido        : out std_logic;

        cantidad    : out integer range 0 to MAX_ESTRELLAS;
        lista_lista : out std_logic;
        overflow    : out std_logic
    );
end entity;

architecture rtl of lista_estrellas is

    type estados is (
        REPOSO,
        RECIBIR_CENTROIDE,
        LISTA_PREPARADA
    );

    type datos_estrella is record
        x          : unsigned(16 downto 0);
        y          : unsigned(16 downto 0);
        area       : unsigned(16 downto 0);
        intensidad : unsigned(24 downto 0);
    end record;

    constant ESTRELLA_VACIA : datos_estrella := (
        x          => (others => '0'),
        y          => (others => '0'),
        area       => (others => '0'),
        intensidad => (others => '0')
    );

    type tabla_estrellas is array (0 to MAX_ESTRELLAS - 1)
        of datos_estrella;

    signal estado : estados := REPOSO;

    signal memoria : tabla_estrellas := (others => ESTRELLA_VACIA);
    signal estrella_lectura : datos_estrella;

    signal cantidad_registro : integer range 0 to MAX_ESTRELLAS := 0;
    signal overflow_registro : std_logic := '0';

begin

    listo_lista <= '1' when estado = RECIBIR_CENTROIDE else '0';
    lista_lista <= '1' when estado = LISTA_PREPARADA else '0';

    cantidad <= cantidad_registro;
    overflow <= overflow_registro;

    estrella_lectura <= memoria(indice_lectura);

    x_lectura <= estrella_lectura.x;
    y_lectura <= estrella_lectura.y;
    area_lectura <= estrella_lectura.area;
    intensidad_lectura <= estrella_lectura.intensidad;

    dato_valido <= '1' when estado = LISTA_PREPARADA and
                            indice_lectura < cantidad_registro else '0';

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then

                estado <= REPOSO;
                cantidad_registro <= 0;
                overflow_registro <= '0';

            else

                case estado is

                    when REPOSO | LISTA_PREPARADA =>

                        if start = '1' then

                            cantidad_registro <= 0;
                            overflow_registro <= '0';

                            estado <= RECIBIR_CENTROIDE;

                        end if;

                    when RECIBIR_CENTROIDE =>

                        if centroide_valido = '1' then

                            if cantidad_registro < MAX_ESTRELLAS then

                                memoria(cantidad_registro).x <= x_c;
                                memoria(cantidad_registro).y <= y_c;
                                memoria(cantidad_registro).area <= area_c;

                                memoria(cantidad_registro).intensidad <=
                                    intensidad_c;

                                cantidad_registro <= cantidad_registro + 1;

                            else

                                overflow_registro <= '1';

                            end if;

                        elsif fin_centroides = '1' then

                            estado <= LISTA_PREPARADA;

                        end if;

                end case;

            end if;

        end if;
    end process;

end architecture;
