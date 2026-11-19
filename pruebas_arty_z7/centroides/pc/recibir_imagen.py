"""STY1 QVGA receiver, automatic PC trigger and PNG/RAW/evidence, no pip required."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import struct
import time
import zlib

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
        for b in data:
            if b == 10:
                line = self.text.strip()
                if line.startswith(('ARM ', 'ERROR ', 'OK ')):
                    self.messages.append(line)
                self.text = ''
            elif 32 <= b < 127:
                self.text = (self.text + chr(b))[-512:]
    def feed(self, data):
        self.buffer.extend(data)
        frames = []
        while True:
            start = self.buffer.find(b'STY1')
            if start < 0:
                keep = next((n for n in (3, 2, 1) if self.buffer.endswith(b'STY1'[:n])), 0)
                used = len(self.buffer) - keep
                self._noise(self.buffer[:used]); del self.buffer[:used]
                break
            self._noise(self.buffer[:start]); del self.buffer[:start]
            if len(self.buffer) < 12: break
            if self.buffer[:12] != HEADER:
                self.errors.append('Cabecera incorrecta: se exige STY1 320x240 Y=76800')
                del self.buffer[0]; continue
            if len(self.buffer) < PACKET_SIZE: break
            payload = bytes(self.buffer[12:PACKET_SIZE - 1])
            if (sum(payload) & 255) != self.buffer[PACKET_SIZE - 1]:
                self.errors.append('Checksum incorrecto; imagen descartada')
                del self.buffer[0]; continue
            frames.append(payload); del self.buffer[:PACKET_SIZE]
        return frames
    def expire(self):
        if self.buffer:
            self.errors.append(f'Trama incompleta: {len(self.buffer)}/{PACKET_SIZE} bytes')
            self.buffer.clear()

def png_bytes(payload):
    if len(payload) != PIXELS: raise ValueError('Longitud de imagen incorrecta')
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    rows = b''.join(b'\0' + payload[y * WIDTH:(y + 1) * WIDTH] for y in range(HEIGHT))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', WIDTH, HEIGHT, 8, 0, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))

def save_image(payload, directory, origin='hardware'):
    directory.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc)
    base = directory / ('captura_' + stamp.strftime('%Y%m%d_%H%M%S_%fZ'))
    packet = HEADER + payload + bytes([sum(payload) & 255])
    base.with_suffix('.png').write_bytes(png_bytes(payload))
    base.with_suffix('.raw').write_bytes(payload)
    base.with_suffix('.sty1').write_bytes(packet)
    metadata = {'utc': stamp.isoformat(), 'origen': origin, 'width': WIDTH, 'height': HEIGHT,
                'payload_bytes': len(payload), 'checksum': packet[-1], 'checksum_correcto': True,
                'sha256_payload': hashlib.sha256(payload).hexdigest(),
                'min': min(payload), 'max': max(payload), 'media': sum(payload) / len(payload)}
    base.with_suffix('.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    return base.with_suffix('.png')

def main():
    from serial_windows import Serial, ports
    parser = argparse.ArgumentParser(description='Tesis definitiva: STY1 a PNG; UART0 115200 8N1')
    parser.add_argument('--port')
    parser.add_argument('--list-ports', action='store_true')
    parser.add_argument('--auto', action='store_true', help='Pedir fotos con comando c; exige firmware TESIS')
    parser.add_argument('--count', type=int, default=1, help='Fotos que guardar; 0 = continuo')
    parser.add_argument('--timeout', type=float, default=25, help='Segundos sin imagen completa')
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'capturas')
    args = parser.parse_args()
    available = ports()
    if args.list_ports:
        print(json.dumps(available, indent=2)); return 0
    if args.count < 0 or args.timeout <= 0: parser.error('count >= 0 y timeout > 0')
    if not args.port:
        if len(available) != 1:
            parser.error('Indica --port COMn. Puertos: ' + ', '.join(p['port'] for p in available))
        args.port = available[0]['port']
    decoder = Decoder(); received = 0; ready = False; requested = False
    deadline = time.monotonic() + args.timeout
    last_data = time.monotonic()
    next_request = 0.0
    try:
        with Serial(args.port) as port:
            print(f'{args.port}: 115200 8N1; STY1 320x240; ' + ('disparo automatico' if args.auto else 'pulsa BTN1'))
            if args.auto: port.write(b's')
            while args.count == 0 or received < args.count:
                data = port.read()
                now = time.monotonic()
                frames = decoder.feed(data)
                if data: last_data = now
                elif decoder.buffer and now - last_data > 2: decoder.expire()
                for message in decoder.messages:
                    print(message, flush=True)
                    if message.startswith('ARM TESIS READY'): ready = True
                    if message.startswith('ERROR '):
                        raise RuntimeError(message)
                decoder.messages.clear()
                if decoder.errors:
                    raise RuntimeError('; '.join(decoder.errors))
                for payload in frames:
                    path = save_image(payload, args.output)
                    received += 1
                    print(f'PASS FOTO {received}: 320x240, 76800 bytes, checksum correcto -> {path}', flush=True)
                    requested = False; deadline = now + args.timeout; next_request = now + 0.3
                if args.auto and ready and not requested and now >= next_request and (not args.count or received < args.count):
                    port.write(b'c'); requested = True; deadline = now + args.timeout
                    print('Solicitud de captura enviada.', flush=True)
                if now > deadline:
                    raise TimeoutError('Sin foto completa. Revisar carga BIT/ELF, conexion y camara.'
                                       + (' Firmware TESIS no confirmado.' if args.auto and not ready else ''))
    except (OSError, RuntimeError) as exc:
        print('ERROR:', exc); return 1
    except KeyboardInterrupt:
        print('Recepcion detenida.'); return 130
    return 0

if __name__ == '__main__': raise SystemExit(main())
