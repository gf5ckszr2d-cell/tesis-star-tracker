set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build simulation_runtime]
file mkdir $out
cd $out
set bin [file join $::env(XILINX_VIVADO) bin]
proc run_cmd {args} {
    if {[catch {exec {*}$args 2>@1} result]} {puts $result; error "Failed: $args"}
    puts $result
    return $result
}
run_cmd [file join $bin xvhdl.bat] --2008 [file join $root rtl sccb_runtime_bridge.vhd] [file join $root tb tb_sccb_runtime.vhd]
run_cmd [file join $bin xelab.bat] work.tb_sccb_runtime -s runtime
set f [open run.tcl w]; puts $f {run all}; puts $f quit; close $f
set result [run_cmd [file join $bin xsim.bat] runtime -tclbatch run.tcl]
if {![string match *PASS_SCCB_RUNTIME* $result]} {error "No runtime PASS"}
exit 0
