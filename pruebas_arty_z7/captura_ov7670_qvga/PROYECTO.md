# captura_ov7670_qvga: 320x240

## Banco automatizado D1-D3 - 2026-11-10

La entrada para las pruebas con soporte es [BANCO_DOE.md](BANCO_DOE.md).
Se preparo control SCCB desde ARM para leer y fijar exposicion/ganancia,
patrones nativos G5, adquisicion automatica, fichas visuales D1 y analisis PC
hasta separacion D3. Vivado/XSim, Vitis y pruebas de software pasaron. Esta
revision aun no se cargo ni se probo fisicamente. El preflight verifica hashes.

Los centroides de este banco son calculados en PC. El bitstream Arty sigue
siendo de captura y no acredita el detector VHDL ni FAT F02. Se conservan la
ROM inicial, el protocolo STY1, QVGA y YUV422. Los cambios y su impacto en
hardware se detallan en BANCO_DOE.md. No se avanza a identificacion ni actitud.

## Reparacion del proyecto Vivado - 2026-11-07

El `sistema_captura_arm.bd` encontrado estaba vacio (`design_tree` sin
componentes). La sintesis anterior contenia solo un wrapper vacio y la
implementacion fallo con DRC INBB-3 por la instancia `sistema_captura_arm_i`
sin definir. No se sabe como quedo vacio; la ruta guardada del proyecto era
anterior a su traslado. Vivado 2025.2 tampoco resolvia las referencias de
modulos del BD cuando las fuentes propias estaban marcadas como VHDL 2008.

Se reconstruyo el BD desde `scripts/sistema_captura_arm_diagnostico.tcl` y se
regeneraron wrapper e IP. Los scripts marcan el RTL de este proyecto como VHDL
para permitir referencias de modulo; el testbench conserva VHDL 2008. No se
modifico RTL, XDC, resolucion ni formato. El cambio de configuracion del
proyecto afecta la generacion de hardware y debe verificarse en placa.

Vivado 2025.2 completo sintesis, implementacion y bitstream; DRC sin errores,
WNS 3.058 ns y WHS 0.055 ns para las restricciones especificadas. El informe
de metodologia mantiene 20 avisos TIMING-18 por retardos de E/S; cumplir las
restricciones existentes no demuestra que todas las interfaces esten plenamente
caracterizadas. Vitis actualizo plataforma y compilo el ARM. Los hashes de
XSA, BIT, ELF, PS init y fuentes ARM coinciden con el workspace. La placa no
estaba conectada y la captura fisica de esta reconstruccion no se ha probado.
Los resultados anteriores se conservaron en `build/resultados_antes_reparacion_20261107/`.

Proyecto independiente de captura Arty Z7-10, VHDL, YUV422 -> Y -> BRAM -> UART.
Vivado: `build/proyecto/captura_ov7670_qvga.xpr`. Vitis: workspace `vitis/` dentro de ESTA carpeta.
Fuentes propias: `rtl/`, `arm/src/`, `pc/`; no se importa RTL ni ARM de la otra variante.
En Windows se usa `Q:` como alias del repositorio para evitar rutas largas. Los
scripts verifican su destino; `Q:/pruebas_arty_z7/captura_ov7670_qvga/vitis/` y esta
carpeta `vitis/` son el mismo workspace, no copias distintas.
Editar el ARM en `arm/src`; `update_vitis.py` copia esas fuentes al componente Vitis.

1. Vivado: ejecutar `scripts/create_project.tcl` para abrir/crear el proyecto completo.
2. Para reconstruir: `scripts/build_fix010.tcl` y despues Vitis `-s scripts/update_vitis.py`.
3. Verificar: Python `scripts/verify_delivery.py`.
4. Programar: XSCT `scripts/load_capture.tcl`, con el terminal serie cerrado.
5. Recibir: Python `pc/recibir_imagen.py --port COM3`, pulsar BTN1; COM3 115200 8N1.

`build/diagnostico/resultados/` conserva BIT/XSA/ELF. Los logs previos son evidencia
historica; `build/verificacion_independencia.json` verifica las rutas y copias actuales.
No abrir el antiguo XPR renombrado como `.xpr.historial_qvga`; la entrada vigente es la de arriba.
El workspace hermano antiguo `Vitis_captura_uart/` se conserva como historial, no es
necesario para construir ni cargar este proyecto. La placa solo ejecuta una variante a la vez.

Secuencia historica: primero QQVGA 160x120 (`captura_ov7670`); despues QVGA 320x240
(`captura_ov7670_qvga`). Ambos fueron capturados fisicamente antes de esta separacion.
La separacion no cambia el RTL funcional ni recalibra la camara; exposicion/ganancia siguen auto.
