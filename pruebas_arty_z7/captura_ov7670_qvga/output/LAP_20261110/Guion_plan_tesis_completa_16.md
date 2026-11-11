# Guion de exposición · Planificación de toda la tesis

16 diapositivas. DoE: 1–11. LAP: 12–16.

Alcance: D1–D5, integración operativa en FPGA, aceptación de laboratorio y entrega final de tesis. Se presentan planes y metas por comprobar. Tiempo orientativo: 10–13 minutos.

## Diapositiva 1. Star Tracker

Esta exposición planifica toda la tesis. El DoE definirá factores, niveles, repeticiones y análisis desde la captura hasta la identificación y la actitud. El LAP establecerá cómo aceptar el sistema completo. La planificación también incluye integración en FPGA, informes y entrega final. Las cantidades son propuestas de ensayo y los límites son metas por comprobar.

## Diapositiva 2. DoE · Objetivo y alcance de toda la tesis

El objetivo será caracterizar y ajustar un sistema que capture estrellas, extraiga sus centroides, las identifique en catálogo y estime actitud con una salida válida. D1 a D3 estudiarán imagen, posición y separación. D4 estudiará identificación y D5 actitud y tiempo. Después se integrará la cadena operativa en FPGA y se comprobará con el LAP. El PC preparará escenas y actuará como referencia independiente y registro.

## Diapositiva 3. DoE · Flujo y dependencias

D1 fijará una imagen útil para medir en D2. D2 fijará la referencia y el tamaño útil para estudiar separación en D3. D3 definirá qué campos pueden entrar al identificador de D4. D4 entregará correspondencias verificables para estimar actitud en D5. El LAP comprobará la configuración integrada con datos reservados. Un fallo de imagen devolverá a D1, de geometría o tamaño a D2, de separación a D3, de identificación a D4 y de estimación a D5.

## Diapositiva 4. DoE · Variables, controles y referencia

Las unidades de diseño serán píxeles del generador y las medidas serán píxeles de cámara o grados, según la etapa. Se registrará el escalado real de la ventana. La geometría relacionará pantalla, cámara y catálogo. Antes de comparar centroides se obtendrá un mapa local y antes de verificar actitud se calibrarán intrínsecos y distorsión, indicando marcos, focal efectiva e incertidumbre. Las cinco repeticiones por condición se distribuirán en cinco bloques con orden aleatorio.

## Diapositiva 5. D1 · Exposición y ganancia

D1 planificará un factorial de tres exposiciones y dos ganancias. Cada una de las seis condiciones tendrá cinco repeticiones, una por bloque. El patrón inicial será un campo fijo de cinco fuentes. Se registrarán integridad, contraste, ruido de fondo, picos y saturación. Los códigos de registro se comprobarán en la preparación y se fijarán antes de ejecutar la matriz. Se elegirá un perfil que permita medir las etapas siguientes.

## Diapositiva 6. D2 · Tamaño y centroide

D2 combinará tres diámetros del patrón y dos posiciones con cinco repeticiones por condición. Se usará una fuente aislada y el perfil seleccionado en D1. Se registrarán FWHM, posición, error radial y dispersión. Las coordenadas de referencia procederán de la geometría calibrada y del escalado real. El análisis en PC caracterizará la escena y contrastará el resultado, mientras que el LAP verificará el centroide operativo de FPGA.

## Diapositiva 7. D3 · Separación y ruido

D3 cruzará tres separaciones y dos niveles de ruido del generador. Cada cuadro tendrá cinco fuentes y cada condición tendrá cinco repeticiones. El perfil y el diámetro quedarán fijos después de D2. Se medirán detecciones correctas, fusiones, omisiones y falsas por cuadro y por fuente. La distancia mínima entre centros se registrará en píxeles de diseño y también se medirá en cámara. El dominio útil se transmitirá a D4.

## Diapositiva 8. D4 · Catálogo e identificación estelar

D4 planificará tres sectores de catálogo y dos condiciones: nominal y una fuente falsa añadida. Cada sector contendrá ocho fuentes reales identificadas en HIP, con geometría y catálogo versionados. Habrá cinco repeticiones por condición. H01, H02 y H03 son etiquetas de sectores por seleccionar, no identificadores HIP inventados. Se registrarán asociaciones correctas, falsas y rechazos. El catálogo de evaluación será independiente de las salidas del identificador.

## Diapositiva 9. D5 · Actitud y tiempo de respuesta

D5 combinará tres ejes y dos giros virtuales de referencia, con cinco repeticiones. Se renderizarán campos de catálogo a partir de orientaciones conocidas y una geometría de cámara calibrada. Se comprobará primero que cada orientación conserve suficientes fuentes visibles. El sistema entregará cuaternión y validez. Se comparará con q_ref y se medirá el tiempo desde la solicitud aceptada de captura hasta la salida estable.

## Diapositiva 10. DoE · Cantidades y procedimiento previsto

El plan base reservará ciento cincuenta capturas para las cinco matrices, treinta por etapa. Se añadirán cincuenta y siete auxiliares y doscientas nuevas para LAP. El total base será cuatrocientas siete. La extensión dinámica, si se incluye, agregará setenta y cinco. Se aleatorizará el orden dentro de cada bloque y se conservarán intentos fallidos. Cada registro identificará patrón, configuración, versiones, unidades, tiempo y archivos originales.

## Diapositiva 11. DoE · Análisis, integración y cierre de tesis

