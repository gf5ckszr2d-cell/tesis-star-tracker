library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.patron_central_pkg.all;

-- Lectura sincrona: habilitar e indice se muestrean en el flanco ascendente.
-- Las salidas registradas corresponden a esa peticion. No hay matching.
-- Una ROM de dos entradas puede implementarse en LUT; no se exige BRAM.
entity rom_patron_central is
    port (
        clk : in std_logic;
        habilitar : in std_logic;
        indice : in unsigned(5 downto 0);
        valido : out std_logic;
        id_referencia : out unsigned(5 downto 0);
        x_referencia, y_referencia : out unsigned(16 downto 0)
    );
end entity;

architecture rtl of rom_patron_central is
    signal dato : referencia_estrella := REFERENCIA_VACIA;
    signal dato_valido : std_logic := '0';
begin
    id_referencia <= dato.id;
    x_referencia <= dato.x;
    y_referencia <= dato.y;
    valido <= dato_valido;
    process(clk)
    begin
        if rising_edge(clk) then
            dato <= REFERENCIA_VACIA;
            dato_valido <= '0';
            if habilitar = '1' then
                if to_integer(indice) < NUMERO_REFERENCIAS then
                    dato <= PATRON_CENTRAL(to_integer(indice));
                    dato_valido <= '1';
                end if;
            end if;
        end if;
    end process;
end architecture;
