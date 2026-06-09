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

## SCCB/I2C on JA
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports { SCL }]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { SDA }]
set_property PULLUP true [get_ports { SDA }]

## OV7670 camera data/control
set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33 } [get_ports { cam_data[0] }]
set_property -dict { PACKAGE_PIN F16 IOSTANDARD LVCMOS33 } [get_ports { cam_data[1] }]
set_property -dict { PACKAGE_PIN G16 IOSTANDARD LVCMOS33 } [get_ports { cam_data[2] }]
set_property -dict { PACKAGE_PIN H14 IOSTANDARD LVCMOS33 } [get_ports { cam_data[3] }]
set_property -dict { PACKAGE_PIN E16 IOSTANDARD LVCMOS33 } [get_ports { cam_data[4] }]
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports { cam_data[5] }]
set_property -dict { PACKAGE_PIN G13 IOSTANDARD LVCMOS33 } [get_ports { cam_data[6] }]
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { cam_data[7] }]
set_property -dict { PACKAGE_PIN K1  IOSTANDARD LVCMOS33 } [get_ports { cam_xclk }]
set_property -dict { PACKAGE_PIN F6  IOSTANDARD LVCMOS33 } [get_ports { cam_pclk }]
set_property -dict { PACKAGE_PIN J2  IOSTANDARD LVCMOS33 } [get_ports { cam_vsync }]
set_property -dict { PACKAGE_PIN G6  IOSTANDARD LVCMOS33 } [get_ports { cam_href }]
set_property -dict { PACKAGE_PIN E7  IOSTANDARD LVCMOS33 } [get_ports { cam_pwdn }]
set_property -dict { PACKAGE_PIN J3  IOSTANDARD LVCMOS33 } [get_ports { cam_reset }]
create_clock -add -name cam_pclk_pin -period 41.667 -waveform {0 20.833} [get_ports { cam_pclk }]
set_clock_groups -asynchronous -group [get_clocks { sys_clk_pin }] -group [get_clocks { cam_pclk_pin }]

## OV7670 PCLK enters through PMOD JC2/F6, which is not a clock-capable pin on this
## Nexys A7 package. The camera cable already uses this pinout, so the prototype
## accepts a non-dedicated route for this external pixel clock.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cam_pclk_IBUF]

## USB-RS232 UART TX
set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 } [get_ports { uart_tx }]
