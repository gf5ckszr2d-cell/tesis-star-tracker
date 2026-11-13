# Revisión del gimbal para el banco de pruebas

Fecha: 13 de noviembre de 2026. Objeto: mecanismo encontrado en
`OneDrive/Documentos/Mecanismo para tesis`. Revisión de sus cinco planos y del
ensamblaje completo mediante la API de Inventor 2027.2. El objetivo confirmado
por Alexander es cambiar el banco de cámara fija a un gimbal de tres grados de
libertad. Esta revisión registra esa decisión; no actualiza el manuscrito ni RTL.

## Dictamen

**El diseño es una base aprovechable para un prototipo de orientación de cámara,
pero todavía no cumple como banco de referencia angular validado.** Tiene tres
etapas rotatorias y una estructura compacta. Falta convertir el ensamblaje estático
en un modelo de movimiento verificable, cerrar alineación y encajes, y medir el
ángulo real con incertidumbre suficiente para el ensayo del Star Tracker.

No hay evidencia de fabricación, precisión angular, repetibilidad, tiempo de
asentamiento, velocidad uniforme ni estabilidad óptica medida. La existencia de
CAD y planos no acredita esas prestaciones.

## Lo comprobado

| Aspecto | Evidencia y resultado | Alcance |
|---|---|---|
| Archivos recibidos | 16 originales, 4.330.943 bytes, con versiones anteriores; SHA-256 idéntico | Copia preservada |
| Dependencias | Cuatro piezas externas recuperadas: cámara, servo y dos tornillos | Ocho referencias directas resueltas dentro de `CAD_portable` |
| Ensamblaje | 39 ocurrencias, 88 restricciones, cero objetos `AssemblyJoint` | Las restricciones también pueden representar articulaciones; cero joints no implica cero movilidad física |
| Componentes según planos | Tres MG996R, tres discos metálicos 25T, dos soportes laterales PETG, base PETG, portacámara PETG y OV7670 | Materiales y componentes declarados; no inspección del ejemplar físico |
| Tamaño del conjunto CAD | X: 124,60 mm; Y: 134,50 mm; Z: 115,10 mm, en la postura guardada | No incluye envolvente de movimiento ni cableado |
| Movilidad guardada | Base y `cajita:1` fijadas; las tres etapas presentan cero giros disponibles | El ensamblaje está posicionado/bloqueado |
| Diagnóstico sin guardar | Al liberar `cajita:1` y suprimir las restricciones angulares, cada etapa reporta un giro y cero traslaciones; actualización correcta | Indicio favorable de la arquitectura 3R; no demuestra barrido completo ni independencia en todo el espacio de trabajo |
| Interferencias estáticas | 23 pares con volumen común en la postura guardada | Clasificación pendiente; no se interpretan todos como choque físico |

La lista de componentes de los planos comprende 39 instancias: 1 base + 12 M3x10
+ 2 soportes + 16 M3x5 + 3 servos + 3 discos + 1 portacámara + 1 cámara. Coincide
con el conteo del ensamblaje.

## Ejes y alineación

En coordenadas del ensamblaje, los ejes de salida identificados por las
restricciones `Coincidencia:36`, `:38` y `:40` son aproximadamente:

| Etapa | Recta del eje, en mm | Interpretación en postura inicial |
|---|---|---|
| 1 | X = 10,15; Z = 0; dirección Y | Giro de base, yaw |
| 2 | Y = 114,50; Z = 0; dirección X | Giro intermedio, pitch |
| 3 | X = 9,35; Y = 114,50; dirección Z | Giro final, roll nominal |

Son direcciones ortogonales en esta postura. Los ejes 1 y 2 se cortan; los ejes
2 y 3 también. Los ejes 1 y 3 tienen **0,80 mm de separación mínima**: los tres
no pasan por un único punto. Es una cadena 3R casi concurrente, no un gimbal
esférico ideal. Esto no impide orientar la cámara, pero hay que decidir si se
corrige mecánicamente o se modelan sus traslaciones.

Tres superficies cilíndricas del modelo de cámara, de radios 6, 7 y 7,8 mm,
comparten eje paralelo a Z y pasan por X = 7,4873; Y = 114,6499 mm. Ese eje del
barril del lente queda a **1,8687 mm del eje de giro final**. No es una medición
del eje óptico real ni de la pupila de entrada, pero revela una excentricidad
geométrica que merece corregirse o calibrarse.

