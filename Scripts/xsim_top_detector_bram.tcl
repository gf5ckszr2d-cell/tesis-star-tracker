set repo_root [file normalize [file join [file dirname [info script]] ".."]]
set sim_dir [file join $repo_root "sim_build" "xsim_top_detector_bram"]
set run_tcl [file join $sim_dir "run_top_detector_bram.tcl"]
set snapshot "tb_star_tracker_top_detector_snapshot"

file mkdir $sim_dir
cd $sim_dir

if {[info exists ::env(XILINX_VIVADO)]} {
    set vivado_bin [file join $::env(XILINX_VIVADO) "bin"]
} else {
    set vivado_bin [file dirname [file dirname [file dirname [info nameofexecutable]]]]
}

set xvhdl [file join $vivado_bin "xvhdl.bat"]
set xelab [file join $vivado_bin "unwrapped" "win64.o" "xelab.exe"]
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
    [file join $repo_root "Protocolo de comunicacion" "rtl" "i2c_master.vhd"] \
    [file join $repo_root "Protocolo de comunicacion" "rtl" "uart_tx.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_xclk_gen.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_init_config.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_runtime_config.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_capture_y_stream.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_capture_store.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "framebuffer_y_bram.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_uart_dump.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "unsigned_iterative_divider.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_star_centroid.vhd"] \
    [file join $repo_root "Top" "rtl" "star_tracker_top.vhd"] \
]

foreach rtl_file $rtl_files {
    run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $rtl_file]
}

run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib \
    [file join $repo_root "Top" "tb" "tb_star_tracker_top.vhd"]]

run_cmd [list $xelab --debug typical --relax --mt 2 \
    -L xil_defaultlib -L unisim -L unimacro -L secureip \
    -generic_top DIAGNOSTIC_MODE=false \
    --snapshot $snapshot xil_defaultlib.tb_star_tracker_top]

set fh [open $run_tcl w]
puts $fh {run all}
puts $fh {quit}
close $fh

set sim_output [run_cmd [list cmd /c $xsim $snapshot -tclbatch $run_tcl]]
if {![regexp {PASS_TOP_DETECTOR_BRAM} $sim_output]} {
    error "PASS_TOP_DETECTOR_BRAM not found in simulator output"
}

puts "SIMULACION_TOP_DETECTOR_BRAM_COMPLETADA"
exit 0
