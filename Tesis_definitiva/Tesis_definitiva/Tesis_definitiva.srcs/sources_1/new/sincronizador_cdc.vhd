
library ieee;
use ieee.std_logic_1164.all;

entity sincronizador_cdc is
    port (
        clk_destino : in std_logic;
        reset       : in std_logic;

        dato_entrada : in std_logic;
        dato_salida  : out std_logic
    );
end entity;

architecture rtl of sincronizador_cdc is

    signal etapa_1 : std_logic := '0';
    signal etapa_2 : std_logic := '0';

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of etapa_1 : signal is "TRUE";
    attribute ASYNC_REG of etapa_2 : signal is "TRUE";

    attribute SHREG_EXTRACT : string;
    attribute SHREG_EXTRACT of etapa_1 : signal is "NO";
    attribute SHREG_EXTRACT of etapa_2 : signal is "NO";

begin

    dato_salida <= etapa_2;

    process(clk_destino)
    begin
        if rising_edge(clk_destino) then

            if reset = '1' then

                etapa_1 <= '0';
                etapa_2 <= '0';

            else

                etapa_1 <= dato_entrada;
                etapa_2 <= etapa_1;

            end if;

        end if;
    end process;

end architecture;
