source [file join [file dirname [info script]] fuentes.tcl]
set out [file join $captura_root build simulation_top_runtime]
file mkdir $out
cd $out
set bin [file join $::env(XILINX_VIVADO) bin]
proc run_cmd {args} {
    if {[catch {exec {*}$args 2>@1} result]} {puts $result; error "Failed: $args"}
    puts $result
    return $result
}
foreach f $captura_rtl {run_cmd [file join $bin xvhdl.bat] --2008 $f}
run_cmd [file join $bin xvhdl.bat] --2008 [file join $captura_root tb captura_xclk_fast_sim.vhd] [file join $captura_root tb tb_captura_uart.vhd]
run_cmd [file join $bin xvhdl.bat] --2008 [file join $captura_root tb tb_top_runtime.vhd]
run_cmd [file join $bin xelab.bat] work.tb_top_runtime -L unisims_ver -L unisim -s top_runtime
set f [open run.tcl w]; puts $f {run all}; puts $f quit; close $f
set result [run_cmd [file join $bin xsim.bat] top_runtime -tclbatch run.tcl]
if {![string match *PASS_TOP_RUNTIME* $result]} {error "No top runtime PASS"}
exit 0
