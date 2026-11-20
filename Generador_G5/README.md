# Simulador de cielo para Samsung Odyssey G5

## Patrón sintético fijo — ensayo inicial (19/11/2026)

Abre **[patron_sintetico.html](patron_sintetico.html)** para el ensayo actual.
Muestra 48 fuentes idénticas en 8 columnas × 6 filas: una posición aleatoria
dentro de cada sector, con márgenes. La semilla inicial `20261119` permite
reproducir las posiciones. No hay animación ni regeneración automática.
La cuadrícula organiza la distribución; las fuentes no están alineadas en ella.

Cada fuente es una gaussiana circular truncada, con diámetro de soporte inicial
24 px, sigma 4,8 px y pico 255 sobre fondo 0. Tamaño y brillo se ajustan juntos
para toda la familia y conservan las posiciones. Estos valores son propuestas
para probar con la cámara, no parámetros calibrados.

La página selecciona un recorte digital 4:3 con ocho centros. Permite moverlo
y cambiar su ancho sobre el mismo patrón. Ese recorte **no modela la óptica,
la curvatura del G5 ni el FOV real**, y el conteo no equivale a ocho detecciones.
El encuadre físico y la exposición deberán verificarse con la cámara. No se
cambia la resolución ni ningún archivo RTL del proyecto.

Pulsa **Mostrar patrón en pantalla completa** (o F) en el G5: se muestra solo
la imagen, sin sectores, números, recorte ni controles. Esc vuelve a los controles.
Si el navegador rechaza la API de pantalla completa, la presentación ocupa la
ventana igualmente; F11 permite ocultar la barra del navegador.
El PNG exportado también contiene exclusivamente el patrón nativo 2560 × 1440.
JSON y CSV guardan las coordenadas, los identificadores P01–P48 y los parámetros
del mismo estado. El origen está arriba a la izquierda; x crece a la derecha,
y hacia abajo. JSON conserva también el recorte seleccionado.

Estas posiciones forman el **patrón estelar de referencia** del ensayo; no
requieren Hipparcos ni constelaciones. El matching queda para el siguiente paso.
Este cambio corresponde a una herramienta de estímulo en PC; no valida el
determinismo temporal de la arquitectura FPGA ni modifica el hardware.

Generación reproducible y comprobación desde esta carpeta:

```powershell
node tests/synthetic_pattern_checks.mjs
node tools/export_synthetic_pattern.mjs --out patrones/sintetico48_s20261119
```

El exportador exige una carpeta nueva y escribe PNG, JSON y CSV con SHA-256
en un manifiesto. Admite `--seed`, `--diameter` y `--level`.

Referencia inicial guardada en `patrones/sintetico48_s20261119/`.
El [informe geométrico](../Documentacion/Geometria_patron/Informe_geometrico.pdf)
deriva pantalla → XYZ → píxel esperado. Con 250 mm y el FOV horizontal supuesto
de 25° solo entran P21 y P28; los ocho del recorte digital no representan una
captura óptica de ocho. El FOV de la lente exacta todavía no está sustentado.
Comprobación de software: 48 fuentes e identificadores únicos, posiciones
reproducibles, separación mayor que el diámetro máximo, ocho centros en el
recorte inicial `(904, 258, 912, 684)` y conservación del patrón al moverlo.
La interfaz, la presentación sin guías y la salida PNG se revisaron en Chrome.

## Simulador astronómico anterior

Banco óptico auxiliar para el G5 LS27AG550ELXPE. Funciona offline abriendo `index.html`;
no necesita instalar paquetes. La cámara permanece fija y los controles rotan el
cielo tridimensional antes de proyectarlo sobre el panel QHD. Estima una captura
OV7670 QQVGA. El estado cero reproduce `orion_25cm_m5_v1`; las imágenes y tablas
anteriores permanecen conservadas. Estado: **SIMULATED_UNCALIBRATED**;
no implica validación física, fotométrica ni RTL.

## Manual breve

1. Abre `index.html` en Chrome o Edge y mueve la ventana al G5.
2. Usa resolución nativa `2560 × 1440`, SDR y una configuración fija de brillo/color.
   Desactiva cambios automáticos de brillo/color. Pulsa `F` para pantalla completa.
3. Parte de distancia nominal 25 cm y FOV horizontal nominal 25°. El bloque de configuración
   permite cambiarlos, además de distorsión y parámetros sintéticos de fuente.
4. Ajusta los tres giros del cielo: horizontal, vertical y sobre la vista. Se aplica la base
   `cameraBasis` a las direcciones del cielo; yaw/pitch ±75°, roll ±180°, paso 0.1°.
   Estos ángulos describen el estímulo solicitado: no se estima actitud.
