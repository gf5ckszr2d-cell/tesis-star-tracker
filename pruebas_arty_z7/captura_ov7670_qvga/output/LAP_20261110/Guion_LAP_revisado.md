# Guion de exposición · Star Tracker y LAP

Alexander Bolívar Huachaca · 10/11/2026

Duración orientativa: 9 a 12 minutos. Los centroides de esta entrega se calculan en PC. D3 reanaliza cinco fotos de D1, no una campaña independiente.

## Diapositiva 1. Star Tracker

Presento la caracterización experimental del banco Arty con cámara OV7670. Esta entrega documenta D1, D2 y la separabilidad observada en D3. Después delimito D4 y D5 con sus valores objetivo y cierro con el protocolo de aceptación de laboratorio, LAP. Todos los resultados mostrados proceden de archivos reales.

## Diapositiva 2. Alcance de la entrega

La caracterización que cierro es inicial y tiene un dominio concreto. D1 compara seis perfiles. D2 analiza dos tamaños con dos posiciones. D3 reutiliza cinco capturas del campo seleccionado para medir separabilidad observada. D4 y D5 son etapas definidas, sin resultados experimentales. Por eso el cierre no equivale a aceptar todavía un sensor completo de actitud.

## Diapositiva 3. Flujo experimental D1, D2 y D3

D1 proporciona imágenes con fuentes distinguibles y fija exposición y ganancia. D2 necesita ese perfil estable para que una variación de brillo no se confunda con un cambio de tamaño o posición. D2 caracteriza tamaños, enfoque mediante FWHM y centroides. D3 usa esas condiciones para comprobar qué fuentes permanecen separadas. Si falla la imagen se vuelve a D1. Si falla el tamaño o el umbral se itera D2.

## Diapositiva 4. Montaje real del banco

La fotografía muestra la cámara sujeta al soporte, la conexión con el Arty y el patrón en el monitor Samsung. La distancia es de 250 milímetros, el brillo del monitor está en cero y el HDR está desactivado. El montaje conserva la posición de cámara durante las series.

## Diapositiva 5. Cadena y configuración evaluadas

La placa realiza la adquisición y la extracción de luminancia Y. El diagnóstico transporta el cuadro por UART hasta el computador. En esta campaña el computador calcula detecciones y centroides para caracterizar el banco. Es importante separar este análisis de la validación del detector y del centroide implementados en VHDL, que no se midieron aquí.

## Diapositiva 6. D1 · Barrido de exposición y ganancia

El barrido utiliza tres códigos de exposición y dos de ganancia, con cinco cuadros por combinación. Las seis combinaciones distinguen las cinco fuentes sin saturación. El controlador selecciona C06 por maximizar el contraste de la fuente más débil dentro de las condiciones aceptadas. Los valores de exposición y ganancia son códigos de registro, no milisegundos ni decibelios.

## Diapositiva 7. D1 · Capturas y perfil seleccionado

Estas son dos imágenes originales de la misma escena. Con el perfil más bajo las fuentes se distinguen con menor intensidad. El perfil seleccionado aumenta su contraste y conserva los cinco componentes separados. No se aplicó un enfoque artificial ni una mejora visual a estas evidencias.

## Diapositiva 8. Referencia local y niveles digitales Y

La referencia geométrica relaciona coordenadas de diseño con píxeles de cámara. Se ajustaron seis posiciones y se reservaron tres para comprobar el mapa. El residuo máximo reservado es de 0,130 píxeles. La curva de niveles Y muestra que el blanco uniforme satura con el perfil elegido. Esto limita su uso radiométrico, aunque las estrellas seleccionadas no saturan.

## Diapositiva 9. D2 · Evaluación geométrica del centroide

Se transforma la posición de cada fuente en la pantalla a una posición de referencia en la imagen mediante el mapa afín medido. El paso de pantalla y la distancia de 250 milímetros relacionan esa escala con un modelo geométrico de proyección. El parámetro focal equivalente de 562,65 píxeles deriva de esa escala; no es una medición independiente de la focal óptica. El centroide pondera la intensidad Y de la fuente y se compara con la referencia en píxeles de cámara. El enfoque se mantiene fijo y su resultado se caracteriza mediante FWHM.

