library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_rom_patron_central is end entity;
architecture prueba of tb_rom_patron_central is
    signal clk : std_logic := '0';
    signal habilitar, valido : std_logic := '0';
    signal indice, id : unsigned(5 downto 0) := (others => '0');
    signal xr,yr : unsigned(16 downto 0);
    signal entrada_valida, salida_valida : std_logic := '0';
    signal xe,ye,xs,ys : unsigned(16 downto 0) := (others => '0');
    signal reset : std_logic := '1';
    signal start, centroide_valido, fin, busy, convertido : std_logic := '0';
    signal xc,yc,area, x_inferior,y_inferior : unsigned(16 downto 0);
    signal intensidad : unsigned(24 downto 0);
    signal indice_grupo : integer range 0 to 63;
begin
    clk <= not clk after 4 ns;
    rom : entity work.rom_patron_central
        port map(clk,habilitar,indice,valido,id,xr,yr);
    adaptar : entity work.coordenadas_inferior_izquierda
        port map(entrada_valida,xe,ye,salida_valida,xs,ys);
    calcular : entity work.calcular_centroides
        port map(clk=>clk,reset=>reset,start=>start,numero_grupos=>1,grupo_valido=>'1',
            area_grupo=>to_unsigned(3,17),suma_luminancia=>to_unsigned(300,25),
            suma_x_luminancia=>to_unsigned(1500,32),suma_y_luminancia=>to_unsigned(69300,32),
            area_minima=>to_unsigned(2,17),area_maxima=>to_unsigned(500,17),
            indice_grupo=>indice_grupo,listo_lista=>'1',x_c=>xc,y_c=>yc,area_c=>area,
            intensidad_c=>intensidad,centroide_valido=>centroide_valido,fin_centroides=>fin,busy=>busy);
    adaptar_real : entity work.coordenadas_inferior_izquierda
        port map(centroide_valido,xc,yc,convertido,x_inferior,y_inferior);

    process
        procedure flanco is begin wait until rising_edge(clk); wait for 1 ns; end;
        procedure comprobar_xy(a,b,c,d : natural; esperado : std_logic) is
        begin
            entrada_valida<='1'; xe<=to_unsigned(a,17); ye<=to_unsigned(b,17);
            wait for 1 ns;
            assert salida_valida=esperado severity failure;
            assert to_integer(xs)=c and to_integer(ys)=d severity failure;
        end;
    begin
        wait for 1 ns;
        assert valido='0' report "ROM inicialmente invalida" severity failure;
        flanco;
        habilitar<='1'; indice<=to_unsigned(0,6);
        wait for 1 ns;
        assert valido='0' report "La ROM no debe responder antes del flanco" severity failure;
        flanco;
        assert valido='1' and id=21 and xr=67338 and yr=45013
            report "P21 incorrecta" severity failure;
        indice<=to_unsigned(1,6); wait for 1 ns;
        assert id=21 report "La salida debe estar registrada" severity failure;
        flanco;
        assert valido='1' and id=28 and xr=27128 and yr=16370
            report "P28 incorrecta" severity failure;
        for i in 2 to 63 loop
            indice<=to_unsigned(i,6); flanco;
            assert valido='0' and id=0 and xr=0 and yr=0
                report "Direccion fuera de ROM no anulada" severity failure;
        end loop;
        indice<=(others=>'0'); habilitar<='0'; flanco;
        assert valido='0' and xr=0 and yr=0 severity failure;
        comprobar_xy(0,0,0,61184,'1');
        comprobar_xy(81664,61184,81664,0,'1');
        comprobar_xy(1408,2112,1408,59072,'1'); -- (5.5,8.25) -> (5.5,230.75)
        comprobar_xy(81665,0,0,0,'0');
        comprobar_xy(0,61185,0,0,'0');
        entrada_valida<='0'; wait for 1 ns;
        assert salida_valida='0' and xs=0 and ys=0 severity failure;
        reset<='0'; start<='1'; flanco; start<='0';
        wait until centroide_valido='1' for 2 us; wait for 1 ns;
        assert centroide_valido='1' report "El calculo existente no entrego XY" severity failure;
        assert xc=1280 and yc=59136 report "Centroide real distinto de (5,231)" severity failure;
        assert convertido='1' and x_inferior=1280 and y_inferior=2048
            report "El centroide debe salir en X=5,Y=8 desde abajo" severity failure;
        report "PASS_ROM_PATRON_CENTRAL: P21/P28, 62 direcciones invalidas, lectura sincrona, conversion y centroide real X=5 Y=8";
        finish;
    end process;
    process begin wait for 10 us; assert false report "TIMEOUT" severity failure; end process;
end architecture;
