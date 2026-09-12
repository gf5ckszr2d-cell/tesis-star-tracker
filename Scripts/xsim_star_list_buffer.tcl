set repo_root [file normalize [file join [file dirname [info script]] ".."]]
set sim_dir [file join $repo_root "sim_build" "xsim_star_list_buffer"]
set run_tcl [file join $sim_dir "run_star_list_buffer.tcl"]
set snapshot "tb_star_list_buffer_snapshot"

file mkdir $sim_dir
cd $sim_dir

if {[info exists ::env(XILINX_VIVADO)]} {
    set vivado_bin [file join $::env(XILINX_VIVADO) "bin"]
} else {
    set vivado_bin [file dirname [file dirname [file dirname [info nameofexecutable]]]]
}

set xvhdl [file join $vivado_bin "xvhdl.bat"]
set xelab [file join $vivado_bin "xelab.bat"]
set xsim [file join $vivado_bin "xsim.bat"]

proc run_cmd {cmd_list} {
    puts "RUN: $cmd_list"
    set result [catch {exec {*}$cmd_list 2>@1} output]
    puts $output
    if {$result != 0} {
        error "Command failed: $cmd_list"
    }
    return $output
}

set rtl_file [file join $repo_root "Configuracion camara" "rtl" "star_list_buffer.vhd"]
set tb_file [file join $repo_root "Configuracion camara" "tb" "tb_star_list_buffer.vhd"]

run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $rtl_file]
run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $tb_file]
run_cmd [list cmd /c $xelab --debug typical --relax --mt 2 -L xil_defaultlib \
    --snapshot $snapshot xil_defaultlib.tb_star_list_buffer]

set fh [open $run_tcl w]
puts $fh {log_wave -recursive *}
puts $fh {run all}
puts $fh {quit}
close $fh

set sim_output [run_cmd [list cmd /c $xsim $snapshot -tclbatch $run_tcl]]
if {![regexp {PASS_STAR_LIST_BUFFER} $sim_output]} {
    error "PASS_STAR_LIST_BUFFER not found in simulator output"
}

puts "SIMULACION_STAR_LIST_BUFFER_COMPLETADA"
exit 0
