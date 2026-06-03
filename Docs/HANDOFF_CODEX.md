# Handoff Codex - tesis-star-tracker

Este archivo es la memoria de traspaso para futuras sesiones de Codex en este repositorio. Codex
no comparte memoria entre la PC y la laptop: la memoria oficial del proyecto debe estar en Git, en
el README, Docs, scripts, commits y archivos de contexto.

## Cambio de entorno principal

- El desarrollo principal del proyecto pasa a realizarse en la PC.
- La laptop queda como entorno secundario, principalmente para laboratorio, pruebas fisicas y
  programacion de la Nexys A7 si hace falta.
- No asumir memoria de sesiones anteriores de Codex en la laptop.
- No rehacer el proyecto ni repetir trabajo ya hecho: leer el repositorio antes de proponer cambios.

## Estado actual validado

Proyecto: `tesis-star-tracker`.

- FPGA objetivo: Nexys A7-100T.
- Camara: OV7670.
- Lenguaje principal: VHDL.
- Simulador principal: Vivado/XSim.
- No usar GHDL para el flujo actual del proyecto.
- El repositorio todavia esta en la etapa de bring-up/captura de camara; no implementar deteccion de
  estrellas, centroides ni actitud hasta que el usuario lo indique.

Flujo completo validado en simulacion:

```text
init SCCB/I2C -> camara OV7670 simulada -> captura QQVGA 160x120 en YUV 4:2:2
-> extraccion de Y -> BRAM -> frame_uart_dump -> uart_tx -> receptor UART en testbench
```

Resumen corto:

```text
SCCB/I2C -> OV7670 simulada -> captura Y -> BRAM -> UART
```

El PASS esperado del test global UART incluye:

- magic `STY1`
- width `160`
- height `120`
- payload length `19200` bytes
- payload Y esperado
- checksum correcto

El testbench global reporta:

```text
PASS_TOP_UART_FULL: init, captura QQVGA, BRAM, UART, payload y checksum correctos
```

## Cambios importantes ya realizados

- Testbench global UART: `Top/tb/tb_star_tracker_top_uart_full.vhd`.
- Script XSim del test global: `Scripts/xsim_top_uart_full.tcl`.
- `star_tracker_top.vhd` incluye `SIM_BYPASS_XCLK_LOCK` con default `false`, para no afectar
  hardware real. En el testbench se usa `true`.
- Se corrigio un bug en `Protocolo de comunicacion/rtl/i2c_master.vhd` relacionado con
  `WAIT_START_RELEASE`.
- La ruta UART y `frame_uart_dump` son parte del flujo validado y no deben eliminarse.

## Documentacion y archivos revisados en esta PC

Archivos encontrados y relevantes:

- `README.md`
- `Docs/EXPLICACION_SRC_RTL.md`
- `Docs/EXPLICACION_SRC_RTL.pdf`
- `Scripts/xsim_top_uart_full.tcl`
- `Scripts/vivado_synth_check.tcl`
- `Scripts/vivado_smoke.tcl`
- `Top/tb/tb_star_tracker_top_uart_full.vhd`
- `Top/tb/tb_star_tracker_top.vhd`
- `Top/rtl/star_tracker_top.vhd`

Nota: `Docs/EXPLICACION_TOP_GLOBAL.md` fue mencionado como documento esperado, pero no aparece en
este checkout al momento de crear este handoff. La documentacion RTL didactica existente esta en
`Docs/EXPLICACION_SRC_RTL.md` y ya incluye descripcion del flujo y diagramas de estado.

## Reglas para no perder sincronizacion entre PC y laptop

1. Antes de empezar en cualquier maquina, ejecutar `git pull`.
2. Revisar `git status`.
3. Hacer cambios pequenos y verificables.
4. Hacer commits pequenos con mensajes claros.
5. Al terminar una sesion de trabajo, ejecutar `git push`.
6. Antes de continuar en la otra maquina, ejecutar `git pull`.
7. Si hay cambios locales sin commit en una maquina, no continuar en la otra sin resolver la
   sincronizacion.

## Regla de continuidad para futuras sesiones

Antes de modificar RTL, scripts o testbenches, una futura sesion de Codex debe leer este archivo,
`AGENTS.md`, el README y la documentacion RTL existente. Todo cambio importante debe quedar
documentado en el repositorio.
