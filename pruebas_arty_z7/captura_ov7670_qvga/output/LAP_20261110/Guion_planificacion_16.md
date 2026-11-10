# Guion de exposición · Planificación del DoE y del LAP

16 diapositivas. Parte 1: DoE (1–11). Parte 2: LAP (12–16).

La exposición plantea qué se investigará y cómo se decidirá la aceptación. No presenta resultados medidos ni conformidades obtenidas. Tiempo orientativo: 8–11 minutos.

## Diapositiva 1. Star Tracker

Esta exposición presenta la planificación del ensayo. La primera parte define qué investigará el DoE, qué variables se modificarán y cuántas capturas se programarán. La segunda parte define el LAP: qué requisitos se comprobarán, con qué métodos y qué criterios permitirán emitir una decisión. Los números que presentaré son cantidades y límites del plan, no resultados de validación.

## Diapositiva 2. DoE · Objetivo y alcance

El DoE investigará cómo influyen la exposición y la ganancia sobre la imagen, cómo cambian el tamaño de fuente y el centroide con la geometría, y cómo afectan la separación y el ruido al reconocimiento de fuentes distintas. El alcance experimental se limita a D1, D2 y D3, sobre luminancia QVGA. D4 y D5 serán etapas posteriores de identificación y actitud y no tendrán criterios de aceptación en este plan.

## Diapositiva 3. DoE · Flujo y dependencias

D1 deberá proporcionar un perfil estable de captura antes de medir el tamaño y la posición en D2. D2 deberá permitir fijar el tamaño de fuente y la referencia geométrica antes de estudiar separación en D3. Si falla la imagen se volverá a D1. Si el problema corresponde al tamaño o al umbral, se iterará D2. Los parámetros candidatos del DoE se congelarán antes de usar capturas nuevas en el LAP.

## Diapositiva 4. DoE · Variables y condiciones del banco

Se distinguirán factores manipulados, respuestas medidas y variables de control. Los factores son exposición y ganancia en D1, diámetro y posición en D2, separación y ruido en D3. Se mantendrán fijos el montaje, la distancia, el foco, el formato y las condiciones de pantalla. El ruido de D3 se especificará en códigos RGB del generador y se registrará también su efecto sobre el fondo capturado.

## Diapositiva 5. D1 · Factores, niveles y repeticiones

D1 tendrá un diseño factorial completo de tres niveles de exposición por dos de ganancia. Cada condición se capturará cinco veces, distribuidas en cinco bloques. Cada bloque incluirá una captura por condición en orden aleatorio. Los códigos iniciales deberán verificarse en la preparación y se fijarán antes de comenzar la matriz. El patrón será un campo constante de cinco fuentes sobre fondo negro.

## Diapositiva 6. D2 · Factores, niveles y repeticiones

D2 tendrá tres diámetros de diseño y dos posiciones, con cinco repeticiones por condición. Se mantendrá fijo el perfil de exposición y ganancia elegido mediante D1. Los tamaños se expresarán en píxeles del patrón, mientras que el FWHM y los centroides se medirán en píxeles de cámara. La posición desplazada estará cincuenta píxeles de diseño a la derecha del centro y deberá quedar dentro del encuadre.

## Diapositiva 7. D2 · Referencia geométrica y medición

Antes de comparar centroides se establecerá una correspondencia entre pantalla y cámara. Se registrará el escalado real de la ventana y se usarán nueve posiciones de fuente, con tres capturas por posición. Se ajustará un mapa con seis posiciones y se reservarán tres para comprobarlo. El paso de pantalla y la distancia relacionarán desplazamiento y ángulo. La focal o escala equivalente se obtendrá del ajuste, sin asignarle de antemano un valor medido.

## Diapositiva 8. D3 · Factores, niveles y repeticiones

D3 estudiará tres separaciones y dos niveles de ruido añadido, con cinco repeticiones por condición. Cada cuadro contendrá cinco fuentes de igual intensidad. Exposición, ganancia y tamaño se mantendrán fijos. El tamaño nominal inicial será cuatro píxeles de diseño y deberá ser observable en D2. Antes de congelar la matriz se comprobará que los discos del patrón no se solapan nominalmente.

## Diapositiva 9. DoE · Cantidad de capturas planificada

Las matrices de D1, D2 y D3 programan treinta capturas cada una, noventa en total. La preparación contempla cinco fotos de piloto, quince referencias de niveles digitales, veintisiete para geometría y diez de confirmación de D2. Esto suma ciento cuarenta y siete capturas del DoE. El LAP tendrá veinte nuevas, por lo que el total planificado será ciento sesenta y siete. Los reintentos se registrarán aparte. Las referencias de niveles digitales usarán RGB 0, 64, 128, 192 y 255 con tres capturas por nivel.

## Diapositiva 10. DoE · Procedimiento de adquisición

