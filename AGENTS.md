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
- No avanzar a deteccion de estrellas, centroides o actitud hasta que el usuario lo indique.
- Antes de modificar RTL, explicar que archivo se tocara y por que.
- Mantener cambios minimos y verificables.
- Distinguir claramente cambios de simulacion y cambios que afectan hardware real.
- No rehacer documentacion RTL existente si basta con consultarla o actualizarla puntualmente.
- Todo cambio importante debe quedar documentado.

## Flujo actual del sistema

Flujo validado:

```text
init SCCB/I2C -> XCLK -> captura OV7670 -> extraccion Y -> BRAM -> UART
```

Flujo detallado:

```text
init SCCB/I2C -> camara OV7670 simulada -> captura QQVGA 160x120 en YUV 4:2:2
-> extraccion de Y -> BRAM -> frame_uart_dump -> uart_tx -> receptor UART en testbench
```

El PASS esperado del test global UART incluye:

- magic `STY1`
- width `160`
- height `120`
- payload length `19200` bytes
- payload Y correcto
- checksum correcto

## Archivos clave

- `README.md`: estado general, estructura y formato UART.
- `Docs/EXPLICACION_SRC_RTL.md`: documentacion RTL didactica con descripcion y diagramas de estado.
- `Scripts/xsim_top_uart_full.tcl`: flujo Vivado/XSim del test global UART.
- `Top/tb/tb_star_tracker_top_uart_full.vhd`: testbench global UART.
- `Top/rtl/star_tracker_top.vhd`: top-level del sistema.
- `Protocolo de comunicacion/rtl/i2c_master.vhd`: maestro SCCB/I2C.
- `Configuracion camara/rtl/frame_uart_dump.vhd`: volcado de frame por UART.

Antes de modificar modulos RTL, consultar la documentacion existente. La documentacion RTL ya existe
y debe usarse como referencia para entender interfaces, maquinas de estado y flujo de datos.

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
