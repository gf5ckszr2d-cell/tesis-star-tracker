# Validacion local - 2026-10-20

**Revision actual: ver el apartado final del 21-10-2026.** Las pruebas y estados anteriores
se conservan como historial, no describen la entrega vigente.

Configuracion vigente: 100 MHz desde FCLK_CLK0 del Zynq; ver ultima seccion.

Herramienta: Vivado/XSim 2025.2. Ejecucion batch de `scripts/simulate.tcl`, salida 0.
Resultado final: `PASS_CAPTURA_AMBOS_RELOJES`.

| Reloj del core | Resultado | Tiempo simulado al PASS |
|---|---|---|
| 100 MHz | PASS_RELOJ_100000000 | 35.186115033 ms |
| 125 MHz | PASS_RELOJ_125000000 | 31.727920365 ms |

En cada corrida se verificaron:

- Ausencia de configuracion/transmision antes de start y rechazo de un rebote corto.
- Los 21 pares de registros SCCB originales, sin reconfigurar en la segunda captura.
- MMCM real de Unisim, sin bypass de lock, y XCLK de 24 MHz.
- Dos frames distintos de 160x120. Cada paquete STY1 contiene su cabecera exacta,
  los 19200 bytes Y esperados en orden y el checksum modulo 256 correcto.
- Una sola captura con start mantenido, nueva captura tras soltar/pulsar,
  y descarte de una pulsacion mientras se transmite por UART.
- Retorno de TX a idle tras reset.

El testbench acelera exclusivamente baud (CLK_FREQ_HZ/4) y debounce (4 ciclos).
En esa validacion inicial los defaults eran 921600 baud y 2000000 ciclos de filtro.
La imagen de prueba es sintetica; no es una fotografia de la OV7670 real.

Integridad antes del ajuste de reloj: las siete copias de modulos del hito 1 coincidieron por SHA-256 tanto
con `origen_modulos.json` como con los originales del repositorio. El top nuevo
y su generador XCLK son independientes del top global y las etapas estelares.
Los productos de simulacion quedan en `build/simulation/` (fuera del control de versiones).
El log `xsim.log` corresponde a la ultima corrida de 125 MHz.

Impacto: top sintetizable nuevo, MMCM y sincronizadores afectan una futura
implementacion fisica. Los generics acelerados pertenecen solo al testbench.
No se ejecuto sintesis, implementacion, generacion de bitstream/XSA, programacion,
creacion de bloques de diseno, wrappers ni compilacion Vitis para esta captura.
No se valido cableado, timing implementado ni calidad optica en placa.

## Ajuste explicito a entrada de 125 MHz - 2026-10-20

Se fijaron los defaults CLK_FREQ_HZ=125000000 en captura_uart_top, captura_xclk,
i2c_master, uart_tx y ov7670_init_config. El top sigue propagando el parametro
a todos los consumidores. Se actualizaron el script de creacion y el generic
guardado en el XPR existente. El filtro de boton pasa a 2500000 ciclos (20 ms).
No se modificaron formulas ni los 21 pares de registros iniciales de la camara.
Los originales Nexys y la prueba UART/PS previa no se modificaron.

Verificacion nueva: `scripts/check_clocks.tcl`, Vivado/XSim 2025.2, salida 0.
`PASS_RELOJES_125` a 50.204 us, con MMCM real y defaults sin generic map:

- Entrada de 125 MHz (periodo 8 ns).
- XCLK de 24 MHz.
- SCL de 100 kHz (periodo entre flancos de 10 us).
- UART nominal 921600: divisor entero 135, periodo de bit 1080 ns;
  baud efectivo aproximado 925926, error +0.47%, ya presente por redondeo.

Compilaron los nueve RTL y el testbench de reloj. Tambien paso la comprobacion
estatica de los cinco defaults, script, XPR y ROM de camara intacta.
La prueba completa de imagen indicada arriba es anterior a este ajuste de
defaults; no se repitio porque las formulas y el caso explicito de 125 MHz
no cambiaron. No se genero hardware ni se valido fisicamente en esta revision.
Si Vivado ya estaba abierto, aplicar el generic de 125 MHz en la Tcl Console
como indica README para actualizar tambien la configuracion en memoria.

## Configuracion vigente restaurada a 100 MHz - 2026-10-20

Por solicitud del usuario, defaults CLK_FREQ_HZ=100000000 en captura_uart_top,
captura_xclk, i2c_master, uart_tx y ov7670_init_config. Script y XPR guardado
actualizados a 100 MHz. Debounce restaurado a 2000000 ciclos (20 ms).
El reloj esperado es FCLK_CLK0 del PS configurado a 100 MHz; no SYSCLK directo.
El baud permanece en 921600. No se modifico la configuracion inicial de camara.
Las siete copias de modulos originales vuelven a coincidir con sus hashes.

