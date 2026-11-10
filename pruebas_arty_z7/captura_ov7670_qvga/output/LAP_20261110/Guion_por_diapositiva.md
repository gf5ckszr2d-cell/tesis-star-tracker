# Guion de exposición · Star Tracker y LAP

Alexander Bolívar Huachaca · 10/11/2026

Duración orientativa: 9 a 12 minutos. Los centroides de esta entrega se calculan en PC. D3 reanaliza cinco fotos de D1, no una campaña independiente.

## Diapositiva 1. Star Tracker

Presento la caracterización experimental del banco Arty con cámara OV7670. Esta entrega documenta D1, D2 y la separabilidad observada en D3. Después delimito D4 y D5 con sus valores objetivo y cierro con el protocolo de aceptación de laboratorio, LAP. Todos los resultados mostrados proceden de archivos reales.

## Diapositiva 2. Alcance de la entrega

La caracterización que cierro es inicial y tiene un dominio concreto. D1 compara seis perfiles. D2 analiza dos tamaños con dos posiciones. D3 reutiliza cinco capturas del campo seleccionado para medir separabilidad observada. D4 y D5 son etapas definidas, sin resultados experimentales. Por eso el cierre no equivale a aceptar todavía un sensor completo de actitud.

## Diapositiva 3. Montaje real del banco

La fotografía muestra la cámara sujeta al soporte, la conexión con el Arty y el patrón en el monitor Samsung. La distancia de 250 milímetros, brillo del monitor en cero y HDR desactivado son condiciones confirmadas por el operador. Las fotos documentan el montaje, pero no son una medición de distancia ni de luminancia.

## Diapositiva 4. Cadena y configuración evaluadas

La placa realiza la adquisición y la extracción de luminancia Y. El diagnóstico transporta el cuadro por UART hasta el computador. En esta campaña el computador calcula detecciones y centroides para caracterizar el banco. Es importante separar este análisis de la validación del detector y del centroide implementados en VHDL, que no se midieron aquí.

## Diapositiva 5. D1 · Barrido de exposición y ganancia

El barrido utiliza tres códigos de exposición y dos de ganancia, con cinco cuadros por combinación. Las seis combinaciones distinguen las cinco fuentes sin saturación. El controlador selecciona C06 por maximizar el contraste de la fuente más débil dentro de las condiciones aceptadas. Los valores de exposición y ganancia son códigos de registro, no milisegundos ni decibelios.

## Diapositiva 6. D1 · Capturas y perfil seleccionado

Estas son dos imágenes originales de la misma escena. Con el perfil más bajo las fuentes se distinguen con menor intensidad. El perfil seleccionado aumenta su contraste y conserva los cinco componentes separados. No se aplicó un enfoque artificial ni una mejora visual a estas evidencias.

## Diapositiva 7. Referencia local y niveles digitales Y

La referencia geométrica relaciona coordenadas de diseño con píxeles de cámara. Se ajustaron seis posiciones y se reservaron tres para comprobar el mapa. El residuo máximo reservado es de 0,130 píxeles. La curva de niveles Y muestra que el blanco uniforme satura con el perfil elegido. Esto limita su uso radiométrico, aunque las estrellas seleccionadas no saturan.

## Diapositiva 8. D2 · Tamaño y centroide en PC

Se analizan veinte cuadros completos, cinco por tamaño y posición. Ambos tamaños permiten medir un centroide sin las banderas de recorte, saturación o baja señal del análisis. La dispersión radial temporal es inferior a 0,017 píxeles en estas series. El error de la tabla se compara con el mapa local y no sustituye la comprobación de exactitud absoluta del centroide FPGA.

## Diapositiva 9. D2 · Evidencia de fuente aislada

Aquí comparo dos cuadros originales de las series de D2. El diámetro de cuatro píxeles de diseño produce una fuente capturada con FWHM del orden de cinco píxeles. El de ocho produce una fuente más ancha y luminosa. Son medidas del conjunto pantalla, lente y sensor, con el enfoque conservado durante la adquisición.

## Diapositiva 10. D3 · Separabilidad del campo observado

Para D3 reanalizo las cinco capturas del campo seleccionado de D1. Se asocian las veinticinco observaciones esperadas y no aparecen fusiones, omisiones ni componentes falsos aceptados. La menor distancia observada entre centroides es aproximadamente 44,3 píxeles de cámara. Esto demuestra separabilidad en ese campo, pero no identifica la distancia mínima que el banco puede resolver.

## Diapositiva 11. Síntesis de la caracterización D1–D3

El resultado de esta entrega es una caracterización inicial cerrada con su evidencia identificada. D1 deja un perfil seleccionado, D2 cuantifica tamaños y repetibilidad, y D3 confirma que el campo observado resulta separable. La separación de 44,3 píxeles es un punto verificado del dominio, no un umbral mínimo ni una validación bajo ruido añadido.

## Diapositiva 12. D4 · Identificación y valores objetivo

