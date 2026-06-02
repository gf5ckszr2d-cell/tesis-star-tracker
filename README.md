# tesis-star-tracker

Repositorio de trabajo para una tesis/prototipo de **star tracker** implementado en FPGA. El objetivo general del proyecto es construir una plataforma capaz de adquirir imagen desde una camara, detectar estrellas y, en etapas posteriores, estimar orientacion a partir de patrones estelares.

## Estado actual

La etapa actual del repositorio esta enfocada en el **bring-up de la camara OV7670 y la primera captura de luminancia**. El diseno ya incluye inicializacion automatica de registros por I2C/SCCB, generacion de `XCLK` para la camara y captura de un stream de bytes `Y` desde la salida YUV 4:2:2.

Aunque el nombre general del proyecto es `star_tracker`, este repositorio todavia no implementa procesamiento estelar completo. Por ahora valida la configuracion inicial de la camara, guarda un frame de luminancia en BRAM y lo transmite por UART.

## Hardware objetivo

- Placa FPGA: Digilent Nexys A7-100T.
- Camara: OV7670.
- Interfaz actual con la camara: I2C/SCCB para configuracion de registros y bus paralelo `D[7:0]` con `PCLK`, `VSYNC` y `HREF` para captura.
- XCLK esperado para la camara: 24 MHz generado desde el reloj de 100 MHz de la placa mediante MMCM.
- Top-level actual: `star_tracker_top`.

## Entradas y salidas del top

| Puerto | Direccion | Uso |
|---|---:|---|
| `clk` | in | Reloj de sistema de 100 MHz de la Nexys A7. |
| `rst` | in | Reset general activo en alto. |
| `start_btn` | in | Inicia configuracion; despues de init exitoso rearma una nueva captura. |
| `SDA`, `SCL` | inout/out | Bus SCCB/I2C hacia la OV7670. |
| `cam_xclk` | out | Reloj de 24 MHz entregado a la camara. |
| `cam_pclk` | in | Reloj de pixel generado por la OV7670. |
| `cam_vsync`, `cam_href` | in | Sincronismos de frame y linea. |
| `cam_data[7:0]` | in | Bus paralelo de video. |
| `cam_pwdn`, `cam_reset` | out/out | Control basico de power-down y reset de la camara. |
| `uart_tx` | out | Envio binario del frame por USB-UART. |
| `pixel_valid`, `frame_done` | out/out | LEDs/debug de captura. |
| `led_read_data[7:0]` | out | Ultimo byte `Y` capturado. |
| `busy`, `ok`, `fail` | out/out/out | Estado general del flujo. |

## Mapeo actual Nexys-OV7670

| Funcion | Puerto RTL | Pin Nexys |
|---|---|---|
| SCCB SCL | `SCL` | JA1 / C17 |
| SCCB SDA | `SDA` | JA2 / D18 |
| Datos camara | `cam_data[0]`..`cam_data[7]` | JB1, JB2, JB3, JB4, JB7, JB8, JB9, JB10 |
| XCLK | `cam_xclk` | JC1 / K1 |
| PCLK | `cam_pclk` | JC2 / F6 |
| VSYNC | `cam_vsync` | JC3 / J2 |
| HREF | `cam_href` | JC4 / G6 |
| PWDN | `cam_pwdn` | JC7 / E7 |
| RESET | `cam_reset` | JC8 / J3 |
| UART a PC | `uart_tx` | D4 |

El top ya no usa switches. Toda la configuracion de la camara viene de `ov7670_init_config`.

## Estructura del repositorio

