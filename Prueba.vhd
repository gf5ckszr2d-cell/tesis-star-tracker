library ieee;
use ieee.std_logic_1164.all;

entity divisor_frecuencia is
    generic (
        DIVIDE_BY : positive := 2  -- división de frecuencia. 2 = /2, 4 = /4, etc.
    );
    port (
        clk_in  : in  std_logic;
        rst     : in  std_logic;
        clk_out : out std_logic
    );
end entity divisor_frecuencia;

architecture rtl of divisor_frecuencia is
    signal counter : integer range 0 to 2147483647 := 0;
    signal clk_reg : std_logic := '0';
    constant HALF_PERIOD : integer := DIVIDE_BY / 2;
begin

    process(clk_in, rst)
    begin
        if rst = '1' then
            counter <= 0;
            clk_reg <= '0';
        elsif rising_edge(clk_in) then
            if DIVIDE_BY < 2 then
                clk_reg <= clk_in; -- sin división válida
            else
                if counter = HALF_PERIOD - 1 then
                    clk_reg <= not clk_reg;
                    counter <= 0;
                else
                    counter <= counter + 1;
                end if;
            end if;
        end if;
    end process;

    clk_out <= clk_reg;

end architecture rtl;
