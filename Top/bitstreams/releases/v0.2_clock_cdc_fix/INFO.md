# v0.2_clock_cdc_fix

| Campo | Valor |
| --- | --- |
| Versión | `v0.2_clock_cdc_fix` |
| Fecha de esta release | 2026-09-11 |
| Commit de origen | `0c1d66f445e8d99bb26661f9491b0755fd45580f` |
| Archivo en el commit | `Top/bitstreams/star_tracker_top_nexys.bit` |
| SHA-256 | `535CB3853C02663055567669EFC1346284D4C7B6D6CF2AFD23DD0907E30BB6BB` |
| Blob Git | `4c6d0b6f843bbee9b86ca3cee23969ba6be9c8e6` |
| Placa | Nexys A7-100T |
| Vivado | 2025.2 |
| Estado | `HARDWARE_VALIDATION_PENDING` |

## Cableado OV7670 relevante

| Señal OV7670 | PMOD | Pin FPGA |
| --- | --- | --- |
| PCLK | JB10 | H16 |
| PWDN | JA3 | E18 |
| HREF | JB2 | F16 |

Las demás señales conservan las asignaciones documentadas en
`Top/constraints/star_tracker_top_nexys.xdc` del commit `0c1d66f`. La cámara se
alimenta con 3.3 V y GND.

## Pruebas y resultados registrados

- Simulaciones: PASS.
- Integración superior UART: `PASS_TOP_UART_FULL`.
- Configuración de cámara: `PASS_CAMERA_CONFIG_INTEGRATION`.
- Captura y almacenamiento: `PASS_CAPTURE_STORAGE_INTEGRATION`.
- CDC peligrosos reportados: 0.
- WNS: +3.676 ns.
- WHS: +0.048 ns.
- Captura física: pendiente.

## Observaciones

El archivo fue extraído directamente del blob almacenado por Git en `0c1d66f`.
Su SHA-256 coincide con el valor esperado y con el bitstream de trabajo que
estaba presente antes de crear esta release. No se modificó RTL ni se recompiló
el diseño durante este versionado.
