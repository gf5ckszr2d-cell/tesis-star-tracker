# Cableado OV7670 - Arty Z7-10

Vista de la camara exactamente como la foto aportada: lente a la derecha y
conector a la izquierda, con 3.3V/GND arriba. No invertir esta vista al enchufar.
Seguir la numeracion fisica del conector JA/JB de la placa, no adivinar izquierda
y derecha al girar la placa. JA1 significa pin fisico 1, no el nombre de par JA1_P.

| Fila de senales | Columna izquierda camara | JA fisico | Columna derecha camara | JB fisico |
|---:|---|---:|---|---:|
| 1 | SCL | 1 | SDA | 1 |
| 2 | VS / VSYNC | 2 | HD / HREF | 2 |
| 3 | PCLK | **7 (MRCC)** | MCLK / XCLK | 3 |
| 4 | D7 | 4 | D6 | 4 |
| 5 | D5 | **3** | D4 | 7 |
| 6 | D3 | 8 | D2 | 8 |
| 7 | D1 | 9 | D0 | 9 |
| 8 | RST de la camara | 10 | PWDN | 10 |

Se conserva el orden por columnas, salvo PCLK y D5 intercambiados dentro de JA
para que PCLK entre por JA7/U18 (MRCC positivo). JB conserva el orden completo.
No cruzar senales entre JA y JB.

```text
Numeracion del Pmod (usar la marca de pin 1 de la placa):
 1   2   3   4   5=GND   6=3.3V
 7   8   9  10  11=GND  12=3.3V
```

La camara de la foto indica 3.3V: conectar a 3.3 V y GND, por ejemplo los
contactos de alimentacion del Pmod. No conectar 5 V ni usar un GPIO para alimentar.
Comprobar que SDA tenga el pull-up a 3.3 V del modulo; el XDC agrega uno debil.

BTN0 (D19) -> rst del core, activo alto. BTN1 (D20) -> start, activo alto.
RST de la camara es otra senal: la maneja cam_reset en JA10; no unirla directamente
al pulsador de reset ni al pin de reset del procesador.

## Cargar los constraints

Con el proyecto correcto abierto en la Tcl Console:

```tcl
source {C:/Users/alexa/tesis-star-tracker/pruebas_arty_z7/captura_ov7670/scripts/add_constraints.tcl}
```

Agrega solo camara_botones_arty_z7.xdc y retira la referencia a la antigua
excepcion de ruteo si estaba cargada. Puede repetirse sin duplicar archivos.
Para el top VHDL tambien restablece el generic
CLK_FREQ_HZ=100000000 sin cambiar el baud ni otros generics.

En la integracion de Zynq, hacer externos los puertos de camara y los botones
con los nombres EXACTOS del XDC (cam_data como vector [7:0], SDA, SCL, etc.).
clk recibe internamente FCLK_CLK0 a 100 MHz. tx va internamente al RX de AXI UART
Lite. No se les asigna un pin PL. El core y AXI UART Lite deben compartir baud.
Estos XDC no convierten por si solos el proyecto RTL en un diseno Zynq integrado:
todavia faltan esas conexiones, que Alexander configurara en Vivado.

## Entrada dedicada de reloj

PCLK se conecta a JA7/U18, entrada MRCC positiva. D5 pasa a JA3/Y16.
No se aplica CLOCK_DEDICATED_ROUTE FALSE ni se necesita un segundo XDC.
Si ya estaba cableada la version anterior, intercambiar esos dos cables.

El periodo declarado de PCLK es un presupuesto de hasta 24 MHz, no una medicion.
No se inventan input/output delays ni false paths para ocultar violaciones;
el timing de la interfaz y CDC debe revisarse en el diseno integrado final.

Referencia oficial de pines:
https://github.com/Digilent/digilent-xdc/blob/master/Arty-Z7-10-Master.xdc