## Diapositiva 10. D2 · Condiciones de ensayo

Las condiciones C01 a C04 combinan diámetros de cuatro y ocho píxeles de diseño con una posición central y otra desplazada cincuenta píxeles. Cada una tiene cinco cuadros completos. C05 tiene un solo cuadro y se excluye del análisis por serie incompleta. C06 no tiene datos. Todas usan el perfil de D1 E384 G16 y umbral Y9.

## Diapositiva 11. D2 · Resultados y conclusión

Las condiciones C01 a C04 producen fuentes aisladas sin saturación. La dispersión radial temporal queda entre 0,009 y 0,017 píxeles, y el RMS frente a la referencia geométrica local entre 0,028 y 0,130 píxeles. Se consideran útiles los tamaños de cuatro y ocho píxeles de diseño para este montaje. La evaluación utiliza el centroide calculado en PC.

## Diapositiva 12. D2 · Evidencia de fuente aislada

Aquí comparo dos cuadros originales de las series de D2. El diámetro de cuatro píxeles de diseño produce una fuente capturada con FWHM del orden de cinco píxeles. El de ocho produce una fuente más ancha y luminosa. Son medidas del conjunto pantalla, lente y sensor, con el enfoque conservado durante la adquisición.

## Diapositiva 13. D3 · Condiciones geométricas evaluadas

D3 clasifica cuatro separaciones dentro del mismo campo de cinco fuentes: centro a esquina, vertical, horizontal y diagonal exterior. Los códigos C01 a C04 identifican clases de pares, no capturas independientes. Se usan las mismas cinco imágenes con diámetro de ocho píxeles y sin ruido añadido. El total es de cincuenta distancias de pares obtenidas de veinticinco observaciones de fuentes.

## Diapositiva 14. D3 · Resultados y conclusión

Para D3 reanalizo las cinco capturas del campo seleccionado de D1. Se asocian las veinticinco observaciones esperadas y no aparecen fusiones, omisiones ni componentes falsos aceptados. Las cuatro clases de pares permanecen separadas. La menor distancia observada entre centroides es aproximadamente 44,3 píxeles de cámara. La conclusión corresponde al campo evaluado, sin establecer el límite mínimo de resolución.

## Diapositiva 15. Síntesis de la caracterización D1–D3

El resultado de esta entrega es una caracterización inicial cerrada con su evidencia identificada. D1 deja un perfil seleccionado, D2 cuantifica tamaños y repetibilidad, y D3 confirma que el campo observado resulta separable. La separación de 44,3 píxeles es un punto verificado del dominio, no un umbral mínimo ni una validación bajo ruido añadido.

## Diapositiva 16. D4 · Identificación estelar

D4 es la etapa posterior de identificación frente a un catálogo Hipparcos. Usa la información de tamaño y separación obtenida en D1 a D3 para seleccionar escenas observables. Su salida esperada será la asociación de cada fuente con una identidad HIP. Se conserva aquí como continuación del proceso y no se incorpora a los criterios de aceptación de este LAP.

## Diapositiva 17. D5 · Actitud y respuesta temporal

D5 es la etapa posterior al establecimiento de las identidades. Utilizará correspondencias geométricas para estimar la actitud y comprobarla frente a una referencia. También registrará el estado de validez y el tiempo operativo. La transferencia UART de fotografías se analiza aparte. Esta etapa queda como continuación y no forma parte de las decisiones de aceptación actuales.

## Diapositiva 18. LAP · Protocolo de aceptación de laboratorio

El LAP organiza la aceptación de las funciones evaluadas. Para cada ensayo presenta una condición, el procedimiento, un criterio y el resultado observado. Este documento comprende la integridad de captura, la calidad de fuente, la repetibilidad del centroide calculado en PC y la separación geométrica del campo. D4 y D5 no forman parte de esta aceptación.

## Diapositiva 19. Sustento bibliográfico del LAP

Los papers sustentan cómo organizar y medir, no certifican nuestro banco ni fijan automáticamente nuestros límites. Schulz y colaboradores respaldan la verificación modular con escenas sintéticas y ruido controlado. Sun y colaboradores muestran la importancia de los errores ópticos y de una referencia de laboratorio. Lou y colaboradores distinguen el error de extracción del centroide y su compensación. Adoptamos esas ideas como base metodológica.

