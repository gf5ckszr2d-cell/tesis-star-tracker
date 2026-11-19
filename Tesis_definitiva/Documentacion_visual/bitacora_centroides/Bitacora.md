# Bitácora de timing de centroides

Proyecto `Tesis_definitiva` en Arty Z7-10. La comparación usa el reporte ruteado de Vivado 2025.2 con `clk_fpga_0` a **125 MHz** y el mismo XDC. El procesamiento parte de una imagen QVGA ya guardada en BRAM. Los [diagramas de la propuesta original](../parte_2_propuesta/imagenes_generadas/) se conservan como referencia.

| Corrida | Cambio | WNS (ns) | TNS (ns) | Destinos con falla de setup | WHS (ns) |
|---|---|---:|---:|---:|---:|
| [00 · Original](00_original/design_1_wrapper_timing_summary_routed.rpt#L146) | Lectura encadenada de etiqueta y datos | −3.582 | −17163.080 | 11324 | +0.064 |
| [01 · Lectura en dos ciclos](01_lectura_en_dos_ciclos/design_1_wrapper_timing_summary_routed.rpt#L146) | Registro de etiqueta, registro del grupo y espera en cálculo | −3.199 | −14174.519 | 9812 | +0.024 |
| [02 · Productos registrados](02_productos_registrados/design_1_wrapper_timing_summary_routed.rpt#L146) | Multiplicar en un ciclo y acumular en el siguiente | −1.797 | −5477.286 | 8881 | +0.071 |
| [03 · Tabla en BRAM](03_tabla_en_bram/design_1_wrapper_timing_summary_routed.rpt#L145) | Leer, sumar y escribir los acumulados en distintos ciclos | −0.099 | −0.181 | 3 | +0.052 |
| [04 · Byte registrado](04_byte_registrado/design_1_wrapper_timing_summary_routed.rpt#L145) | Separar la selección del byte y la suma de comprobación | **+0.145** | **0.000** | **0** | **+0.027** |

## 00 · Diseño original

En el mismo ciclo, el índice de `calcular_centroides` seleccionaba la etiqueta, leía el grupo y habilitaba la carga del acumulado. La peor ruta iba de `indice_reg[1]` a `suma_x_registro_reg[23]/CE`. Vivado midió 11.087 ns en la ruta de datos, con un requisito de 8 ns.

[Captura del reporte](00_original/timing_vivado.png) · [Esquema de la ruta](00_original/esquema_ruta_critica.png) · [VHDL original](00_original/agrupar_pixeles.vhd)

La simulación repetida con el VHDL original pasó tanto las cinco escenas de agrupación como la comparación de las dos tramas de foto y lista. [Agrupación](00_original/grupos.log) · [UART simulado](00_original/uart.log)

## 01 · Lectura registrada

`agrupar_pixeles` registra la etiqueta de la tabla y, en el ciclo siguiente, registra los datos del grupo. `calcular_centroides` incorpora `ESPERAR_LECTURA` antes de evaluar el grupo válido. XSim entregó los mismos bytes para una foto con dos centroides y otra vacía. La peor ruta pasó al cálculo y la acumulación de `fila × luminancia` en `agrupar_pixeles`.

[Simulación](01_lectura_en_dos_ciclos/xsim.log) · [VHDL de cálculo](01_lectura_en_dos_ciclos/calcular_centroides.vhd) · [Nueva peor ruta](01_lectura_en_dos_ciclos/design_1_wrapper_timing_summary_routed.rpt#L241)

## 02 · Productos registrados

La ruta de 01 partía de `fila` y terminaba en la suma ponderada `sy`. En 02, `CALCULAR_PESO` guarda `x × Y` y `y × Y` como enteros sin signo. `ACUMULAR_DATOS` usa los productos registrados y añade un ciclo por píxel brillante aceptado. El resultado aritmético se conserva. Con el ajuste, la peor ruta pasó a la selección y actualización del acumulado dentro de la tabla de grupos. La ruta de datos de ese caso fue de 9.430 ns.

[RTL](02_productos_registrados/agrupar_pixeles.vhd) · [UART simulado](02_productos_registrados/xsim.log) · [Cinco escenas de agrupación](02_productos_registrados/grupos.log) · [Peor ruta de 02](02_productos_registrados/design_1_wrapper_timing_summary_routed.rpt#L241)

## 03 · Acumulados en BRAM

El índice `grupo_actual` seleccionaba y actualizaba acumulados de una tabla de registros en el mismo ciclo. Se trasladaron área y sumas a BRAM con lectura síncrona. Para unir grupos, `LEER_RAIZ` y `LEER_GRUPO_UNION` leen los operandos, `UNIR_ETIQUETAS` calcula el resultado y la memoria escribe el dato ya registrado. En la revisión final, `LEER_REVISION` prepara el dato para `CONSOLIDAR_GRUPOS`. Las etiquetas padre conservan el orden y las reglas de unión originales.

El uso del diseño completo bajó de 11 201 a 4 921 LUT y de 16 068 a 8 705 registros. Quedaron tres destinos con falla de setup. La peor ruta sale del índice de la lista y llega al acumulador del checksum en el UART de pruebas.

[RTL](03_tabla_en_bram/agrupar_pixeles.vhd) · [Utilización](03_tabla_en_bram/design_1_wrapper_utilization_placed.rpt#L35) · [Simulación](03_tabla_en_bram/grupos.log) · [Peor ruta de 03](03_tabla_en_bram/design_1_wrapper_timing_summary_routed.rpt#L240)

## 04 · Byte del UART registrado

El emisor de pruebas seleccionaba un byte de la lista y lo sumaba al checksum dentro del mismo ciclo. `PREPARAR_BYTE` registra el byte. `ENVIAR_BYTE` usa ese registro para transmitir y actualizar la suma cuando el UART está libre. XSim volvió a generar los mismos 153 676 bytes de las dos parejas STY1/STC1 de referencia.

El diseño final cumple las restricciones actuales. Hay cero destinos con falla de setup o hold y cero redes con error de ruteo. El camino con menor margen quedó entre la BRAM de grupos y el mapa de grupos, con +0.145 ns de slack. El uso final fue de 4 912 LUT, 8 702 registros y 25.5 BRAM36 equivalentes.

[RTL del emisor](04_byte_registrado/enviar_centroides_uart.vhd) · [UART simulado](04_byte_registrado/uart.log) · [Cinco escenas](04_byte_registrado/grupos.log) · [Estado de ruteo](04_byte_registrado/design_1_wrapper_route_status.rpt)

El reporte todavía señala 13 entradas y 5 salidas sin retardos externos definidos. La prueba de captura y centroides en la placa queda como validación física.

## Diagramas del diseño final

| Imagen | Tipo | Estados del RTL original → final |
|---|---|---:|
| [Detección de centroides](diagramas_finales/00_general.png) | Flujo entre los cuatro bloques | — |
| [Umbral y posición](diagramas_finales/01_umbral_posicion.png) | FSM | 7 → 7 |
| [Agrupación de píxeles](diagramas_finales/02_agrupar_pixeles.png) | FSM | 13 → 17 |
| [Cálculo de centroides](diagramas_finales/03_calcular_centroides.png) | FSM | 9 → 10 |
| [Lista de estrellas](diagramas_finales/04_lista_estrellas.png) | FSM | 3 → 3 |

El contorno turquesa de los estados intermedios marca los añadidos durante las correcciones. El UART de diagnóstico se mantiene fuera del diagrama general de centroides.
