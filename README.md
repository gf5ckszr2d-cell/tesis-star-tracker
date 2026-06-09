# tesis-star-tracker

Repositorio de tesis para un prototipo de star tracker en FPGA. El alcance actual no incluye todavia deteccion de estrellas, centroides ni determinacion de actitud; esta etapa valida la configuracion de la camara OV7670, la captura de luminancia `Y`, el almacenamiento de un frame en BRAM y el envio por UART hacia la PC.

## Estado oficial

- FPGA objetivo: Digilent Nexys A7-100T.
- Camara: OV7670.
- Lenguaje RTL: VHDL.
- Simulacion oficial: Vivado/XSim mediante scripts TCL.
- No usar GHDL en este repositorio.
- Resolucion actual: QQVGA `160x120`.
- Formato de entrada de camara: YUV `4:2:2`.
- Top global oficial: `Top/rtl/star_tracker_top.vhd`.
- Proyecto Vivado oficial: `Top/vivado_projects/star_tracker_top/star_tracker_top.xpr`.
- Bitstream oficial: `Top/bitstreams/star_tracker_top_nexys.bit`.

Flujo validado:

```text
init SCCB/I2C -> OV7670 -> XCLK/PCLK -> captura Y -> BRAM -> frame_uart_dump -> uart_tx USB
```

El test global esperado valida paquete UART con `STY1`, ancho `160`, alto `120`, payload `19200` bytes, payload Y correcto y checksum correcto.

## Estructura

```text
.
|-- Protocolo de comunicacion/
|   |-- rtl/
|   |   |-- i2c_master.vhd
|   |   `-- uart_tx.vhd
|   |-- tb/
|   `-- scripts/
|-- Configuracion camara/
|   |-- rtl/
|   |   |-- ov7670_xclk_gen.vhd
|   |   |-- ov7670_init_config.vhd
|   |   |-- ov7670_capture_y_stream.vhd
|   |   |-- frame_capture_store.vhd
|   |   |-- framebuffer_y_bram.vhd
|   |   `-- frame_uart_dump.vhd
|   |-- tb/
|   `-- scripts/
|-- Top/
|   |-- rtl/star_tracker_top.vhd
|   |-- tb/tb_star_tracker_top.vhd
|   |-- constraints/star_tracker_top_nexys.xdc
|   |-- vivado_projects/
|   `-- bitstreams/
|-- Scripts/
|-- Docs/
`-- AGENTS.md
```

## Modulos principales

- `i2c_master`: maestro SCCB/I2C usado para configurar la OV7670.
- `uart_tx`: transmisor UART 8N1.
- `ov7670_xclk_gen`: genera `XCLK` de 24 MHz desde el reloj de 100 MHz de la Nexys A7-100T.
- `ov7670_init_config`: envia la tabla de registros de inicializacion de la OV7670.
- `ov7670_capture_y_stream`: capturador FSM en dominio `PCLK`; espera sincronizacion con `VSYNC` antes de capturar y emite solo luminancia `Y` del patron YUV 4:2:2.
- `frame_capture_store`: arma una captura unica, escribe pixeles en direccion row-major y marca frame listo.
- `framebuffer_y_bram`: framebuffer dual-clock para `19200` bytes.
- `frame_uart_dump`: lee la BRAM y genera el paquete binario UART.
- `star_tracker_top`: integra inicializacion, captura, almacenamiento y envio UART.

## Mapeo Nexys A7-100T y OV7670

El constraint oficial es `Top/constraints/star_tracker_top_nexys.xdc`. La salida UART usa el USB-UART integrado de la Nexys A7-100T; no hay UART por PMOD.

Mapeo fisico ordenado para el header 2x9 de la OV7670:

| Fila OV7670 | Lado izquierdo | Nexys | Lado derecho | Nexys |
|---:|---|---|---|---|
| 1 | 3.3V | 3.3V | GND | GND |
| 2 | SCL | JA1 | SDA | JA7 |
| 3 | VS | JA2 | HS/HREF | JA8 |
| 4 | PCLK | JA3 | XCLK | JA9 |
| 5 | D7 | JA4 | D6 | JA10 |
| 6 | D5 | JB1 | D4 | JB7 |
| 7 | D3 | JB2 | D2 | JB8 |
| 8 | D1 | JB3 | D0 | JB9 |
| 9 | RESET | JB4 | PWDN | JB10 |

Entradas/salidas de usuario:

- `start_btn`: inicia la configuracion; despues de una captura y envio completo puede armar una nueva captura.
- `rst`: reset general activo en alto.
- `ok`: indica inicializacion/captura/envio completados.
- `fail`: indica error de inicializacion, captura o almacenamiento.
- `busy`: indica actividad de init, I2C, captura, dump o UART.
- `led_read_data[7:0]`: muestra el ultimo byte `Y` capturado.

## Simulacion XSim

Ejecutar desde Vivado Tcl Shell o desde una terminal con Vivado en `PATH`:

```powershell
vivado -mode batch -source "Protocolo de comunicacion/scripts/xsim_i2c_master.tcl"
vivado -mode batch -source "Configuracion camara/scripts/xsim_ov7670_init_config.tcl"
vivado -mode batch -source "Configuracion camara/scripts/xsim_ov7670_xclk_gen.tcl"
vivado -mode batch -source "Configuracion camara/scripts/xsim_ov7670_capture_y_stream.tcl"
vivado -mode batch -source "Scripts/xsim_top_uart_full.tcl"
```

El test global `Scripts/xsim_top_uart_full.tcl` elabora `Top/tb/tb_star_tracker_top.vhd` y genera `sim_build/xsim_top_uart_full/xsim_top_uart_full.wdb`.

## Proyecto Vivado y bitstream

Para recrear el proyecto oficial:

```powershell
vivado -mode batch -source "Top/vivado_projects/create_star_tracker_top_project.tcl"
```

Para generar el bitstream oficial:

```powershell
vivado -mode batch -source "Top/vivado_projects/build_star_tracker_top_bitstream.tcl"
```

El resultado se copia a:

```text
Top/bitstreams/star_tracker_top_nexys.bit
```

## Formato UART

El frame se transmite por `uart_tx` a `921600` baud, 8N1, como paquete binario:

```text
0x53 0x54 0x59 0x31    magic "STY1"
0xA0 0x00              width  = 160
0x78 0x00              height = 120
0x00 0x4B 0x00 0x00    payload length = 19200
19200 bytes            luminancia Y, row-major
1 byte                 checksum: suma modulo 256 del payload
```

## Trabajo futuro

- Validacion fisica de camara y UART en placa.
- Recepcion/visualizacion del frame en PC.
- Preprocesamiento de imagen.
- Deteccion de estrellas.
- Calculo de centroides.
- Identificacion estelar y estimacion de actitud.
