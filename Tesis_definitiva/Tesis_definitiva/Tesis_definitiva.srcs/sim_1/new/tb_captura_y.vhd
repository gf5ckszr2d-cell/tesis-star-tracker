library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_captura_y is
end entity;

architecture sim of tb_captura_y is

    constant ANCHO : integer := 320;
    constant ALTO  : integer := 240;

    signal pclk      : std_logic := '0';
    signal reinicio  : std_logic := '1';
    signal habilitar : std_logic := '0';

    signal vsync : std_logic := '0';
    signal href  : std_logic := '0';
    signal datos : std_logic_vector(7 downto 0) := (others => '0');

    signal luminancia     : std_logic_vector(7 downto 0);
    signal pixel_valido   : std_logic;
    signal posicion_x     : unsigned(9 downto 0);
    signal posicion_y     : unsigned(9 downto 0);
    signal imagen_activa  : std_logic;
    signal fin_imagen     : std_logic;
    signal desbordamiento : std_logic;

begin

    pclk <= not pclk after 10 ns;

    modulo : entity work.captura_y
        generic map (
            ANCHO_IMAGEN => ANCHO,
            ALTO_IMAGEN  => ALTO
        )
        port map (
            pclk           => pclk,
            reset => reinicio,
            habilitar      => habilitar,
            vsync          => vsync,
            href           => href,
            datos          => datos,
            luminancia     => luminancia,
            pixel_valido   => pixel_valido,
            posicion_x     => posicion_x,
            posicion_y     => posicion_y,
            imagen_activa  => imagen_activa,
            fin_imagen     => fin_imagen,
            desbordamiento => desbordamiento
        );

    prueba : process

        procedure avanzar is
        begin
            wait until rising_edge(pclk);
            wait for 1 ns;
        end procedure;

    begin

        avanzar;
        avanzar;

        assert pixel_valido = '0' and imagen_activa = '0'
               and fin_imagen = '0' and desbordamiento = '0'
            report "ERROR: reinicio incorrecto"
            severity failure;

        reinicio <= '0';
        href <= '1';
        avanzar;

        assert pixel_valido = '0' and imagen_activa = '0'
            report "ERROR: captura sin habilitar"
            severity failure;

        habilitar <= '1';
        avanzar;

        assert pixel_valido = '0' and imagen_activa = '0'
            report "ERROR: captura antes de VSYNC"
            severity failure;

        href <= '0';
        vsync <= '1';
        avanzar;

        vsync <= '0';
        avanzar;

        for y in 0 to ALTO - 1 loop

            href <= '1';

            for x in 0 to ANCHO - 1 loop

                datos <= std_logic_vector(
                    to_unsigned((x + 3 * y) mod 256, 8)
                );

                avanzar;

                assert pixel_valido = '1'
                       and luminancia = datos
                       and posicion_x = to_unsigned(x, 10)
                       and posicion_y = to_unsigned(y, 10)
                       and imagen_activa = '1'
                       and fin_imagen = '0'
                       and desbordamiento = '0'
                    report "ERROR: pixel o coordenadas incorrectos"
                    severity failure;

                datos <= x"A5";
                avanzar;

                assert pixel_valido = '0'
                    report "ERROR: se capturo un byte de color"
                    severity failure;

            end loop;

            href <= '0';
            avanzar;

            assert pixel_valido = '0' and desbordamiento = '0'
                   and fin_imagen = '0'
                report "ERROR: cierre de linea incorrecto"
                severity failure;

        end loop;

        vsync <= '1';
        avanzar;

        assert fin_imagen = '1' and imagen_activa = '0'
               and pixel_valido = '0' and desbordamiento = '0'
            report "ERROR: fin de imagen incorrecto"
            severity failure;

        avanzar;

        assert fin_imagen = '0'
            report "ERROR: fin_imagen dura mas de un ciclo"
            severity failure;

        vsync <= '0';
        href <= '1';

        for i in 0 to ANCHO * 2 loop
            datos <= x"00";
            avanzar;
        end loop;

        assert desbordamiento = '1'
            report "ERROR: no se detecto el desbordamiento"
            severity failure;

        reinicio <= '1';
        avanzar;

        assert desbordamiento = '0' and pixel_valido = '0'
               and imagen_activa = '0' and fin_imagen = '0'
            report "ERROR: reinicio final incorrecto"
            severity failure;

        report "PRUEBA CORRECTA";

        finish;

    end process;

end architecture;