## Diapositiva 20. LAP · Comprobaciones realizadas

Esta tabla incluye únicamente comprobaciones realizadas con los archivos del ensayo. Se revisó la integridad del cuadro, la calidad del campo de fuentes, la repetibilidad del centroide y la asociación geométrica de las fuentes. El protocolo registra los datos y permite reconstruir la decisión.

## Diapositiva 21. LAP · Criterios y aceptación

El protocolo compara cada comprobación con un criterio concreto. Los cuadros archivados deben conservar dimensiones e integridad. D1 debe distinguir cinco fuentes sin saturarlas. D2 evalúa la estabilidad temporal del centroide, con un límite exploratorio de medio píxel. D3 exige cinco fuentes asociadas por cuadro sin fusiones, omisiones ni falsas aceptadas. Estas decisiones se limitan a las condiciones evaluadas.

## Diapositiva 22. LAP · Decisiones y desviaciones

La aceptación es limitada al alcance de la evidencia. Los cuadros archivados satisfacen el contrato de datos y el campo fijo distingue sus cinco fuentes. Sin embargo, la campaña registró una transferencia incompleta y una interrupción del visualizador. Esos datos no entraron como cuadros válidos. La decisión se refiere a los cuadros completos y a las condiciones geométricas comprobadas.

## Diapositiva 23. Cierre del alcance presentado

Concluyo la caracterización inicial del banco hasta la separabilidad observada de D3. Tenemos un perfil de captura seleccionado, medidas de fuentes aisladas y un campo fijo con todas sus fuentes distinguibles. La entrega también define D4 y D5 y organiza el LAP con requisitos, criterios y evidencias. El alcance queda cerrado y sus límites quedan declarados, sin presentar todavía un Star Tracker completo aceptado.

## Diapositiva 24. Referencias y paquete de evidencias

El paquete adjunto conserva las fotos originales del montaje, las capturas y sus datos sin mejorar artificialmente las imágenes. Incluye el análisis usado en esta presentación y un índice de evidencia. El guion sigue exactamente el orden de las diapositivas. Las referencias bibliográficas apoyan la metodología, mientras que los criterios aplicados se trazan a los registros del banco.

## Diapositiva 25. Anexo A · Muestras de captura D1

Este mosaico reúne nueve capturas originales ya utilizadas en el análisis. Las primeras seis muestran los perfiles C01 a C06 y las últimas tres son repeticiones del perfil seleccionado C06. El recorte central y la escala son iguales en todas las celdas. Los archivos originales completos permanecen en el paquete de evidencias.

## Diapositiva 26. Anexo B · Muestras de fuente aislada D2

Este segundo mosaico presenta nueve ejemplos de las series existentes de D2, con tamaños de cuatro y ocho píxeles de diseño y posiciones central o desplazada. Las etiquetas identifican la condición y la toma. Estas imágenes ilustran la repetibilidad observada y no añaden nuevas adquisiciones ni nuevos resultados al informe.

## Respuestas breves para preguntas

- **¿Cómo se evalúa el centroide?** Se proyectan las coordenadas de pantalla al plano de captura mediante el mapa geométrico local y se compara ese centro de referencia con el centroide ponderado por Y. Se informan RMS local y dispersión temporal.
- **¿Qué relación tienen pantalla, distancia y foco?** El paso de pantalla es 0,2331 mm/px y la distancia es 250 mm. La escala horizontal medida es 0,5246 px de cámara por px de diseño. De ella se deriva un parámetro de proyección equivalente de 562,65 px. No representa una medición óptica independiente de focal. El foco fijo se caracteriza por FWHM.
- **¿Qué son C01–C04 de D3?** Son cuatro clases de pares de fuentes del mismo campo: centro–esquina, vertical, horizontal y diagonal exterior. Comparten cinco capturas; no son cuatro series independientes.
- **¿D3 encuentra la separación mínima?** Verifica separación en el campo observado, con distancia mínima entre sus fuentes de unos 44,3 px de cámara. No determina el límite mínimo de resolución.
- **¿Qué acepta este LAP?** Sólo las condiciones evaluadas de integridad, captura, repetibilidad del centroide PC y separación geométrica.
