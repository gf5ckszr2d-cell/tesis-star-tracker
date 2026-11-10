source [file join [file dirname [info script]] fuentes.tcl]
set out [file join $captura_root build simulation_qvga]
file mkdir $out
cd $out
set bin [file join $::env(XILINX_VIVADO) bin]
proc run_cmd {args} {
    set status [catch {exec {*}$args 2>@1} result]
    puts $result
    if {$status} {error "Fallo: $args"}
    return $result
}
foreach f $captura_rtl {run_cmd [file join $bin xvhdl.bat] --2008 $f}
run_cmd [file join $bin xvhdl.bat] --2008 [file join $captura_root tb captura_xclk_fast_sim.vhd]
run_cmd [file join $bin xvhdl.bat] --2008 [file join $captura_root tb tb_captura_uart.vhd]
set f [open run.tcl w]; puts $f {run all}; puts $f {quit}; close $f
run_cmd [file join $bin xelab.bat] work.tb_captura_uart -L unisims_ver -L unisim -s qvga
set output [run_cmd [file join $bin xsim.bat] qvga -tclbatch run.tcl]
if {![string match *PASS_CAPTURA_UART* $output]} {error "No PASS QVGA"}
puts "PASS_QVGA: geometry, >65535 pixels, Y payload, two UART packets; XCLK behavioural simulation only"
exit 0