D4 queda delimitado como la identificación de observaciones frente a un catálogo Hipparcos. Los resultados esperados son identidades con correspondencia preservada y conteos de falsas asociaciones y rechazos. La meta documentada es al menos 99 por ciento de asociaciones emitidas correctas y al menos cinco coincidencias distintas para aceptar una solución de actitud. Esta etapa no tiene resultados medidos en la entrega.

## Diapositiva 13. D5 · Actitud, validez y tiempo

D5 utilizará únicamente correspondencias aceptadas para calcular actitud. Sus valores objetivo son un RMS angular de 0,1 grados, una tasa de soluciones correctas de al menos 90 por ciento y un presupuesto objetivo de 0,1 segundos para la cadena operativa. El tiempo de transferencia UART de las fotos no es esa latencia. Aquí presento las metas y la forma de evaluarlas, sin atribuir cuaterniones ni tiempos obtenidos.

## Diapositiva 14. LAP · Protocolo de aceptación de laboratorio

LAP es la denominación que utilizamos en el curso para el protocolo de aceptación de laboratorio. El documento fija alcance, configuración, procedimiento, criterio, evidencia y decisión. El diseño de experimentos caracteriza el comportamiento y ayuda a elegir condiciones. El LAP contrasta resultados con requisitos dentro de un entorno controlado y deja las desviaciones explícitas.

## Diapositiva 15. Sustento bibliográfico del LAP

Los papers sustentan cómo organizar y medir, no certifican nuestro banco ni fijan automáticamente nuestros límites. Schulz y colaboradores respaldan la verificación modular con escenas sintéticas y ruido controlado. Sun y colaboradores muestran la importancia de los errores ópticos y de una referencia de laboratorio. Lou y colaboradores distinguen el error de extracción del centroide y su compensación. Adoptamos esas ideas como base metodológica.

## Diapositiva 16. Trazabilidad con los requisitos del proyecto

La tabla conecta las evidencias con los requisitos documentados. La adquisición física usa la variante Arty QVGA autorizada. Los requisitos históricos de QQVGA no se reescriben. La caracterización de centroide en PC aporta información de diseño, pero no declara cumplido RS-05 en FPGA. Identificación, actitud y tiempo conservan sus metas como parte del alcance siguiente.

## Diapositiva 17. LAP · Procedimientos y criterios

Estos ensayos definen la aceptación por función. L01 verifica tamaño e integridad del cuadro. L02 requiere comparar el centroide FPGA con una referencia independiente y mantiene el objetivo RMS de 0,2 píxeles. L03 exige contar las fuentes correctas, fusiones, omisiones y falsas dentro del campo declarado. L04 y L05 quedan ligados a las metas de identificación y actitud. No sustituyo sus resultados ausentes con cálculos del PC.

## Diapositiva 18. LAP · Decisiones y desviaciones

La aceptación es limitada al alcance de la evidencia. Los cuadros archivados satisfacen el contrato de datos y el campo fijo distingue sus cinco fuentes. Sin embargo, la campaña registró una transferencia incompleta y una interrupción del visualizador. Esos datos no entraron como cuadros válidos. La estabilidad continua del enlace, el centroide FPGA y la aceptación del sistema completo permanecen sin demostrar.

## Diapositiva 19. Cierre del alcance presentado

Concluyo la caracterización inicial del banco hasta la separabilidad observada de D3. Tenemos un perfil de captura seleccionado, medidas de fuentes aisladas y un campo fijo con todas sus fuentes distinguibles. La entrega también define D4 y D5 y organiza el LAP con requisitos, criterios y evidencias. El alcance queda cerrado y sus límites quedan declarados, sin presentar todavía un Star Tracker completo aceptado.

## Diapositiva 20. Referencias y paquete de evidencias

El paquete adjunto conserva las fotos originales del montaje, las capturas y sus datos sin mejorar artificialmente las imágenes. Incluye el análisis usado en esta presentación y un índice de evidencia. El guion sigue exactamente el orden de las diapositivas. Las referencias bibliográficas apoyan la metodología, mientras que los límites numéricos de aceptación se trazan al archivo de requisitos del proyecto.

## Respuestas breves para preguntas

- **¿D3 encuentra la separación mínima?** No. Confirma separabilidad en el campo observado, con distancia mínima entre sus fuentes de unos 44,3 px de cámara. No se ejecutó el barrido 8/16/24 px con ruido.
- **¿Se cumple RMS de 0,2 px en FPGA?** No se evaluó. Los centroides son de PC y el mapa es empírico.
- **¿Cuántas fotos independientes sustentan D1–D3?** D1 usa 30 y D2 20 cuadros completos. D3 reutiliza 5 de los 30 de D1. No suman 55 fotos independientes.
- **¿El enlace quedó aceptado?** Los archivos recibidos son íntegros. Hubo una transferencia incompleta y una interrupción de visualización. La estabilidad continua no queda aceptada.
- **¿Los papers fijan esos límites numéricos?** No. Respaldan la metodología. Los valores de aceptación proceden de los requisitos documentados del proyecto.
