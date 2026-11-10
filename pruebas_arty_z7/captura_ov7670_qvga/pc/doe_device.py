"""Bounded serial transactions for DOE1 ARM firmware. No button presses needed."""
import sys
import time
import json
from pathlib import Path
from recibir_imagen import Decoder

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'build/python_deps'))
REGISTERS = [0x0A,0x0B,0x00,0x01,0x02,0x03,0x04,0x07,0x10,0x11,0x12,0x13,
             0x14,0x15,0x17,0x18,0x19,0x1A,0x32,0x3A,0x3B,0x3D,0x3E,0x40,
             0x6A,0x70,0x71,0x72,0x73,0x92,0x93,0x9D,0x9E,0xA2]


class Camera:
    def __init__(self, port, output):
        import serial
        self.port=serial.Serial(port,115200,timeout=.1,write_timeout=2,
                                xonxoff=False,rtscts=False,dsrdtr=False)
        self.raw=(output/'uart.bin').open('ab')
        self.commands=(output/'commands.jsonl').open('a',encoding='utf-8')
        self.decoder=Decoder()
        self._consume_initial()

    def _consume_initial(self):
        end=time.monotonic()+.5
        while time.monotonic()<end:
            data=self.port.read(max(1,min(self.port.in_waiting,4096)))
            self.raw.write(data)
        self.decoder=Decoder()

    def exchange(self, command, predicate, timeout=3):
        self.commands.write(json.dumps(dict(time=time.time(),tx=command))+'\n'); self.commands.flush()
        self.port.write(command.encode('ascii')); self.port.flush()
        frames, messages = [], []
        deadline=time.monotonic()+timeout
        while time.monotonic()<deadline:
            data=self.port.read(max(1,min(self.port.in_waiting,4096)))
            self.raw.write(data); self.raw.flush()
            frames.extend(self.decoder.feed(data))
            messages.extend(self.decoder.messages); self.decoder.messages.clear()
            if self.decoder.errors:
                raise RuntimeError('; '.join(self.decoder.errors))
            errors=[m for m in messages if m.startswith('ERROR ') or
                    (m.startswith('ARM captura: ') and not m.startswith('ARM captura: OK '))]
            if errors:
                raise RuntimeError('; '.join(errors))
            if predicate(frames,messages):
                return frames,messages
        raise TimeoutError(f'Sin respuesta completa a {command!r}: {messages}')

    def handshake(self):
        self.exchange('v\n',lambda f,m:'ARM DOE1 READY' in m)

    def capture(self):
        frames,messages=self.exchange('c',lambda f,m:bool(f) and
            any(x.startswith('OK imagen 76800 checksum') for x in m),timeout=20)
        if len(frames)!=1:
            raise RuntimeError('Se exige exactamente una imagen por solicitud')
        return frames[0], messages

    def read(self, reg):
        _, messages=self.exchange(f'r{reg:02X}\n', lambda f,m:any(x.startswith(f'ARM REG {reg:02X} ') for x in m))
        return int(next(x for x in messages if x.startswith(f'ARM REG {reg:02X} ')).split()[-1],16)

    def write(self, reg, value):
        self.exchange(f'w{reg:02X}{value:02X}\n',lambda f,m:f'ARM REG {reg:02X} {value:02X}' in m)
        if self.read(reg)!=value:
            raise RuntimeError(f'Lectura no confirma registro {reg:02X}={value:02X}')

    def snapshot(self):
        result={f'{reg:02X}':self.read(reg) for reg in REGISTERS}
        if result['0A']!=0x76:
            raise RuntimeError(f'PID OV7670 inesperado: {result["0A"]:02X}')
        return result

    def freeze(self):
        # Freeze AEC, AGC and AWB. Retain all other COM8 bits and the current WB gains.
        self.write(0x13,self.read(0x13)&~7)
        self.write(0x3B,self.read(0x3B)&~0x80)  # disable night-mode frame-rate extension
        return self.snapshot()

    def profile(self, exposure, gain):
        if not 1<=exposure<=510 or not 0<=gain<=1023:
            raise ValueError('Piloto limitado a AEC 1..510 y AGC 0..1023; codigos, no ms/dB')
        if self.read(0x13)&7:
            raise RuntimeError('AEC/AGC/AWB siguen automaticos')
        self.write(0x04,(self.read(0x04)&0xFC)|(exposure&3))
        self.write(0x10,(exposure>>2)&255)
        self.write(0x07,(self.read(0x07)&0xC0)|((exposure>>10)&63))
        self.write(0x03,(self.read(0x03)&63)|((gain>>2)&0xC0))
        self.write(0x00,gain&255)
        return self.snapshot()

    def close(self):
        self.port.close(); self.raw.close(); self.commands.close()


def decode_profile(registers):
    return dict(exposure_code=((registers['07']&63)<<10)|(registers['10']<<2)|(registers['04']&3),
                gain_code=((registers['03']>>6)<<8)|registers['00'])
