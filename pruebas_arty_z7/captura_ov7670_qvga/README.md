**Entrada vigente:** [PROYECTO.md](PROYECTO.md): captura_ov7670_qvga, 320x240, Vivado y Vitis independientes.
Las revisiones anteriores de este README se conservan como historial.

# Hito 1: captura OV7670 por UART, VHDL independiente

**Revision QVGA 21-10-2026:** la prueba Arty trabaja ahora con 320x240 YUV422,
76800 bytes de luminancia y direcciones BRAM de 17 bits. Ver
[CALIBRACION_QVGA.md](CALIBRACION_QVGA.md) para cambios y estado de verificacion.
La version QQVGA comprobada se conserva completa en `antes_qvga_20261021/`.
Se utiliza el mismo proyecto de diagnostico Arty y workspace ARM; Nexys conserva
su resolucion. El primer objetivo es una toma QVGA; los ensayos de estrella vienen despues.

**Revision vigente 21-10-2026:** captura integrada con ARM, LEDs y receptor PC.
**Correccion posterior del LED 010:** ver [FIX_010.md](FIX_010.md), con la
regresion de blanking VSYNC/HREF, contadores desde ARM y correccion de ventana
horizontal despues de medir fisicamente 312 bytes por linea.
Ver [diagnostico y comparacion antes/despues](DIAGNOSTICO_20261021.md) y el ultimo apartado de
[VALIDACION.md](VALIDACION.md). El proyecto corregido esta en `build/diagnostico/`.
Las secciones originales siguientes describen el hito inicial y conservan su historial.

Top: `rtl/captura_uart_top.vhd`. Usar la lista vigente `scripts/fuentes.tcl` en un
proyecto nuevo y elegir `captura_uart_top` como entidad superior. VHDL-2008.
No agregar el top global ni todas las carpetas del repositorio: no son dependencias.
`scripts/fuentes.tcl` enumera las fuentes y falla con un mensaje claro si falta alguna.

```text
start -> inicializacion SCCB original -> esperar siguiente VSYNC
      -> capturar Y -> BRAM de 19200 bytes -> frame_uart_dump -> uart_tx -> tx
```

## Uso y puertos

1. Aplicar `rst=1` y soltarlo. Reset activo alto; tambien reinicia la configuracion.
2. Pulsar `start`. La primera pulsacion configura la camara y toma una imagen.
3. Esperar el paquete UART completo antes de pulsar otra vez. Cada pulsacion posterior
   toma una imagen nueva sin reescribir los registros SCCB.

Mantener start pulsado no repite capturas. El filtro de rebote exige un nivel estable
por `DEBOUNCE_CYCLES`; se filtran tanto pulsacion como liberacion. Las pulsaciones
mientras esta ocupado se descartan. No se necesita ningun switch ni boton de calibracion.

| Puerto | Funcion |
|---|---|
| `clk` | Reloj real de 100 o 125 MHz, segun el generic |
| `rst` | Reset activo alto |
| `start` | Boton de captura activo alto |
| `tx` | UART serie 8N1, idle alto, logica 3.3 V al salir por un pin |
| `SDA`, `SCL` | Configuracion SCCB de la OV7670; SDA requiere pull-up fisico |
| `cam_pclk`, `cam_vsync`, `cam_href`, `cam_data(7:0)` | Entradas de la camara |
| `cam_xclk`, `cam_reset`, `cam_pwdn` | Salidas hacia la camara |

Reloj/start/reset/TX son los puertos de control y salida de usuario, pero los puertos
de la camara tambien son obligatorios. No se puede capturar una camara real solo con
cuatro senales. El core no incluye LED de estado; el resultado util es el paquete TX.
Un error SCCB requiere reset. No incluye recuperacion ni timeout de camara desconectada.

## Relojes y enlace UART

- Por defecto `CLK_FREQ_HZ=100000000` en el top, XCLK, SCCB, UART e inicializacion.
- Conectar FCLK_CLK0 del Zynq configurado a 100 MHz. No conectar directamente SYSCLK de 125 MHz con esta configuracion.
- `captura_xclk.vhd` usa MMCM/BUFG 7-series en VHDL para generar 24 MHz en ambos casos;
  no necesita Clocking Wizard, bloque de diseno ni wrapper generado.
