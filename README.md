# Star Tracker en FPGA

Esta tesis propone una arquitectura FPGA con comportamiento temporal determinista bajo condiciones de operación definidas. La evidencia central será el conteo de ciclos y una cota temporal justificada para ese dominio de entrada, contrastada con las pruebas del banco. Un Samsung Odyssey G5 muestra un patrón estelar de referencia y una cámara OV7670 observa la escena. La Arty Z7-10 se usa para las pruebas actuales; la Nexys A7-100T es la plataforma prevista para la implementación final.

## Una arquitectura y un patrón de referencia

Los cinco pasos se conservan como guía para diseñar y explicar el recorrido de los datos dentro de una arquitectura completa. El alcance acordado el 19/11/2026 se centra en demostrar su comportamiento temporal determinista. Los resultados funcionales del banco aportarán evidencia de funcionamiento en las condiciones elegidas.

Para el ensayo inicial se usa una sola familia de fuentes sintéticas. El **[patrón estelar de referencia](Generador_G5/patron_sintetico.html)** contiene 48 puntos de igual forma y brillo, distribuidos aleatoriamente dentro de una división de 8 columnas × 6 filas. La semilla conserva sus posiciones. Una tabla guarda sus identificadores y coordenadas; esta referencia se define para el banco y no requiere un catálogo astronómico.

El generador permite explorar recortes digitales 4:3 e inicia con ocho centros dentro del recorte. La cantidad que registre la OV7670 depende del encuadre y la respuesta física y se comprobará con capturas. El matching será el siguiente paso después de revisar el patrón. La prueba física y la demostración de la cota temporal siguen pendientes.

## Cámara y procesamiento

- **OV7670 en QVGA de 320 × 240.** La configuración anterior de 160 × 120 era QQVGA. La previsualización QQVGA de la documentación histórica del generador es independiente de la resolución de captura del proyecto vigente.
- **YUV 4:2:2.** La FPGA extrae luminancia Y de 8 bits y guarda 76 800 muestras por imagen. El reloj XCLK es de 24 MHz y la lógica de procesamiento en la Arty trabaja a 125 MHz.
- **Perfil fijo D1-C06.** COM8 `13=88` desactiva exposición, ganancia y balance automáticos. Los registros de exposición son `04=00`, `10=60` y `07=40`. La ganancia usa `00=10` y la extensión nocturna queda desactivada con `3B=00`. La secuencia completa está en [ov7670_init_config.vhd](Tesis_definitiva/Tesis_definitiva/Tesis_definitiva.srcs/sources_1/new/ov7670_init_config.vhd). Los valores están en hexadecimal.
- **Perfil inicial del detector.** Umbral `Y ≥ 45`, conectividad de ocho vecinos, área de 2 a 500 píxeles brillantes y hasta 64 resultados. El área y el umbral se ajustarán con las tomas del banco.
- **UART de pruebas.** En la Arty, la salida de diagnóstico entrega primero la foto `STY1` y luego la lista `STC1` de esa foto. Los criterios de aceptación se definen antes de comparar las coordenadas y los recuentos.

## Banco de validación

Se usa el **Samsung Odyssey G5 LS27AG550ELXPE**, de 27 pulgadas, 2560 × 1440 y curvatura 1000R. El banco parte de la resolución nativa en SDR. Durante cada serie se fijan y registran el brillo, el refresco, la distancia, la alineación y el perfil de la cámara. Los 250 mm del generador son la distancia nominal inicial. Se mide la distancia real y se verifica la escala monitor–cámara con puntos de referencia. [Ficha del monitor](https://www.samsung.com/pe/monitors/gaming/odyssey-g5-g55a-27-inch-165hz-1ms-ls27ag550elxpe/)

El generador permite conservar el patrón y las coordenadas de las estrellas mostradas. Con el mecanismo se posiciona la cámara y se deja que se estabilice antes de cada toma. Para usar una pose como referencia de actitud se deben medir los ángulos reales y verificar los ejes del banco. Las órdenes a los servos describen el movimiento solicitado.

La prueba de centroides variará tamaño, brillo y separación de las estrellas. Se guardarán el patrón, la foto y la lista UART. Una cruz en la imagen mostrará la posición medida y otra la posición esperada en coordenadas de cámara. Los casos de ajuste y los casos de validación serán distintos.

## Contenido del repositorio

- [Tesis definitiva](Tesis_definitiva/Tesis_definitiva/Tesis_definitiva.xpr) contiene el proyecto Vivado 2025.2 para la Arty Z7-10, sus fuentes VHDL, el diseño de bloques y las restricciones. Al abrirlo en otro equipo, instala la definición de la placa si hace falta y genera los productos del diseño de bloques.
- [Bitácora de centroides](Tesis_definitiva/Documentacion_visual/bitacora_centroides/Bitacora.md) conserva las corridas comparadas, los reportes y los diagramas finales. El WNS ruteado pasó de −3.582 ns a **+0.145 ns**, con WHS **+0.027 ns** bajo las restricciones actuales.
- [Pruebas Arty](pruebas_arty_z7/) contiene las fuentes de la prueba de captura, una toma de referencia y las herramientas del receptor.
- [Generador G5](Generador_G5/) contiene el generador de estrellas y el [perfil inicial del banco](Generador_G5/configuracion_banco.json).
- [Mecanismo 3GDL MG90S](Inventor/Mecanismo_3GDL/Mecanismo_original_MG90S_cruz/) contiene el ensamblaje y las piezas de Inventor, junto con los STL de fabricación.

