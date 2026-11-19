"""Recibe una pareja STY1/STC1 y compara centroides con la misma foto en PC."""
import argparse
import base64
import csv
from datetime import datetime
from html import escape
import json
import math
from pathlib import Path
import struct
import time

from recibir_imagen import Decoder, HEADER, PACKET_SIZE, WIDTH, HEIGHT, PIXELS, png_bytes

TOLERANCIA = 0.006
RADIO_ASOCIACION = 3.0


def decodificar_lista(trama):
    if len(trama) < 9 or trama[:4] != b"STC1":
        raise ValueError("Falta la cabecera de centroides STC1.")
    cantidad, overflow, umbral, reservado = trama[4:8]
    if cantidad > 64 or overflow > 1 or reservado != 0 or len(trama) != 9 + 16 * cantidad:
        raise ValueError("Longitud o cabecera STC1 incorrecta.")
    if sum(trama[:-1]) & 255 != trama[-1]:
        raise ValueError("Checksum STC1 incorrecto.")
    estrellas = []
    for x, y, area, intensidad in struct.iter_unpack("<IIII", trama[8:-1]):
        if x > (WIDTH - 1) * 256 or y > (HEIGHT - 1) * 256:
            raise ValueError("Coordenada STC1 fuera de la imagen.")
        if not 1 <= area <= PIXELS or not 1 <= intensidad <= 255 * area:
            raise ValueError("Área o intensidad STC1 fuera de rango.")
        estrellas.append((x / 256, y / 256, area, intensidad))
    return estrellas, umbral, bool(overflow)


class Receptor:
    def __init__(self):
        self.buffer = bytearray()
        self.texto = Decoder()
        self.ready = False

    def feed(self, datos):
        self.buffer.extend(datos)
        pares = []
        while True:
            inicio = self.buffer.find(b"STY1")
            if inicio < 0:
                conservar = next((n for n in (3, 2, 1) if self.buffer.endswith(b"STY1"[:n])), 0)
                usados = len(self.buffer) - conservar
                self.texto._noise(self.buffer[:usados])
                del self.buffer[:usados]
                break
            self.texto._noise(self.buffer[:inicio])
            del self.buffer[:inicio]
            if len(self.buffer) < PACKET_SIZE + 8:
                break
            if self.buffer[:12] != HEADER:
                raise ValueError("Cabecera STY1 incorrecta.")
            foto = bytes(self.buffer[12:PACKET_SIZE - 1])
            if sum(foto) & 255 != self.buffer[PACKET_SIZE - 1]:
                raise ValueError("Checksum STY1 incorrecto.")
            if self.buffer[PACKET_SIZE:PACKET_SIZE + 4] != b"STC1":
                raise ValueError("No llegó STC1 inmediatamente después de la foto.")
            cantidad = self.buffer[PACKET_SIZE + 4]
            if cantidad > 64:
                raise ValueError("Cantidad STC1 fuera de rango.")
            fin = PACKET_SIZE + 9 + 16 * cantidad
            if len(self.buffer) < fin:
                break
            trama = bytes(self.buffer[PACKET_SIZE:fin])
            decodificar_lista(trama)
            pares.append((foto, trama))
            del self.buffer[:fin]
        for linea in self.texto.messages:
            print(linea, flush=True)
            if linea.startswith("ARM CENTROIDES READY"):
                self.ready = True
            if linea.startswith("ERROR "):
                raise RuntimeError(linea)
        self.texto.messages.clear()
        return pares


def referencia(foto, umbral, area_min=2, area_max=500):
    """Componentes mediante búsqueda de vecinos en la imagen completa."""
    mascara = bytearray(pixel >= umbral for pixel in foto)
    estrellas = []
    for posicion in range(PIXELS):
        if not mascara[posicion]:
            continue
        mascara[posicion] = 0
        pendientes = [posicion]
        area = total = sx = sy = 0
        while pendientes:
            actual = pendientes.pop()
            y, x = divmod(actual, WIDTH)
            y8 = foto[actual]
            area += 1
            total += y8
            sx += x * y8
            sy += y * y8
            for yy in range(max(0, y - 1), min(HEIGHT, y + 2)):
                for xx in range(max(0, x - 1), min(WIDTH, x + 2)):
                    vecino = yy * WIDTH + xx
                    if mascara[vecino]:
                        mascara[vecino] = 0
                        pendientes.append(vecino)
        if area_min <= area <= area_max and total:
            estrellas.append((sx / total, sy / total, area, total))
    return estrellas


