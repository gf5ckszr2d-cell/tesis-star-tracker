## Arty Z7-10 Rev.B: OV7670 + botones, PCLK en entrada MRCC JA7/U18.
## Fuente de pines: Digilent/digilent-xdc/Arty-Z7-10-Master.xdc.
## Los nombres son los puertos EXTERNOS del diseno final. Al usar BD,
## conservar estos nombres al hacer Make External (sin sufijo _0).
## clk viene de FCLK_CLK0 a 100 MHz y tx va a AXI UART Lite: SIN LOC externo.
## Alimentacion: 3.3 V y GND por separado; nunca asignarlos a un GPIO.

## Columna izquierda de la camara, de arriba abajo (sin alimentacion).
## Primer grupo de cuatro -> JA1..JA4.
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports {SCL}]          ;# JA1: SCL
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports {cam_vsync}]    ;# JA2: VS
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {cam_data[5]}]  ;# JA3: D5
set_property -dict {PACKAGE_PIN Y17 IOSTANDARD LVCMOS33} [get_ports {cam_data[7]}]  ;# JA4: D7
## Segundo grupo de cuatro -> JA7..JA10; JA5/6 son alimentacion.
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports {cam_pclk}]     ;# JA7: PCLK, MRCC positivo
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {cam_data[3]}]  ;# JA8: D3
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {cam_data[1]}]  ;# JA9: D1
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports {cam_reset}]    ;# JA10: RST camara

## Columna derecha de la camara, de arriba abajo (sin GND).
## Primer grupo de cuatro -> JB1..JB4.
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports {SDA}]          ;# JB1: SDA
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports {cam_href}]     ;# JB2: HD / HREF
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports {cam_xclk}]     ;# JB3: MCLK / XCLK
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {cam_data[6]}]  ;# JB4: D6
## Segundo grupo de cuatro -> JB7..JB10; JB5/6 son alimentacion.
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {cam_data[4]}]  ;# JB7: D4
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS33} [get_ports {cam_data[2]}]  ;# JB8: D2
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {cam_data[0]}]  ;# JB9: D0
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports {cam_pwdn}]     ;# JB10: PWDN

## Resistencia debil de respaldo; comprobar los pull-ups del modulo SCCB.
set_property PULLUP true [get_ports {SDA}]

## Pulsadores PL, activos altos. rst del core NO es el reset activo bajo del PS.
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports {rst}]          ;# BTN0: reset core
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports {start}]        ;# BTN1: captura

## Presupuesto de PCLK hasta 24 MHz; no afirma que el sensor entregue 24 MHz.
## FCLK_CLK0 y sus constraints proceden del PS. No crear aqui un reloj de 125 MHz.
create_clock -name cam_pclk_pin -period 41.667 [get_ports {cam_pclk}]
## No se inventan retardos de E/S ni excepciones CDC generales: requieren
## revisar el BD final y los tiempos del sensor para cerrar timing.
## No se necesita excepcion CLOCK_DEDICATED_ROUTE: PCLK usa una entrada MRCC.
