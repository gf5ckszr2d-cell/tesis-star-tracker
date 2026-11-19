# Escena de referencia para identificación

La imagen fija del monitor es el **estímulo**, no el catálogo por sí sola. El CSV conserva
la correspondencia entre cada punto dibujado y su estrella Hipparcos (HIP, AR, Dec,
magnitud V y vector unitario ICRS), además de su centro en píxeles del G5. Así las
simulaciones posteriores pueden comprobar identificadores y geometría sin depender
del entorno mecánico ni de una calibración física todavía pendiente.

`orion_base/` congela los valores iniciales de `engine.js`: centro 83,8° AR,
−5,4° Dec, magnitud límite 6,5, monitor 2560 × 1440 y referencia óptica
inicial de 50 cm/25°. El PNG es exactamente el buffer Y8 del patrón, sin menú,
líneas ni etiquetas; `manifest.json` guarda parámetros, procedencia y SHA-256.
La escena contiene **642 estrellas en pantalla**. El FOV central inicial abarca
**181 centros geométricos**, no 181 detecciones garantizadas. Esta cifra supera
la capacidad actual de 64 entradas de `star_list_buffer`; por ello, antes de
usar esta escena para identificación RTL se debe definir y simular una política
reproducible de selección de estrellas observables, o una escena menos densa.
No se debe asumir que el detector retiene las 64 más brillantes: hoy conserva
hasta 64 resultados en orden de emisión.

## Imagen de trabajo elegida para la lista de 64

`orion_25cm_m5_v1/` es la candidata de diseño para continuar la tesis. Conserva
Orión (AR 83,8°, Dec −5,4°), G5 2560 × 1440 y FOV horizontal 25°, pero fija
la referencia a 25 cm, limita Vmag a 5,0, usa claridad provisional 100% y
radio aparente 8 px. Es **una imagen nueva y estática**, no un zoom de
`orion_base`. Contiene 294 estrellas HIP en todo el panel.

El test `tests/reference_catalog_checks.mjs` comprueba la imagen y el CSV y
explora orientaciones con yaw −70°..70° y pitch −36°..36°:

- En 3 553 poses de paso 1° con el FOV completo dentro del panel: 9..46
  centros geométricos por captura. El máximo deja 18 entradas de margen
  respecto a `star_list_buffer` (64).
- En una muestra de 141 poses de paso 5°, la vista QQVGA sintetizada y una
  aproximación por componentes 8-conectados con `Y >= 45` y área 2..500
  producen 9..40 objetos. Esto **no es XSim del detector** ni garantiza
  detecciones físicas: exposición, ruido, foco y respuesta del G5/OV7670
  todavía pueden modificar conteos y causar overflow.

La claridad al 100% es una elección para el estímulo sintético y mantiene
orden de brillo, pero **no calibra magnitudes astronómicas con Y de cámara**.
Si cambian distancia, FOV, magnitud límite o fotometría, se debe crear otra
imagen y su CSV/manifest juntos. La lista de 64 limita estrellas observadas
por frame, **no** las 294 entradas posibles del futuro catálogo FPGA.

Regenerar otra escena desde un JSON exportado por la interfaz G5:

```powershell
node Simulador_cielo_G5/tools/export_reference_scene.mjs --config C:\ruta\g5_star_sim_....json --out Simulador_cielo_G5/catalogo_referencia/nueva_escena
```

El exportador comprueba versión, origen Hipparcos y hash de escena, y rechaza
sobrescribir un directorio existente. Si se cambia una configuración que
modifica la imagen, se genera una nueva escena; no se altera `orion_base`.
El preset elegido también puede regenerarse en un directorio nuevo con
`--preset orion_25cm_m5_v1 --out <directorio_nuevo>`.
Los controles de cámara que solo desplazan el FOV no cambian el catálogo de
puntos del monitor. El estado de esta escena es `SIMULATED_UNCALIBRATED`.

Esta preparación no crea aún una ROM VHDL ni implementa identificación o actitud.
El identificador futuro deberá consumir la lista indexada de centroides existente
y contrastarla con una representación cuantizada y acotada del catálogo.
