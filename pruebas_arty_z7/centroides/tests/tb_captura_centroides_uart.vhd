library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

architecture camara_simulada of captura is
    signal numero_foto : natural := 0;
begin
    scl <= '1';
    sda <= 'Z';
    cam_reset <= not reset;
    xclk <= '0';
    reloj_listo <= '1';
    busy <= '0';
    done <= '1';
    error <= '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                numero_foto <= 0;
                cambio_imagen_lista_clk <= '0';
            elsif start = '1' then
                if numero_foto = 1 then
                    assert cambio_fin_lectura = '1'
                        report "La primera imagen sigue ocupada" severity failure;
                end if;
                numero_foto <= numero_foto + 1;
                if numero_foto mod 2 = 0 then
                    cambio_imagen_lista_clk <= '1';
                else
                    cambio_imagen_lista_clk <= '0';
                end if;
            end if;

            dato_lectura <= x"08";
            if numero_foto = 1 then
                case to_integer(direccion_lectura) is
                    when 20 * 320 + 10 => dato_lectura <= x"3C";
                    when 20 * 320 + 11 => dato_lectura <= x"B4";
                    when 180 * 320 + 270 => dato_lectura <= x"3C";
                    when 180 * 320 + 272 => dato_lectura <= x"78";
                    when 181 * 320 + 271 => dato_lectura <= x"5A";
                    when 50 * 320 + 200 => dato_lectura <= x"C8";
                    when 50 * 320 + 201 => dato_lectura <= x"2C";
                    when others => null;
                end case;
            end if;
        end if;
    end process;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

architecture salida_simulada of uart_tx is
    file salida : text open write_mode is "uart_bytes.txt";
    constant TAM_IMAGEN : natural := 76813;
    constant FIN_PRIMER_PAR : natural := TAM_IMAGEN + 9 + 32;
    constant FIN_SEGUNDO_PAR : natural := FIN_PRIMER_PAR + TAM_IMAGEN + 9;
    signal cantidad : natural := 0;
    signal ocupado : std_logic := '0';
begin
    busy <= ocupado;
    process(clk)
        variable renglon : line;
    begin
        if rising_edge(clk) then
            done <= '0';
            tx_line <= '1';
            if reset = '1' then
                ocupado <= '0';
                cantidad <= 0;
            elsif ocupado = '1' then
                ocupado <= '0';
                done <= '1';
                if cantidad = FIN_PRIMER_PAR or cantidad = FIN_SEGUNDO_PAR then
                    tx_line <= '0';
                end if;
            elsif tx_start = '1' then
                write(renglon, to_integer(unsigned(tx_data)));
                writeline(salida, renglon);
                cantidad <= cantidad + 1;
                ocupado <= '1';
            end if;
        end if;
    end process;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_captura_centroides_uart is
end entity;

architecture sim of tb_captura_centroides_uart is
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal start : std_logic := '0';
    signal tx, sda : std_logic;
begin
    clk <= not clk after 4 ns;
    prueba : entity work.top_star_tracker
        port map (
            clk => clk, reset => reset, start => start, scl => open, sda => sda,
            cam_reset => open, xclk => open, pclk => '0', vsync => '0',
            href => '0', datos => x"00", tx => tx,
            reloj_listo => open, busy => open, done => open, error => open
        );

    process
    begin
        wait for 32 ns;
        reset <= '0';
        for n in 1 to 2 loop
            wait until falling_edge(clk);
            start <= '1';
            wait until falling_edge(clk);
            start <= '0';
            wait until falling_edge(tx);
            wait for 80 ns;
        end loop;
        report "Dos pares STY1/STC1 recibidos";
        finish;
    end process;

    process
    begin
        wait for 30 ms;
        assert false report "No llegaron las dos parejas completas" severity failure;
    end process;
end architecture;
