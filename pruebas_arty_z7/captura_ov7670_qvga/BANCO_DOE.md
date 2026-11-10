# Banco automatizado Arty QVGA, D1 a D3

Preparacion del 10 de noviembre de 2026. La implementacion y las pruebas de
software estan realizadas. La carga de esta revision y las mediciones opticas
quedan pendientes de conectar Arty, camara y soporte. No se detecto un puerto
serie durante la preparacion.

La referencia es `Star_Tracker_DoE_FAT_Actualizado.pptx`, 26 diapositivas,
aportada en `C:/Users/alexa/OneDrive/Documentos/ChatGPT/Tesis/entrega_doe/`.
Se utilizan D1, D2 y D3, diapositivas 3 a 14. Sus niveles de ejemplo se eligen
de nuevo mediante un piloto. El archivo original no se modifica en esta fase.

## Alcance verificable

Arty Z7-10 + OV7670, 320x240, entrada YUV 4:2:2, extraccion Y8, BRAM,
STY1 de 76800 muestras y checksum. La ruta QQVGA historica permanece aparte.
El ARM recibe la imagen del PL a 921600 baudios y la entrega al USB a 115200.
Solo transferir una imagen al PC requiere unos 6,67 s. Ese tiempo no representa
latencia del detector.

**Esta variante Arty captura imagenes. Los centroides del banco se calculan
en PC.** No incluye el detector VHDL en el bitstream ni mide sus salidas.
El informe identifica `PC_OFFLINE_Y8` y deja FAT F02/RS-05 sin evaluar.
El detector VHDL existente en otros proyectos conserva su propio alcance.
No se realizan identificacion estelar, Hipparcos, actitud ni cuaterniones.

## Antes y despues

| Aspecto | Antes | Preparacion DOE1 |
|---|---|---|
| Disparo | BTN1 o comando `c` | Mismo disparo, secuenciado desde PC |
| Sensor | ROM de 21 registros, COM8=8F automatico | Misma ROM al iniciar; lectura SCCB y ajuste posterior |
| Exposicion/ganancia | Sin mando PC | Codigos AEC y AGC con lectura de confirmacion |
| Automatismos | AEC/AGC/AWB activos | Se congelan los tres; se desactiva extension nocturna |
| Patrones | Generador G5 de cielo, vista sintetica QQVGA | Patrones de ensayo nativos 2560x1440, separados del generador de cielo |
| Evidencia | RAW/PNG de capturas | RAW, PNG, UART original, comandos, patrones, registros, JSON/CSV e informe |
| Criterio visual | Sin registro del ensayo | 30 fichas D1, seleccion y justificacion humanas |

Impacto en hardware: `rtl/captura_uart_top.vhd` arbitra la inicializacion y el
nuevo `rtl/sccb_runtime_bridge.vhd` sobre el maestro SCCB existente. La conexion
EMIO de 64 bits ya estaba disponible. No cambian pines, XDC, clocks, resolucion,
capturador, BRAM, formato UART ni la ROM inicial. Se conservan
`frame_uart_dump` e `i2c_master`.

El puente solo acepta operaciones cuando la inicializacion termino y la captura
esta en reposo. Una lectura escribe primero la direccion del registro, hace STOP
y luego lee un byte con direccion SCCB 0x43. NACK o indisponibilidad detienen el
ensayo. Tras timeout o error de captura se conserva la evidencia y se requiere
revisar/reiniciar la corrida. No hay reintentos silenciosos.

## Arranque cuando el soporte este listo

Desde la raiz del repositorio:

```powershell
./pruebas_arty_z7/captura_ov7670_qvga/scripts/banco_doe.ps1 -Preflight
./pruebas_arty_z7/captura_ov7670_qvga/scripts/banco_doe.ps1 -Load -Port auto
```

