"""Genera constantes de ROM a partir del calculo nominal ya existente."""
import csv
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
FUENTE = HERE.parent / 'Documentacion/Geometria_patron/resultados_nominales/calculo.json'

def referencias():
    datos = json.loads(FUENTE.read_text(encoding='utf-8'))
    p = datos['parameters']
    registros = []
    for fila in datos['stars']:
        if not fila['inside_nominal_fov']:
            continue
        x = fila['u_expected']
        y = p['image_height_px'] - 1 - fila['v_expected']
        registros.append(dict(id=int(fila['id'][1:]), nombre=fila['id'],
            x_px=x, y_px=y, x_256=round(x*256), y_256=round(y*256),
            x_monitor_izquierda_px=fila['u_monitor'],
            y_monitor_abajo_px=p['screen_height_px']-1-fila['v_monitor'],
            x_monitor_arco_desde_izquierda_mm=fila['x_from_left_arc_mm'],
            y_monitor_desde_abajo_mm=fila['y_from_bottom_mm']))
    assert 0 < len(registros) <= 64
    assert p['image_width_px'] <= 512 and p['image_height_px'] <= 512
    for r in registros:
        assert 0 <= r['x_256'] <= (p['image_width_px']-1)*256
        assert 0 <= r['y_256'] <= (p['image_height_px']-1)*256
    return datos, registros

def main():
    datos, filas = referencias()
    p = datos['parameters']
    digest = hashlib.sha256(json.dumps(datos,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    # Commas must precede line comments in a VHDL aggregate.
    entradas = '\n'.join(f"        {i} => (id => to_unsigned({r['id']}, 6), x => to_unsigned({r['x_256']}, 17), y => to_unsigned({r['y_256']}, 17)){',' if i+1<len(filas) else ''} -- {r['nombre']}" for i,r in enumerate(filas))
    codigo = f'''-- Generado por generar_rom.py. Referencia nominal fija, no calibrada.
-- Origen de imagen: centro del pixel inferior izquierdo (0,0).
-- Coordenadas unsigned de 17 bits, ocho fraccionarios: pixeles = entero/256.
-- d={p['distance_mm']} mm; FOV horizontal SUPUESTO={p['horizontal_fov_deg']} grados.
-- SHA256 del JSON canonico de calculo: {digest}
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package patron_central_pkg is
    constant ANCHO_REFERENCIA : positive := {p['image_width_px']};
    constant ALTO_REFERENCIA : positive := {p['image_height_px']};
    constant BITS_FRACCIONARIOS : natural := 8;
    constant NUMERO_REFERENCIAS : positive := {len(filas)};
    type referencia_estrella is record
        id : unsigned(5 downto 0);
        x, y : unsigned(16 downto 0);
    end record;
    constant REFERENCIA_VACIA : referencia_estrella := (
        id => (others => '0'), x => (others => '0'), y => (others => '0'));
    type tabla_referencias is array (natural range <>) of referencia_estrella;
    constant PATRON_CENTRAL : tabla_referencias(0 to NUMERO_REFERENCIAS-1) := (
{entradas}
    );
end package;
'''
    (HERE/'rtl').mkdir(exist_ok=True)
    (HERE/'rtl/patron_central_pkg.vhd').write_text(codigo,encoding='utf-8')
    with (HERE/'referencia_rom.csv').open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(filas[0])); w.writeheader(); w.writerows(filas)
    print(f"ROM: {len(filas)} referencias; origen inferior izquierdo; 17 bits, escala 256")
    for r in filas: print(f"{r['nombre']}: X={r['x_px']:.6f}, Y={r['y_px']:.6f}; enteros=({r['x_256']},{r['y_256']})")

if __name__ == '__main__': main()
