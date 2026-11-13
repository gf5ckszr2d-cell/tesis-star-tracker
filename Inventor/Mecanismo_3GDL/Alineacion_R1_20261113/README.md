# Gimbal R1: alineación corregida

13 de noviembre de 2026. Corrección solicitada por Alexander, limitada a la
alineación geométrica. Se conserva íntegro el diseño recibido en `../Original`
y el paquete anterior en `../CAD_portable`.

**Abrir:** [CAD/Gimbal_3GDL_alineado_R1.iam](CAD/Gimbal_3GDL_alineado_R1.iam).
Las nueve referencias directas se resuelven dentro de `CAD/`.

## Cambios realizados

1. Añadido `Separador_pitch_0p8_R1.ipt` entre el segundo disco y el soporte
   `Base_Z:2`. Espesor 0,8 mm, diámetro exterior 20 mm, centro de 5,5 mm y
   cuatro pasos de 3 mm a radio 7 mm. Está vinculado mediante tres restricciones
   de origen al disco `Pieza6:2`. El desfase axial `Coincidencia:42` es ahora
   0,8 mm. El soporte y las etapas siguientes se desplazan sobre el eje pitch
   sin modificar la geometría del soporte ni del servo.
2. En la copia de `cajita.ipt`, desplazados los círculos de los bocetos traseros
   `Boceto2` y `Boceto4`: +1,86269768833 mm en X local y +0,14993302131 mm en Y
   local. Se liberaron las referencias proyectadas de esos círculos para permitir
   la corrección; los contornos y taladros frontales de la cámara se conservan.
   El patrón trasero queda centrado en X local = 0; Y local = 4,5 mm, alineado
   con el barril del lente del modelo recibido.
3. Se retiró la fijación al espacio de `cajita:1` para que el solver pueda situarla
   con sus restricciones. Se activó su restricción angular inicial a 0 grados
   para conservar una postura de referencia estática. Esta revisión no convierte
   el ensamblaje en una simulación de movimiento de tres articulaciones.

Los círculos modificados conservan sus diámetros. La cámara, servos, discos,
base, soportes principales y modelos de tornillos mantienen sus archivos fuente.
No se ha modificado RTL, control de motores ni hardware físico.

## Comprobación después de guardar y volver a abrir

| Comprobación | Antes | R1 |
|---|---:|---:|
| Distancia mínima entre ejes 1 y 3 | 0,8000 mm | Menor de 0,00001 mm |
| Distancia del barril del lente al eje 3 | 1,8687 mm | Menor de 0,00001 mm |
| Centro común de los tres ejes | No existía | (10,15; 114,50; 0) mm |
| Referencias directas resueltas | 8 | 9, incluida la pieza nueva |
| Ocurrencias / restricciones | 39 / 88 | 40 / 91 |
| Pares con solapamiento en postura inicial | 23 | 23; mismos pares, sin nuevos |

Las direcciones son ortogonales en la postura de referencia. La tolerancia de
0,00001 mm es un umbral de comprobación numérica del CAD, **no una tolerancia
de fabricación ni precisión física**. El eje del barril modelado se usa como
referencia geométrica; no se ha medido el eje óptico real o la pupila de entrada.

Las operaciones del portacámara y separador se actualizaron correctamente y
presentan un sólido por pieza. Las 91 restricciones del conjunto están
actualizadas. Se verificaron nuevamente las referencias y la alineación tras
cerrar y abrir el ensamblaje guardado.

## Captura real e imagen explicativa

- [Captura_real_Inventor_Gimbal_R1.jpg](Captura_real_Inventor_Gimbal_R1.jpg): captura
  real de la ventana de Inventor, obtenida mediante Computer Use. Sin líneas
  añadidas ni edición de sus píxeles. Se conservan los bytes JPEG originales
  entregados por la herramienta de captura.
- [Gimbal_R1_ejes_anotados_generada.png](Gimbal_R1_ejes_anotados_generada.png):
  imagen generada a partir de esa captura con el generador integrado, añadiendo
  ejes X/pitch, Y/yaw y Z/roll y señalando su centro común. Es una ilustración
  explicativa; no se utiliza para medir distancias, certificar píxeles idénticos
  al original ni reemplazar la comprobación del modelo.

Las direcciones y el centro empleados en el prompt provienen de la proyección
de puntos 3D leída de la vista real de Inventor. Se guardan en
`Control/proyeccion_captura.txt`; el prompt íntegro está en
`Control/prompt_imagen_generada.txt`. La cámara es ortográfica.

Ambas imágenes se subieron a la raíz de **Mi unidad**, por solicitud de Alexander:

- [Captura real en Drive](https://drive.google.com/file/d/1p2vUWCpcso_LGCPQLD9N-qw9rfOWun1k/view?usp=drivesdk).
- [Imagen con ejes en Drive](https://drive.google.com/file/d/12W0AYg630zUSrNeJwsVyucaAwNMULdqt/view?usp=drivesdk).

Los nombres, tamaños e identificadores se comprobaron con una lectura de
metadatos después de cada subida. No se cambió la configuración de acceso.

## Límite de esta corrección

**Alineación CAD corregida; banco físico todavía no validado.** El separador
reduce en 0,8 mm la longitud disponible de los tornillos en ese acople respecto
al montaje sin separador: se debe verificar el apoyo y enganche reales antes
de fabricar/armar. La selección final de longitud no se ha cambiado en el CAD.

Se mantienen los 23 solapamientos anteriores, incluidos tres pares servo/disco
que requieren revisar el acople real. No se ha comprobado el barrido completo,
rigidez, repetibilidad, velocidad ni exactitud angular de los servos. Esas tareas
continúan pendientes, conforme a `../REVISION_BANCO.md`.

## Evidencia y reproducción

`Control/correccion.txt` registra operaciones, alineación e interferencias.
`Control/verificacion_reapertura_y_vista.txt` registra la comprobación del
ensamblaje guardado, sus nueve referencias locales y la vista preparada.
`Control/verificacion_R1.json` resume distancias y conservación de archivos.

`Corregir_alineacion.ps1` se ejecuta sobre una copia nueva del paquete recibido,
con los diez `.ipt` en `CAD/` y el `.iam` original copiado como
`Gimbal_3GDL_alineado_R1.iam`. No debe ejecutarse otra vez sobre esta revisión
terminada: se detiene si encuentra el separador para impedir correcciones dobles.
La carpeta `CAD/OldVersions/` contiene reservas locales automáticas de los
ensayos de edición; no se versiona. Las versiones históricas del usuario siguen
preservadas en `../Original/OldVersions/`.
