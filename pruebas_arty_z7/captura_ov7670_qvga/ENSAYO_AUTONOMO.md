# Ejecución local D1–D3, 10 de noviembre de 2026

El usuario autorizó evaluar automáticamente D1, D2 y separación D3, conservar el
enfoque actual y usar la ventana del generador escalada. No se modifica el PPT
original en esta fase. No se suben cambios ni fotografías a GitHub.

## Cambios de software PC

`pc/doe_autonomo.py` utiliza el transporte existente, sin modificar RTL ni ARM.
Conserva QVGA 320×240, YUV422 y STY1. Los centroides evaluados se calculan en PC
sobre Y8; esta ejecución no valida el detector FPGA ni su exactitud absoluta.

- D1: cinco fuentes iguales y separadas, seis perfiles de exposición/ganancia,
  cinco cuadros por condición. Se ensayan diámetros de diseño 8, 12 y 16 si el
  anterior no produce un candidato válido.
- Negro–blanco: niveles RGB 0, 64, 128, 192 y 255, tres cuadros por nivel; se
  conserva la curva RGB→Y. Son códigos digitales, no luminancia física absoluta.
- D2: fuentes aisladas, tamaños y umbral exploratorios, geometría afín local
  con posiciones reservadas para comprobar el ajuste, confirmación en cuadros
  nuevos. La repetibilidad temporal no equivale a exactitud absoluta.
- D3: separaciones de diseño 8, 16 y 24, ruido RGB 0 y 8, cinco cuadros por
  condición. Una fusión es un límite observado, no un error que deba ocultarse.

La ventana debe permanecer visible y con las mismas dimensiones durante cada
ejecución. Se registra `display_geometry` en el manifiesto: el patrón de diseño
2560×1440 se estira al viewport, con escalas X/Y independientes. Por ejemplo,
2560×1384 con DPR 1 implica sx=1 y sy=1384/1440; los tamaños indicados por el
generador son píxeles de diseño, no tamaños nativos verificados del monitor.

Cada adquisición guarda PNG y RAW originales, checksum verificado, registros,
condición, repetición y metadatos del patrón. `commands.jsonl` y `uart.bin`
conservan el control. Las decisiones se guardan en `decisions.json` y los
resultados en `measurements.json`, CSV y `report.html`.

## Incidencias observadas y límites

Una fotografía inicial correspondía al fondo de Google porque la pestaña se
había cerrado; está descartada explícitamente en su JSON. Tras abrir y conservar
la pestaña del generador se obtuvo `campo_generador_abierto.png`: cinco fuentes
detectadas, sin pico >=250. Es un piloto, no la aceptación de toda la serie D1.

Se observó `ERROR DOE SCCB 3` después de lecturas correctas. Aumentar solamente
la pausa a 0,8 s no lo eliminó. Después del error, tres lecturas del PID
respondieron sin reiniciar la placa: el fallo observado fue transitorio. El
cliente ahora reintenta hasta dos veces únicamente errores SCCB 2/3 de accesos
a registros, con pausa de 1 s y registro explícito. Las escrituras de perfil son
idempotentes y mantienen la comprobación por lectura. No se reintenta ni duplica
silenciosamente una captura fallida. La causa del fallo de control no está
establecida y no se declara reparado el hardware.

Se corrigió la invocación local de XSCT desde el controlador de recuperación:
PowerShell con rutas explícitas en vez de argumentos de `cmd` que produjeron
«La sintaxis del comando no es correcta». La recarga manual de los mismos
artefactos sí devolvió `ARM_RUNNING`; esto no prueba aún toda la recuperación
automática. No se cambiaron los artefactos BIT/ELF.

Verificación del cliente: seis pruebas pasan, incluyendo aceptación
de cinco fuentes, rechazo por fuente ausente/saturada y ventana visible escalada
con rechazo al cambiar escala u ocultarse y ejecución completa con cámara
sintética. Esta última detecta errores de integración del controlador; no
reemplaza el ensayo físico. Se corrigió un conflicto entre el atributo `d1`
heredado del controlador original y el método D1 autónomo, observado después de
completar la primera calibración física. Aquellas 15 referencias se conservan,
pero ese intento no aprobó D1. La evidencia física y las pruebas sintéticas se
mantienen separadas. Si los discos de diseño se solapan en D3, el resultado se
etiqueta `STIMULUS_OVERLAP` y no se atribuye a resolución óptica.

## Rutas de evidencia

- `build/ensayos_doe/20261110_132742_autonomo`: foto descartada y piloto correcto
  `campo_generador_abierto.png`, RAW y JSON.
- `build/ensayos_doe/20261110_134632_autonomo`: primer intento detenido por
  control, diagnóstico de lecturas y recuperación; no es un DoE aprobado.
- `build/ensayos_doe/20261110_135145_autonomo`: ejecución posterior con control
  acotado. Consultar su manifiesto y decisiones para el resultado real; la
  existencia de la carpeta no significa que D1–D3 hayan pasado.

## Cierre solicitado y entrega LAP

El usuario pidió detener las pruebas y terminar el PPT y un guion por
diapositiva. Se cerró el análisis con los datos existentes, sin fabricar el
barrido D3 que no llegó a ejecutarse.

