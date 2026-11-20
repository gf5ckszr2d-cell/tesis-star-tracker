library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.escenas_pkg.all;

entity tb_identificacion is end entity;

architecture prueba of tb_identificacion is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal disponible, desborde : std_logic := '0';
    signal cantidad : unsigned(7 downto 0) := (others => '0');
    signal indice, obs : unsigned(7 downto 0);
    signal id : unsigned(8 downto 0);
    signal x, y : unsigned(17 downto 0);
    signal intensidad : unsigned(24 downto 0);
    signal leido, hecho, exito, coincide : std_logic;
    signal coincide_n : unsigned(3 downto 0);
    signal escenario : natural range 0 to escenas'high := 0;
begin
    clk <= not clk after 4 ns;
    dut : entity work.star_identifier
        port map (
            clk, rst, disponible, desborde, cantidad, indice, leido,
            x, y, intensidad, open, hecho, exito, coincide_n,
            coincide, obs, id, open
        );
    process(clk)
        variable i : natural;
    begin
        if rising_edge(clk) then
            i := to_integer(indice);
            leido <= '0';
            if i < 8 and i < to_integer(cantidad) then
                leido <= '1';
                x <= to_unsigned(escenas(escenario)(i)(0),18);
                y <= to_unsigned(escenas(escenario)(i)(1),18);
                intensidad <= to_unsigned(10+i,25);
            elsif i = 8 and cantidad = 9 then
                leido <= '1';
                x <= to_unsigned(70*256,18);
                y <= to_unsigned(85*256,18);
                intensidad <= to_unsigned(1,25);
            end if;
        end if;
    end process;
    process
        variable contados : natural;
        variable vistos : std_logic_vector(7 downto 0);
        variable i, ciclos : natural;
        constant prueba_nueve : natural := escenas'length;
        constant prueba_cuatro : natural := prueba_nueve + 1;
        constant prueba_desborde : natural := prueba_nueve + 2;
    begin
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);
        for caso in 0 to prueba_desborde loop
            if caso < prueba_nueve then
                escenario <= caso;
                cantidad <= to_unsigned(cantidades(caso),8);
            elsif caso = prueba_nueve then
                escenario <= 0;
                cantidad <= to_unsigned(9,8);
            elsif caso = prueba_cuatro then
                cantidad <= to_unsigned(4,8);
            else
                cantidad <= to_unsigned(8,8);
                desborde <= '1';
            end if;
            disponible <= '1';
            contados := 0;
            vistos := (others => '0');
            ciclos := 0;
            loop
                wait until rising_edge(clk);
                wait for 1 ns;
                ciclos := ciclos+1;
                assert ciclos < 80000 report "Sin respuesta del identificador" severity failure;
                if coincide = '1' then
                    i := to_integer(obs);
                    assert caso <= prueba_nueve and i < 8 severity failure;
                    assert vistos(i) = '0' severity failure;
                    assert to_integer(id) = escenas(escenario)(i)(2)
                        report "ID incorrecto en caso " & integer'image(caso) severity failure;
                    vistos(i) := '1';
                    contados := contados+1;
                end if;
                exit when hecho = '1';
            end loop;
            if caso <= prueba_nueve then
                assert exito = '1' and contados = cantidades(escenario) and coincide_n = contados
                    report "Asignaciones incompletas en caso " & integer'image(caso) severity failure;
            else
                assert exito = '0' and contados = 0 severity failure;
            end if;
            report "CASO " & integer'image(caso) & " coincidencias " & integer'image(contados) &
                " ciclos " & integer'image(ciclos);
            disponible <= '0';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
        end loop;
        report "PASS_IDENTIFICACION_CENTRAL";
        finish;
    end process;
end architecture;