5. **Las estrellas del G5 se mueven y se recalcula la vista estimada; la cámara permanece
   en pose cero y su huella no gira.** La cantidad de estrellas visibles puede cambiar.
6. Activa líneas, nombres de constelaciones o HIP si quieres orientarte. Son guías en
   otra capa y no forman parte de la imagen de catálogo.
7. Pulsa `M` para retirar menú y todas las guías. Otra pulsación los devuelve.
    La aplicación no usa arrastre ni rueda del mouse para navegar por el cielo.
8. Exporta JSON, CSV y PNG del mismo estado. Mantén el cielo estable al capturar y asocia
   la captura física con su `stateId`. El asentamiento y disparo no están automatizados.

La aplicación sigue funcionando con `file://`. Si el navegador impide guardar preferencias,
permite trabajar y exportarlas sin almacenamiento persistente. La prueba automatizada del navegador
puede usar un servidor temporal en loopback; no es necesario para el uso normal.

### Vista general del sector

El botón **Ver sector completo**, junto a la previsualización, muestra todo el patrón
actual con proporción 16:9. Es una vista de consulta: bloquea temporalmente los giros,
parámetros y reinicio del cielo. **Volver a vista de cámara** recupera el mismo encuadre
QQVGA y habilita los controles. No cambia distancia, FOV, configuración ni exportaciones;
no simula una cámara distinta. El botón de pantalla completa del navegador sigue separado.

## Qué cambia cada control

| Grupo | Imagen del G5 | Vista OV7670 |
|---|---|---|
| Giros del cielo | Reproyectan las estrellas conservando HIP | Cambia con el patrón; cámara inmóvil |
| Distancia / FOV / k1-k2 | Distancia cambia proyección; FOV y lente no predeforman el patrón | Se recalcula el modelo de observación |
| Líneas, nombres, HIP y FOV | Solo capa de guías | No aparecen |
| M | Oculta o muestra menú y guías, sin cambiar la textura | No cambia el frame |
| F | Permanece fija | No cambia el frame; cambia la presentación en pantalla completa |

La proyección del panel es geométrica, sin predeformación de lente. k1/k2 actúan en la vista
estimada. `rotating_scene.js` rota direcciones del catálogo y conserva tanto el rayo base
como el rayo del estado y el rayo del panel. Las preferencias de cámara móvil se ignoran.

Las figuras de constelaciones sirven para reconocimiento humano. No constituyen identificación
estelar ni estimación de actitud del FPGA. El futuro identificador trabajará con estrellas y
direcciones de catálogo, no con estos dibujos.

## Valores iniciales y calibración pendiente

| Parámetro | Inicial | Significado |
|---|---:|---|
| Patrón digital G5 | 2560 × 1440 | Buffer nativo, relación 16:9 preservada |
| Ancho/alto activo | 596.736 × 335.664 mm | Valores nominales; confirmar con el panel |
| Curvatura horizontal | 1000 mm | Modelo cilíndrico 1000R, sin curva vertical |
| Distancia | 25 cm | Centro óptico al centro del panel; hipótesis de diseño |
| FOV horizontal / vertical | 25° / 18.881° | Nominal; vertical calculado para sensor 4:3 |
| Región / magnitud límite | Orión, 83.8°/−5.4°, Vmag ≤ 5.0 | 294 estrellas en estado cero; otros estados pueden cambiar ese conteo |
| Captura estimada | 160 × 120, Y8 | Una matriz nueva por actualización |
| Claridad | 100% | Elección visual provisional para superar el umbral sintético |
| Radio luminoso | 8 px G5 | Escala gaussiana: sigma = radio/2.5 |
| PSF de cámara | sigma 0.55 px | Desenfoque gaussiano provisional de la vista |
| Negro / pico RGB | 0 / 255 | Extremos digitales del patrón |
| k1 / k2 | 0 / 0 | No se modela distorsión medida |

**Por qué 100%:** el barrido QQVGA sintético mostró más componentes útiles con este nivel;
se conserva el orden de brillo, pero no es una calibración fotométrica. Con claridad C,
gamma = 0.60 − 0.0045 C y el nivel del centro del punto es:

```text
flujo_relativo = clamp(10^(-0.4 * (Vmag + 1.5)), 0, 1)
nivel = negro + (pico - negro) * flujo_relativo^gamma
```

La claridad 100% realza estrellas débiles sin volverlas todas blancas; también reduce el
contraste entre magnitudes. Estos parámetros se registran junto con cada imagen y CSV.