La campaña `build/ensayos_doe/20261110_135729_autonomo` archivó 132 cuadros.
Todos los PNG coinciden con su RAW de 76 800 bytes y su SHA-256 registrado.
La primera rama completó D1 (seis perfiles por cinco cuadros), dos tamaños de
D2 en dos posiciones (20 cuadros completos), 27 cuadros geométricos y dos
curvas de referencia de 15 cuadros. Una transferencia incompleta en D2
provocó el retorno a D1. La segunda rama se interrumpió por falta de
confirmación del navegador. Los registros conservan esos fallos.

El análisis de D2 usa únicamente los 20 cuadros completos de diámetros 4 y 8
de la primera rama. La dispersión radial está entre 0,0090 y 0,0169 px de
cámara. Los RMS frente al mapa local están entre 0,0276 y 0,1296 px. Son
resultados PC y no aceptación de RS-05 del centroide FPGA.

El cierre D3 consiste en reanalizar cinco cuadros C06 del campo fijo de D1:
25/25 asociaciones, cero fusiones, omisiones y falsas aceptadas. La menor
distancia observada entre fuentes es aproximadamente 44,34 px de cámara.
Estas cinco fotos NO son independientes de D1. No se ejecutó el barrido
8/16/24 px ni ruido RGB sigma 8. No se obtuvo un límite mínimo de resolución.

El PPT nuevo es `output/LAP_20261110/Star_Tracker_D1_D5_LAP.pptx`, con 20
diapositivas editables, notas de exposición y fotos reales del montaje. D4 y
D5 incluyen metas sin atribuir resultados. El LAP traza requisitos y criterios
y limita la conformidad a la evidencia disponible. El guion y el ZIP con
originales, matrices fuente e índice acompañan el PPT. Se preservó el PPT
original. La revisión estructural y visual se realizó sobre las 20 diapositivas.

El controlador de reportes se corrigió para tolerar filas que tienen una
referencia pero aún no tienen componentes calculados, caso observado tras la
interrupción. También se prepararon una cola RX PC de 262 144 bytes, timeout
de captura de 60 s y una actualización del generador sin espera indefinida de
requestAnimationFrame. Estas mitigaciones NO se validaron físicamente después
de la petición de detener pruebas. `pc/doe_lap_cierre.py` quedó como ruta
experimental de cierre rápido, sin campaña completa ejecutada. No se declara
el banco autónomo listo ni el enlace estable. No hubo cambios RTL ni ARM.

### Anexos de muestras

Se agregó una revisión de 22 diapositivas: las 20 anteriores conservan sus
renders idénticos, comprobados por SHA-256, y se anexaron dos mosaicos 3×3 de
capturas existentes. El anexo A reúne nueve muestras D1 y el B nueve muestras
D2. Los recortes centrales usan la misma escala y no alteran los PNG/RAW
originales. Cada celda tiene condición y número de toma, y el ZIP incorpora
el índice con ID y hash de cada muestra. No se tomaron fotografías nuevas.

La revisión local es `Star_Tracker_D1_D5_LAP_con_anexos.pptx`, acompañada del
guion y las evidencias con el mismo sufijo. Se actualizaron los tres archivos
ya subidos a Mi unidad conservando sus IDs y enlaces. La versión local de
20 diapositivas permanece disponible.

### Revisión documental de geometría, condiciones y LAP

La revisión `Star_Tracker_LAP_revisado_v3.pptx` contiene 26 diapositivas.
Incluye un flujo editable D1–D2–D3 en la diapositiva 3, después del alcance,
y elimina las referencias históricas a 160×120 y la expresión «distancia
declarada». Presenta distancia 250 mm y explica la comparación geométrica
mediante la matriz afín ya obtenida de 9 posiciones (6 ajuste y 3 reservadas),
la escala de ventana y el centroide ponderado por Y.

Se calculó documentalmente el parámetro equivalente de proyección
f_eq=s·D/p=562,65 px a partir de s=0,524612 px de cámara/px de diseño,
D=250 mm y p=596,736/2560=0,2331 mm/px de pantalla. Es una equivalencia del
modelo local, no una medición óptica independiente de la focal ni una nueva
calibración física. El enfoque fijo se caracteriza mediante FWHM.

D2 incluye códigos C01–C06 y conserva la distinción de las cuatro series
completas frente a C05 incompleta y C06 sin datos. D3-C01–C04 son clases de
pares del mismo campo: centro–esquina, vertical, horizontal y diagonal
exterior. Las 5 imágenes compartidas proporcionan 20, 10, 10 y 10 distancias
respectivamente, con medias de 44,49, 50,26, 73,44 y 88,99 px de cámara.
No constituyen nuevas adquisiciones ni cuatro experimentos independientes.

El LAP se simplificó a integridad, calidad de captura, repetibilidad de
centroide PC y separación observada. Se retiraron del protocolo los
requisitos de identificación, actitud, latencia y centroide FPGA no
evaluados. D4 y D5 permanecen como etapas posteriores por iterar. Las
referencias ahora incluyen los títulos completos. El guion y el ZIP se
actualizaron en los mismos archivos de Drive. No se operó la cámara ni la
FPGA para esta revisión y no se inventaron mediciones.
