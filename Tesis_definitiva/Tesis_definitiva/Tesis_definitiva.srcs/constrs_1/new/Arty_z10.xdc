
# JA1 - SCL
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports SCL]

# JA2 - VSYNC
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports vsync]

# JA3 - D5
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {datos[5]}]

# JA4 - D7
set_property -dict {PACKAGE_PIN Y17 IOSTANDARD LVCMOS33} [get_ports {datos[7]}]

# JA7 - PCLK
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports pclk]

# JA8 - D3
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {datos[3]}]

# JA9 - D1
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {datos[1]}]

# JA10 - RESET CAMARA
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports cam_reset]


# JB1 - SDA
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports SDA]

# JB2 - HREF
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports href]

# JB3 - XCLK
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports xclk]

# JB4 - D6
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {datos[6]}]

# JB7 - D4
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {datos[4]}]

# JB8 - D2
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS33} [get_ports {datos[2]}]

# JB9 - D0
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {datos[0]}]

# SCCB / I2C

set_property PULLUP true [get_ports SDA]

# BTN0 - RESET
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports reset_btn]

# BTN1 - START
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports start]

# PCLK

create_clock -name reloj_pclk -period 41.667 [get_ports pclk]

# LED0 - CONFIGURACION EN CURSO
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports busy]

# LED1 - FIN DE CONFIGURACION
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports done]

# LED2 - ERROR DE CONFIGURACION
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports error]

# LED3 - GENERADOR XCLK BLOQUEADO
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports reloj_listo]


#set_false_path -to [get_pins {sincronizar_configurada/etapa_1_reg/D}]

#set_false_path -to [get_pins {sincronizar_imagen_lista/etapa_1_reg/D}]

#set_false_path -to [get_pins {sincronizar_fin_envio/etapa_1_reg/D}]

set_false_path -to [get_pins -hierarchical -filter {NAME =~ */sincronizar_configurada/etapa_1_reg/D}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */sincronizar_imagen_lista/etapa_1_reg/D}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */sincronizar_fin_envio/etapa_1_reg/D}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */sincronizar_start/etapa_1_reg/D}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */sincronizar_orden_captura/etapa_1_reg/D}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */reinicio_meta_reg/PRE || NAME =~ */reinicio_pclk_reg/PRE}]