Para calibrar, fija exposición, ganancia, balance y ajustes del monitor. Captura un fondo negro
y mide su media y ruido; si la cámara entrega Y=10 para RGB=0, ese 10 es un fondo capturado,
no un motivo para poner el negro del monitor en RGB=10. Mide después varios niveles y estrellas
sin saturación, usando señal integrada sobre el fondo, no solo el píxel máximo. Guarda esas
capturas para obtener la respuesta monitor→cámara. Una calibración futura requerirá
otra configuración versionada; no mezclar referencias de configuraciones diferentes.

La vista puede mostrar estrellas más tenues que el patrón ampliado: integra áreas del panel en
solo 160 × 120 muestras. Los conteos indican centros geométricos dentro del FOV, **no detecciones
garantizadas**; el umbral, el ruido y la exposición real decidirán cuáles detecta el FPGA.

## Geometría y límites

Se usa el centro de pantalla como origen, cámara en `(0,0,d)`, mirando inicialmente hacia −Z:

```text
x = R sin(alpha)
z = R (1 - cos(alpha))
y = coordenada vertical plana
```

El ancho nominal se interpreta como longitud de arco; comprobar esa convención al medir.
Para generar esta imagen, cada dirección de catálogo intersectó el cilindro usando la
referencia del estado. El estado cero usa 25 cm, pose cero y k1/k2=0. Una rotación nueva
reproyecta todas las fuentes seleccionadas, incluidas las que entran al campo desde fuera.

La cámara virtual observa esos puntos físicos desde la distancia fijada. La vista utiliza
proyección inversa por píxel, 4 × 4 submuestras, muestreo bilineal de la textura Y8 y una PSF
gaussiana normalizada. El buffer QQVGA se reconstruye al cambiar el patrón. Su mapa de
rayos se reutiliza si la configuración física virtual no cambia.

La cámara permanece fija y centrada. El marco base tiene +X derecha, +Y arriba y −Z hacia
la pantalla. La rotación activa se aplica al cielo, con orden y signos de `cameraBasis`.
No equivale a girar un PNG plano. Cambiar distancia/FOV crea otra configuración y referencia.

El FOV sobre el cilindro puede tener bordes curvos. Se recorta al panel; si el encuadre contiene
todo el monitor, el contorno puede quedar fuera y desaparecer. El porcentaje de panel en la
captura sigue indicando la cobertura. La tarjeta de dimensiones muestra la huella ideal
solo cuando está completa.

A 25° y pose central, k=0, la huella física es aproximadamente:

| Distancia | Huella sobre el panel |
|---|---|
| 25 cm | 11.0 × 8.3 cm |

Pendiente medir: distancia, FOV efectivo, área/arco del panel, distorsión, PSF, exposición,
respuesta fotométrica y alineación fija del centro óptico. No se modelan
desplazamientos laterales de cámara, tangencial p1/p2, foco, respuesta angular del LCD,
ruido, PWM, refresco ni rolling shutter. La validación actual es del software, no del banco físico.

## Calidad digital

El patrón mantiene un buffer Y8 de 2560 × 1440; las guías tienen un canvas separado.
En ventanas de otra relación de aspecto se usan márgenes negros, sin estirar la imagen.
La correspondencia 1:1 se estima con dimensiones CSS y devicePixelRatio; no puede certificar
el escalador del sistema, la señal de vídeo ni los píxeles del panel. Confirmar con la
resolución nativa del G5. Zoom del navegador y escalado de Windows al 100%
son un punto de partida sencillo, no una medición óptica.

La resolución QHD no convierte la previsualización QQVGA en una captura de mayor resolución.
La frecuencia y el brillo del monitor deben mantenerse fijos durante la calibración;
la interacción entre refresco/PWM y exposición requiere comprobación física.

## Catálogos y atribución

Hipparcos Main Catalogue I/239: 15 537 estrellas con Vmag <= 7, identificador HIP,
coordenadas ICRS en época J1991.25 y magnitud Johnson V.
Crédito: **ESA (1997), The Hipparcos and Tycho Catalogues**.