```text
.
|-- Configuracion camara/
|   |-- rtl/
|   |   |-- frame_capture_store.vhd
|   |   |-- frame_uart_dump.vhd
|   |   |-- framebuffer_y_bram.vhd
|   |   |-- ov7670_capture_y_stream.vhd
|   |   |-- ov7670_init_config.vhd
|   |   `-- ov7670_xclk_gen.vhd
|   `-- tb/
|       |-- tb_framebuffer_y_bram.vhd
|       |-- tb_ov7670_capture_y_stream.vhd
|       `-- tb_ov7670_init_config.vhd
|-- Constraints/
|   `-- nexys.xdc
|-- Protocolo de comunicacion/
|   |-- rtl/
|   |   |-- i2c_master.vhd
|   |   `-- uart_tx.vhd
|   `-- tb/
|       |-- tb_i2c_master.vhd
|       `-- tb_uart_tx.vhd
|-- Top/
|   |-- rtl/
|   |   `-- star_tracker_top.vhd
|   `-- tb/
|       `-- tb_star_tracker_top.vhd
`-- README.md
```

## Archivos principales

- `Protocolo de comunicacion/rtl/i2c_master.vhd`: maestro I2C/SCCB basico. Genera START/STOP, envia direccion y bytes de escritura, lee un byte y reporta `done`, `busy` y `ack_error`.
- `Configuracion camara/rtl/ov7670_init_config.vhd`: controlador de inicializacion de la OV7670. Recorre una tabla ROM de pares registro/valor para configurar QQVGA 160x120 en YUV, esperando 1 ms despues del reset inicial.
- `Configuracion camara/rtl/ov7670_xclk_gen.vhd`: generador de `XCLK` de 24 MHz usando `MMCME2_BASE` para la Nexys A7-100T.
- `Configuracion camara/rtl/ov7670_capture_y_stream.vhd`: capturador en dominio `PCLK`. Usa `VSYNC` y `HREF`, interpreta el orden `Y U Y V` y emite solo los bytes de luminancia `Y`.
- `Configuracion camara/rtl/frame_capture_store.vhd`: controlador de escritura de frame. Toma `pixel_valid`, calcula direccion row-major y congela el frame al terminar.
- `Configuracion camara/rtl/framebuffer_y_bram.vhd`: framebuffer inferido dual-clock para guardar 19,200 bytes `Y`.
- `Configuracion camara/rtl/frame_uart_dump.vhd`: lee la BRAM y envia el frame por UART con encabezado binario y checksum.
- `Protocolo de comunicacion/rtl/uart_tx.vhd`: transmisor UART 8N1, usado para volcar el frame a la PC a 921600 baud.
- `Top/rtl/star_tracker_top.vhd`: integra `XCLK`, inicializacion automatica, maestro I2C, captura de luminancia, BRAM y UART TX. Los LEDs muestran ultimo byte `Y`, estado de init/dump y errores.
- `Constraints/nexys.xdc`: constraints de pines para la Nexys A7-100T. Incluye reloj, LEDs, botones, `SCL`/`SDA`, bus paralelo de la OV7670, control de camara y `uart_tx` por USB-UART.
- `Protocolo de comunicacion/tb/tb_i2c_master.vhd`: testbench del maestro I2C con esclavo simulado para validar una escritura.
- `Protocolo de comunicacion/tb/tb_uart_tx.vhd`: testbench del transmisor UART 8N1.
- `Configuracion camara/tb/tb_framebuffer_y_bram.vhd`: testbench de escritura/lectura dual-clock del framebuffer.
- `Configuracion camara/tb/tb_ov7670_init_config.vhd`: testbench integrado del controlador de inicializacion con el maestro I2C y un esclavo OV7670 simulado. Verifica en `SDA/SCL` la secuencia `0x42`, registro y valor para cada par de configuracion.
- `Configuracion camara/tb/tb_ov7670_capture_y_stream.vhd`: testbench de captura con camara simulada. Genera `PCLK`, `VSYNC`, `HREF` y bytes `Y U Y V`, y verifica que solo salgan los `Y`.
- `Top/tb/tb_star_tracker_top.vhd`: testbench integrado del top-level con esclavo I2C simulado y una trama de camara minima.

## Simulacion de testbenches

Los testbenches pueden simularse con un simulador VHDL como GHDL o el simulador incluido en Vivado. Ejemplo con GHDL desde la raiz del repositorio:

```powershell
ghdl -a "Protocolo de comunicacion/rtl/i2c_master.vhd"
ghdl -a "Protocolo de comunicacion/rtl/uart_tx.vhd"
ghdl -a "Configuracion camara/rtl/ov7670_xclk_gen.vhd"
ghdl -a "Configuracion camara/rtl/ov7670_init_config.vhd"
ghdl -a "Configuracion camara/rtl/ov7670_capture_y_stream.vhd"
ghdl -a "Configuracion camara/rtl/frame_capture_store.vhd"
ghdl -a "Configuracion camara/rtl/framebuffer_y_bram.vhd"
ghdl -a "Configuracion camara/rtl/frame_uart_dump.vhd"
ghdl -a "Top/rtl/star_tracker_top.vhd"
```

Para simular el maestro I2C:

```powershell
ghdl -a "Protocolo de comunicacion/tb/tb_i2c_master.vhd"
ghdl -e tb_i2c_master
ghdl -r tb_i2c_master --stop-time=2ms
```

Para simular el transmisor UART:

```powershell
ghdl -a "Protocolo de comunicacion/tb/tb_uart_tx.vhd"
ghdl -e tb_uart_tx
ghdl -r tb_uart_tx --stop-time=20us
```

Para simular el framebuffer:

```powershell
ghdl -a "Configuracion camara/tb/tb_framebuffer_y_bram.vhd"
ghdl -e tb_framebuffer_y_bram
ghdl -r tb_framebuffer_y_bram --stop-time=2us
```

Para simular el controlador de inicializacion de la OV7670:

```powershell
ghdl -a "Configuracion camara/tb/tb_ov7670_init_config.vhd"
ghdl -e tb_ov7670_init_config
ghdl -r tb_ov7670_init_config --stop-time=20ms
```

Para simular el capturador de luminancia:

```powershell
ghdl -a "Configuracion camara/tb/tb_ov7670_capture_y_stream.vhd"
ghdl -e tb_ov7670_capture_y_stream
ghdl -r tb_ov7670_capture_y_stream --stop-time=10us
```

Para simular el top integrado:

```powershell
ghdl -a "Top/tb/tb_star_tracker_top.vhd"
ghdl -e tb_star_tracker_top
ghdl -r tb_star_tracker_top --stop-time=30ms
```

Nota: en Windows, las rutas con espacios deben mantenerse entre comillas. El top usa la primitiva Xilinx `MMCME2_BASE`, por lo que la simulacion integrada de `star_tracker_top` puede requerir Vivado/XSim o bibliotecas `unisim` disponibles en GHDL.

## Formato UART del frame

Cuando se captura un frame completo, el top congela la BRAM y transmite por `uart_tx` a 921600 baud, 8N1. El paquete es binario:

```text
0x53 0x54 0x59 0x31    magic "STY1"
0xA0 0x00              width  = 160, little-endian
0x78 0x00              height = 120, little-endian
0x00 0x4B 0x00 0x00    payload length = 19200, little-endian
19200 bytes            luminancia Y, row-major
1 byte                 checksum: suma modulo 256 del payload
```

Tiempo aproximado de envio: `19213 bytes * 10 / 921600 = 0.208 s`.

Ejemplo minimo de lectura en Python:

```python
import serial