Con esa excentricidad, un giro ideal de roll desplazaría transversalmente la
línea del barril una cuerda `d = 2 e sin(|roll|/2)`. Como ejemplo geométrico, para
10 grados resulta d ≈ 0,326 mm; a 250 mm representa una escala angular de
aproximadamente 0,075 grados. Para 90 grados: d ≈ 2,643 mm y 0,606 grados.
Estos valores son ilustrativos, calculados con la distancia nominal de la
documentación anterior; no son errores medidos del Star Tracker ni sustituyen
una proyección completa del panel. Muestran por qué la traslación importa
cuando la escena está cerca.

**Acción recomendada:** centrar el eje del barril respecto al tercer eje y hacer
concurrir los tres ejes cerca de la pupila de entrada, o calibrar una transformación
rígida por etapa incluyendo desplazamientos. También debe distinguirse el centro
de giro del centro de masas: el primero determina la geometría óptica; el segundo,
las cargas gravitatorias y el esfuerzo de los servos.

## Encajes e interferencias

Los tres solapamientos de mayor volumen son:

| Par | Volumen común CAD |
|---|---:|
| Servo MG996R:3 / Pieza6:3 | 120,215 mm³ |
| Servo MG996R:2 / Pieza6:2 | 50,352 mm³ |
| Servo MG996R:1 / Pieza6:1 | 50,352 mm³ |

Los otros veinte corresponden a tornillos con soportes o cámara, con volúmenes
aproximados de 0,14938 mm³ o 0,0000436 mm³. Pueden provenir de la representación
de roscas, diámetros nominales o imprecisiones geométricas. Los tres pares
servo/disco también pueden incluir una representación simplificada del acople
estriado. **Se deben revisar mediante sección y dimensiones del servo/disco
real; el análisis automático no permite aprobar ni rechazar esos encajes.**

No se hizo barrido de colisiones durante el movimiento. Antes de fabricar o
alimentar el conjunto hay que verificar cada eje, combinaciones de los tres,
extremos, tornillos salientes, acceso para montaje, visión libre del lente y
bucles del cable. Definir límites por la geometría real y el servo concreto;
no asumir 180 grados utilizables ni rotación continua.

## Rigidez y fabricación

El soporte lateral del plano tiene espesor nominal de 3 mm y ancho de 25 mm;
base y portacámara muestran paredes de 2 mm. Es una arquitectura liviana con
cargas en voladizo sobre los acoples de servo. Puede servir como prototipo,
pero el CAD no demuestra que la flexión, vibración o histéresis sean pequeñas
frente al presupuesto angular.

Conviene fijar la base a una plataforma rígida, aliviar la tracción del cable
de cámara y evaluar apoyo opuesto con rodamiento si la flecha/repetibilidad
lo exige. Medir primero para dimensionar refuerzos. La comprobación de par debe
incluir masas y brazos reales, gravedad en el peor caso, aceleraciones, fricción
y cableado; no utilizar el par de bloqueo como par continuo admisible.

Los planos declaran tolerancia general ±0,01 mm y acabado N6 en piezas señaladas
como PETG. Esas exigencias no están justificadas para la fabricación propuesta:
hay que definir tolerancias por función, ajustes, orientación de impresión y
verificación dimensional. Los pasos nominales de 3 mm deben distinguir taladro
pasante, rosca o inserto. La altura y el espesor del montaje del servo deben
permitir los M3x10/M3x5 reales. No se certificó impresión ni ajuste físico.

También debe revisarse la coherencia entre cotas y modelo: la base CAD mide
70 × 60 × 42 mm, mientras la cadena vertical 20 + 21 + 20 del plano de planta
suma 61 mm. Además, el cajetín indica revisión `26/09/27` y documento
`MEC-2027-1`, aunque los archivos son de septiembre de 2026. Se conservó el PDF
original sin corregirlo.

## Ángulo de referencia y control