- [Catálogo ESA](https://www.cosmos.esa.int/web/hipparcos/catalogues)
- [Distribución HEASARC](https://heasarc.gsfc.nasa.gov/W3Browse/all/hipparcos.html)
- [Especificaciones G5](https://www.samsung.com/pe/monitors/gaming/odyssey-g5-g55a-27-inch-165hz-1ms-ls27ag550elxpe/)

Las 88 constelaciones proceden del conjunto Western de Stellarium, revisión
`92df9e4c48c7a3b21d4b0cfc6ce088dd8ce2f2df`. Se usan polilíneas HIP y nombres tradicionales
latinos/internacionales. Todas sus estrellas están presentes en el catálogo local.
Se conservan las dos partes de Serpens bajo un código IAU y se normaliza el estilo fino de líneas.
No se importan ilustraciones ni código de renderizado.

Datos derivados bajo CC BY-SA, crédito al equipo de Stellarium. La declaración original no
especifica versión. Ver `data/CONSTELLATIONS_LICENSE.md` para URL, revisión, hashes y atribución.
No confundir líneas tradicionales con límites oficiales IAU: los dibujos admiten variantes.

Regeneración reproducible (requiere red solo para la primera descarga):

```powershell
python Simulador_cielo_G5/tools/build_hipparcos_catalog.py
node Simulador_cielo_G5/tools/build_constellations.mjs
```

Las respuestas originales se guardan en `sim_build/catalog_cache/`, ignorado por Git.
El generador de constelaciones verifica las 88 figuras y cada referencia HIP antes de escribir.

## Configuración exportada

Exportación actual: `STAR_TRACKER_G5_ROTATING_STATE_V1`, con `stateId`, configuración,
referencia base, cámara fija, metadatos de catálogo y tabla HIP por estado. Los vectores
base, rotados y del panel se conservan por separado. El CSV y el PNG se exportan aparte.
Este contrato es diferente de las escenas V1/V3 anteriores: no alimentar con estos archivos
el generador antiguo de ROM sin adaptar y comprobar primero esa transferencia.
Estos hashes cortos FNV detectan cambios de frame; las pruebas usan SHA-256 para comparar bytes.

Se persisten giros de cielo, parámetros y guías en una clave nueva.
Las preferencias del modo configurable anterior permanecen almacenadas pero se ignoran;
no se interpretan como giros del nuevo cielo. La aplicación funciona aunque `localStorage` se bloquee.

Exportación reproducible sin navegador, desde la raíz del repositorio:

```powershell
node Simulador_cielo_G5/tools/export_rotating_scene.mjs --out carpeta_nueva --yaw 12 --pitch -6 --roll 20
```

También acepta `--config estado.json` exportado por la interfaz, `--distance-cm` y `--fov`.
Exige un directorio nuevo y no sobrescribe referencias. Produce PNG QHD, CSV HIP, vista
estimada PNG/RAW y manifiesto con SHA-256. El ejemplo `cielo_rotado_demo_20261015` conserva
309 fuentes en el panel; no es un catálogo FPGA nuevo ni una captura física.

Para el banco auxiliar ver [OV7670 y ESP32-WROOM-32](../Docs/Banco_OV7670_ESP32.md).

Comprobación del modo nuevo: `node Simulador_cielo_G5/tests/rotating_scene_checks.mjs`.
Incluye 27 estados de límites/centro, invariantes angulares, entrada de fuentes desde el
hemisferio inicialmente oculto, cámara fija, A-B-A y vaciado. `fixed_ui_checks.mjs` ahora
comprueba la interfaz de cielo rotado; `fixed_scene_checks.mjs` conserva la referencia antigua.

## Verificación

```powershell
node --check Simulador_cielo_G5/simulator.js
node --check Simulador_cielo_G5/fixed_scene.js
node --check Simulador_cielo_G5/rotating_scene.js
node --check Simulador_cielo_G5/engine.js
node --check Simulador_cielo_G5/geometry.js
node Simulador_cielo_G5/tests/geometry_checks.mjs
node Simulador_cielo_G5/tests/catalog_checks.mjs
node Simulador_cielo_G5/tests/default_scene_checks.mjs
node Simulador_cielo_G5/tests/simulator_checks.mjs
node Simulador_cielo_G5/tests/reference_catalog_checks.mjs
node Simulador_cielo_G5/tests/fixed_scene_checks.mjs
node Simulador_cielo_G5/tests/fixed_ui_checks.mjs
node Simulador_cielo_G5/tests/rotating_scene_checks.mjs
```

Las regresiones anteriores del motor conservan la comprobación de textura fija y
cámara móvil como antecedente. Las pruebas del modo nuevo comprueban cielo variable,
cámara fija y referencias por estado; el barrido de 27 estados obtuvo 7–42 centros
geométricos/FOV. No es una garantía de detección ni un barrido exhaustivo del dominio.
La interfaz tiene comprobaciones de DOM y se revisó en Chrome headless mediante file://:
controles, cámara fija, contenidos JSON/CSV/PNG y ocultación de guías. Las descargas a
disco del navegador automatizado fueron canceladas por el entorno; se verificaron los
contenidos de los Blob y la exportación a disco mediante el generador de consola.
No sustituye revisar escala, presentación y capturas en el G5 físico. No requiere
Vivado ni modifica el diseño FPGA.