El primer comando verifica dependencias y hashes sin tocar la placa. El segundo
inicia hw_server si hace falta, carga BIT/ELF por JTAG y abre el servidor del banco.
Si hay varios puertos se elige el del Arty explicitamente, por ejemplo `-Port COM3`.
Cerrar primero el terminal serie de Vitis. `-Python` permite indicar otro Python
con numpy, Pillow y pyserial. La preparacion local usa el runtime de Codex y
pyserial 3.5 en `build/python_deps/`.

Panel del operador: `http://127.0.0.1:8765/`.
Patron del G5: `http://127.0.0.1:8765/patron`.
El servidor escucha solo en loopback. La ventana del patron va al G5 y se activa
su boton de pantalla completa. Se comprueba tamano fisico del viewport, DPR,
visibilidad y confirmacion del patron antes y despues de cada captura. Cambios
de pantalla durante una toma invalidan esa adquisicion. No se acepta una pagina
oculta ni un patron redimensionado.

Alexander conecta el montaje, comprueba cableado, fija la distancia real,
registra refresco y entorno, deja brillo del monitor en 0 y desactiva HDR,
brillo adaptativo y filtros de color. El programa no puede accionar la lente ni
los controles OSD. El enfoque tiene una pausa con imagen de prueba y un boton
para pedir otra vista. Una vez confirmado, foco, pose, iluminacion y monitor
deben permanecer fijos. Si solo hay una pantalla, volver al patron al confirmar
las pausas. Codex puede operar los controles del banco cuando se solicite iniciar.

## Secuencia preparada

1. Disparo inicial para configurar la camara y revisar enfoque. Registro PID/VER
   y del perfil automatico. Congelacion de AEC, AGC y AWB, con ganancias de color
   retenidas. Desactivacion de COM11[7] para evitar extension nocturna del periodo.
2. Negro y respuesta RGB->Y inicial: niveles 0,16,32,64,96,128,160,192,224,240,255,
   tres imagenes por nivel. Se guarda la imagen completa y se mide una zona central
   de 30x30 pixeles. El ruido temporal se mide con las tres imagenes negras.
3. Piloto con ganancia codificada 0 y AEC alrededor del valor automatico,
   limitado a 1..510. Si no hay una fuente aislada sin saturacion digital, se
   detiene para revisar el banco. Los numeros representan codigos, no ms ni dB.
4. D1: tres codigos AEC alrededor del piloto y dos codigos AGC (0 y 16),
   cinco imagenes por condicion. El orden de las seis condiciones se aleatoriza
   con semilla registrada. La escena usa un disco de 8 pixeles del monitor.
5. Pausa D1: Alexander registra por imagen si esta completa, si distingue el
   punto y si reconoce el contorno. Selecciona C01..C06 y justifica la consistencia
   de la serie. No se prellenan sus decisiones. La seleccion debe conservar margen
   digital: ninguna de sus cinco imagenes puede alcanzar Y>=250.
6. Repeticion completa de negro y respuesta con el perfil D1 seleccionado.
   El umbral se fija una sola vez para D2/D3 a
   `ceil(max(p99.9 negro) + max(5, 5*sigma temporal media))`.
   Falta de contraste, respuesta no monotona con tolerancia de 2 DN o un umbral
   excesivo detienen el ensayo. Este criterio es provisional y queda registrado.
7. Geometria local: nueve posiciones en una grilla de +/-60 pixeles del monitor,
   tres imagenes cada una. Se ajusta una transformacion afin con seis posiciones
   y se comprueba con otras tres. Un error de comprobacion mayor de 1 pixel detiene
   el proceso. El mapa admite inversiones de ejes y escalas diferentes.
8. D2: discos de 4,8,12 pixeles del monitor, centro y +50 pixeles horizontales,
   cinco capturas por fila. Se miden centroide Y ponderado de componentes
   8-conectados, area y FWHM interpolada. El tamano elegido debe dar una deteccion
   valida en sus diez imagenes, sin banderas ni margen de saturacion agotado.
   Entre los elegibles se escoge la menor dispersion temporal radial en PC.
