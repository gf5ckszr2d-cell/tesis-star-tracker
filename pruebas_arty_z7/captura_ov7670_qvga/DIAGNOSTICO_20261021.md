# Captura Arty Z7-10: antes y despues (21-10-2026)

Trabajo local sobre `pruebas_arty_z7`. El top Nexys y las etapas estelares no se modificaron.
La copia `antes_20261021/` guarda fuentes, BD, XDC, XPR, aplicacion C, XSA y ELF anteriores.
El proyecto corregido es `build/diagnostico/captura_diagnostico.xpr`; el XPR original se conserva.

| Parte | Antes encontrado en los archivos reales | Despues |
|---|---|---|
| Reset PL | `proc_sys_reset`: `C_AUX_RESET_HIGH=0`, `aux_reset_in=0`: reset permanentemente solicitado | `C_AUX_RESET_HIGH=1` con la misma entrada a 0, inactiva; BTN0 permite recuperar solo el core de captura |
| Baud PL/PS | Wrapper generado instancia PL a **115200**; C inicializa UART1 a **921600**. El generic del wrapper superior no configura el modulo del BD | Default de `captura_uart_top` y parametro explicito del modulo BD a **921600**; UART0-PC se mantiene a **115200**, 8N1 |
| SCCB | ACK y dato leidos en el mismo ciclo que ordena subir SCL; SDA cambia a la vez que baja SCL | Cuatro fases a 100 kHz, SDA se establece con SCL bajo, ACK/datos a mitad de SCL alto, sincronizador SDA de dos registros; IOBUF conservado |
| Arranque camara | Configuracion inmediata tras lock; reset software con espera de 1 ms | 10 ms tras lock antes de SCCB, 10 ms tras reset software, 300 ms de estabilizacion tras configurar; mismos 21 registros |
| Integridad del frame | Solo se comprueban limites de coordenadas; cualquier fin de frame permite volcar BRAM | Se exige secuencia row-major completa de 19200 pixeles, lineas completas y ningun overflow; frames cortos/duplicados se rechazan |
| Bloqueos y LEDs | Sin diagnosticos y espera indefinida | Cuatro LEDs, timeout por etapa de 4 s y recuperacion con BTN0 |
| ARM | Bytes hasta pausa de 100 ms, sin validar STY1; bloquea recepcion al enviar al PC | IRQ UART1/GIC 82, anillo RAM 64 KiB, trama completa en RAM, cabecera exacta y checksum; error de UART, overflow y timeout descartan la trama; capturas sucesivas |
| Temporizador | Lectura estable del contador global, habilitado manualmente | Se conserva lectura alto/bajo/alto y se incorpora el prescaler al calculo CPU/2; sin dependencia de `xtime_l.h` |
| Linker | `lscript.ld` existente usado por CMake | Se conserva esa solucion y el script; se compilan tambien `sty1.c/h` |
| PC | No habia receptor especifico integrado con esta aplicacion | `pc/recibir_imagen.py`: COM3/115200, STY1 binario, dimensiones, checksum, timeout, PNG y RAW, visualizacion |
| Constraints | Dos XDC con nombres de puertos distintos; sin presupuesto de datos externos | Solo XDC de BD activo en la copia; se conservan pines JA/JB; LEDs y BTN0 segun Digilent; presupuesto de entrada respecto al flanco descendente de PCLK |

Los dos primeros fallos estan **confirmados en la configuracion guardada y el wrapper generado** y son suficientes para impedir la ruta prevista. No son una medicion del contenido que estaba programado en la placa. El cambio SCCB corrige la posicion del muestreo y mejora su margen; no demuestra que ese fuese el fallo fisico. Pull-ups, señales y calidad de imagen permanecen pendientes de prueba fisica.

## Uso minimo

1. En Vitis abrir `pruebas_arty_z7/Vitis_captura_uart`, ejecutar `receptor_ov7670_test` con el bitstream corregido `captura_ov7670/build/diagnostico/resultados/sistema_captura_arm_wrapper.bit`. Debe usar el ELF de `receptor_ov7670_test/build/`.
2. Alternativa reproducible con cable JTAG y hw_server local activo: ejecutar desde la raiz del repositorio:

```powershell
& 'C:/AMDDesignTools/2025.2/Vitis/bin/xsct.bat' 'pruebas_arty_z7/captura_ov7670/scripts/load_capture.tcl'
```

3. Cerrar el terminal serie de Vitis para liberar COM3 y abrir el receptor:

```powershell
py -3.13 'pruebas_arty_z7/captura_ov7670/pc/recibir_imagen.py' --port COM3
```

En esta PC Python 3.13 ya tiene `pyserial` y Pillow; si faltan en otro entorno: `py -3.13 -m pip install -r pruebas_arty_z7/captura_ov7670/pc/requirements.txt`.

4. Pulsar BTN0 y soltarlo, luego BTN1. La primera captura configura la camara. Esperar el PNG y el mensaje `OK` en PC antes de otra captura. Guardado predeterminado en `pc/capturas/`.

