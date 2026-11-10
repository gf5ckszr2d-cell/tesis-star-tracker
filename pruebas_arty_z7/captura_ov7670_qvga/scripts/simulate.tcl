source [file join [file dirname [info script]] fuentes.tcl]
set out [file join $captura_root build simulation_final]
if {[info exists ::env(CAPTURE_RUN_DIR)]} {set out [file join $captura_root build $::env(CAPTURE_RUN_DIR)]}
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
run_cmd [file join $bin xvhdl.bat] --2008 [file join $captura_root tb tb_captura_uart.vhd]
set f [open run.tcl w]
puts $f {run all}
puts $f {quit}
close $f
set cases {100000000 tb_captura_uart 125000000 tb_captura_uart_125}
if {[info exists ::env(CAPTURE_ONLY_100)]} {set cases {100000000 tb_captura_uart}}
foreach {hz top} $cases {
    set snap captura_${hz}
    run_cmd [file join $bin xelab.bat] work.$top -L unisims_ver -L unisim -s $snap
    set output [run_cmd [file join $bin xsim.bat] $snap -tclbatch run.tcl]
    if {![string match *PASS_CAPTURA_UART* $output]} {error "No hay PASS para $hz Hz"}
    puts "PASS_RELOJ_${hz}"
}
puts "PASS_CAPTURA_CASOS_SOLICITADOS"
exit 0
