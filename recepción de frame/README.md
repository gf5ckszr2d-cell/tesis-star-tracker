# Recepcion de frame UART

Esta carpeta contiene el receptor Python para el bitstream actual del proyecto.

## Formato esperado

- Magic: `STY1`
- Width: `160`
- Height: `120`
- Payload: `19200` bytes
- Formato de imagen: `Y8` en escala de grises
- Checksum: suma modulo 256 del payload

## Uso rapido desde PowerShell

Abrir PowerShell en esta carpeta:

```powershell
cd "C:\Users\alexa\tesis-star-tracker\recepción de frame"
```

Instalar dependencias:

```powershell
.\setup_python.cmd
```

Listar puertos serie:

```powershell
.\run_list_serial_ports.cmd
```

Capturar un frame por UART:

```powershell
.\run_capture_frame_uart.cmd --port COM4 --baud 921600
```

Tambien se puede ejecutar directamente con PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup_python.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\list_serial_ports.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_capture_frame_uart.ps1 -Port COM4 -Baud 921600
```

## Orden recomendado

1. Conectar la Nexys A7-100T por USB.
2. Programar el bitstream.
3. Abrir el receptor UART en PowerShell.
4. Ejecutar la captura.
5. Presionar `start_btn` en la FPGA.

## Salida

Por defecto se crean:

- `capturas/frame_y.raw`
- `capturas/frame_y.png`

## Notas

- Este receptor no espera `RGB565`.
- El script antiguo de `38400` bytes no aplica a este bitstream.
- El baudrate esperado por defecto es `921600`.
- Cambia `COM4` por el puerto que aparezca al ejecutar `run_list_serial_ports.cmd`.
- Si no aparece `STY1`, revisar baudrate, puerto COM, reset/start de la FPGA y cableado de la camara.
