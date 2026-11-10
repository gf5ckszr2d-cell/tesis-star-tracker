"""Bounded physical capture probe. Close Vitis serial terminal before running."""
import argparse
import json
from pathlib import Path
import time
import serial
from recibir_imagen import Decoder, save_image

p = argparse.ArgumentParser()
p.add_argument('--seconds', type=float, default=120)
p.add_argument('--port', default='COM3')
p.add_argument('--trigger', action='store_true', help='send c after ARM boot message')
p.add_argument('--frames', type=int, default=1, help='number of complete images to verify')
a = p.parse_args()
if a.frames < 1:
    p.error('--frames must be positive')
out = Path(__file__).resolve().parents[1]/'build'/'physical_qvga'
out.mkdir(parents=True, exist_ok=True)
d = Decoder()
report = {'port': a.port, 'baud': 115200, 'requested_frames': a.frames, 'messages': [], 'errors': [], 'images': [], 'received_bytes': 0}
started = time.monotonic()
result = 2
triggered = False
try:
    with serial.Serial(a.port, 115200, timeout=0.1, rtscts=False, dsrdtr=False) as port, (out/'uart.bin').open('wb') as raw:
        print('COM3_READY: serial recorder active at 115200; waiting for BTN1', flush=True)
        while time.monotonic()-started < a.seconds:
            data = port.read(max(1, min(port.in_waiting, 4096)))
            if not data:
                continue
            raw.write(data); raw.flush(); report['received_bytes'] += len(data)
            frames = d.feed(data)
            for message in d.messages:
                report['messages'].append(message); print(message, flush=True)
                if a.trigger and not triggered and message.startswith('Receptor OV7670 listo'):
                    port.write(b'c'); port.flush(); triggered=True
                    print('SOFTWARE_CAPTURE_REQUESTED', flush=True)
                if message.startswith('ARM captura: ') and not message.startswith('ARM captura: OK '):
                    result=3
            d.messages.clear()
            for error in d.errors:
                report['errors'].append(error); print('ERROR:', error, flush=True)
            d.errors.clear()
            for payload in frames:
                image = save_image(payload, out, show=False)
                report['images'].append(str(image))
                print('PHYSICAL_FRAME_OK:', image, flush=True)
                if len(report['images']) >= a.frames:
                    result=0
                elif a.trigger:
                    port.write(b'c'); port.flush()
                    print('SOFTWARE_CAPTURE_REQUESTED: repeat without reset', flush=True)
            if result in (0,3):
                break
except serial.SerialException as exc:
    report['errors'].append(str(exc)); print('SERIAL_ERROR:', exc, flush=True); result=1
finally:
    report['elapsed_seconds'] = round(time.monotonic()-started,3)
    report['result'] = result
    (out/'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
raise SystemExit(result)
