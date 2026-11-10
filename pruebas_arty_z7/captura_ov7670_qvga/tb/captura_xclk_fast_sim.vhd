library ieee;
use ieee.std_logic_1164.all;
-- Simulation ONLY: geometry/UART regression. MMCM RTL is unchanged and was
-- verified separately with the full UNISIM model. Not listed in fuentes.tcl.
architecture fast_sim of captura_xclk is
    signal test_clock : std_logic := '0';
begin
    test_clock <= not test_clock after 20.833333 ns;
    xclk <= test_clock when rst='0' else '0';
    locked <= not rst;
end architecture;
