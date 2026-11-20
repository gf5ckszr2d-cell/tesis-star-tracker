# ROM del patrón central para la primera prueba

Código independiente, todavía sin instanciar en el proyecto Vivado ni cargar
en una placa. No añade matching ni modifica captura, centroides o UART.

## Referencia fija

`rtl/patron_central_pkg.vhd` contiene las dos fuentes centrales que entran con
el modelo anterior: cámara centrada a 250 mm, imagen 320 × 240, FOV horizontal
**supuesto** de 25°, patrón fijo `sintetico48-s20261119-d24-l255`. El FOV exacto
de la lente sigue pendiente; esta es una referencia nominal para calibrar después.
El recorte digital de ocho no se transforma en ocho entradas de ROM.

El origen XY es el **centro del píxel inferior izquierdo**, con X hacia la
derecha e Y hacia arriba. X e Y son `unsigned(16 downto 0)` con ocho bits
fraccionarios: se divide entre 256 para obtener píxeles. No son coordenadas XYZ.
Los datos XYZ y las distancias físicas desde la esquina del panel permanecen en
el cálculo geométrico; `referencia_rom.csv` conserva también esa referencia física.

| Dirección | Fuente | X en píxeles | Y en píxeles | X × 256 | Y × 256 |
|---|---|---:|---:|---:|---:|
| 0 | P21 | 263,037113 | 175,833511 | 67338 | 45013 |
| 1 | P28 | 105,968716 | 63,945488 | 27128 | 16370 |

La ROM entrega las coordenadas cuantizadas por redondeo. Se conserva la precisión
del cálculo en el CSV. Las direcciones 2–63 o `habilitar=0` entregan `valido=0`
y campos cero en el siguiente flanco. La lectura es síncrona y registrada.
Una tabla tan pequeña puede sintetizarse en LUT; no se fuerza BRAM física.
Para síntesis se añaden, en este orden, paquete, ROM y adaptador de `rtl/`.
La selección de placa, instanciación y conexiones se harán después.

## Los centroides ya dan XY

Se consultaron `calcular_centroides.vhd`, `umbral_posicion.vhd` y
`lista_estrellas.vhd` actuales de `Tesis_definitiva`. El cálculo entrega
`x_c = floor(256·suma(x·Y)/suma(Y))` y análogamente para `y_c`. El origen
existente es superior izquierdo; la lista guarda estas coordenadas sin identificar
la fuente Pxx. El índice de lista es un orden de resultados, no un ID del patrón.

`rtl/coordenadas_inferior_izquierda.vhd` adapta esas salidas sin cambiar el
detector: `x=x_c`, `y=(ALTO_IMAGEN−1)·256−y_c`. En esta imagen se usa 239,
no 240. Comprueba límites y validez para impedir un desbordamiento al restar.
Es combinacional y sus genéricos permiten también 160 × 120 sin cambiar la ROM
320 × 240. Una ROM para otra resolución debe regenerarse con su referencia.

Un centroide da la posición de una región detectada; para saber sus XY no se
necesita matching. Asignarle P21/P28 requiere una correspondencia, que en esta
primera toma fija puede revisarse manualmente. No se implementa identificación.

## Sensibilidad a distancia y giro

`evaluar_error_pose.py` mantiene congelada la ROM y calcula en PC qué desviaciones
se esperan para 240 mm y para yaw, pitch y roll de ±1° y ±2°, además de un caso
combinado. Usa la geometría curva completa y la traslación del centro óptico.
El giro de cámara es `R=Ry(yaw)·Rx(pitch)·Rz(roll)` en los ejes de cámara
X derecha, Y abajo, Z hacia el panel. Los puntos se transforman con `R^T`.
Yaw positivo mira a la derecha; pitch positivo mira hacia arriba. No hay giros
automáticos del patrón ni regeneración de la ROM durante el barrido.

El CSV por stdout separa el desplazamiento geométrico del error respecto a los
enteros de la ROM, que incluye cuantización; marca fuentes que salen del campo
y cuenta todos los centros visibles de las 48 fuentes. Son predicciones del
modelo, no errores ópticos medidos ni una tolerancia aprobada. La referencia
permanece en píxeles; no se pretende reconstruir profundidad desde un centroide.

```powershell
python ROM_patron_central/generar_rom.py
python ROM_patron_central/evaluar_error_pose.py
python -m unittest discover -s ROM_patron_central/tests -p "test_*.py"
& C:/AMDDesignTools/2025.2/Vivado/bin/vivado.bat -mode batch -nojournal -nolog -source ROM_patron_central/scripts/xsim_rom_patron_central.tcl
```

El testbench verifica la ROM, todas las direcciones inválidas y el adaptador.
Además instancia el `calcular_centroides` existente con un grupo de tres píxeles
de igual luminancia en (4,231), (5,231) y (6,231): demuestra que entrega (5,231)
y que el adaptador lo presenta como **X=5, Y=8** desde abajo. Es una prueba
digital de código, sin afirmar una captura óptica ni programación de FPGA.
