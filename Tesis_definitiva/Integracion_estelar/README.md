# Integración estelar en Vivado

Proyecto `Tesis_definitiva/Tesis_definitiva.xpr`, Zynq XC7Z010-1 y reloj de proceso de 125 MHz.

## Resultado

El checkpoint de `05_actitud_posruteo` contiene la cadena completa. El [Timing Summary de impl_1](05_actitud_posruteo/timing_impl_1.rpt) tiene WNS de +0,055 ns y WHS de +0,017 ns, con cero destinos fallidos. El [estado de ruteo](05_actitud_posruteo/estado_ruteo.rpt) registra las 22 714 redes ruteables conectadas. El ensayo con la placa y la calibración de la cámara siguen pendientes.

## Identificación

La ROM contiene 48 direcciones del generador G5. La tabla de parejas contiene 322 entradas indexadas por intervalos de 0,25°. La lista del detector admite hasta 64 centroides por cuadro. El identificador selecciona hasta ocho por intensidad y exige cinco correspondencias. Un desborde de la lista invalida la identificación de ese cuadro.

El identificador reconstruye un rayo por centroide con los parámetros nominales de cámara. Luego toma el par de mayor separación como ancla, examina las parejas del catálogo en el intervalo y sus dos vecinos, y evalúa las dos asignaciones del ancla. Cada ID nuevo debe ser compatible con todos los ID ya asignados en esa hipótesis. La comparación principal maximiza el número de coincidencias y desempata por error acumulado de cuerda al cuadrado.

Las vistas sintéticas giran alrededor del centro de proyección. Los resultados corresponden al patrón de banco y a su distancia nominal de 250 mm. La cobertura angular del montaje se puede examinar en `sim/cobertura.json` dentro de la carpeta de resultados. El recuento óptico y la validación de una pose arbitraria quedan para ensayos con la cámara.

## Depuración UART

El puerto continúa a 921 600 baudios. La imagen `STY1` precede a los centroides `STC1`. La trama `STM1` entrega las coincidencias de esa foto y `STQ2` se añade en la versión con actitud. Los enteros de varios bytes usan orden little endian.

| Trama | Bytes | Campos |
|---|---:|---|
| STM1 | 26 | Firma 0–3, número de coincidencias 4, foto 5–8, hasta ocho parejas índice de centroide/ID de catálogo 9–24, suma módulo 256 en 25 |
| STQ2 | 27 | Firma 0–3, validez 4, número de coincidencias 5, foto 6–9, cuatro enteros con signo de 32 bits `w,x,y,z` en 10–25, suma módulo 256 en 26 |

Los índices de centroide comienzan en 0 y los ID de catálogo en 1. En STM1 se rellena con FF el espacio que sobra. El cuaternión describe el giro de los ejes de cámara a los ejes de la referencia. Dividir cada componente entre 32768. Cuando STQ2 indica inválido, los cuatro componentes valen cero.

`node leer_uart.cjs captura.bin` valida la suma de cada trama y muestra los centroides, los ID y el cuaternión por foto en una captura binaria.

## Reproducción

Desde la raíz del repositorio, resolución nominal y valores del patrón se importan del generador existente. El argumento de carpeta debe ser exclusivo para cada corrida. `correr_timing.tcl` agrega las fuentes al XPR y ejecuta síntesis e implementación hasta ruteo.

```powershell
$scriptDir = 'Tesis_definitiva/Integracion_estelar'
$evidencia = "$scriptDir/identificacion_repetida"
node "$scriptDir/generar_escenas.cjs" "$evidencia/sim"
vivado -mode batch -source "$scriptDir/verificar_identificacion.tcl" -tclargs $evidencia identificacion
vivado -mode batch -source "$scriptDir/correr_timing.tcl" -tclargs 'Tesis_definitiva/Tesis_definitiva' $evidencia identificacion
```

Las carpetas numeradas guardan las fuentes, los diagramas y la evidencia de cada revisión. El informe identifica qué se ejecutó y qué estado alcanzó cada corrida.

El argumento final selecciona las fuentes que se agregan al XPR. El ruteo usa el top que esté activo en el proyecto. Para reproducir una revisión anterior después de instalar otra, hacer la corrida en una copia e incorporar las fuentes de la revisión archivada.

Con la versión completa, pasar `actitud` al banco de simulación y a la corrida de síntesis y ruteo. `optimizar_ruteo.tcl` abre el checkpoint guardado, aplica `AggressiveExplore` y escribe otro checkpoint con su Timing Summary. [Vivado 2025.2, referencia de phys_opt_design](https://docs.amd.com/r/2025.2-English/ug835-vivado-tcl-commands/phys_opt_design)

`continuar_posruteo.tcl` aplica esa misma etapa en `impl_1` tras una corrida completa de `route_design`.
