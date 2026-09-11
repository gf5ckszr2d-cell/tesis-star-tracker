# v0.1_historico_funcional

| Campo | Valor |
| --- | --- |
| Versión | `v0.1_historico_funcional` |
| Fecha de esta release | 2026-09-11 |
| Commit de origen | `27a3eaca41db209e63f4866aa839493701e40522` |
| Archivo en el commit | `Top/bitstreams/star_tracker_top_nexys.bit` |
| SHA-256 | `02570251EAF1926114CDC2D4D5A9CEF8FAEA61309FDC1E22A5B2D7801D92B74B` |
| Blob Git | `d8ed850b065661b71252a2ac4df0d0abd4d745c0` |
| Placa | Nexys A7-100T |
| Vivado | 2025.2, según el proyecto XPR almacenado en el mismo commit |
| Estado | `HARDWARE_VERIFIED_HISTORICAL` |

## Alcance y evidencia

Este archivo corresponde al diseño anterior. Fue extraído directamente del
blob almacenado por Git en `27a3eac`; no se regeneró. Existe evidencia histórica
de captura física funcional. Esa prueba no fue repetida durante la creación de
esta release, por lo que el estado distingue expresamente la evidencia histórica
de una validación física nueva.

## Cableado OV7670 del XDC de `27a3eac`

Esta versión requiere el cableado anterior. La tabla reproduce las asignaciones
del archivo `Top/constraints/star_tracker_top_nexys.xdc` del mismo commit.

| Señal OV7670 | PMOD | Pin FPGA |
| --- | --- | --- |
| SCL | JA1 | C17 |
| VSYNC | JA2 | D18 |
| PCLK | JA3 | E18 |
| D7 | JA4 | G17 |
| D5 | JA7 | D17 |
| D3 | JA8 | E17 |
| D1 | JA9 | F18 |
| RESET | JA10 | G18 |
| SDA | JB1 | D14 |
| HREF | JB2 | F16 |
| XCLK | JB3 | G16 |
| D6 | JB4 | H14 |
| D4 | JB7 | E16 |
| D2 | JB8 | F13 |
| D0 | JB9 | G13 |
| PWDN | JB10 | H16 |

La alimentación de la cámara continúa siendo 3.3 V y GND. No usar el cableado
de v0.2 con este bitstream: en v0.1 PCLK y PWDN ocupan las posiciones opuestas.

## Pruebas y observaciones

- Evidencia histórica: captura física funcional con el diseño anterior.
- Verificación de conservación: SHA-256 y blob Git comprobados contra
  `27a3eac`.
- No se ejecutaron nuevamente simulaciones ni una prueba física al crear esta
  release.
- El bitstream histórico no fue recompilado ni modificado.