def comparar(fpga, ref):
    candidatos = sorted((math.hypot(f[0] - r[0], f[1] - r[1]), i, j)
                        for i, f in enumerate(fpga) for j, r in enumerate(ref))
    pares = {}
    usados = set()
    for distancia, i, j in candidatos:
        if distancia > RADIO_ASOCIACION:
            break
        if i not in pares and j not in usados:
            pares[i] = (j, distancia)
            usados.add(j)
    filas = []
    for i, f in enumerate(fpga):
        if i in pares:
            j, distancia = pares[i]
            r = ref[j]
            estado = "OK" if distancia <= TOLERANCIA and f[2:] == r[2:] else "diferencia"
            filas.append((i, *f, j, *r, distancia, estado))
        else:
            filas.append((i, *f, None, None, None, None, None, None, "extra"))
    for j, r in enumerate(ref):
        if j not in usados:
            filas.append((None, None, None, None, None, j, *r, None, "faltante"))
    return filas


COLUMNAS = ("i FPGA", "X FPGA", "Y FPGA", "Área FPGA", "S0 FPGA",
            "i PC", "X PC", "Y PC", "Área PC", "S0 PC", "Error px", "Resultado")


def guardar(foto, trama, destino, origen):
    fpga, umbral, overflow = decodificar_lista(trama)
    ref = referencia(foto, umbral)
    filas = comparar(fpga, ref)
    aprobado = not overflow and all(f[-1] == "OK" for f in filas)
    errores = [f[-2] for f in filas if f[-2] is not None]
    destino.mkdir(parents=True, exist_ok=False)
    imagen = png_bytes(foto)
    (destino / "foto.png").write_bytes(imagen)
    (destino / "foto.sty1").write_bytes(HEADER + foto + bytes([sum(foto) & 255]))
    (destino / "centroides.stc1").write_bytes(trama)
    with (destino / "centroides.csv").open("w", newline="", encoding="utf-8-sig") as archivo:
        writer = csv.writer(archivo)
        writer.writerow(COLUMNAS)
        writer.writerows(filas)
    resumen = {"origen": origen, "umbral": umbral, "area_min": 2, "area_max": 500,
               "tolerancia_numerica_px": TOLERANCIA, "radio_asociacion_px": RADIO_ASOCIACION,
               "detecciones_fpga": len(fpga), "detecciones_pc": len(ref), "overflow": overflow,
               "diferencias": sum(f[-1] != "OK" for f in filas),
               "error_max_px": max(errores, default=None), "coincide_con_pc": aprobado}
    (destino / "resumen.json").write_text(json.dumps(resumen, indent=2), encoding="utf-8")
    marcadores = []
    for j, (x, y, _, _) in enumerate(ref):
        marcadores.append(f'<circle cx="{x}" cy="{y}" r="4" fill="none" stroke="#51f1ab" stroke-width=".8"><title>PC {j}</title></circle>')
    for i, (x, y, _, _) in enumerate(fpga):
        marcadores.append(f'<path d="M{x - 5},{y}h10 M{x},{y - 5}v10" stroke="#ffb347" stroke-width=".9"/>'
                          f'<text x="{x + 5 if x < 297 else x - 17}" y="{y - 4 if y > 8 else y + 12}" fill="#ffce89" font-size="5">#{i}</text>')
    def visible(valor):
        if valor is None:
            return "—"
        return f"{valor:.4f}" if isinstance(valor, float) else escape(str(valor))
    celdas = "".join("<tr>" + "".join(f"<td>{visible(v)}</td>" for v in fila) + "</tr>" for fila in filas)
    if not filas:
        celdas = '<tr><td colspan="12">Ninguna estrella detectada por la FPGA ni por la referencia.</td></tr>'
    svg = "".join(marcadores)
    encabezados = "".join(f"<th>{escape(c)}</th>" for c in COLUMNAS)
    png = base64.b64encode(imagen).decode()
    resultado = "Coincide con la referencia" if aprobado else "Revisar diferencias"
    (destino / "validacion.html").write_text(f"""<!doctype html><html lang="es"><meta charset="utf-8">
<title>Validación de centroides</title><style>
body{{font:16px system-ui;color:#15273b;background:#f2f5f9;margin:0}}main{{max-width:1040px;margin:auto;padding:24px}}
svg{{width:min(100%,720px);display:block;background:#131923}}table{{border-collapse:collapse;background:white}}
th,td{{padding:7px 9px;border-bottom:1px solid #d9e1ef;text-align:right}}th{{background:#203650;color:white}}
.scroll{{overflow:auto}}.pc{{color:#007b59}}.fpga{{color:#985000}}
</style><main><h1>Validación de centroides</h1><p>{escape(origen)} · 320 × 240 · umbral {umbral} · área 2 a 500 px</p>
<p><strong>{resultado}</strong> · FPGA {len(fpga)} · PC {len(ref)} · overflow {'sí' if overflow else 'no'}</p>
<p><span class="fpga">Cruces numeradas: FPGA</span> · <span class="pc">Círculos: referencia PC</span></p>
<svg viewBox="-.5 -.5 320 240" xmlns="http://www.w3.org/2000/svg" aria-label="Foto marcada">
<image x="-.5" y="-.5" width="320" height="240" style="image-rendering:pixelated" href="data:image/png;base64,{png}"/>{svg}</svg>
<p>Tolerancia numérica: {TOLERANCIA} px. La comparación usa la misma foto y cuantifica diferencias del algoritmo.</p>
<div class="scroll"><table><thead><tr>{encabezados}</tr></thead><tbody>{celdas}</tbody></table></div></main></html>
""", encoding="utf-8")
    return resumen


