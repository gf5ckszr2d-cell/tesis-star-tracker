# Recepcion de frame UART

Esta carpeta contiene el receptor Python para el bitstream actual del proyecto.

## Formato esperado

- Magic: `STY1`
- Width: `160`
- Height: `120`
- Payload: `19200` bytes
- Formato de imagen: `Y8` en escala de grises
- Checksum: suma modulo 256 del payload

## Dependencias

```powershell
python -m pip install -r "recepción de frame/requirements.txt"
```

Si `python` no esta en PATH, usar el ejecutable completo de Python.

## Ver puertos serie

```powershell
python "recepción de frame/list_serial_ports.py"
```

O directamente:

```powershell
".\recepción de frame\run_list_serial_ports.cmd"
```

## Capturar un frame

Abrir el programa primero y despues presionar `start` en la FPGA.

```powershell
python "recepción de frame/capture_frame_uart.py" --port COM6 --baud 921600
```

O directamente:

```powershell
".\recepción de frame\run_capture_frame_uart.cmd" --port COM6 --baud 921600
```

## Salida

Por defecto se crean:

- `capturas/frame_y.raw`
- `capturas/frame_y.png`

## Notas

- Este receptor no espera `RGB565`.
- El script anterior de `38400` bytes no aplica a este bitstream.
- Si no aparece `STY1`, revisar baudrate, puerto COM, GND comun y cableado del UART.
