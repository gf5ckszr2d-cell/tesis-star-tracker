set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build store_integrity]
file mkdir $out
cd $out
set bin [file join $::env(XILINX_VIVADO) bin]
proc run_cmd {args} {
    if {[catch {exec {*}$args 2>@1} result]} {puts $result; error "Failed: $args"}
    puts $result
    return $result
}
run_cmd [file join $bin xvhdl.bat] --2008 [file join $root rtl frame_capture_store.vhd] [file join $root tb tb_store_integrity.vhd]
run_cmd [file join $bin xelab.bat] work.tb_store_integrity -s store
set f [open run.tcl w]; puts $f {run all}; puts $f quit; close $f
set result [run_cmd [file join $bin xsim.bat] store -tclbatch run.tcl]
if {![string match *PASS_STORE_INTEGRITY* $result]} {error "No STORE PASS"}
exit 0
