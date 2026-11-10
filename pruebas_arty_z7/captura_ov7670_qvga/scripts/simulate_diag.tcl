source [file join [file dirname [info script]] fuentes.tcl]
set out [file join $captura_root build diag_reset]
file mkdir $out
cd $out
set bin [file join $::env(XILINX_VIVADO) bin]
proc checked {args} {
    if {[catch {exec {*}$args 2>@1} result]} {puts $result; error "Failed: $args"}
    puts $result
    return $result
}
checked [file join $bin xvhdl.bat] --2008 {*}$captura_rtl [file join $captura_root tb tb_diag_reset.vhd]
checked [file join $bin xelab.bat] work.tb_diag_reset -L unisim -s diag
set f [open run.tcl w]; puts $f {run all}; puts $f quit; close $f
set result [checked [file join $bin xsim.bat] diag -tclbatch run.tcl]
if {![string match *PASS_DIAG_RESET* $result]} {error "No DIAG PASS"}
exit 0
