# tesis-star-tracker

Repositorio de tesis para un prototipo de star tracker en FPGA. El alcance actual llega hasta la captura de luminancia `Y` en BRAM y su procesamiento posterior, tambien en VHDL, para detectar componentes brillantes y calcular sus centroides. La identificacion estelar y la determinacion de actitud aun no forman parte de esta etapa. Python se reserva para pruebas auxiliares de capturas, no para el pipeline operativo.

## Estado oficial

- FPGA objetivo: Digilent Nexys A7-100T.
- Camara: OV7670.
- Lenguaje RTL: VHDL.
- Simulacion oficial: Vivado/XSim mediante scripts TCL.
- No usar GHDL en este repositorio.
- Resolucion actual: QQVGA `160x120`.
- Formato de entrada de camara: YUV `4:2:2`.
- Top global oficial: `Top/rtl/star_tracker_top.vhd`.
- Fuente reproducible oficial de Vivado: scripts TCL y archivos RTL/XDC versionados.
- Proyecto GUI regenerable: `Top/vivado_projects/star_tracker_top/star_tracker_top.xpr`.
- Bitstream oficial: `Top/bitstreams/star_tracker_top_nexys.bit`.

Flujos implementados:

```text
SW8=0: OV7670 -> captura Y -> BRAM -> umbral -> componentes 8-conectados -> centroides -> lista de estrellas
SW8=1: OV7670 -> captura Y -> BRAM -> frame_uart_dump -> uart_tx USB -> fin
```

