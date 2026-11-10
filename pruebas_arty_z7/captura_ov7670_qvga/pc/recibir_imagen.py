"""STY1 binary receiver. Dependencies: pyserial and Pillow (pip install -r requirements.txt)."""
import argparse
from datetime import datetime
from pathlib import Path
import struct
import sys
import time

WIDTH, HEIGHT = 320, 240
PIXELS = WIDTH * HEIGHT
HEADER = struct.pack('<4sHHI', b'STY1', WIDTH, HEIGHT, PIXELS)
PACKET_SIZE = PIXELS + 13


class Decoder:
    def __init__(self):
        self.buffer = bytearray()
        self.errors = []
        self.messages = []
        self.text = ''

    def _noise(self, data):
        # Diagnostics are displayed only outside fixed-length binary packets.
        for value in data:
            if value == 10:
                line = self.text.strip()
                if line.startswith(('ERROR ', 'ARM ', 'Receptor ', 'OK ')):
                    self.messages.append(line)
                self.text = ''
            elif 32 <= value < 127:
                self.text = (self.text + chr(value))[-256:]

    def feed(self, data):
        self.buffer.extend(data)
        frames = []
        while True:
            start = self.buffer.find(b'STY1')
            if start < 0:
                # Keep only an actual partial magic, so a final diagnostic line
                # is displayed immediately even if no binary packet follows.
                keep = next((n for n in (3,2,1) if self.buffer.endswith(b'STY1'[:n])), 0)
                used = len(self.buffer)-keep
                self._noise(self.buffer[:used])
                del self.buffer[:used]
                break
            self._noise(self.buffer[:start])
            del self.buffer[:start]
            if len(self.buffer) < 12:
                break
            if self.buffer[:12] != HEADER:
                self.errors.append('Cabecera STY1 invalida: se exige 320x240/76800 bytes')
                del self.buffer[0]
                continue
            if len(self.buffer) < PACKET_SIZE:
                break
            payload = bytes(self.buffer[12:PACKET_SIZE-1])
            if sum(payload) & 255 != self.buffer[PACKET_SIZE-1]:
                self.errors.append('Checksum incorrecto; trama descartada')
                del self.buffer[0]
                continue
            frames.append(payload)
            del self.buffer[:PACKET_SIZE]
        return frames

    def expire(self):
        if self.buffer.startswith(b'STY1'):
            self.errors.append(f'Timeout: trama incompleta ({len(self.buffer)}/{PACKET_SIZE} bytes)')
            del self.buffer[0]
        return self.feed(b'')


def save_image(payload, directory, show=True):
    from PIL import Image
    directory.mkdir(parents=True, exist_ok=True)
    name = directory / ('captura_' + datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
    image = Image.frombytes('L', (WIDTH, HEIGHT), payload)
    image.save(name.with_suffix('.png'))
    name.with_suffix('.raw').write_bytes(payload)
    if show:
        image.resize((640, 480), Image.Resampling.NEAREST).show()
    return name.with_suffix('.png')


def main():
    import serial
    parser = argparse.ArgumentParser(description='OV7670 -> ARM -> COM -> PNG; STY1 binario')
    parser.add_argument('--port', default='COM3')
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parent / 'capturas_qvga')
    parser.add_argument('--no-show', action='store_true')
    parser.add_argument('--count', type=int, default=0, help='0 = continuar hasta Ctrl+C')
    args = parser.parse_args()
    decoder = Decoder()
    received = 0
    last_data = time.monotonic()
    try:
        with serial.Serial(args.port, 115200, timeout=0.1, bytesize=8,
                           parity='N', stopbits=1, xonxoff=False, rtscts=False,
                           dsrdtr=False) as port:
            print(f'{args.port} abierto a 115200 8N1. Pulsa BTN1; esperando STY1...')
            while not args.count or received < args.count:
                data = port.read(max(1, min(port.in_waiting, 4096)))
                if data:
                    last_data = time.monotonic()
                    frames = decoder.feed(data)
                elif time.monotonic() - last_data > 2:
                    frames = decoder.expire()
                    last_data = time.monotonic()
                else:
                    frames = []
                for error in decoder.errors:
                    print('ERROR:', error, file=sys.stderr)
                decoder.errors.clear()
                for message in decoder.messages:
                    print('ARM:', message)
                decoder.messages.clear()
                for payload in frames:
                    path = save_image(payload, args.output, not args.no_show)
                    received += 1
                    print(f'OK {received}: 320x240, 76800 bytes, checksum correcto -> {path}')
    except serial.SerialException as exc:
        print(f'ERROR {args.port}: {exc}. Cierra el terminal Vitis antes de abrir el puerto.', file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print('\nRecepcion terminada.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