No usar IMG/FIN ni texto como delimitadores: cada paquete es `STY1` + uint16LE 160 + uint16LE 120 + uint32LE 19200 + 19200 bytes Y + suma modulo 256. Total 19213 bytes. El ARM solo reenvia paquetes validos; los textos quedan entre paquetes. La suma de 8 bits es la del protocolo existente y no tiene la capacidad de deteccion de un CRC.

La salida PC tarda como minimo 1,67 s por imagen. El anillo permite recibir durante ese envio, pero no permite una tasa sostenida mayor que UART0; cualquier desbordamiento se denuncia y descarta. Las pulsaciones mientras PL esta ocupado se descartan.

## LEDs fisicos LD0..LD3

| LED | Estado normal |
|---|---|
| LD0 | Latido: reloj/logica activos |
| LD1 | Parpadea durante arranque/configuracion/estabilizacion; fijo tras SCCB correcto |
| LD2 | Parpadea esperando/capturando; fijo cuando hay un frame completo para UART |
| LD3 | Parpadea durante transmision PL; fijo al completar el paquete PL-PS |

**En error**, LD0 parpadea rapido y **LD3 LD2 LD1** representan este codigo binario fijo:

| Codigo | Primera etapa detenida | Comprobacion fisica concreta |
|---|---|---|
| 001 | SCCB/NACK o timeout de inicializacion | Alimentacion, RESET alto, XCLK 24 MHz, SDA con pull-up a nivel compatible, direccion de escritura 0x42 y ACK al noveno pulso |
| 010 | Geometria/overflow de captura | Orden D0..D7, HREF con 320 bytes por linea, 120 lineas activas por frame; VSYNC activo alto |
| 011 | No completa captura en 4 s | PCLK presente en JA7/U18, VSYNC y HREF activos; comprobar que PCLK y D5 no estan intercambiados |
| 100 | No termina UART en 4 s | Verificar bitstream corregido; UART PL-PS es una conexion interna, sin cable externo |
| 101 | MMCM/arranque no listo | FCLK_CLK0 100 MHz y XCLK 24 MHz |
| 110 | PCLK no confirma liberacion de BRAM | PCLK debe continuar durante blanking (`COM10=00`) |

BTN0 reinicia y permite reintentar. Si LD0 no muestra latido, comprobar primero programacion, ejecucion del PS y FCLK/reset. LD3 solo acredita el final del transmisor PL, no que ARM o PC hayan recibido correctamente.

Las unicas comprobaciones fisicas pendientes son: (1) alimentacion/tierra/PWDN a GND y continuidad del cableado ya existente, (2) patron de LEDs y señales indicadas por el primer error, (3) obtener PNG real y repetir con la escena cambiada. No reconectar PWDN a JB10: se conserva a GND; la salida PL en JB10 queda sin conectar al sensor.

## Reproduccion y limites

Vivado tiene rutas internas largas en Windows. Para esta copia se asigno `Q:` al repositorio con `subst Q: C:\Users\alexa\tesis-star-tracker`. Si Q: ya existe, verificar que apunta a esa ruta antes de usarlo. Los scripts `prepare_diagnostic.tcl` y `build_diagnostic.tcl` se ejecutan con `vivado.bat -mode batch -source Q:/pruebas_arty_z7/captura_ov7670/scripts/<script>`.

`simulate.tcl` comprueba 100 y 125 MHz; definir `$env:CAPTURE_ONLY_100='1'` selecciona solo el caso usado por el PS. Aceleracion de baud, debounce y esperas de camara **solo en TB**. El MMCM/lock se simula realmente. `simulate_sccb.tcl` comprueba ACK/lectura/NACK; `simulate_store.tcl` frames completos e invalidos. `pc/test_receptor.py` comprueba el parser Python y PNG; `tb/test_sty1.c` comprueba el parser C del ARM.

Los toggles CDC cruzan mediante dos registros `ASYNC_REG`, y la BRAM permanece estable hasta el handshake de liberacion. Las excepciones temporales solo alcanzan la primera etapa de esos sincronizadores y la asercion de los sincronizadores de reset. No se agregaron false paths al bus de datos de camara, grupos de reloj completos ni excepciones de ruteo de PCLK.

El presupuesto externo usa PCLK hasta 24 MHz y retardo sensor 0..5 ns desde su flanco descendente, mas un presupuesto de skew de cable de +/-2 ns: **falta medir ese skew**. Los avisos de salidas LED/SCCB/reset sin un receptor sincronico definido no acreditan tiempos electricos externos. Un timing positivo verifica el modelo utilizado, no el cableado real.

Fuentes: [pines oficiales Digilent](https://github.com/Digilent/digilent-xdc/blob/master/Arty-Z7-10-Master.xdc); [hoja de datos OmniVision OV7670 v1.4, tablas 4 y 5](https://www.haoyuelectronics.com/Attachment/OV7670%20%2B%20AL422B%28FIFO%29%20Camera%20Module%28V2.0%29/OV7670%20datasheet%28V1.4%29.pdf).

Los resultados de esta primera revision se registran al final de `VALIDACION.md`.
La revision posterior [FIX_010.md](FIX_010.md) si incluye carga por JTAG y medicion
real de la camara: 120 lineas de 312 bytes con la ventana original. Consultar
ese documento para el ajuste posterior y el estado fisico vigente.
