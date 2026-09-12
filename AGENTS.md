# AGENTS.md - reglas permanentes para Codex

Estas reglas aplican a cualquier sesion de Codex que trabaje en este repositorio.

## Reglas de proyecto

- Usar VHDL como lenguaje principal del RTL.
- Usar Vivado/XSim mediante scripts TCL para simulacion.
- No usar GHDL.
- No borrar la ruta UART.
- No borrar `frame_uart_dump`.
- No cambiar QQVGA `160x120` sin instruccion explicita.
- No cambiar YUV `4:2:2` sin justificacion tecnica.
- La deteccion y los centroides post-BRAM ya estan autorizados e implementados en VHDL.
- No avanzar a identificacion estelar ni determinacion de actitud hasta que el usuario lo indique.
- Antes de modificar RTL, explicar que archivo se tocara y por que.
- Mantener cambios minimos y verificables.
- Distinguir claramente cambios de simulacion y cambios que afectan hardware real.
- No rehacer documentacion RTL existente si basta con consultarla o actualizarla puntualmente.
- Todo cambio importante debe quedar documentado.

## Flujo actual del sistema

Flujo normal implementado:

```text
init SCCB/I2C -> XCLK -> captura OV7670 -> extraccion Y -> BRAM
-> umbral -> componentes 8-conectados -> centroides Q8.8
-> lista indexada de hasta 64 estrellas
```

Flujo de diagnostico de captura:

```text
SW8=1 -> captura QQVGA 160x120 en YUV 4:2:2 -> extraccion de Y -> BRAM
-> frame_uart_dump -> uart_tx -> receptor UART en testbench -> fin
```

Con `SW8=0` no se usa UART. La BRAM es la frontera entre captura y procesamiento; no convertir
la deteccion a streaming sin instruccion explicita. El UART termina siempre en la captura y no debe
ampliarse para transportar centroides.

El PASS esperado del test global UART incluye:

- magic `STY1`
- width `160`
- height `120`
- payload length `19200` bytes
- payload Y correcto
- checksum correcto

## Archivos clave

- `README.md`: estado general, estructura y formato UART.
- `Scripts/xsim_top_uart_full.tcl`: flujo Vivado/XSim del test global UART.
- `Top/tb/tb_star_tracker_top.vhd`: testbench global UART.
- `Top/rtl/star_tracker_top.vhd`: top-level del sistema.
- `Protocolo de comunicacion/rtl/i2c_master.vhd`: maestro SCCB/I2C.
- `Configuracion camara/rtl/ov7670_capture_y_stream.vhd`: capturador oficial por FSM sincronizado con VSYNC.
- `Configuracion camara/rtl/frame_uart_dump.vhd`: volcado de frame por UART.
- `Configuracion camara/rtl/frame_star_centroid.vhd`: deteccion y centroides post-BRAM.
- `Configuracion camara/rtl/star_list_buffer.vhd`: almacenamiento RTL inferido de estrellas por frame.
- `Configuracion camara/rtl/unsigned_iterative_divider.vhd`: division secuencial para Q8.8.
- `Scripts/xsim_frame_star_centroid.tcl`: prueba reproducible del detector.
- `Scripts/xsim_star_list_buffer.tcl`: prueba unitaria reproducible de la lista.
- `Scripts/xsim_top_detector_bram.tcl`: prueba integrada del modo normal con `SW8=0`.

Antes de modificar modulos RTL, consultar primero `README.md`, `Docs/` y los scripts TCL existentes
para entender interfaces, maquinas de estado y flujo de datos.

## Simulacion y hardware

- El simulador principal es Vivado/XSim.
- Los scripts TCL deben ser la forma preferida de correr simulaciones reproducibles.
- `SIM_BYPASS_XCLK_LOCK` existe para simulacion y debe mantenerse con default `false` para hardware
  real.
- Si un cambio solo afecta testbench, generics de simulacion o scripts, documentarlo como cambio de
  simulacion.
- Si un cambio afecta top-level, RTL sintetizable, constraints, clocks, resets o interfaces fisicas,
  documentarlo como cambio con impacto potencial en hardware real.

## Memoria entre maquinas

Codex no comparte memoria entre la PC y la laptop. La memoria oficial es el repositorio: README,
Docs, scripts, commits y archivos de contexto.

Para trabajar entre PC y laptop:

1. Ejecutar `git pull` antes de empezar.
2. Revisar `git status`.
3. Hacer commits pequenos.
4. Ejecutar `git push` al terminar.
5. Ejecutar `git pull` en la otra maquina antes de continuar.

La PC es el entorno principal de desarrollo. La laptop queda principalmente para laboratorio,
pruebas fisicas y programacion de la Nexys A7 si hace falta.
