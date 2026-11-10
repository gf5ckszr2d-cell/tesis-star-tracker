# Solo simulacion XSim de los relojes; no crea ni abre un proyecto GUI.
source [file join [file dirname [info script]] fuentes.tcl]
set out [file join $captura_root build check_clocks]
file mkdir $out
cd $out
set bin [file join $::env(XILINX_VIVADO) bin]
proc run_checked {args} {
    set status [catch {exec {*}$args 2>@1} output]
    puts $output
    if {$status} {error "Fallo: $args"}
    return $output
}
run_checked [file join $bin xvhdl.bat] --2008 {*}$captura_rtl [file join $captura_root tb tb_relojes_100.vhd]
run_checked [file join $bin xelab.bat] work.tb_relojes_100 -L unisim -s relojes_100
set f [open run.tcl w]
puts $f {run all}
puts $f {quit}
close $f
set output [run_checked [file join $bin xsim.bat] relojes_100 -tclbatch run.tcl]
if {![string match *PASS_RELOJES_100* $output]} {error "Falta PASS_RELOJES_100"}
exit 0
