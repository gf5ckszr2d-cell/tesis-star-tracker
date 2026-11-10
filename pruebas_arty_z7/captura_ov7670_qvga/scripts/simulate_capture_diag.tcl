set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build capture_diag]
file mkdir $out
cd $out
set bin [file join $::env(XILINX_VIVADO) bin]
proc checked {args} {
    if {[catch {exec {*}$args 2>@1} result]} {puts $result; error "Failed: $args"}
    puts $result
    return $result
}
checked [file join $bin xvhdl.bat] --2008 [file join $root rtl capture_frame_diag.vhd] [file join $root tb tb_capture_diag.vhd]
checked [file join $bin xelab.bat] work.tb_capture_diag -s capture_diag
set f [open run.tcl w]; puts $f {run all}; puts $f quit; close $f
set result [checked [file join $bin xsim.bat] capture_diag -tclbatch run.tcl]
if {![string match *PASS_CAPTURE_DIAG* $result]} {error "No CAPTURE DIAG PASS"}
exit 0
