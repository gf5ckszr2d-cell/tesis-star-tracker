-- Generado por generar_rom.py. Referencia nominal fija, no calibrada.
-- Origen de imagen: centro del pixel inferior izquierdo (0,0).
-- Coordenadas unsigned de 17 bits, ocho fraccionarios: pixeles = entero/256.
-- d=250.0 mm; FOV horizontal SUPUESTO=25.0 grados.
-- SHA256 del JSON canonico de calculo: 19b4513e0899e314cf96a6d39518f2551de65a87083174df9cae08a758765655
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package patron_central_pkg is
    constant ANCHO_REFERENCIA : positive := 320;
    constant ALTO_REFERENCIA : positive := 240;
    constant BITS_FRACCIONARIOS : natural := 8;
    constant NUMERO_REFERENCIAS : positive := 2;
    type referencia_estrella is record
        id : unsigned(5 downto 0);
        x, y : unsigned(16 downto 0);
    end record;
    constant REFERENCIA_VACIA : referencia_estrella := (
        id => (others => '0'), x => (others => '0'), y => (others => '0'));
    type tabla_referencias is array (natural range <>) of referencia_estrella;
    constant PATRON_CENTRAL : tabla_referencias(0 to NUMERO_REFERENCIAS-1) := (
        0 => (id => to_unsigned(21, 6), x => to_unsigned(67338, 17), y => to_unsigned(45013, 17)), -- P21
        1 => (id => to_unsigned(28, 6), x => to_unsigned(27128, 17), y => to_unsigned(16370, 17)) -- P28
    );
end package;
