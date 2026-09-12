# Deteccion y centroides con BRAM como frontera

## Finalidad

Este hito extiende el sistema despues de la captura completa sin alterar el protocolo UART validado. Todo el procesamiento operativo se implementa en VHDL. Python puede analizar capturas fuera del FPGA, pero no participa en la ruta normal.

## Seleccion de modo

El valor de `SW8` se sincroniza y se fija al armar cada captura:

- `SW8=0`: la BRAM es recorrida por `frame_star_centroid`; sus resultados se guardan en `star_list_buffer` y, al terminar, el frame queda liberado para una captura futura.
- `SW8=1`: la BRAM es recorrida exclusivamente por `frame_uart_dump`; se envia el paquete `STY1` y el pipeline termina ahi.

Los consumidores no leen la BRAM al mismo tiempo. El framebuffer conserva un puerto de escritura en `cam_pclk` y un puerto de lectura en el reloj de sistema; el top multiplexa la direccion del puerto de lectura segun el modo fijado.

## Algoritmo VHDL post-BRAM

1. Esperar el evento que indica frame completo.
2. Recorrer en orden row-major las 19 200 direcciones de la BRAM.
3. Clasificar como primer plano cada pixel con `Y >= threshold`.
4. Etiquetar componentes de 8 vecinos usando solo izquierda, arriba-izquierda, arriba y arriba-derecha, que son los vecinos ya recorridos.
5. Resolver equivalencias de etiquetas y acumular por componente:
   - area;
   - `sum(Y)`;
   - `sum(x * Y)`;
   - `sum(y * Y)`.
6. Rechazar componentes fuera del intervalo de area configurado.
7. Calcular secuencialmente los centroides ponderados:

```text
cx_Q8.8 = (sum(x * Y) * 256) / sum(Y)
cy_Q8.8 = (sum(y * Y) * 256) / sum(Y)
```

8. Emitir un pulso `star_valid` por componente aceptado. La salida contiene indice, centroide X/Y, area e intensidad.
9. Guardar X, Y, area e intensidad en la lista de estrellas y publicar `star_count` al finalizar el frame.

La seleccion de la menor raiz vecina se hace en cuatro ciclos, uno por vecino. Esta decision reduce la profundidad combinacional y permite cerrar 100 MHz sin cambiar el resultado matematico.

## Parametros iniciales del top

| Parametro | Valor | Finalidad |
|---|---:|---|
| Resolucion | 160x120 | Mantener QQVGA y el framebuffer existente |
| Umbral Y | 45 | Punto de partida para separar fuentes brillantes |
| Conectividad | 8 | Unir diagonales que pertenecen a la misma estrella |
| Area minima | 2 pixeles | Rechazar impulsos aislados |
| Area maxima | 500 pixeles | Rechazar regiones excesivamente grandes |
| Etiquetas provisionales | 64 | Limitar recursos y detectar saturacion explicitamente |
| Capacidad de la lista | 64 estrellas | Coincidir con el maximo actual del detector |
| Formato de centroide | Q8.8, 18 bits | Conservar fraccion subpixel sin punto flotante |

Estos valores son parametros de ingenieria iniciales, no una calibracion astronomica definitiva. Deben ajustarse con capturas reales sin cambiar la arquitectura del hito.

## Interfaces y continuidad futura

`star_list_buffer` usa una matriz RTL inferida de 64 palabras por 75 bits. No contiene atributos que fuercen BRAM, LUTRAM o registros. La palabra se distribuye asi:

| Bits | Campo | Ancho |
|---|---|---:|
| 74:57 | Centroide X Q8.8 | 18 |
| 56:39 | Centroide Y Q8.8 | 18 |
| 38:24 | Area | 15 |
| 23:0 | Intensidad acumulada | 24 |

El puerto de lectura es sincrono: se aplica `rd_index` y, un ciclo despues, `rd_valid` y los cuatro campos indican la entrada solicitada. La lista solo se presenta como valida despues de `frame_done`. Al comenzar un frame nuevo se reinician el conteo, `list_ready` y `overflow`; no se borra fisicamente la matriz porque el conteo invalida logicamente los datos anteriores. Una estrella posterior a la entrada 64 activa `overflow` sin escribir fuera de rango.

Esta interfaz queda lista para una etapa VHDL posterior. Sus senales se preservan con `MARK_DEBUG` para poder observarlas mediante ILA aunque todavia no exista el consumidor siguiente. No se reutiliza el UART para ellas.

Quedan fuera de este hito la identificacion estelar, el catalogo de estrellas y la estimacion de actitud.

## Verificacion realizada

- XSim unitario del buffer con cero, una, varias y 64 estrellas, lectura individual, reemplazo entre frames y overflow.
- XSim integrado detector-buffer con dos componentes sinteticos, incluyendo union diagonal, areas, intensidades y centroides Q8.8 conocidos.
- Regresion global del modo diagnostico para comprobar que `STY1`, 160x120, 19 200 bytes y checksum permanecen iguales.
- Sintesis para Nexys A7-100T con comprobacion CDC y reportes de utilizacion/timing.
- No se genera bitstream en este hito; la validacion fisica del nuevo modo normal queda pendiente.