La BRAM es la frontera: primero se almacena el frame completo y solo despues lo recorre el consumidor seleccionado. El modo UART conserva el paquete `STY1` ya validado y no transmite resultados del detector.

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
|   |   |-- frame_uart_dump.vhd
|   |   |-- unsigned_iterative_divider.vhd
|   |   |-- frame_star_centroid.vhd
|   |   `-- star_list_buffer.vhd
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
- `ov7670_runtime_config`: permite calibrar contraste, ganancia, exposicion y brillo despues de la inicializacion.
- `ov7670_capture_y_stream`: capturador FSM en dominio `PCLK`; espera sincronizacion con `VSYNC` antes de capturar y emite solo luminancia `Y` del patron YUV 4:2:2.
- `frame_capture_store`: arma una captura unica, escribe pixeles en direccion row-major y marca frame listo.
- `framebuffer_y_bram`: framebuffer dual-clock para `19200` bytes.
- `frame_uart_dump`: lee la BRAM y genera el paquete binario UART.
- `unsigned_iterative_divider`: divisor secuencial usado por el calculo de centroides.
- `frame_star_centroid`: recorre un frame completo, aplica umbral, etiqueta componentes 8-conectados y emite centroides ponderados en Q8.8.
- `star_list_buffer`: almacena hasta 64 resultados por frame en memoria RTL inferida y permite leerlos por indice.
- `star_tracker_top`: integra inicializacion, captura y almacenamiento; despues dirige la lectura de BRAM al detector o al volcado UART segun `SW8`.

## Mapeo Nexys A7-100T y OV7670

El constraint oficial es `Top/constraints/star_tracker_top_nexys.xdc`. La salida UART usa el USB-UART integrado de la Nexys A7-100T; no hay UART por PMOD.

Mapeo fisico ordenado para el header 2x9 de la OV7670:

| Fila OV7670 | Lado izquierdo | Nexys | Lado derecho | Nexys |
|---:|---|---|---|---|
| 1 | 3.3V | 3.3V | GND | GND |
| 2 | SCL | JA1 | SDA | JB1 |
| 3 | VS | JA2 | HS/HREF | JB2 |
| 4 | PCLK | JB10 | XCLK | JB3 |
| 5 | D7 | JA4 | D6 | JB4 |
| 6 | D5 | JA7 | D4 | JB7 |
| 7 | D3 | JA8 | D2 | JB8 |
| 8 | D1 | JA9 | D0 | JB9 |
| 9 | RESET | JA10 | PWDN | JA3 |

Entradas/salidas de usuario:

- `start_btn`: inicia la configuracion; despues de una captura y envio completo puede armar una nueva captura.
- `rst`: reset general activo en alto.
- `SW8=0`: modo normal; ejecuta deteccion y centroides en el FPGA despues de capturar el frame.
- `SW8=1`: modo diagnostico; corta el pipeline despues de captura y envia solo el frame por UART.
- `ok`: indica inicializacion y consumidor del frame completados.
- `fail`: indica error de inicializacion, captura, almacenamiento, etiquetas o capacidad de la lista.
- `busy`: indica actividad de init, I2C, captura, detector, dump o UART.
- `led_read_data[7:0]`: muestra el ultimo byte `Y` capturado.

## Calibracion manual de camara

El bitstream mantiene como base la configuracion validada de la ROM. La calibracion manual es
opcional y queda bloqueada mientras `SW15=0`; en ese estado, `btn_config` y los switches de
selector/valor no generan escrituras SCCB/I2C y el flujo de captura funciona como antes.

Con `SW15=1`, `BTND` aplica el valor de `SW7:0` al parametro seleccionado por `SW14:13`:

| `SW14:13` | Parametro | Registro |
|---|---|---|
| `00` | Contraste | `0x56` |
| `01` | Ganancia manual | `0x13=0x8B`, luego `0x00` |
| `10` | Exposicion manual | `0x13=0x8E`, luego `0x10` |
| `11` | Brillo | `0x55` |

El reset general restaura el flujo de inicializacion desde la ROM base.

## Simulacion XSim

Ejecutar desde Vivado Tcl Shell o desde una terminal con Vivado en `PATH`:

```powershell
vivado -mode batch -source "Protocolo de comunicacion/scripts/xsim_i2c_master.tcl"
vivado -mode batch -source "Configuracion camara/scripts/xsim_ov7670_init_config.tcl"
vivado -mode batch -source "Configuracion camara/scripts/xsim_ov7670_xclk_gen.tcl"
vivado -mode batch -source "Configuracion camara/scripts/xsim_ov7670_capture_y_stream.tcl"
vivado -mode batch -source "Scripts/xsim_star_list_buffer.tcl"
vivado -mode batch -source "Scripts/xsim_frame_star_centroid.tcl"
vivado -mode batch -source "Scripts/xsim_top_detector_bram.tcl"
vivado -mode batch -source "Scripts/xsim_top_uart_full.tcl"
vivado -mode batch -source "Scripts/vivado_synth_check.tcl"
```

El test global `Scripts/xsim_top_uart_full.tcl` elabora `Top/tb/tb_star_tracker_top.vhd` y genera `sim_build/xsim_top_uart_full/xsim_top_uart_full.wdb`.

La prueba del detector usa un frame sintetico pequeno con dos estrellas conocidas y comprueba numero de objetos, area, intensidad y centroides ponderados Q8.8. Los detalles del algoritmo y sus limites estan en `Docs/deteccion_centroides_bram.md`.

## Deteccion y centroides post-BRAM

La configuracion inicial del top usa umbral de luminancia `Y >= 45`, conectividad de 8 vecinos, area valida entre 2 y 500 pixeles y hasta 64 etiquetas provisionales. Para cada componente valido se produce un pulso `star_valid` con indice, area, intensidad acumulada y:

```text
centroid_x_q8_8 = (sum(x * Y) << 8) / sum(Y)
centroid_y_q8_8 = (sum(y * Y) << 8) / sum(Y)
```

Cada pulso `star_valid` se guarda en `star_list_buffer`. Cada entrada ocupa 75 bits:

```text
[74:57] centroide X Q8.8 (18 bits)
[56:39] centroide Y Q8.8 (18 bits)
[38:24] area               (15 bits)
[23:0]  intensidad         (24 bits)
```

La lista tiene 64 entradas y lectura sincrona por indice, con un ciclo de latencia. Un nuevo frame pone `star_count=0` y hace no validas las entradas anteriores sin imponer un borrado masivo de la memoria. Al finalizar, `list_ready` valida `star_count` y las lecturas. Si llega una estrella 65, `overflow` se activa y no se escribe fuera de rango.

Los resultados permanecen como interfaz interna para la siguiente etapa VHDL y estan preservados para depuracion ILA. No se conectan al UART, de modo que el hito de captura `STY1` queda congelado.

## Proyecto Vivado y bitstream

Para recrear el proyecto oficial:

```powershell
vivado -mode batch -source "Top/vivado_projects/create_star_tracker_top_project.tcl"
```

Para generar el bitstream oficial directamente desde RTL/XDC, sin depender del estado local del `.xpr`:

```powershell
vivado -mode batch -source "Top/vivado_projects/build_star_tracker_top_bitstream.tcl"
```

El resultado se copia a:

```text
Top/bitstreams/star_tracker_top_nexys.bit
```

Antes de programar la placa con este bitstream, intercambiar fisicamente `PCLK` y `PWDN`:
`PCLK` pasa a `JB10/H16` y `PWDN` a `JA3/E18`; `HS/HREF` permanece en `JB2/F16`.
`JB10/H16` es el lado P de un par `MRCC`; por eso el reloj de pixel ya no necesita
`CLOCK_DEDICATED_ROUTE FALSE`.

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

- Validacion fisica del modo normal de deteccion y centroides en placa.
- Ajuste experimental del umbral y filtros de area con imagenes reales.
- Consumir la lista indexada desde la futura etapa de identificacion VHDL.
- Identificacion estelar y estimacion de actitud.
