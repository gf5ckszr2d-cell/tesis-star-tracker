set repo_root [file normalize [file join [file dirname [info script]] ".."]]
set sim_dir [file join $repo_root "sim_build" "xsim_frame_star_centroid"]
set run_tcl [file join $sim_dir "run_frame_star_centroid.tcl"]
set snapshot "tb_frame_star_centroid_snapshot"

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

set rtl_files [list \
    [file join $repo_root "Configuracion camara" "rtl" "unsigned_iterative_divider.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_star_centroid.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "star_list_buffer.vhd"] \
]
set tb_file [file join $repo_root "Configuracion camara" "tb" "tb_frame_star_centroid.vhd"]

foreach rtl_file $rtl_files {
    run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $rtl_file]
}
run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $tb_file]
run_cmd [list cmd /c $xelab --debug typical --relax --mt 2 -L xil_defaultlib --snapshot $snapshot xil_defaultlib.tb_frame_star_centroid]

set fh [open $run_tcl w]
puts $fh {log_wave -recursive *}
puts $fh {run all}
puts $fh {quit}
close $fh

set sim_output [run_cmd [list cmd /c $xsim $snapshot -tclbatch $run_tcl]]
if {![regexp {PASS_FRAME_STAR_CENTROID} $sim_output]} {
    error "PASS_FRAME_STAR_CENTROID not found in simulator output"
}

puts "SIMULACION_FRAME_STAR_CENTROID_COMPLETADA"