D1 a D3 analizarán efectos de factores e interacciones, con bloqueo temporal y métricas por condición. D4 evaluará precisión de asociaciones y rechazos. D5 evaluará error angular, soluciones correctas y latencia. Después se integrará la cadena operativa, se simulará en Vivado/XSim, se sintetizará y se revisarán recursos y timing después de implementación. El bitstream final se comprobará en hardware mediante el LAP. La tesis cerrará con resultados, incertidumbres, limitaciones y archivos reproducibles.

## Diapositiva 12. LAP · Alcance completo y fundamento

El LAP será el protocolo de aceptación de laboratorio para la cadena completa: adquisición, detección, centroides, identificación, actitud y tiempo de respuesta en FPGA. Usará una configuración congelada y datos reservados. Las referencias apoyan la simulación de estrellas, la calibración y el análisis de centroides. Los límites numéricos procederán de los requisitos del proyecto, con metas pendientes de fijar, y no se atribuirán a los artículos como si fueran una norma de aceptación.

## Diapositiva 13. LAP · Requisitos y métodos de verificación

Se agruparán los requisitos en cinco ensayos de la cadena completa. L01 comprobará el contrato de captura y el rechazo de datos erróneos. L02 verificará detección, centroides y capacidad. L03 contrastará las asociaciones HIP y las coincidencias mínimas. L04 comprobará actitud y validez contra una referencia independiente. L05 medirá tiempo y revisará la implementación operativa en FPGA. La referencia PC no sustituirá la salida real que se somete a aceptación.

## Diapositiva 14. LAP · Metas y reglas de aceptación

Estas son metas de los requisitos que se fijarán antes de ejecutar. El error de centroide se medirá en salida FPGA frente a una referencia con incertidumbre caracterizada. Las asociaciones correctas se dividirán entre las emitidas y los rechazos se informarán aparte. La actitud exigirá precisión y proporción de soluciones correctas. La latencia terminará cuando cuaternión y validez estén estables. El fallo rápido no contará como solución exitosa.

## Diapositiva 15. LAP · Muestra reservada y evidencias esperadas

Se planificarán doscientos cuadros nuevos reservados. Cien corresponderán a diez posiciones de fuente aislada con diez repeticiones para el centroide. Otros cien corresponderán a diez escenas reservadas con diez repeticiones para el sistema completo. Se seleccionarán antes del LAP con geometría, sectores y perturbaciones definidos, sin utilizarlos para ajustar. Una captura podrá servir a varios requisitos sin volver a contarse. Se añadirán pruebas digitales negativas y evidencias de implementación.

## Diapositiva 16. LAP · Decisión y entrega final de tesis

El cierre de tesis dependerá de una matriz trazable desde cada requisito hasta el método, criterio, evidencia y decisión. Si cumple se registrará conformidad. Si incumple se conservará la desviación con su magnitud y alcance. Si falta referencia o evidencia se marcará no evaluable. Toda corrección cambiará de versión y repetirá las verificaciones afectadas. La entrega final incluirá la memoria con metodología, resultados, incertidumbre, limitaciones y conclusiones, además de archivos y sustentación.

## Respuestas breves

- **¿Cuántas capturas se planifican?** D1–D5: 150. Auxiliares: 57. DoE base: 207. LAP reservado: 200. Total base: 407. La extensión dinámica añade 75 y llevaría el total a 482. Reintentos y registros adicionales de calibración se contabilizarán aparte.
- **¿Por qué cinco repeticiones?** Es una propuesta exploratoria en cinco bloques. El piloto permitirá revisar su suficiencia según la variabilidad antes de congelar el plan. No representa un cálculo de potencia.
- **¿Cómo se evaluará el centroide?** Se contrastará la salida FPGA con una referencia geométrica independiente basada en escalado real pantalla–cámara y calibración, con puntos reservados e incertidumbre. La repetibilidad se informará separada de la exactitud.
- **¿Cómo se evaluará actitud?** Contra q_ref independiente, con calibración y marcos registrados. El ensayo numérico sobre vectores idénticos se separará del ensayo óptico completo.
- **¿Qué son H01, H02 y H03?** Etiquetas propuestas de tres sectores que se seleccionarán del catálogo real. No son identificadores HIP inventados.
- **¿Se usará PC para aceptar una función FPGA?** El PC aportará referencia y registro. La función operativa se comprobará en la salida de la FPGA.
- **¿Los papers exigen estos límites?** Respaldan métodos de simulación, calibración y métricas. Los límites son metas de los requisitos del proyecto que se cerrarán antes del LAP.
- **¿Hasta dónde llega el plan?** Hasta identificación, actitud, integración, LAP y entrega de la tesis con memoria, anexos, fuentes, datos y sustentación.

## Referencias

- Schulz et al. (2021). Universal Verification Platform and Star Simulator for Fast Star Tracker Design. https://doi.org/10.3390/s21030907
- Sun, Xing y You (2013). Optical System Error Analysis and Calibration Method of High-Accuracy Star Trackers. https://doi.org/10.3390/s130404598
- Lou et al. (2026). A Multi-Strategy Adaptive Error Modeling and Compensation Method for Star Point Centroid Extraction. https://doi.org/10.5194/isprs-archives-XLIX-B1-2026-279-2026

Requisitos del proyecto: `Documentacion/control/requisitos.csv`. Las metas pendientes de revisión conservarán ese estado hasta su cierre previo al LAP.
