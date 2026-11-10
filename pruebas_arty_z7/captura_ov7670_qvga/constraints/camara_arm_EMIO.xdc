
## ============================================================
## ARTY Z7-10 Rev.B - OV7670 QQVGA + ZYNQ ARM
## UART1 mediante EMIO hacia el ARM
## FCLK_CLK0 = 100 MHz
## ============================================================

## IMPORTANTE:
## Los puertos externos del Block Design tienen sufijo _0.
## clk y rst son internos, no necesitan pines externos.
## tx va directamente a UART1_RX mediante EMIO.
## Alimentacion OV7670: 3.3 V y GND por separado.

## ============================================================
## CAMARA OV7670 - CONECTOR JA
## ============================================================

## JA1 - SCL
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports SCL_0]

## JA2 - VSYNC
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports cam_vsync_0]

## JA3 - D5
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {cam_data_0[5]}]

## JA4 - D7
set_property -dict {PACKAGE_PIN Y17 IOSTANDARD LVCMOS33} [get_ports {cam_data_0[7]}]

## JA7 - PCLK (MRCC)
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports cam_pclk_0]

## JA8 - D3
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {cam_data_0[3]}]

## JA9 - D1
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {cam_data_0[1]}]

## JA10 - RESET CAMARA
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports cam_reset_0]


## ============================================================
## CAMARA OV7670 - CONECTOR JB
## ============================================================

## JB1 - SDA
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports SDA_0]

## JB2 - HREF
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports cam_href_0]

## JB3 - XCLK
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports cam_xclk_0]

## JB4 - D6
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {cam_data_0[6]}]

## JB7 - D4
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {cam_data_0[4]}]

## JB8 - D2
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS33} [get_ports {cam_data_0[2]}]

## JB9 - D0
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {cam_data_0[0]}]

## JB10 - PWDN
## PWDN fisicamente a GND. Esta salida constante NO se conecta al modulo.
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports cam_pwdn_0]


## ============================================================
## SCCB / I2C
## ============================================================

## Pull-up interno de respaldo.
## Verificar que el modulo OV7670 tenga pull-ups adecuados.
set_property PULLTYPE PULLUP [get_ports SDA_0]


## ============================================================
## PULSADOR DE CAPTURA
## ============================================================

## BTN1 - START
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports start_0]

## BTN0 - RESET (NO UTILIZADO)
## El reset ahora procede de Processor System Reset.
## No asignar un pin externo a rst.


## ============================================================
## CLOCK DE LA CAMARA
## ============================================================

## PCLK: periodo minimo presupuestado 41.667 ns (24 MHz).
## No significa que la camara siempre entregue 24 MHz.
create_clock -period 41.667 -name cam_pclk_pin [get_ports cam_pclk_0]

## FCLK_CLK0 = 100 MHz, generado por Zynq Processing System.
## No crear otro reloj de sistema en el XDC.


## ============================================================
## COMUNICACION UART
## ============================================================

## FPGA UART TX -> ZYNQ UART1 RX por EMIO.
## Conexion interna: no necesita PACKAGE_PIN.

## ZYNQ UART0 -> USB UART -> PC
## Configurado mediante MIO 14 y 15 en Processing System.


## ============================================================
## NOTAS
## ============================================================

## Verificar timing y cruces entre dominios de reloj.
## No se agregan excepciones CDC sin justificacion.
## No usar CLOCK_DEDICATED_ROUTE FALSE para PCLK.
## Alimentar OV7670 con niveles electricos compatibles a 3.3 V.

# Digilent Arty-Z7-10-Master.xdc, four discrete LEDs, no camera-pin reuse.
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {diag_led[0]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {diag_led[1]}]
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {diag_led[2]}]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {diag_led[3]}]
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports reset_btn]

# OV7670 DS v1.4, table 4: data/HREF updated at PCLK falling edge,
# tPDV/tPHH/tPHL = 0..5 ns. COM10=00 also changes VSYNC at falling edge.
# +/-2 ns additional skew is an explicit cable budget, pending measurement.
set_input_delay -clock cam_pclk_pin -clock_fall -min -2.0 [get_ports {cam_data_0[*] cam_href_0 cam_vsync_0}]
set_input_delay -clock cam_pclk_pin -clock_fall -max 7.0 [get_ports {cam_data_0[*] cam_href_0 cam_vsync_0}]

# Only the FIRST stage of the explicit two-flop toggle/button synchronizers.
# No exception on their second stage or on the capture data bus.
set_false_path -to [get_pins -hier -filter {NAME =~ */done_meta_reg/D || NAME =~ */ready_meta_reg/D || NAME =~ */error_meta_reg/D || NAME =~ */released_meta_reg/D || NAME =~ */request_meta_reg/D || NAME =~ */button_meta_reg/D || NAME =~ */reset_meta_reg/D || NAME =~ */sda_meta_reg/D}]
# Async assertion of the reset synchronizers; release is synchronized separately.
set_false_path -to [get_pins -hier -filter {NAME =~ */pixel_reset_pipe_reg*/PRE || NAME =~ */sys_reset_pipe_reg*/PRE}]