9. D3: cinco discos en fila, con separaciones entre centros de 8,16,24 pixeles
   del monitor y ruido solicitado sigma=0 u 8 DN RGB. Cinco capturas por fila.
   El perfil, el umbral y el tamano permanecen fijos. La puerta de asociacion se
   fija antes de D3 usando la escala medida y queda en el manifiesto.
10. Informe con asociaciones correctas/esperadas, fuentes fusionadas, omisiones,
    falsas y dispersion. Fin de la corrida, sin ejecutar D4/D5.

Son 90 imagenes D1-D3, mas las adquisiciones adicionales de calibracion,
geometria, piloto y enfoque. El total real queda en el manifiesto y los archivos.
Cinco imagenes por condicion constituyen caracterizacion inicial. No fijan por
si solas una poblacion suficiente para aprobar un FAT o una probabilidad de exito.

## Interpretacion de negro, brillo y referencia

RGB=0 y RGB=255 son extremos digitales del estimulo. Y es una salida del ISP de
8 bits. Ni Y negro tiene por que ser 0, ni el blanco capturado tiene por que ser
255. La funcion `response_curve` registra la respuesta observada con ajustes
congelados y su dispersion. No se convierte a luminancia absoluta, fotones o
magnitudes astronomicas. El G5 da una referencia de posiciones y codigos de
entrada reproducibles, cuya luminancia fisica no se mide aqui.

El limite Y>=250 es un margen frente al rail digital, no una demostracion de
ausencia de saturacion interna del sensor/ISP. Los niveles superiores de la curva
deben inspeccionarse al interpretar una posible meseta. El informe conserva las
imagenes originales para esa evaluacion.

El ruido sigma=8 es ruido digital de escena, con semilla fija por condicion;
las cinco imagenes repiten el mismo patron. Al sumarlo sobre negro y recortar
a [0,255], cambian su media y desviacion efectivas. Se registran ambas, ademas
de sigma antes del recorte. No equivale a inyectar ruido gaussiano en el sensor.
Los discos que se solapan geometricamente llevan `overlap_requested=true`.

El mapa pantalla-camara es empirico, obtenido con otros frames y posiciones
reservadas para comprobacion. Su error se informa. No acredita una referencia
metrologica independiente con incertidumbre suficiente para RS-05 (0,2 px).
Una cruz sobre la imagen tampoco acredita exactitud. La dispersion temporal
no mide sesgo. Las separaciones y diametros en monitor y camara quedan separados.

El generador de cielo existente conserva su estado sintetico QQVGA y no se usa
como referencia optica calibrada para estas pruebas. Los patrones D1-D3 se
generan directamente para el monitor nativo, sin catalogos ni estrellas HIP.

## Archivos y continuidad

Cada corrida crea `build/ensayos_doe/FECHA_HORA/` y nunca reutiliza una carpeta.
Incluye `manifest.json`, `state.json`, `commands.jsonl`, `uart.bin`, PNG/RAW,
patrones PNG con JSON, `visual_D1.json`, curvas inicial/final, `geometry.json`,
`measurements.json`, `measurements.csv`, `summaries.json` y `report.html`.
El informe superpone referencias empiricas y centroides PC en capas SVG sobre
la imagen original. No altera los PNG/RAW. Cada captura tiene checksum de
transporte y SHA-256. Los registros se releen al terminar cada serie; cambios
invalidan la corrida. El manifiesto registra hashes de RTL, ARM, BIT y ELF.

El arranque comprueba `build/diagnostico/resultados/doe_release.json`. Si cambian
fuentes o archivos de carga, se exige reconstruir/verificar y sellar de nuevo.
BIT/XSA/ELF y el workspace Vitis siguen siendo salidas locales regenerables.
El respaldo anterior a DOE1 esta en `build/antes_banco_doe_20261110/`.

Para retomar en otra maquina: sincronizar Git, reconstruir con Vivado/Vitis,
instalar dependencias PC, ejecutar las verificaciones y sellar la entrega.
No asumir que los archivos de `build/` viajan por Git.

