# QVGA y primera calibracion: una estrella aislada

## Estado y antes/despues

Solicitud del usuario: trabajar ahora en QVGA y caracterizar el tamano de una
estrella para el centroide, antes de calibrar geometria completa de la lente.
El objetivo Nexys sigue en QQVGA; esta revision afecta solo la prueba Arty.

| Parametro | QQVGA validado | Nueva prueba QVGA |
|---|---|---|
| Resolucion Y | 160x120 | 320x240 |
| Pixeles/payload | 19200 | 76800 |
| Bytes YUV por linea | 320 | 640 |
| Direcciones BRAM | 15 bits | 17 bits |
| Diagnostico de pixeles | 16 bits | 17 bits |
| Paquete STY1 | 19213 bytes | 76813 bytes |

Backup recuperable `../captura_ov7670/antes_qvga_20261021/`: RTL, TB, scripts, PC, constraints,
fuentes ARM, PS init y resultados BIT/XSA/ELF de la version QQVGA. Los originales
del proyecto principal Nexys no se modifican. Conservar este backup completo.

La ROM usa QVGA /2 (COM14=19, DCWCTR=11, PCLK_DIV=F1), segun la
[guia OmniVision, tabla 2-2](https://www.haoyuelectronics.com/Attachment/OV7670%20%2B%20AL422B%28FIFO%29%20Camera%20Module%28V2.0%29/OV7670%20Implementation%20Guide%20%28V1.0%29.pdf).
Ventana H=168..24 con wrap 784, V=12..492, como referencia del
[driver original Linux](https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov7670.c).
Conserva YUV422, XCLK 24 MHz, BRAM antes del consumidor y UART de captura.

El snapshot GPIO conserva los campos anteriores excepto min_bytes que ocupa
22:12 (11 bits, satura a 2047); bit 23 contiene pixels[16]. Los bits 51:36
contienen pixels[15:0]. Es imprescindible usar el ARM actualizado: antes el
contador saturaba en 65535. Receptor PC y cabecera ARM exigen 320x240/76800.

## Primera prueba: tamano de estrella, no un diametro universal

Orden acordado: primero obtener una imagen QVGA real. Despues definir y ejecutar
los ensayos de parametros de diseno. Esta propuesta no significa que ya se haya
medido exposicion, establecido un diametro optimo o realizado el barrido.

Usar un solo punto brillante sobre fondo oscuro, camara y escena inmoviles,
en el centro del cuadro. Capturar PNG original; no medir una captura de pantalla
ampliada ni una imagen redimensionada. Si se usa un monitor, el diametro del
punto en pixeles del monitor NO es el diametro que ve la camara.

Ensayar FWHM aproximados de 1.5, 2, 2.5, 3 y 4 pixeles de camara, manteniendo
fijos exposicion, ganancia y brillo de la escena durante cada comparacion.
2-3 pixeles FWHM es solo una banda inicial de ensayo, no un optimo demostrado.
FWHM es el ancho a mitad de altura sobre el fondo; no equivale al numero de
pixeles por encima del umbral ni al diametro total visible. La huella completa
puede cubrir 3x3, 5x5 o mas pixeles aunque FWHM sea pequeno.

Referencias tecnicas: [informe NASA sobre muestreo y defocus](https://ntrs.nasa.gov/api/citations/20220007061/downloads/TM-20220007061.pdf)
y [estudio original de centroides Gaussianos](https://pmc.ncbi.nlm.nih.gov/articles/PMC6163372/).
No existe un unico tamano optimo independiente del ruido, senal y algoritmo.

Por cada ajuste, guardar 20-30 frames sin mover nada y registrar:

- Fondo y variacion del fondo; pico de la estrella y pixeles saturados.
- FWHM horizontal/vertical y area del componente al umbral utilizado.
- Centroide ponderado por Y con componente 8-conectado; repetibilidad en X/Y.
- Exposicion real, ganancia, foco, brillo y geometria de la escena.

No saturar: el perfil recortado pierde informacion. Como margen de exploracion
puede mantenerse el pico por debajo de 240-250 DN, verificando tambien contraste.
Es un criterio de ensayo, no una calibracion radiometrica. La imagen Y tiene
gamma/ISP: los DN no representan directamente fotones ni magnitud astronomica.

El optimo provisional sera el ajuste que conserve deteccion, no sature y minimice
la dispersion del centroide. La dispersion temporal NO mide sesgo: para evaluar
error subpixel hay que mover la estrella una cantidad conocida y comparar.
No cambiar tamano, foco y exposicion simultaneamente. Una mancha grande no crea
ruido: reparte la luz, integra mas fondo y puede empeorar el contraste.

Herramienta preparada: `pc/medir_estrella.py imagen1.png imagen2.png ...`.
`--center X Y --radius 6 --threshold 45` fija una ROI comun. Sin `--center`
busca la region mas brillante; usarlo solo con una estrella aislada.
Genera `pc/calibracion/estrellas.csv` y `resumen.json` con FWHM interpolado,
centroide y banderas de saturacion, fondo insuficiente y ROI truncada.
Es analisis auxiliar en PC; no reemplaza el detector VHDL ni certifica Q8.8.
El SNR de contraste pico/fondo no sustituye una caracterizacion del detector.

## Exposicion: el paso necesario para barridos comparables

La ROM actual mantiene COM8=8F: AEC y AGC activos. Por ello una captura correcta
NO demuestra exposicion conocida o fija. Esta revision QVGA no agrega todavia
un mando de exposicion manual ni lectura de registros desde COM3.
El siguiente control necesario es leer/congelar AEC/AGC o fijar ambos por SCCB.

Segun la guia OmniVision, se desactiva AEC con COM8[0]=0 y AGC con COM8[2]=0;
AEC[15:0]={AECHH[5:0],AECH[7:0],COM1[1:0]}, registros 07/10/04.
No basta escribir solo AECH si se quiere una exposicion reproducible completa.

    T_exp = AEC * T_fila_interna
    T_fila_interna = 2 * (784 + dummy_pixels) / f_INT_CLK

Hay que verificar CLKRC/PLL y dummy pixels antes de convertir a milisegundos.
No usar duracion UART, 1/FPS ni periodo HREF QVGA directamente como exposicion:
la unidad AEC corresponde a fila interna VGA, antes de reducir resolucion.
Empezar con barridos cercanos a 1, 2, 5, 10 y 20 ms solo tras esa conversion.
Para la primera prueba estatica puede usarse auto y registrar resultados como
exploratorios, sin atribuir un tiempo de exposicion ni comparar fotometria.

## Movimiento angular y blur

Primero medir estrella quieta; despues fijar el ajuste y aumentar movimiento
con velocidad conocida. Para centro del campo, giro pequeno de yaw/pitch:

    arrastre_px ~= f_px * omega_rad_s * T_exp_s
    omega_limite_deg_s ~= (180/pi) * b_px / (f_px * T_exp_s)

El presupuesto inicial b=0.5 pixeles es una decision de ensayo, no una frontera
universal. Con FOV horizontal SUPUESTO de 25 grados y ancho 320, fx~=721.7 px:
1 ms ->39.7 deg/s; 5 ms ->7.94; 10 ms ->3.97; 20 ms ->1.98.
Son ejemplos nominales; FOV y exposicion de esta camara aun no se han medido.
`pc/limite_blur.py --fov-deg 25 --exposure-ms 1 5 10 20` reproduce el modelo.
Usar `--focal-px` con fx/fy calibrado para reemplazar el FOV supuesto.

La relacion focal/velocidad/exposicion sigue el modelo del
[estudio original de exposicion y dinamica](https://pmc.ncbi.nlm.nih.gov/articles/PMC4003974/).
La OV7670 usa rolling shutter: lineas distintas se exponen en instantes distintos.
El limite por arrastre de un punto no garantiza geometria rigida de todo el campo,
ni identificacion correcta. En bordes, roll y con distorsion cambian los factores.
Usar un soporte o desplazamiento de patron con velocidad medida; mover la camara
con la mano no determina una velocidad angular maxima cuantificable.

La calibracion completa de lente/FOV puede hacerse despues con tablero o posiciones
angulares conocidas. Una sola estrella fija no permite obtener fx/fy ni distorsion.
La prueba con monitor caracteriza el banco; no acredita sensibilidad al cielo real.

## Verificacion

`scripts/simulate_qvga.tcl`: dos frames completos, payload, checksum, >65535
pixeles, SCCB, blanking, botones/reset. Sustituye el MMCM por arquitectura de
reloj SOLO de simulacion, no incluida en fuentes.tcl ni en el bitstream. El
generador XCLK sintetizable no se cambia; su regresion UNISIM anterior se conserva.
Las pruebas C y PC verifican paquetes y perfiles sinteticos conocidos.
Resultados de implementacion y prueba fisica se agregan al terminar.

## Resultado QVGA efectivamente obtenido

- XSim: PASS_QVGA, 75.283140137 ms simulados, dos paquetes completos y contadores
  correctos por encima de 65535. Reloj XCLK de comportamiento SOLO en esta prueba.
- Implementacion: PASS_BUILD_DIAGNOSTICO. WNS +2.922 ns, WHS +0.073 ns,
  TNS/THS cero. 466 LUT, 24/60 BRAM36, 1 DSP. CDC sin warning/critical;
  permanecen recomendaciones DSP y avisos de E/S previamente documentados.
- ARM recompilado: text=38157, data=3088, bss=165544. Parser C QVGA PASS.
- PC: nueve tests PASS (seis de paquete/PNG y tres del medidor de estrella).
- Se cargaron BIT y ELF por JTAG y se recibieron DOS imagenes reales sin reset:

```text
ARM captura: OK lineas=240 bytes_min=640 bytes_max=640 pixeles=76800 primera_linea_mala=ninguna
OK imagen 76800 checksum; esperando BTN1
```

Evidencia: `build/load_capture.log`, `build/physical_qvga_console.log`,
`build/physical_qvga/report.json`, `uart.bin`, PNG y RAW. Nombres de capturas:
`captura_20261021_133216_576762` y `captura_20261021_133224_275836`.
El reporte termina en result=0, dos imagenes y cero errores del receptor.

Estas tomas NO caracterizan una estrella: primera imagen rango 0..1 DN y ningun
pixel >=45; segunda 0..49 DN y solo dos pixeles >=45, sin una estrella aislada
evaluable. Cero pixeles saturados en ambas. Ver `image_statistics.json`.
Esto acredita formato, geometria y transmision, no optica, exposicion ni centroide.

Queda cargada la version QVGA. BTN1 y receptor PC mantienen el mismo uso; el
receptor actualizado guarda por defecto en `pc/capturas_qvga/`. COM3 queda libre.
La exposicion/ganancia siguen automaticas, sin barrido de calibracion ejecutado.
