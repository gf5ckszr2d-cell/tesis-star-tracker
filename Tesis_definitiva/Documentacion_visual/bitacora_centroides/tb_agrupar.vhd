library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.env.all;
entity tb_agrupar is end;
architecture sim of tb_agrupar is
signal clk : std_logic := '0';
signal reset : std_logic := '1';
signal start, valido, ultimo, brillante : std_logic := '0';
signal x,y : unsigned(9 downto 0) := (others=>'0');
signal lum : std_logic_vector(7 downto 0) := (others=>'0');
signal listo, terminado, ocupado, exceso, grupo_valido : std_logic;
signal indice : integer range 0 to 63 := 0;
signal cantidad : integer range 0 to 64;
signal area : unsigned(16 downto 0);
signal s0 : unsigned(24 downto 0);
signal sx,sy : unsigned(31 downto 0);
type resultado is record
a : unsigned(16 downto 0);
s0 : unsigned(24 downto 0);
sx,sy : unsigned(31 downto 0);
end record;
type tabla_resultados is array(integer range <>) of resultado;
type marcas is array(integer range <>) of boolean;
constant esperado_0 : tabla_resultados(0 to 6) := (
0 => (to_unsigned(2,17), to_unsigned(30,25), x"00000014", x"00000014"),
1 => (to_unsigned(1,17), to_unsigned(30,25), x"00002562", x"0000005a"),
2 => (to_unsigned(1,17), to_unsigned(40,25), x"00000000", x"000000a0"),
3 => (to_unsigned(4,17), to_unsigned(260,25), x"00000776", x"00000b0e"),
4 => (to_unsigned(3,17), to_unsigned(300,25), x"00000cee", x"000017de"),
5 => (to_unsigned(4,17), to_unsigned(540,25), x"00002b48", x"00005582"),
6 => (to_unsigned(1,17), to_unsigned(200,25), x"0000f938", x"0000bab8")
);
constant esperado_1 : tabla_resultados(0 to 0) := (
0 => (to_unsigned(76800,17), to_unsigned(19584000,25), x"ba2f1600", x"8b7df600")
);
constant esperado_3 : tabla_resultados(0 to 63) := (
0 => (to_unsigned(1,17), to_unsigned(10,25), x"00000000", x"00000000"),
1 => (to_unsigned(1,17), to_unsigned(11,25), x"00000016", x"00000000"),
2 => (to_unsigned(1,17), to_unsigned(12,25), x"00000030", x"00000000"),
3 => (to_unsigned(1,17), to_unsigned(13,25), x"0000004e", x"00000000"),
4 => (to_unsigned(1,17), to_unsigned(14,25), x"00000070", x"00000000"),
5 => (to_unsigned(1,17), to_unsigned(15,25), x"00000096", x"00000000"),
6 => (to_unsigned(1,17), to_unsigned(16,25), x"000000c0", x"00000000"),
7 => (to_unsigned(1,17), to_unsigned(17,25), x"000000ee", x"00000000"),
8 => (to_unsigned(1,17), to_unsigned(18,25), x"00000120", x"00000000"),
9 => (to_unsigned(1,17), to_unsigned(19,25), x"00000156", x"00000000"),
10 => (to_unsigned(1,17), to_unsigned(20,25), x"00000190", x"00000000"),
11 => (to_unsigned(1,17), to_unsigned(21,25), x"000001ce", x"00000000"),
12 => (to_unsigned(1,17), to_unsigned(22,25), x"00000210", x"00000000"),
13 => (to_unsigned(1,17), to_unsigned(23,25), x"00000256", x"00000000"),
14 => (to_unsigned(1,17), to_unsigned(24,25), x"000002a0", x"00000000"),
15 => (to_unsigned(1,17), to_unsigned(25,25), x"000002ee", x"00000000"),
16 => (to_unsigned(1,17), to_unsigned(26,25), x"00000340", x"00000000"),
17 => (to_unsigned(1,17), to_unsigned(27,25), x"00000396", x"00000000"),
18 => (to_unsigned(1,17), to_unsigned(28,25), x"000003f0", x"00000000"),
19 => (to_unsigned(1,17), to_unsigned(29,25), x"0000044e", x"00000000"),
20 => (to_unsigned(1,17), to_unsigned(30,25), x"000004b0", x"00000000"),
21 => (to_unsigned(1,17), to_unsigned(31,25), x"00000516", x"00000000"),
22 => (to_unsigned(1,17), to_unsigned(32,25), x"00000580", x"00000000"),
23 => (to_unsigned(1,17), to_unsigned(33,25), x"000005ee", x"00000000"),
24 => (to_unsigned(1,17), to_unsigned(34,25), x"00000660", x"00000000"),
25 => (to_unsigned(1,17), to_unsigned(35,25), x"000006d6", x"00000000"),
26 => (to_unsigned(1,17), to_unsigned(36,25), x"00000750", x"00000000"),
27 => (to_unsigned(1,17), to_unsigned(37,25), x"000007ce", x"00000000"),
28 => (to_unsigned(1,17), to_unsigned(38,25), x"00000850", x"00000000"),
29 => (to_unsigned(1,17), to_unsigned(39,25), x"000008d6", x"00000000"),
30 => (to_unsigned(1,17), to_unsigned(40,25), x"00000960", x"00000000"),
31 => (to_unsigned(1,17), to_unsigned(41,25), x"000009ee", x"00000000"),
32 => (to_unsigned(1,17), to_unsigned(42,25), x"00000a80", x"00000000"),
33 => (to_unsigned(1,17), to_unsigned(43,25), x"00000b16", x"00000000"),
34 => (to_unsigned(1,17), to_unsigned(44,25), x"00000bb0", x"00000000"),
35 => (to_unsigned(1,17), to_unsigned(45,25), x"00000c4e", x"00000000"),
36 => (to_unsigned(1,17), to_unsigned(46,25), x"00000cf0", x"00000000"),
37 => (to_unsigned(1,17), to_unsigned(47,25), x"00000d96", x"00000000"),
38 => (to_unsigned(1,17), to_unsigned(48,25), x"00000e40", x"00000000"),
39 => (to_unsigned(1,17), to_unsigned(49,25), x"00000eee", x"00000000"),
40 => (to_unsigned(1,17), to_unsigned(50,25), x"00000fa0", x"00000000"),
41 => (to_unsigned(1,17), to_unsigned(51,25), x"00001056", x"00000000"),
42 => (to_unsigned(1,17), to_unsigned(52,25), x"00001110", x"00000000"),
43 => (to_unsigned(1,17), to_unsigned(53,25), x"000011ce", x"00000000"),
44 => (to_unsigned(1,17), to_unsigned(54,25), x"00001290", x"00000000"),
45 => (to_unsigned(1,17), to_unsigned(55,25), x"00001356", x"00000000"),
46 => (to_unsigned(1,17), to_unsigned(56,25), x"00001420", x"00000000"),
47 => (to_unsigned(1,17), to_unsigned(57,25), x"000014ee", x"00000000"),
48 => (to_unsigned(1,17), to_unsigned(58,25), x"000015c0", x"00000000"),
49 => (to_unsigned(1,17), to_unsigned(59,25), x"00001696", x"00000000"),
50 => (to_unsigned(1,17), to_unsigned(60,25), x"00001770", x"00000000"),
51 => (to_unsigned(1,17), to_unsigned(61,25), x"0000184e", x"00000000"),
52 => (to_unsigned(1,17), to_unsigned(62,25), x"00001930", x"00000000"),
53 => (to_unsigned(1,17), to_unsigned(63,25), x"00001a16", x"00000000"),
54 => (to_unsigned(1,17), to_unsigned(64,25), x"00001b00", x"00000000"),
55 => (to_unsigned(1,17), to_unsigned(65,25), x"00001bee", x"00000000"),
56 => (to_unsigned(1,17), to_unsigned(66,25), x"00001ce0", x"00000000"),
57 => (to_unsigned(1,17), to_unsigned(67,25), x"00001dd6", x"00000000"),
58 => (to_unsigned(1,17), to_unsigned(68,25), x"00001ed0", x"00000000"),
59 => (to_unsigned(1,17), to_unsigned(69,25), x"00001fce", x"00000000"),
60 => (to_unsigned(1,17), to_unsigned(70,25), x"000020d0", x"00000000"),
61 => (to_unsigned(1,17), to_unsigned(71,25), x"000021d6", x"00000000"),
62 => (to_unsigned(1,17), to_unsigned(72,25), x"000022e0", x"00000000"),
63 => (to_unsigned(1,17), to_unsigned(73,25), x"000023ee", x"00000000")
);
constant esperado_4 : tabla_resultados(0 to 0) := (
0 => (to_unsigned(1,17), to_unsigned(255,25), x"00013dc1", x"0000ee11")
);
function valor(caso, px,py : integer) return integer is
begin
case caso is
when 0 =>
if px = 0 and py = 0 then return 10; end if;
if px = 1 and py = 1 then return 20; end if;
if px = 319 and py = 3 then return 30; end if;
if px = 0 and py = 4 then return 40; end if;
if px = 6 and py = 10 then return 50; end if;
if px = 8 and py = 10 then return 60; end if;
if px = 7 and py = 11 then return 70; end if;
if px = 8 and py = 12 then return 80; end if;
if px = 10 and py = 20 then return 90; end if;
if px = 12 and py = 20 then return 100; end if;
if px = 11 and py = 21 then return 110; end if;
if px = 20 and py = 40 then return 120; end if;
if px = 21 and py = 40 then return 130; end if;
if px = 20 and py = 41 then return 140; end if;
if px = 21 and py = 41 then return 150; end if;
if px = 319 and py = 239 then return 200; end if;
when 1 => return 255;
when 2 => return 0;
when 3 =>
if py=0 and px<=128 and px mod 2=0 then return 10+px/2; end if;
when 4 =>
if px=319 and py=239 then return 255; end if;
when others => null;
end case;
return 0;
end;
begin
clk <= not clk after 4 ns;
u: entity work.agrupar_pixeles port map(
clk=>clk,reset=>reset,start=>start,x=>x,y=>y,luminancia=>lum,brillante=>brillante,
pixel_valido=>valido,ultimo_pixel=>ultimo,listo=>listo,
indice_grupo=>indice,area_grupo=>area,suma_luminancia=>s0,
suma_x_luminancia=>sx,suma_y_luminancia=>sy,grupo_valido=>grupo_valido,
numero_grupos=>cantidad,grupos_listos=>terminado,busy=>ocupado,overflow=>exceso);
process
procedure enviar(caso : integer) is
variable v : integer;
begin
wait until falling_edge(clk); start<='1';
wait until falling_edge(clk); start<='0';
for py in 0 to 239 loop
for px in 0 to 319 loop
v:=valor(caso,px,py);
x<=to_unsigned(px,10); y<=to_unsigned(py,10);
lum<=std_logic_vector(to_unsigned(v,8));
if v>0 then brillante<='1'; else brillante<='0'; end if;
if px=319 and py=239 then ultimo<='1'; else ultimo<='0'; end if;
valido<='1';
loop
wait until rising_edge(clk);
exit when listo='1';
end loop;
wait until falling_edge(clk);
valido<='0';
end loop;
end loop;
wait until terminado='1';
wait for 1 ns;
end;
procedure comprobar(esperado : tabla_resultados; desb : std_logic) is
variable vistos : marcas(esperado'range):=(others=>false);
variable encontrado : boolean;
begin
assert cantidad=esperado'length report "cantidad incorrecta" severity failure;
assert exceso=desb report "overflow incorrecto" severity failure;
for i in 0 to cantidad-1 loop
indice<=i;
wait until rising_edge(clk);
wait until rising_edge(clk);
wait for 1 ns;
assert grupo_valido='1' severity failure;
encontrado:=false;
for j in esperado'range loop
if not vistos(j) and area=esperado(j).a and s0=esperado(j).s0 and sx=esperado(j).sx and sy=esperado(j).sy then
vistos(j):=true; encontrado:=true; exit;
end if;
end loop;
assert encontrado report "acumulados incorrectos" severity failure;
end loop;
end;
begin
wait for 30 ns;
wait until falling_edge(clk); reset<='0';
enviar(0); comprobar(esperado_0,'0');
enviar(1); comprobar(esperado_1,'0');
enviar(2); assert cantidad=0 and exceso='0' report "imagen vacia incorrecta" severity failure;
enviar(3); comprobar(esperado_3,'1');
enviar(4); comprobar(esperado_4,'0');
report "PASS agrupacion: diagonales, uniones, bordes, QVGA completa, vacio, limite y reinicio de frame";
finish;
end process;
process begin wait for 100 ms; assert false report "timeout" severity failure; end process;
end;