Primero se fijarán el montaje y las condiciones de pantalla y se versionarán los patrones. Después se ejecutará la preparación y se congelará la matriz. Las condiciones de cada etapa se programarán en cinco bloques con orden aleatorio registrado. Se esperará la estabilización después de cada cambio, se capturará un cuadro completo y se guardarán imagen y metadatos. Al finalizar cada bloque se revisará la integridad y se registrarán las incidencias.

## Diapositiva 11. DoE · Análisis previsto y entregables

El análisis comparará respuestas entre niveles y entre bloques. Para D1 se estudiarán contraste, saturación y visibilidad, incluyendo la interacción entre exposición y ganancia. Para D2 se compararán FWHM, centroide, residuo geométrico y dispersión por tamaño y posición. Para D3 se informarán fuentes correctas, fusiones, omisiones y falsas por separación y ruido. La salida será una configuración candidata y su dominio de uso, que deberán comprobarse en el LAP.

## Diapositiva 12. LAP · Alcance y fundamento

La segunda parte planifica cómo se decidirá la aceptación. El LAP definirá requisitos de captura, referencia y centroide en PC y separación del campo. Los parámetros se mantendrán fijos y se utilizarán capturas nuevas, reservadas frente al ajuste del DoE. Las referencias respaldan el uso de escenas controladas, geometría y métricas de error. Los límites concretos serán criterios propuestos del banco y deberán fijarse antes de esta ejecución.

## Diapositiva 13. LAP · Requisitos y métodos de verificación

Se definirán cuatro requisitos dentro del alcance. L01 conservará tamaño, orden e integridad de los datos y rechazará paquetes erróneos. L02 comprobará que el perfil elegido represente las cinco fuentes sin saturarlas. L03 exigirá una referencia geométrica comprobada y un centroide repetible en PC. L04 comprobará que se distingan las cinco fuentes del campo en los casos de ruido programados. Cada requisito tendrá un método y una evidencia prevista.

## Diapositiva 14. LAP · Criterios de aceptación propuestos

Los criterios se fijarán antes del LAP. L01 verificará el contrato de imagen y que los casos erróneos no se acepten. L02 comprobará cinco fuentes con pico inferior a doscientos cincuenta y contraste relativo mínimo de seis. L03 utilizará un RMS reservado de referencia de hasta 0,2 píxeles y una dispersión radial del centroide de hasta 0,5 píxeles. L04 exigirá cinco fuentes correctas en cada uno de los cinco cuadros de cada caso. Estas son metas del plan, no medidas obtenidas.

## Diapositiva 15. LAP · Muestra y evidencias esperadas

El conjunto reservado del LAP tendrá cuatro lotes de cinco capturas: campo de cinco fuentes sin ruido, el mismo campo con ruido ocho, una fuente central y una desplazada cincuenta píxeles. Son veinte capturas nuevas. Las mismas veinte servirán para integridad; el lote A para calidad de captura; C y D para centroide; A y B para separación. Se guardarán originales, logs y un registro con la medición y la regla aplicada.

## Diapositiva 16. LAP · Decisión y tratamiento de desviaciones

La decisión se emitirá únicamente después de comparar las medidas del conjunto reservado con los criterios fijados. Se podrá registrar conformidad, no conformidad o resultado no evaluable. Toda desviación conservará su evidencia y su causa. Si se cambia un parámetro para corregirla, se guardará una nueva configuración y se repetirá el alcance afectado con un nuevo conjunto de comprobación. La documentación cerrará con una matriz de decisiones por requisito.

## Respuestas breves

- **¿Por qué cinco repeticiones?** Es la elección de este plan para caracterización inicial en cinco bloques. No es una cantidad universal obligatoria del DoE ni garantiza por sí sola potencia estadística. Se revisará según la variabilidad.
- **¿Cuántas capturas se planifican?** 90 en las matrices D1–D3, 57 preparatorias y de confirmación y 20 nuevas para LAP: total 167. Los reintentos se registran aparte.
- **¿Por qué separar DoE y LAP?** El DoE ajusta y caracteriza. El LAP usa parámetros congelados y capturas nuevas reservadas para aplicar criterios.
- **¿Qué significa s*?** Es la separación candidata que se elegirá con D3 antes del LAP. No se asigna una medida de desempeño obtenida.
- **¿El centroide es de FPGA?** Este plan caracteriza centroide en PC. No declara aceptada la salida operativa FPGA.
- **¿Los papers exigen los límites numéricos?** Apoyan el método. Los límites son propuestas del banco y se fijarán antes del LAP.

## Referencias

- Schulz et al. (2021). Universal Verification Platform and Star Simulator for Fast Star Tracker Design. https://doi.org/10.3390/s21030907
- Sun, Xing y You (2013). Optical System Error Analysis and Calibration Method of High-Accuracy Star Trackers. https://doi.org/10.3390/s130404598
- Lou et al. (2026). A Multi-Strategy Adaptive Error Modeling and Compensation Method for Star Point Centroid Extraction. https://doi.org/10.5194/isprs-archives-XLIX-B1-2026-279-2026