Verificacion: `scripts/check_clocks.tcl` (tb_relojes_100), salida 0;
`PASS_RELOJES_100` a 50.205 us: XCLK 24 MHz, SCL 100 kHz y UART 108 ciclos
de 10 ns por bit (1080 ns, baud efectivo aproximado 925926).
Compilaron los nueve VHDL; se comprobaron tambien defaults, script y XPR.
Se conserva el test opcional de 125 MHz con generics explicitos para ese caso.
No se generaron bitstream, XSA ni nuevos bloques de diseno. No hay validacion
fisica nueva. Si Vivado esta abierto, actualizar su generic en memoria:

```tcl
set_property generic {CLK_FREQ_HZ=100000000 UART_BAUD_RATE=921600} [get_filesets sources_1]
```

## Constraints ordenados de camara y botones - 2026-10-20

Se agregaron camara_botones_arty_z7.xdc y pclk_ordenado_ruta.xdc. Mapeo
contrastado con Digilent Arty-Z7-10-Master.xdc: 16 senales de camara y dos
pulsadores, 18 LOC unicos, todos LVCMOS33. Orden de columnas JA/JB conservado
en pines fisicos 1,2,3,4 y 7,8,9,10; alimentacion 3.3 V/GND aparte.
No se asignan LOC a clk ni tx: se reservan a conexiones internas del PS.

El script add_constraints.tcl se verifico en Vivado 2025.2 con un proyecto
en memoria: PASS_CARGA_XDC, salida 0. Dos cargas consecutivas no duplicaron
archivos; se verificaron flags de implementacion, exclusion del waiver de
sintesis, PROCESSING_ORDER LATE, y restablecimiento del generic del core
a 100 MHz conservando el baud. Tcl completo en ambos XDC. No se modifico
el XPR abierto del usuario desde una segunda sesion de Vivado. Para cargar
los cambios en ese proyecto debe ejecutar el source indicado en CABLEADO.md.

Limitacion: PCLK en JA3/Y16 no es clock-capable. Para preservar el orden se
dejo una excepcion CLOCK_DEDICATED_ROUTE FALSE solo sobre su red tras IBUF.
La deteccion de ese IBUF y el ruteo final NO fueron ejecutados/verificados
sobre una netlist sintetizada. La carga en memoria no acredita aplicacion
de cada propiedad a una netlist, timing, ruteo ni funcionamiento fisico.
No se ejecuto sintesis, implementacion, bitstream, XSA ni creacion de BD.
No se cambiaron RTL ni registros de camara.

## Constraint unico con PCLK dedicado - 2026-10-20

Configuracion vigente: solo camara_botones_arty_z7.xdc. Se intercambiaron
PCLK y D5: cam_pclk -> JA7/U18 (MRCC positivo), cam_data[5] -> JA3/Y16.
Se retiro pclk_ordenado_ruta.xdc y su excepcion de ruteo. El cargador retira
la referencia antigua de cualquier proyecto donde se ejecute, agrega solo
el XDC vigente y lo habilita para sintesis/implementacion, orden NORMAL.
Se actualizaron CABLEADO.md y README. No se modificaron RTL ni el resto de LOC.
Verificacion estatica: 18 LOC unicos, un XDC y PCLK/D5 en los pines indicados.
Vivado 2025.2, proyecto en memoria: PASS_XDC_UNICO, salida 0. Dos cargas
consecutivas conservaron un solo XDC, activo en sintesis e implementacion.
El proyecto abierto del usuario requiere ejecutar otra vez add_constraints.tcl
para cargar los cambios y retirar la antigua referencia si sigue en memoria.
No se ejecuto sintesis, implementacion ni programacion de placa.

## Entrega integrada de captura ARM/PC - 21-10-2026

Comparacion completa y uso: `DIAGNOSTICO_20261021.md`. Fuentes anteriores en
`antes_20261021/`; proyecto corregido separado en `build/diagnostico/`.

Resultados efectivamente ejecutados con Vivado/XSim y Vitis 2025.2:

| Comprobacion | Resultado final / evidencia |
|---|---|
| Captura integrada, version final, entrada 100 MHz | PASS_CAPTURA_UART, 27.243492117 ms simulados; `build/simulation_verified_console.log` |
| Contenido de esa prueba | 21 escrituras SCCB, MMCM real/XCLK 24 MHz, dos paquetes STY1 160x120, 19200 bytes Y por paquete, checksum, debounce, start mantenido, descarte ocupado, rearmado y reset |
| SCCB final con sincronizador SDA | PASS_SCCB_TIMING; escritura 0x42, ACK deliberadamente retrasado, lectura A5 y NACK sin esclavo; `build/sccb_console.log` |
| Integridad BRAM | PASS_STORE_INTEGRITY; completo/liberacion, corto, overflow del capturador y coordenadas duplicadas; `build/store_console.log` |
| LEDs/reset sin camara | PASS_DIAG_RESET; NACK muestra 001, TX inactivo, BTN0 recupera sin PCLK y permite reintento; `build/diag_console.log` |
| Parametros reales, sin acelerar baud | PASS_RELOJES_100; XCLK 24 MHz, SCL 100 kHz, UART 108 ciclos/bit = 1080 ns, baud efectivo 925926 (+0.47% respecto a 921600); `build/clocks_console.log` |
| Sintesis e implementacion xc7z010clg400-1 | PASS_BUILD_DIAGNOSTICO, bitstream y XSA con bit generados; `build/build_diagnostic.log` |
| Timing final implementado | WNS **+4.304 ns**, WHS **+0.068 ns**, TNS/THS 0; sin endpoints internos sin restriccion; `build/diagnostico/resultados/timing.rpt` |
| CDC final | 8 cruces informativos CDC-3 y 1 reset CDC-9; **0 warnings / 0 critical** en `resultados/cdc.rpt` |
| DRC | 0 errores; permanecen dos recomendaciones de pipeline DSP DPOP-1/2; `resultados/drc.rpt` |
| Metodologia | Permanecen 20 avisos TIMING-18 sobre E/S y referencia a bordes. Las entradas D/HREF/VSYNC tienen min/max respecto al flanco descendente y aparecen temporizadas en el informe. No se ocultaron avisos ni se completo timing externo inventando retardos |
| Vitis plataforma y ARM | XSA actualizado por API, BSP/plataforma y `receptor_ov7670_test` compilados correctamente; ELF final text=36421, data=3048, bss=107928 bytes; `build/vitis_update.log` |
| Parser C utilizado por ARM | PASS_STY1_C; tramas sucesivas, marcadores binarios, cabecera, checksum, reset por timeout y resincronizacion |
| Receptor PC | 5 tests unittest PASS: diagnosticos ARM fuera de payload, fragmentacion, marcadores dentro de imagen, corrupcion, timeout/recuperacion y PNG roundtrip exacto |
| Coherencia de entrega | PASS_DELIVERY: bit incluido en XSA = bit final = copia de lanzamiento; XSA de plataforma identico; ELF copiado identico; linker y ps7_init conservados por SHA-256; `resultados/verificacion_entrega.json` |

La corrida inicial tambien paso a 125 MHz antes de las ultimas mejoras de reset/SDA;
la verificacion integral de la **version final** se realizo a **100 MHz**, el reloj del BD real.
Solo se aceleran en TB baud, debounce y esperas de arranque; no hay bypass del MMCM.

La copia del proyecto tenia checkpoints OOC del modulo referenciado. Se corrigio
`build_diagnostic.tcl` para forzar su resintesis y evitar entregar un bitstream con RTL
anterior. La configuracion Run de Vitis apunta ahora directamente al bitstream final.
`UserConfig.cmake` incorpora `sty1.c`; el CMake que usa `lscript.ld` se conserva.

**Impacto hardware:** top, SCCB, validacion de captura, reset, LEDs y constraints;
la tabla de 21 registros, BRAM, formato YUV422 y resolucion 160x120 se conservan.
El UART sigue transportando exclusivamente captura, sin centroides.

**Limite fisico:** COM3 enumerado, pero no se programo la placa, no se pulso BTN1 y
no se adquirio una imagen real en esta revision. El skew de cable +/-2 ns es un
presupuesto pendiente de medir. Ver procedimiento por LED en el diagnostico.

`git pull --ff-only` no pudo escribir `.git/FETCH_HEAD` por las restricciones del entorno.
No se realizo commit/push ni se publico el trabajo en servicios externos.

## Revision posterior: 010 medido en hardware

Esta revision reemplaza el limite fisico anterior: se cargo por JTAG la Arty y
se ejecuto el ARM leyendo COM3 a 115200. La primera medicion obtuvo 120 lineas
de 312 bytes (18720 pixeles), primera linea corta 0. La evidencia y el cambio
minimo de ventana horizontal se detallan en [FIX_010.md](FIX_010.md).
La ventana corregida obtuvo dos capturas reales consecutivas sin reset:
120 lineas, 320 bytes por linea, 19200 pixeles, STY1/checksum correcto, dos PNG
160x120 y cero errores del receptor. XSim final PASS, implementacion WNS
+3.458 ns / WHS +0.046 ns, Vitis text=38125/data=3088/bss=107944, seis tests PC
PASS. El `ps7_init.tcl` vigente incluye GPIO EMIO; la verificacion comprueba que
su copia de lanzamiento coincide con la nueva plataforma (no con el backup).
Ver evidencia y limite de enfoque/iluminacion en [FIX_010.md](FIX_010.md).
