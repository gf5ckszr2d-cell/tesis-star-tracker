library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.escenas_pkg.all;
use work.attitude_math_pkg.all;

entity tb_actitud is end entity;

architecture prueba of tb_actitud is
    type paquete_t is array (0 to 26) of std_logic_vector(7 downto 0);
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal iniciar_foto, listo : std_logic := '0';
    signal cantidad : unsigned(7 downto 0) := (others => '0');
    signal indice, observado : unsigned(7 downto 0);
    signal id : unsigned(8 downto 0);
    signal x, y : unsigned(17 downto 0) := (others => '0');
    signal intensidad : unsigned(24 downto 0) := (others => '0');
    signal leido, id_fin, id_ok, id_valido : std_logic := '0';
    signal ray : std_logic_vector(47 downto 0);
    signal identificadas : unsigned(3 downto 0);
    signal escena : natural range 0 to escenas'high := 0;
    signal foto : unsigned(31 downto 0) := (others => '0');
    signal q_fin, q_valido : std_logic;
    signal q : vec4_t;
    signal uart_start, uart_done, paquete_fin : std_logic := '0';
    signal uart_dato : std_logic_vector(7 downto 0);
    signal paquete : paquete_t;
    signal bytes : natural range 0 to 27 := 0;
begin
    clk <= not clk after 4 ns;

    u_id : entity work.star_identifier
        port map (
            clk, rst, listo, '0', cantidad, indice, leido, x, y, intensidad,
            open, id_fin, id_ok, identificadas, id_valido, observado, id, ray
        );

    u_triad : entity work.attitude_triad
        port map (
            clk, rst, iniciar_foto, id_valido, ray, id,
            id_fin, id_ok, q, open, q_fin, q_valido
        );

    u_uart : entity work.enviar_actitud_uart
        port map (
            clk, rst, q_fin, q_valido, identificadas, foto, q,
            '0', uart_done, uart_start, uart_dato, paquete_fin
        );

    process(clk)
        variable i : natural;
    begin
        if rising_edge(clk) then
            i := to_integer(indice);
            leido <= '0';
            if i < to_integer(cantidad) then
                leido <= '1';
                x <= to_unsigned(escenas(escena)(i)(0),18);
                y <= to_unsigned(escenas(escena)(i)(1),18);
                intensidad <= to_unsigned(10+i,25);
            end if;
            uart_done <= uart_start;
            if iniciar_foto = '1' then
                bytes <= 0;
            elsif uart_start = '1' then
                assert bytes < paquete'length severity failure;
                paquete(bytes) <= uart_dato;
                bytes <= bytes + 1;
            end if;
        end if;
    end process;

    process
        variable ciclos_id, ciclos_q, ciclos_uart, esperadas : natural;
        variable suma : unsigned(7 downto 0);
        variable recibido : signed(31 downto 0);
        variable visto : std_logic_vector(7 downto 0);
        variable i : natural;
    begin
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);
        for caso in 0 to escenas'length loop
            foto <= to_unsigned(caso+1,32);
            if caso < escenas'length then
                escena <= caso;
                cantidad <= to_unsigned(cantidades(caso),8);
                esperadas := cantidades(caso);
            else
                escena <= 0;
                cantidad <= to_unsigned(4,8);
                esperadas := 0;
            end if;
            iniciar_foto <= '1';
            wait until rising_edge(clk);
            iniciar_foto <= '0';
            listo <= '1';
            ciclos_id := 0;
            visto := (others => '0');
            loop
                wait until rising_edge(clk);
                wait for 1 ns;
                ciclos_id := ciclos_id+1;
                assert ciclos_id < 150000 severity failure;
                if id_valido = '1' then
                    i := to_integer(observado);
                    assert i < esperadas and visto(i) = '0' severity failure;
                    assert to_integer(id) = escenas(caso)(i)(2) severity failure;
                    visto(i) := '1';
                end if;
                exit when id_fin = '1';
            end loop;
            assert identificadas = esperadas severity failure;
            ciclos_q := 0;
            loop
                wait until rising_edge(clk);
                wait for 1 ns;
                ciclos_q := ciclos_q+1;
                assert ciclos_q < 20000 severity failure;
                exit when q_fin = '1';
            end loop;
            if esperadas /= 0 then
                assert q_valido = '1' report "TRIAD invalido en caso " & integer'image(caso) severity failure;
                for k in 0 to 3 loop
                    assert abs(to_integer(q(k))-cuaterniones(caso)(k)) <= 128
                        report "Componente fuera de tolerancia en caso " & integer'image(caso) severity failure;
                end loop;
            else
                assert q_valido = '0' and q = vec4_t'(others => (others => '0')) severity failure;
            end if;
            ciclos_uart := 0;
            loop
                wait until rising_edge(clk);
                wait for 1 ns;
                ciclos_uart := ciclos_uart+1;
                assert ciclos_uart < 150 severity failure;
                exit when paquete_fin = '1';
            end loop;
            assert bytes = 27 and paquete(0 to 3) = (x"53",x"54",x"51",x"32") severity failure;
            assert paquete(4) = ("0000000" & q_valido) severity failure;
            assert unsigned(paquete(5)) = esperadas severity failure;
            assert unsigned(paquete(9)) = 0 and unsigned(paquete(8)) = 0 and
                   unsigned(paquete(7)) = 0 and unsigned(paquete(6)) = caso+1 severity failure;
            for k in 0 to 3 loop
                for byte in 0 to 3 loop
                    recibido(8*byte+7 downto 8*byte) := signed(paquete(10+4*k+byte));
                end loop;
                assert recibido = q(k) severity failure;
            end loop;
            suma := (others => '0');
            for k in 0 to 25 loop
                suma := suma + unsigned(paquete(k));
            end loop;
            assert suma = unsigned(paquete(26)) severity failure;
            report "CASO " & integer'image(caso) & " MATCHES " & integer'image(esperadas) &
                " CICLOS_ID " & integer'image(ciclos_id) & " CICLOS_Q " & integer'image(ciclos_q) &
                " Q " & integer'image(to_integer(q(0))) & " " & integer'image(to_integer(q(1))) &
                " " & integer'image(to_integer(q(2))) & " " & integer'image(to_integer(q(3)));
            listo <= '0';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
        end loop;
        report "PASS_ACTITUD_UART";
        finish;
    end process;
end architecture;
