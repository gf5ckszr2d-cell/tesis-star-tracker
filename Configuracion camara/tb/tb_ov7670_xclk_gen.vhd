library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

entity tb_ov7670_xclk_gen is
end entity;

architecture sim of tb_ov7670_xclk_gen is

    constant CLK_100MHZ_PERIOD : time := 10 ns;
    constant XCLK_PERIOD_MIN   : time := 41 ns;
    constant XCLK_PERIOD_MAX   : time := 42 ns;
    constant XCLK_HIGH_MIN     : time := 20 ns;
    constant XCLK_HIGH_MAX     : time := 22 ns;
    constant LOCKED_VIEW_TIME  : time := 10 us;

    signal clk_100mhz : std_logic := '0';
    signal rst        : std_logic := '1';

    signal xclk   : std_logic;
    signal locked : std_logic;

begin

    uut : entity work.ov7670_xclk_gen
        port map (
            clk_100mhz => clk_100mhz,
            rst        => rst,
            xclk       => xclk,
            locked     => locked
        );

    clk_process : process
    begin
        while true loop
            clk_100mhz <= '0';
            wait for CLK_100MHZ_PERIOD / 2;
            clk_100mhz <= '1';
            wait for CLK_100MHZ_PERIOD / 2;
        end loop;
    end process;

    stimulus : process
        variable rise_time_1 : time;
        variable rise_time_2 : time;
        variable fall_time   : time;
        variable xclk_period : time;
        variable xclk_high   : time;
    begin
        report "Inicio test unitario ov7670_xclk_gen";

        rst <= '1';
        wait for 200 ns;

        assert locked = '0'
            report "ERROR: locked debe estar en 0 durante reset"
            severity failure;

        rst <= '0';

        wait until locked = '1' for 20 us;
        assert locked = '1'
            report "ERROR: timeout esperando locked despues de liberar reset"
            severity failure;

        wait until rising_edge(xclk);
        rise_time_1 := now;
        wait until falling_edge(xclk);
        fall_time := now;
        wait until rising_edge(xclk);
        rise_time_2 := now;

        xclk_period := rise_time_2 - rise_time_1;
        xclk_high := fall_time - rise_time_1;

        assert xclk_period >= XCLK_PERIOD_MIN and xclk_period <= XCLK_PERIOD_MAX
            report "ERROR: periodo XCLK fuera del rango esperado de 24 MHz"
            severity failure;

        assert xclk_high >= XCLK_HIGH_MIN and xclk_high <= XCLK_HIGH_MAX
            report "ERROR: duty cycle XCLK fuera del rango esperado"
            severity failure;

        report "XCLK bloqueado y verificado: periodo=" & time'image(xclk_period) &
               ", tiempo alto=" & time'image(xclk_high);

        wait for LOCKED_VIEW_TIME;

        rst <= '1';
        wait for 200 ns;

        assert locked = '0'
            report "ERROR: locked no regreso a 0 al aplicar reset"
            severity failure;

        rst <= '0';

        wait until locked = '1' for 20 us;
        assert locked = '1'
            report "ERROR: timeout esperando segundo bloqueo"
            severity failure;

        wait until rising_edge(xclk);
        rise_time_1 := now;
        wait until rising_edge(xclk);
        rise_time_2 := now;
        xclk_period := rise_time_2 - rise_time_1;

        assert xclk_period >= XCLK_PERIOD_MIN and xclk_period <= XCLK_PERIOD_MAX
            report "ERROR: periodo XCLK incorrecto despues del segundo bloqueo"
            severity failure;

        wait for LOCKED_VIEW_TIME;

        report "PASS_OV7670_XCLK_GEN: locked, reset y XCLK de 24 MHz correctos";

        finish;
    end process;

    watchdog : process
    begin
        wait for 50 us;
        assert false
            report "ERROR: timeout test unitario ov7670_xclk_gen"
            severity failure;
    end process;

end architecture;
