set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build sccb_timing]
file mkdir $out
cd $out
set bin [file join $::env(XILINX_VIVADO) bin]
proc run_cmd {args} {
    if {[catch {exec {*}$args 2>@1} result]} {puts $result; error "Failed: $args"}
    puts $result
    return $result
}
run_cmd [file join $bin xvhdl.bat] --2008 [file join $root rtl i2c_master.vhd] [file join $root tb tb_sccb_timing.vhd]
run_cmd [file join $bin xelab.bat] work.tb_sccb_timing -s sccb
set f [open run.tcl w]; puts $f {run all}; puts $f quit; close $f
set result [run_cmd [file join $bin xsim.bat] sccb -tclbatch run.tcl]
if {![string match *PASS_SCCB_TIMING* $result]} {error "No SCCB PASS"}
exit 0
