# Star Tracker en FPGA

Esta tesis desarrolla y valida un rastreador estelar en FPGA, desde la captura hasta el cálculo de un cuaternión. La demostración se hará en un banco controlado. Un Samsung Odyssey G5 muestra un cielo de referencia y una cámara OV7670, montada en un mecanismo de tres grados de libertad con servos MG90S, observa el patrón. La Arty Z7-10 se usa para las pruebas actuales de integración. La Nexys A7-100T es la plataforma prevista para la implementación final.

## Los cinco módulos de la tesis

| Módulo | Qué hace | Qué se demostrará |
|---|---|---|
| 1. Captura | Configura la OV7670 y guarda en BRAM una imagen de luminancia. | Recuperar por UART una foto de 320 × 240 y comprobar dimensiones, contraste y correspondencia con el patrón mostrado. Hay evidencia de captura física en la Arty. |
| 2. Centroides | Aplica un umbral, agrupa píxeles conectados y calcula el centro ponderado por luminancia. | Comparar el resultado con una referencia calculada a partir de la imagen y medir detecciones, fusiones, error de posición y repetibilidad en el banco. El RTL pasó XSim y el ruteo a 125 MHz. La caracterización física está pendiente. |
| 3. Catálogo | Prepara las estrellas de referencia y sus vectores unitarios para el campo utilizado. | Verificar que los identificadores, las coordenadas y el patrón del monitor correspondan a la misma escena. Guardar la selección usada por la FPGA. |
| 4. Identificación | Asocia los centroides observados con las estrellas del catálogo usando relaciones geométricas. | Comparar las correspondencias con los identificadores conocidos del patrón. Registrar aciertos, confusiones y tomas sin identificación. |
| 5. Actitud | Usa pares de vectores observados y de referencia para calcular el cuaternión mediante TRIAD. | Comparar la actitud estimada con poses de referencia del banco, usando el mismo sistema de ejes y registrando el error angular. |

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