- `UART_BAUD_RATE=921600` por defecto, igual que el hito 1. Si el enlace que configures
  posteriormente funciona a 115200, poner este generic en 115200 y ajustar ambos extremos.
- `DEBOUNCE_CYCLES=2000000`: 20 ms a 100 MHz.
- Reset se libera sincronizado por separado en clk y PCLK. Eventos de solicitud,
  frame listo y liberacion de BRAM cruzan los dominios mediante toggles sincronizados.

TX es una senal VHDL para tu conexion posterior. El USB-UART integrado del Arty esta
conectado al PS; no se conecta a TX simplemente cambiando un constraint. Esta prueba
no crea ese enlace ARM. Los pines de camara y botones estan en `constraints/`; ver `constraints/CABLEADO.md`.
El XDC antiguo se conserva solo como referencia; no se debe aplicar sin revisar
reloj, PCLK, pin de TX y nombres de puertos del nuevo top.

## Configuracion y formato conservados

QQVGA 160x120, entrada YUV 4:2:2, extraccion de luminancia Y (imagen monocroma).
Los 21 pares de registros de `ov7670_init_config.vhd` son una copia exacta del hito 1.
No se agregan controles de exposicion, ganancia, brillo ni contraste.
`origen_modulos.json` identifica los origenes y sus hashes; los defaults se restauraron a 100 MHz y las siete copias vuelven a coincidir con sus originales. Los modulos se mantienen
localmente para que cambios en el top general no arrastren esta prueba.

Paquete: `STY1` + ancho uint16 LE + alto uint16 LE + longitud uint32 LE
+ 19200 bytes Y en orden de filas + suma de Y modulo 256 (un byte). Total: 19213 bytes.
Compatible con el receptor de imagen existente bajo `recepcion de frame`.
No transmitir texto de depuracion dentro de este paquete binario.

## Simulacion reproducible

Desde la raiz del repositorio:

```powershell
& 'C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat' -mode batch -nojournal -nolog -source 'pruebas_arty_z7/captura_ov7670/scripts/simulate.tcl'
```

El script compila exclusivamente estas fuentes y el testbench, sin crear proyecto GUI.
Prueba relojes de 100 y 125 MHz con MMCM real simulado, configuracion SCCB de 21 registros,
XCLK de 24 MHz y dos imagenes con patrones distintos. Verifica todos los bytes STY1,
checksum, filtro de rebote, start mantenido, rearmado y descarte de pulsaciones ocupado.
El baud se acelera solo en testbench. No hay bypass de lock en hardware.

Ambas corridas pasaron; ver `VALIDACION.md`. Resultados y logs en `build/simulation/`. El test sintetico no acredita calidad optica,
conexion fisica, timing implementado ni funcionamiento de la placa.

## Iterar por etapas

Cada experimento debe tener su propio top pequeno y su manifiesto de fuentes.
La BRAM es el punto de separacion: esta prueba termina en UART; futuras pruebas de
centroides pueden consumir esa misma interfaz sin integrarlas en este top.
Asi no depende de tener completas las otras etapas ni de copiar el top global.

El alcance entregado es RTL y simulacion. No se genero sintesis, implementacion,
bitstream, XSA, bloque de diseno, wrapper ni aplicacion Vitis para esta captura.

Configuracion vigente del 2026-10-20: entrada de 100 MHz desde FCLK_CLK0 del Zynq.
Defaults VHDL, script y XPR existente en 100 MHz. El baud sigue en 921600;
para un AXI UART Lite a 115200 habra que igualar los baud al integrar el enlace.
Si Vivado estaba abierto, actualizar tambien la configuracion en memoria:

```tcl
set_property generic {CLK_FREQ_HZ=100000000 UART_BAUD_RATE=921600} [get_filesets sources_1]
```

No se modificaron los 21 registros iniciales de la camara, resolucion ni formato.
Comprobacion rapida: `scripts/check_clocks.tcl` usa `tb_relojes_100.vhd`.

Constraints de camara y botones: `constraints/camara_botones_arty_z7.xdc`,
con PCLK en JA7 (MRCC) y D5 en JA3. Cargar en el proyecto abierto mediante
`scripts/add_constraints.tcl`; ver tabla y limitacion PCLK en `constraints/CABLEADO.md`.
No se asignan pines externos a FCLK ni al TX interno. El periodo PCLK es un
presupuesto; falta validar timing e implementacion. Se utiliza un solo XDC.
