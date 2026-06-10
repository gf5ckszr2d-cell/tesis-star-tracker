from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import serial
from PIL import Image


MAGIC = b"STY1"
HEADER_LEN = 12
CHECKSUM_LEN = 1


def read_exact(ser: serial.Serial, size: int, timeout_s: float) -> bytes:
    deadline = time.time() + timeout_s
    chunks = bytearray()

    while len(chunks) < size:
        remaining = size - len(chunks)
        data = ser.read(remaining)
        if data:
            chunks.extend(data)
            continue
        if time.time() >= deadline:
            break

    return bytes(chunks)


def sync_magic(ser: serial.Serial, timeout_s: float) -> bytes | None:
    deadline = time.time() + timeout_s
    window = bytearray()

    while time.time() < deadline:
        data = ser.read(1)
        if not data:
            continue

        window.extend(data)
        if len(window) > len(MAGIC):
            del window[0]

        if bytes(window) == MAGIC:
            return MAGIC

    return None


def parse_header(header: bytes) -> tuple[int, int, int]:
    if len(header) != HEADER_LEN:
        raise ValueError(f"Header incompleto: {len(header)} bytes")

    width = int.from_bytes(header[4:6], byteorder="little", signed=False)
    height = int.from_bytes(header[6:8], byteorder="little", signed=False)
    payload_len = int.from_bytes(header[8:12], byteorder="little", signed=False)
    return width, height, payload_len


def save_outputs(payload: bytes, width: int, height: int, output_dir: Path, stem: str) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)

    raw_path = output_dir / f"{stem}.raw"
    png_path = output_dir / f"{stem}.png"

    raw_path.write_bytes(payload)

    image = Image.frombytes("L", (width, height), payload)
    image.save(png_path)

    return raw_path, png_path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Recibe un frame STY1 por UART y lo guarda como PNG en escala de grises."
    )
    parser.add_argument("--port", required=True, help="Puerto serie, por ejemplo COM6")
    parser.add_argument("--baud", type=int, default=921600, help="Baudrate UART. Default: 921600")
    parser.add_argument("--timeout", type=float, default=10.0, help="Timeout total para sincronizar y leer el frame")
    parser.add_argument(
        "--output-dir",
        default="capturas",
        help="Carpeta donde se guardan los archivos. Default: capturas",
    )
    parser.add_argument(
        "--stem",
        default="frame_y",
        help="Nombre base de salida sin extension. Default: frame_y",
    )
    parser.add_argument(
        "--expect-width",
        type=int,
        default=160,
        help="Ancho esperado. Default: 160",
    )
    parser.add_argument(
        "--expect-height",
        type=int,
        default=120,
        help="Alto esperado. Default: 120",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    output_dir = Path(args.output_dir)

    print(f"Abriendo puerto {args.port} a {args.baud} baudios...")

    try:
        with serial.Serial(args.port, args.baud, timeout=0.2) as ser:
            ser.reset_input_buffer()
            print(f"Esperando magic {MAGIC.decode('ascii')}...")

            magic = sync_magic(ser, args.timeout)
            if magic is None:
                print("Error: no se encontro la cabecera STY1.")
                print("Revisa baudrate, puerto COM, cableado UART y presiona start despues de abrir este programa.")
                return 1

            header_rest = read_exact(ser, HEADER_LEN - len(MAGIC), args.timeout)
            if len(header_rest) != HEADER_LEN - len(MAGIC):
                print(f"Error: header incompleto. Llegaron {len(header_rest)} bytes despues del magic.")
                return 1

            header = magic + header_rest
            width, height, payload_len = parse_header(header)
            print(f"Header recibido: width={width}, height={height}, payload_len={payload_len}")

            expected_payload = args.expect_width * args.expect_height
            if width != args.expect_width or height != args.expect_height:
                print(
                    f"Error: dimensiones inesperadas. Esperado {args.expect_width}x{args.expect_height} y llego {width}x{height}."
                )
                return 1

            if payload_len != expected_payload:
                print(f"Error: payload inesperado. Esperado {expected_payload} bytes y llegaron {payload_len}.")
                return 1

            print(f"Leyendo payload de {payload_len} bytes...")
            payload = read_exact(ser, payload_len, args.timeout)
            if len(payload) != payload_len:
                print(f"Error: llegaron solo {len(payload)} bytes de payload de {payload_len}.")
                return 1

            checksum_data = read_exact(ser, CHECKSUM_LEN, args.timeout)
            if len(checksum_data) != CHECKSUM_LEN:
                print("Error: no llego el byte de checksum.")
                return 1

            checksum_rx = checksum_data[0]
            checksum_calc = sum(payload) & 0xFF
            print(f"Checksum recibido=0x{checksum_rx:02X}, calculado=0x{checksum_calc:02X}")

            if checksum_rx != checksum_calc:
                print("Error: checksum incorrecto.")
                return 1

            raw_path, png_path = save_outputs(payload, width, height, output_dir, args.stem)
            print("Frame recibido correctamente.")
            print(f"RAW: {raw_path}")
            print(f"PNG: {png_path}")
            return 0

    except serial.SerialException as exc:
        print(f"Error abriendo o usando el puerto serie: {exc}")
        return 1
    except Exception as exc:  # pragma: no cover - guardia de CLI
        print(f"Error inesperado: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
