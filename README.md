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
|   |   |-- ov7670_manual_wr_rd.vhd
|   |   `-- ov7670_xclk_gen.vhd
|   `-- tb/
|       |-- tb_framebuffer_y_bram.vhd
|       |-- tb_ov7670_capture_y_stream.vhd
|       |-- tb_ov7670_init_config.vhd
|       `-- tb_ov7670_manual_ctrl.vhd
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
- `Configuracion camara/rtl/ov7670_manual_wr_rd.vhd`: controlador manual para prueba de registros de la OV7670. Captura `sw(15 downto 8)` como direccion de registro y `sw(7 downto 0)` como dato, escribe, vuelve a apuntar al registro, lee y compara.
- `Protocolo de comunicacion/rtl/uart_tx.vhd`: transmisor UART 8N1, usado para volcar el frame a la PC a 921600 baud.
- `Top/rtl/star_tracker_top.vhd`: integra `XCLK`, inicializacion automatica, maestro I2C, captura de luminancia, BRAM y UART TX. Los LEDs muestran ultimo byte `Y`, estado de init/dump y errores.
- `Constraints/nexys.xdc`: constraints de pines para la Nexys A7-100T. Incluye reloj, switches, LEDs, botones, pines PMOD usados para `SCL`/`SDA` y `uart_tx` por USB-UART; los pines de captura de camara quedan pendientes hasta confirmar cableado.
- `Protocolo de comunicacion/tb/tb_i2c_master.vhd`: testbench del maestro I2C con esclavo simulado para validar una escritura.
- `Protocolo de comunicacion/tb/tb_uart_tx.vhd`: testbench del transmisor UART 8N1.
- `Configuracion camara/tb/tb_framebuffer_y_bram.vhd`: testbench de escritura/lectura dual-clock del framebuffer.
- `Configuracion camara/tb/tb_ov7670_init_config.vhd`: testbench integrado del controlador de inicializacion con el maestro I2C y un esclavo OV7670 simulado. Verifica en `SDA/SCL` la secuencia `0x42`, registro y valor para cada par de configuracion.
- `Configuracion camara/tb/tb_ov7670_capture_y_stream.vhd`: testbench de captura con camara simulada. Genera `PCLK`, `VSYNC`, `HREF` y bytes `Y U Y V`, y verifica que solo salgan los `Y`.
- `Configuracion camara/tb/tb_ov7670_manual_ctrl.vhd`: testbench del controlador manual, incluyendo caso correcto y caso de verificacion fallida.
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
ghdl -a "Configuracion camara/rtl/ov7670_manual_wr_rd.vhd"
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

Para simular el controlador manual:

```powershell
ghdl -a "Configuracion camara/tb/tb_ov7670_manual_ctrl.vhd"
ghdl -e tb_ov7670_manual_ctrl
ghdl -r tb_ov7670_manual_ctrl --stop-time=1ms
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
   - `Configuracion camara/rtl/ov7670_manual_wr_rd.vhd`
   - `Top/rtl/star_tracker_top.vhd`
3. Seleccionar `star_tracker_top` como top-level.
4. Agregar `Constraints/nexys.xdc` como archivo de constraints.
5. Agregar constraints para los pines fisicos de `cam_xclk`, `cam_pclk`, `cam_vsync`, `cam_href`, `cam_data[7:0]`, `cam_pwdn` y `cam_reset` segun el cableado real de la camara.
6. Ejecutar elaboracion, sintesis e implementacion.
7. Generar el bitstream y programar la Nexys A7-100T.

Para simular en Vivado, agregar tambien los archivos en las carpetas `tb/` y seleccionar el testbench que se quiera ejecutar como simulation top.

## Proximos bloques pendientes

Las siguientes etapas no estan implementadas todavia y quedan como trabajo futuro del star tracker:

- Constraints definitivos para los pines fisicos de captura de la OV7670.
- Preprocesamiento de imagen.
- Deteccion de estrellas o puntos brillantes.
- Calculo de centroides.
- Identificacion estelar y comparacion contra catalogo.
- Estimacion de actitud/orientacion.

## Notas de coherencia

El nombre `star_tracker` se mantiene como nombre general del proyecto, pero el alcance actual es configuracion de la camara, captura inicial de luminancia, almacenamiento de un frame en BRAM y volcado por UART. Todavia no hay procesamiento de estrellas.