## Verificacion realizada

- XSim global QVGA: dos frames, todos los bytes Y, checksum, 21 registros,
  botones y reset. XCLK de comportamiento solo en este testbench.
- XSim del puente runtime: escritura, puntero+lectura, rechazo sin disponibilidad,
  solicitud sostenida sin repeticion y NACK. Regresion del maestro SCCB con
  lectura de bits, ACK demorado y NACK. La prueba integrada del top verifica
  la pagina EMIO, escritura y lectura SCCB reales en el modelo, sin alterar el
  diagnostico de las dos imagenes QVGA. Son cambios de testbench/simulacion.
- Vivado 2025.2: bitstream generado, WNS +2,727 ns, WHS +0,043 ns, TNS/THS cero.
  536 LUT, 707 registros, 24/60 BRAM36, 1 DSP. Persisten 20 avisos TIMING-18 por
  retardos externos no caracterizados. No se inventaron restricciones para quitarlos.
- Vitis: plataforma y aplicacion ARM compiladas. Verificacion de independencia
  comprueba coincidencia de XSA/BIT/ELF, PS init y fuentes ARM con el workspace.
- Pruebas Python: receptor corrupto/truncado, perfiles de estrella conocidos,
  componentes, fusiones/omisiones/falsas, mapa afin, ruido reproducible, validacion
  de pantalla y corrida completa D1-D3 sintetica con 30 imagenes por etapa.
- Navegador Chrome sin ventana visible: 30 fichas, rechazo de formulario incompleto,
  aceptacion de ficha completa y canvas 2560x1440 a pantalla completa. Cero errores JS.

Los logs y capturas de verificacion estan en `build/banco_doe_*`. Las pruebas
sinteticas se identifican como tales y sus carpetas temporales se eliminan al
terminar. Estas verificaciones no son una toma fisica de la revision DOE1.

Comandos reproducibles:

```powershell
& 'C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat' -mode batch -nojournal -nolog -source pruebas_arty_z7/captura_ov7670_qvga/scripts/simulate_qvga.tcl
& 'C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat' -mode batch -nojournal -nolog -source pruebas_arty_z7/captura_ov7670_qvga/scripts/simulate_runtime.tcl
& 'C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat' -mode batch -nojournal -nolog -source pruebas_arty_z7/captura_ov7670_qvga/scripts/simulate_top_runtime.tcl
& 'C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat' -mode batch -nojournal -nolog -source pruebas_arty_z7/captura_ov7670_qvga/scripts/simulate_sccb.tcl
& 'C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat' -mode batch -nojournal -nolog -source pruebas_arty_z7/captura_ov7670_qvga/scripts/build_diagnostic.tcl
& 'C:/AMDDesignTools/2025.2/Vitis/bin/vitis.bat' -s pruebas_arty_z7/captura_ov7670_qvga/scripts/update_vitis.py
# Con un Python apropiado, conservar logs y luego:
python -m unittest discover -s pruebas_arty_z7/captura_ov7670_qvga/pc -p 'test*.py' -v
python pruebas_arty_z7/captura_ov7670_qvga/scripts/seal_doe_delivery.py
```

Para repetir navegador, iniciar `pc/browser_ui_fixture.py` y ejecutar
`scripts/test_banco_browser.cjs` con Node y la ruta al paquete Playwright.
La fixture no abre puertos serie.

Referencias de registros: [datasheet OmniVision OV7670 v1.01](https://www.olimex.com/Products/Components/Camera/CAMERA-OV7670/resources/OV7670.pdf)
y [guia de implementacion OmniVision v1.0](https://web.mit.edu/6.111/www/f2017/tools/OV7670app.pdf).
AEC se distribuye en 07/10/04; la ganancia usa GAIN y los bits altos de VREF.
Se conservan los bits ajenos a esos campos. No se asignan milisegundos a AEC
sin medir/verificar relojes, tiempos internos y parametros efectivos.