La ficha primaria de [TowerPro MG996R](https://towerpro.com.tw/product/mg996r/),
consultada el 13/11/2026, publica 55 g, 4,8-6,6 V, par de bloqueo de
9,4 kgf·cm a 4,8 V y 11 kgf·cm a 6 V, y banda muerta de 1 microsegundo.
**No establece una garantía de precisión angular absoluta o repetibilidad
para el banco.** La banda muerta temporal no se convierte en grados sin medir
la relación pulso-ángulo del ejemplar, y no incluye todos los errores del acople.

Los MG996R pueden conservarse para accionar el prototipo. Para validar una meta
angular exigente, el ángulo ordenado por PWM no debe utilizarse como si fuera
el ángulo verdadero. El servo cierra su propio lazo interno; el banco necesita
una referencia accesible e independiente, por ejemplo encoders por eje o una
medición óptica externa calibrada. Una IMU sin caracterización de sesgo y deriva
tampoco constituye por sí sola esa referencia. El Star Tracker bajo ensayo no
debe ser la única fuente con la que se evalúe su propio error.

La meta previa de actitud de 0,1 grados es preliminar en
`Documentacion/tesis/matrices/parametros.tex` (P-11), y sigue pendiente el cierre
del presupuesto. La incertidumbre del banco debe recibir una fracción explícita
de esa meta, incluyendo sensor de referencia, alineación, juego, flexión y
sincronización. No se fija aquí una precisión de encoder ni una compra.

Para ensayos dinámicos debe medirse velocidad real y variación, no inferir
movimiento uniforme de una secuencia PWM. Comenzar con ensayo estático:
ordenar posición, esperar asentamiento medido, registrar ángulos y después
capturar. La alimentación de los tres servos se debe dimensionar con corriente
medida/margen y distribución adecuada; no suponer que la salida de la FPGA
alimenta motores. La señal y la potencia requieren una interfaz definida.

## Escena del banco con gimbal

Si se conserva una pantalla a distancia finita, girar la cámara cambia el área
observada, la perspectiva y, cuando el centro óptico se traslada, las direcciones
de las fuentes. Hay que modelar panel, cámara y gimbal en un sistema de coordenadas
común. Para cada fuente, la dirección física se obtiene desde la posición real
de la cámara hasta el punto del panel, no desde la actitud ordenada solamente.
Si el monitor es curvo, incluir su superficie calibrada.

No basta con conservar el patrón usado para cámara fija y asociarlo directamente
a los tres comandos de servo. Es posible trabajar con campos de giro limitados
y geometría calibrada; una escena colimada sería otra arquitectura y requeriría
su propio diseño. La selección de escena y recorrido queda pendiente.

Para el marco de referencia registrar orden de rotaciones, signos, ceros,
alineación inicial y transformación entre cámara y último eje. Cerca de la
singularidad de una cadena de yaw-pitch-roll no puede suponerse que los tres
comandos equivalen a tres giros independientes del espacio. Limitar el recorrido
de ensayo y comprobar el condicionamiento de la cinemática seleccionada.

## Orden propuesto para cerrar el diseño

1. Conservar este diseño recibido y crear una revisión CAD de trabajo. Dejar fija
   solamente la base y definir tres articulaciones controlables con límites.
2. Corregir o justificar los 0,80 mm entre ejes y 1,8687 mm entre barril y roll.
   Definir centro óptico real y sistema de coordenadas.
3. Revisar los tres acoples servo/disco, tolerancias, fijación de base y cableado.
   Completar barrido de colisiones y acceso de montaje en todo el recorrido útil.
4. Cerrar cargas, rigidez y referencia angular independiente. Elegir la precisión
   necesaria mediante el presupuesto del banco antes de seleccionar sensores.
5. Ensayar repetibilidad con acercamiento desde ambos sentidos, retorno a cero,
   deriva en reposo y asentamiento, en varias posiciones y cargas. Registrar por
   separado sesgo, dispersión, histéresis e incertidumbre de la referencia.
6. Calibrar geometría cámara-panel-gimbal y realizar capturas estáticas. Después,
   caracterizar movimiento a las velocidades requeridas y sincronización.
7. Actualizar los capítulos del banco con el diseño confirmado, componentes,
   métricas y evidencia real. No presentar esta inspección CAD como validación
   experimental.

## Trazabilidad

- `Original/PLANITOS.pdf`: cinco hojas completas inspeccionadas visualmente.
- `Revision_20261113/inspeccion_CAD.txt`: referencias, dimensiones, restricciones,
  grados de libertad e interferencias de la postura guardada.
- `Revision_20261113/revision_ejes.txt`: cilindros del lente y diagnóstico de
  movilidad exclusivamente en memoria; cierre sin guardar.
- `Revision_20261113/verificacion_paquete.json`: cálculos reproducibles y copias
  comprobadas mediante `Verificar_paquete.py`.
- `Revision_20261113/manifest_originales.json` y `manifest_dependencias.json`:
  procedencia y hashes de los archivos recibidos.

Las pruebas realizadas son de integridad de archivos y geometría CAD. No se
ejecutó simulación RTL, programación de placa, accionamiento de servos ni ensayo
óptico físico.
