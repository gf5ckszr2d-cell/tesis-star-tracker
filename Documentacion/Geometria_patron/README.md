# Geometría del patrón estelar

Antecedente de la distribución v1: su FOV central nominal contenía dos estrellas.
La distribución vigente v2 se ha diseñado para ocho estrellas a los mismos 25°
y 250 mm. Las ecuaciones de geometría se conservan; sus tablas de posiciones e ID
pertenecen a versiones distintas. La tabla vigente se presenta en la conversación
y en las exportaciones de `patron_sintetico.html`.

Informe acotado al paso de coordenadas de pantalla a coordenadas físicas y
píxeles esperados de cámara, en una pose fija. Conserva el patrón de 48 fuentes
y la semilla `20261119`. No modifica RTL, captura, UART ni identificación.
No estima cuaterniones ni afirma que se haya cargado una memoria en FPGA.

El cálculo usa los datos activos de Samsung LS27AG550ELXPE: 596,736 × 335,664 mm,
2560 × 1440 y 1000R. Interpreta provisionalmente el ancho publicado como arco.
La distancia de diseño es 250 mm. La imagen nominal es 320 × 240, consultada
en la configuración actual; este informe no cambia ninguna resolución.

**El FOV horizontal de 25° es una hipótesis previa del proyecto.** No se ha
identificado la ficha de la lente exacta del banco. La hoja del módulo
OV7670MFSL de OmniVision distingue el Chief Ray Angle de 25° del ángulo de
visión diagonal de 58°. No se transfieren esos 58° al módulo del banco.
La guía de implementación local no establece su FOV óptico.

Bajo el supuesto 25° horizontal, la huella contiene solo P21 y P28 a 250 mm.
El recorte digital anterior de ocho puntos no representa la captura física.
Las ecuaciones y las tablas se actualizan cuando se establezca el FOV nominal
correcto. Los escenarios alternativos de ocho centros no cambian el montaje
ni garantizan detección o fuentes completas lejos del borde.

## Archivos

- `Informe_geometrico.pdf`: copia final del informe, con vistas superior y
  lateral, ejemplo manual, proyección y comparación de centroides.
- `calcular_geometria.py`: cálculo reproducible sin dependencias externas.
- `generar_informe.py`: fuente del PDF, requiere ReportLab y las fuentes Arial
  y Consolas de Windows. En Codex se ejecuta con Python del runtime documental.
- `resultados_nominales/calculo.json`: resultados, parámetros y SHA-256 del
  JSON de referencia usado como entrada.
- `resultados_nominales/referencia_48.csv`: XYZ en mm, direcciones unitarias y
  píxeles proyectados de las 48 fuentes; incluye indicador de visibilidad.
- `resultados_nominales/referencia_visible_25cm_25grados.csv`: las dos fuentes
  dentro del campo nominal de 25°; no es una lista de detecciones medidas.
- `resultados_nominales/ocho_del_recorte_digital.csv`: las ocho del recorte
  anterior y su proyección real dentro o fuera del campo supuesto.
- `resultados_nominales/ocho_solo_distancia_alternativa.csv`: ocho centros
  del escenario matemático a 501,625 mm y 25°; no usar como referencia a 250 mm.

Las columnas `u_scaled_256` y `v_scaled_256` son enteros redondeados con ocho
bits fraccionarios. El eje horizontal 320 px necesita al menos 17 bits sin signo.
Se evita llamar Q8.8 de 16 bits a una coordenada que puede superar 255,996 px.
No hay archivo ROM nuevo ni integración de hardware en este cambio.

## Reproducción

Desde la raíz del repositorio:

```powershell
python Documentacion/Geometria_patron/calcular_geometria.py
python Documentacion/Geometria_patron/generar_informe.py
```

El primer script localiza la referencia en `Generador_G5/` o en su ubicación
anterior. Acepta `--referencia`, `--parametros` y `--out`. Para modificar el
modelo, copia `resultados_nominales/parametros.json` con otro nombre y cambia
los parámetros necesarios. `screen_width_convention` admite `arc` o `chord`.
Los nombres de las tablas nominales de 25 cm/25° describen la corrida inicial;
si cambias distancia o FOV, usa un directorio de salida distinto y consulta sus
parámetros JSON antes de usar las tablas. Se conserva el mismo patrón.

El script verifica la ecuación del cilindro, la norma de los rayos y la
reproyección inversa de las 48 fuentes. Son comprobaciones de cálculo;
la validación experimental requiere comparar con capturas independientes.
El PDF se renderiza a PNG para revisar todas las páginas antes de entregarlo.

## Fuentes

- [Samsung LS27AG550ELXPE](https://www.samsung.com/pe/monitors/gaming/odyssey-g5-g55a-27-inch-165hz-1ms-ls27ag550elxpe/).
- [OpenCV modelo de cámara](https://docs.opencv.org/4.x/d9/d0c/group__calib3d.html).
- [OmniVision OV7670MFSL v1.31](https://w2.electrodragon.com/Chip-dat/OmniVision-dat/OV7670-dat/OV7670-ds.pdf), pp. 1 y 9.