def main():
    parser = argparse.ArgumentParser(description="Capturar y comparar la foto y sus centroides.")
    parser.add_argument("--port", help="Puerto COM de la Arty")
    parser.add_argument("--timeout", type=float, default=25)
    parser.add_argument("--manual", action="store_true", help="Usar BTN1 para disparar.")
    parser.add_argument("--tramas", type=Path, help="Archivo binario STY1 seguido de STC1 para revisión offline.")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        receptor = Receptor()
        if args.tramas:
            pares = receptor.feed(args.tramas.read_bytes())
            if len(pares) != 1:
                raise ValueError("El archivo debe contener una pareja STY1/STC1 completa.")
            origen = "Archivo de tramas"
        else:
            from serial_windows import Serial, ports
            disponibles = ports()
            if not args.port and len(disponibles) != 1:
                parser.error("Indica --port COMn. Disponibles: " + ", ".join(trama["port"] for trama in disponibles))
            puerto = args.port or disponibles[0]["port"]
            limite = time.monotonic() + args.timeout
            enviado = False
            with Serial(puerto) as serial:
                if not args.manual:
                    serial.write(b"s")
                else:
                    print("Pulsa BTN1 en la Arty.", flush=True)
                while time.monotonic() < limite:
                    pares = receptor.feed(serial.read())
                    if pares:
                        break
                    if not args.manual and receptor.ready and not enviado:
                        serial.write(b"c")
                        enviado = True
                else:
                    raise TimeoutError("No llegó el par completo foto/centroides por UART.")
            origen = "Captura por UART " + puerto
        destino = args.output or (Path(__file__).resolve().parents[1] / "resultados" /
                                  datetime.now().strftime("%Y%m%d_%H%M%S_%f"))
        resumen = guardar(*pares[0], destino, origen)
        print(destino / "validacion.html")
        print(json.dumps(resumen, indent=2))
        return 0 if resumen["coincide_con_pc"] else 2
    except (OSError, RuntimeError, ValueError) as exc:
        print("ERROR:", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
