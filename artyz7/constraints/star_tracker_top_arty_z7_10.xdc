## Arty Z7-10 constraints for star_tracker_top_arty_z7_10.
## Camera flow: OV7670 -> Y capture -> BRAM -> UART TX on PL pin.
## Pin base: Digilent Arty-Z7-10-Master.xdc.

## 125 MHz system clock
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { clk_125mhz }]
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk_125mhz }]

## Buttons
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports { rst_btn }]
set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS33 } [get_ports { start_btn }]

## LEDs: busy, ok, fail, frame_done
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]

## OV7670 camera connector.
## JA carries the left camera column. JB carries the right camera column.
## Camera row 1 is power only: 3.3V / GND.
set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports { SCL }]          ;# JA1  -> SCL
set_property PULLUP true [get_ports { SDA }]
set_property -dict { PACKAGE_PIN Y19 IOSTANDARD LVCMOS33 } [get_ports { cam_vsync }]    ;# JA2  -> VS
set_property -dict { PACKAGE_PIN Y16 IOSTANDARD LVCMOS33 } [get_ports { cam_pclk }]     ;# JA3  -> PCLK/PLK
set_property -dict { PACKAGE_PIN Y17 IOSTANDARD LVCMOS33 } [get_ports { cam_data[7] }]  ;# JA4  -> D7
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { cam_data[5] }]  ;# JA7  -> D5
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports { cam_data[3] }]  ;# JA8  -> D3
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports { cam_data[1] }]  ;# JA9  -> D1
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports { cam_reset }]    ;# JA10 -> RESET/RET

## JB carries the right camera column.
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports { SDA }]          ;# JB1  -> SDA
set_property -dict { PACKAGE_PIN Y14 IOSTANDARD LVCMOS33 } [get_ports { cam_href }]     ;# JB2  -> HS/HREF
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { cam_xclk }]     ;# JB3  -> XCLK/XLK
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { cam_data[6] }]  ;# JB4  -> D6
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports { cam_data[4] }]  ;# JB7  -> D4
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports { cam_data[2] }]  ;# JB8  -> D2
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports { cam_data[0] }]  ;# JB9  -> D0
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports { cam_pwdn }]     ;# JB10 -> PWDN

create_clock -add -name cam_pclk_pin -period 41.667 -waveform {0 20.833} [get_ports { cam_pclk }]
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks sys_clk_pin] \
    -group [get_clocks { cam_pclk_pin }]

## OV7670 PCLK follows the same practical wiring order as the Nexys prototype.
## JA3 may not be a dedicated clock-capable input, so this prototype accepts the
## non-dedicated route for the external pixel clock.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cam_pclk_IBUF]

## UART TX from PL. Use a 3.3 V USB-serial adapter on CK_IO0.
## Do not assume the integrated USB-UART bridge is directly connected to PL.
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports { uart_tx_pl }]
