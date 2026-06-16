# Recepcion de frame UART y calibracion

Esta carpeta contiene las herramientas Python para el bitstream Nexys A7 del
proyecto.

## Formato UART esperado

- Magic: `STY1`
- Width: `160`
- Height: `120`
- Payload: `19200` bytes
- Formato de imagen: `Y8` en escala de grises
- Checksum: suma modulo 256 del payload

## Uso rapido

Abrir PowerShell en esta carpeta:

```powershell
cd "C:\Users\alexa\tesis-star-tracker\recepcion de frame"
```

Si Windows no acepta esa ruta por el acento real del nombre de carpeta, usar
autocompletado con `Tab` desde `C:\Users\alexa\tesis-star-tracker`.

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

La salida por defecto es:

- `capturas/frame_y.raw`
- `capturas/frame_y.png`

## Flujo de calibracion con patron estelar

1. Generar patron para la pantalla de la laptop:

```powershell
.\run_generate_star_pattern.cmd --width 2160 --height 1440 --stars 12
```

2. Abrir `patrones/star_pattern.png` a pantalla completa.
3. Capturar el frame con la FPGA:

```powershell
.\run_capture_frame_uart.cmd --port COM4 --baud 921600
```

4. Generar reporte de calibracion:

```powershell
.\run_calibrate_capture.cmd --expected patrones/star_pattern.json --image capturas/frame_y.png --param base
```

Para una prueba con contraste:

```powershell
.\run_calibrate_capture.cmd --expected patrones/star_pattern.json --image capturas/frame_y.png --param contraste --selector 00 --value 0x60
```

## Controles FPGA para calibracion

- `SW[7:0]`: valor del parametro.
- `SW[14:13]`: selector.
- `SW[15]`: habilita modo config manual.
- `BTND`: escribe el parametro por SCCB/I2C.
- `start_btn`: captura una foto con la configuracion actual.
- `rst`: vuelve a la ROM base.

Selectores:

- `00`: contraste, registro `0x56`.
- `01`: ganancia, escribe `0x13 <= 0x8B` y luego `0x00 <= SW[7:0]`.
- `10`: exposicion, escribe `0x13 <= 0x8E` y luego `0x10 <= SW[7:0]`.
- `11`: brillo, registro `0x55`.

## Herramientas separadas

Detectar estrellas:

```powershell
.\run_detect_stars.cmd --image capturas/frame_y.png --threshold 45
```

Comparar centroides:

```powershell
.\run_compare_centroids.cmd --expected patrones/star_pattern.json --detected capturas/detected_stars.json
```

## Notas

- Este receptor no espera `RGB565`.
- El baudrate esperado por defecto es `921600`.
- Cambia `COM4` por el puerto que aparezca al ejecutar `run_list_serial_ports.cmd`.
- Si no aparece `STY1`, revisar baudrate, puerto COM, reset/start de la FPGA y cableado de la camara.
