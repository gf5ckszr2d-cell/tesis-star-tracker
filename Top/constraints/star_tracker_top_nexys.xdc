## Nexys A7-100T constraints for star_tracker_top.
## Main hardware flow: OV7670 -> Y capture -> BRAM -> USB UART.

## 100 MHz system clock
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }]

## LEDs / debug status
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { led_read_data[0] }]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports { led_read_data[1] }]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports { led_read_data[2] }]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { led_read_data[3] }]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { led_read_data[4] }]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { led_read_data[5] }]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { led_read_data[6] }]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports { led_read_data[7] }]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports { busy }]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports { ok }]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports { fail }]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports { pixel_valid }]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports { frame_done }]

## Buttons
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { rst }]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports { start_btn }]
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { btn_config }]

## Switches for runtime camera calibration
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports { sw[2] }]
set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } [get_ports { sw[3] }]
set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports { sw[4] }]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports { sw[5] }]
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { sw[6] }]
set_property -dict { PACKAGE_PIN R13 IOSTANDARD LVCMOS33 } [get_ports { sw[7] }]
set_property -dict { PACKAGE_PIN T8  IOSTANDARD LVCMOS33 } [get_ports { sw[8] }]
set_property -dict { PACKAGE_PIN U8  IOSTANDARD LVCMOS33 } [get_ports { sw[9] }]
set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 } [get_ports { sw[10] }]
set_property -dict { PACKAGE_PIN T13 IOSTANDARD LVCMOS33 } [get_ports { sw[11] }]
set_property -dict { PACKAGE_PIN H6  IOSTANDARD LVCMOS33 } [get_ports { sw[12] }]
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports { sw[13] }]
set_property -dict { PACKAGE_PIN U11 IOSTANDARD LVCMOS33 } [get_ports { sw[14] }]
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports { sw[15] }]

## OV7670 camera connector, ordered by physical 2x9 module rows.
## Camera row 1 is power only: 3.3V / GND.
## JA row pairs: JA1/JA7, JA2/JA8, JA3/JA9, JA4/JA10.
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports { SCL }]          ;# JA1  -> SCL
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { cam_vsync }]    ;# JA2  -> VS
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports { cam_pclk }]     ;# JA3  -> PCLK/PLK
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports { cam_data[7] }]  ;# JA4  -> D7
set_property -dict { PACKAGE_PIN D17 IOSTANDARD LVCMOS33 } [get_ports { cam_data[5] }]  ;# JA7  -> D5
set_property -dict { PACKAGE_PIN E17 IOSTANDARD LVCMOS33 } [get_ports { cam_data[3] }]  ;# JA8  -> D3
set_property -dict { PACKAGE_PIN F18 IOSTANDARD LVCMOS33 } [get_ports { cam_data[1] }]  ;# JA9  -> D1
set_property -dict { PACKAGE_PIN G18 IOSTANDARD LVCMOS33 } [get_ports { cam_reset }]    ;# JA10 -> RESET/RET

## JB row pairs: JB1/JB7, JB2/JB8, JB3/JB9, JB4/JB10.
set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33 } [get_ports { SDA }]  ;# JB1  -> SDA
set_property PULLUP true [get_ports { SDA }]
set_property -dict { PACKAGE_PIN F16 IOSTANDARD LVCMOS33 } [get_ports { cam_href }]  ;# JB2  -> HS/HREF
set_property -dict { PACKAGE_PIN G16 IOSTANDARD LVCMOS33 } [get_ports { cam_xclk }]  ;# JB3  -> XCLK/XLK
set_property -dict { PACKAGE_PIN H14 IOSTANDARD LVCMOS33 } [get_ports { cam_data[6] }]    ;# JB4  -> D6
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports { cam_data[4] }]  ;# JB7  -> D4
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports { cam_data[2] }]  ;# JB8  -> D2
set_property -dict { PACKAGE_PIN G13 IOSTANDARD LVCMOS33 } [get_ports { cam_data[0] }]  ;# JB9  -> D0
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { cam_pwdn }]     ;# JB10 -> PWDN
create_clock -add -name cam_pclk_pin -period 41.667 -waveform {0 20.833} [get_ports { cam_pclk }]
set_clock_groups -asynchronous -group [get_clocks { sys_clk_pin }] -group [get_clocks { cam_pclk_pin }]

## OV7670 PCLK enters through a PMOD pin, which may not be clock-capable on this
## Nexys A7 package. The camera cable already uses this pinout, so the prototype
## accepts a non-dedicated route for this external pixel clock.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cam_pclk_IBUF]

## USB-RS232 UART TX
set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 } [get_ports { uart_tx }]
