# Deteccion y centroides con BRAM como frontera

## Finalidad

Este hito extiende el sistema despues de la captura completa sin alterar el protocolo UART validado. Todo el procesamiento operativo se implementa en VHDL. Python puede analizar capturas fuera del FPGA, pero no participa en la ruta normal.

## Seleccion de modo

El valor de `SW8` se sincroniza y se fija al armar cada captura:

- `SW8=0`: la BRAM es recorrida por `frame_star_centroid`; al terminar, el frame queda liberado para una captura futura.
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
| Formato de centroide | Q8.8, 18 bits | Conservar fraccion subpixel sin punto flotante |

Estos valores son parametros de ingenieria iniciales, no una calibracion astronomica definitiva. Deben ajustarse con capturas reales sin cambiar la arquitectura del hito.

## Interfaces y continuidad futura

`frame_star_centroid` deja una interfaz interna de resultados lista para una etapa VHDL posterior. Las señales se preservan con `MARK_DEBUG` para poder observarlas mediante ILA aunque todavia no exista el consumidor siguiente. No se reutiliza el UART para ellas.

Quedan fuera de este hito la identificacion estelar, el catalogo de estrellas y la estimacion de actitud.

## Verificacion realizada

- XSim unitario con dos componentes sinteticos, incluyendo union diagonal, areas, intensidades y centroides Q8.8 conocidos.
- Regresion global del modo diagnostico para comprobar que `STY1`, 160x120, 19 200 bytes y checksum permanecen iguales.
- Sintesis para Nexys A7-100T con comprobacion CDC y reportes de utilizacion/timing.
- No se genera bitstream en este hito; la validacion fisica del nuevo modo normal queda pendiente.