ser = serial.Serial("COMx", 921600, timeout=5)
header = ser.read(12)
assert header[:4] == b"STY1"
width = int.from_bytes(header[4:6], "little")
height = int.from_bytes(header[6:8], "little")
length = int.from_bytes(header[8:12], "little")
payload = ser.read(length)
checksum = ser.read(1)[0]
assert checksum == (sum(payload) & 0xFF)
```

## Uso en Vivado

Este repositorio no incluye todavia un archivo `.xpr`. Para abrirlo en Vivado:

1. Crear un proyecto RTL nuevo para la placa Nexys A7-100T o para el dispositivo correspondiente de la placa.
2. Agregar como fuentes de diseno:
   - `Protocolo de comunicacion/rtl/i2c_master.vhd`
   - `Protocolo de comunicacion/rtl/uart_tx.vhd`
   - `Configuracion camara/rtl/ov7670_xclk_gen.vhd`
   - `Configuracion camara/rtl/ov7670_init_config.vhd`
   - `Configuracion camara/rtl/ov7670_capture_y_stream.vhd`
   - `Configuracion camara/rtl/frame_capture_store.vhd`
   - `Configuracion camara/rtl/framebuffer_y_bram.vhd`
   - `Configuracion camara/rtl/frame_uart_dump.vhd`
   - `Top/rtl/star_tracker_top.vhd`
3. Seleccionar `star_tracker_top` como top-level.
4. Agregar `Constraints/nexys.xdc` como archivo de constraints.
5. Verificar que el cableado fisico de la OV7670 coincida con el mapeo PMOD documentado en `Constraints/nexys.xdc`.
6. Ejecutar elaboracion, sintesis e implementacion.
7. Generar el bitstream y programar la Nexys A7-100T.

Para simular en Vivado, agregar tambien los archivos en las carpetas `tb/` y seleccionar el testbench que se quiera ejecutar como simulation top.

## Proximos bloques pendientes

Las siguientes etapas no estan implementadas todavia y quedan como trabajo futuro del star tracker:

- Validacion en placa del mapeo fisico OV7670-PMOD.
- Preprocesamiento de imagen.
- Deteccion de estrellas o puntos brillantes.
- Calculo de centroides.
- Identificacion estelar y comparacion contra catalogo.
- Estimacion de actitud/orientacion.

## Notas de coherencia

El nombre `star_tracker` se mantiene como nombre general del proyecto, pero el alcance actual es configuracion de la camara, captura inicial de luminancia, almacenamiento de un frame en BRAM y volcado por UART. Todavia no hay procesamiento de estrellas.
