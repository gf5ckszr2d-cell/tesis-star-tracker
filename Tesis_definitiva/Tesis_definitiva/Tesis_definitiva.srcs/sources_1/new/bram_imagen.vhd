
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_imagen is
    generic (
        BITS_DIRECCION : integer := 17;
        BITS_DATO      : integer := 8;
        TOTAL_PIXELES  : integer := 76800
    );
    port (
        clk_escritura       : in std_logic;
        habilitar_escritura : in std_logic;
        direccion_escritura : in unsigned(BITS_DIRECCION - 1 downto 0);
        dato_escritura      : in std_logic_vector(BITS_DATO - 1 downto 0);

        clk_lectura       : in std_logic;
        direccion_lectura : in unsigned(BITS_DIRECCION - 1 downto 0);
        dato_lectura      : out std_logic_vector(BITS_DATO - 1 downto 0)
    );
end entity;

architecture rtl of bram_imagen is

    type memoria_t is array (0 to TOTAL_PIXELES - 1)
        of std_logic_vector(BITS_DATO - 1 downto 0);

    signal memoria : memoria_t := (others => (others => '0'));

    signal dato_lectura_registro : std_logic_vector(BITS_DATO - 1 downto 0)
                                  := (others => '0');

begin

    dato_lectura <= dato_lectura_registro;

    process(clk_escritura)
    begin
        if rising_edge(clk_escritura) then

            if habilitar_escritura = '1' then

                if to_integer(direccion_escritura) < TOTAL_PIXELES then
                    memoria(to_integer(direccion_escritura)) <= dato_escritura;
                end if;

            end if;

        end if;
    end process;

    process(clk_lectura)
    begin
        if rising_edge(clk_lectura) then

            if to_integer(direccion_lectura) < TOTAL_PIXELES then
                dato_lectura_registro <= memoria(to_integer(direccion_lectura));
            else
                dato_lectura_registro <= (others => '0');
            end if;

        end if;
    end process;

end architecture;
