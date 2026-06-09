set repo_root [file normalize [file join [file dirname [info script]] ".." ".."]]
set sim_dir [file join $repo_root "sim_build" "xsim_ov7670_capture_y_stream_fsm_compare"]
set run_tcl [file join $sim_dir "run_ov7670_capture_y_stream_fsm_compare.tcl"]
set wave_cfg [file join $repo_root "Scripts" "waves_ov7670_capture_y_stream_fsm_compare.wcfg"]
set snapshot "tb_ov7670_capture_y_stream_fsm_compare_snapshot"

file mkdir $sim_dir
cd $sim_dir

if {[info exists ::env(XILINX_VIVADO)]} {
    set vivado_bin [file join $::env(XILINX_VIVADO) "bin"]
} else {
    set vivado_bin [file dirname [file dirname [file dirname [info nameofexecutable]]]]
}
set xvhdl [file join $vivado_bin "xvhdl.bat"]
set xelab [file join $vivado_bin "xelab.bat"]
set xsim  [file join $vivado_bin "xsim.bat"]

proc run_cmd {cmd_list} {
    puts "RUN: $cmd_list"
    set result [catch {exec {*}$cmd_list 2>@1} output]
    puts $output
    if {$result != 0} {
        error "Command failed: $cmd_list"
    }
}

set rtl_files [list \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_capture_y_stream.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_capture_y_stream_fsm.vhd"] \
]
set tb_file [file join $repo_root "Configuracion camara" "tb" "tb_ov7670_capture_y_stream_compare.vhd"]

foreach rtl_file $rtl_files {
    run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $rtl_file]
}
run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $tb_file]

run_cmd [list cmd /c $xelab --debug typical --relax --mt 2 -L xil_defaultlib --snapshot $snapshot xil_defaultlib.tb_ov7670_capture_y_stream_compare]

set fh [open $run_tcl w]
puts $fh [list set wave_cfg $wave_cfg]

puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/pclk}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/rst}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/enable}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/vsync}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/href}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/data}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/seen_pixel_count}

puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/orig_pixel_y}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/orig_pixel_valid}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/orig_pixel_x}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/orig_pixel_y_pos}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/orig_frame_active}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/orig_frame_done}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/orig_overflow}

puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/fsm_pixel_y}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/fsm_pixel_valid}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/fsm_pixel_x}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/fsm_pixel_y_pos}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/fsm_frame_active}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/fsm_frame_done}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/fsm_overflow}

puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/u_original/x_count}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/u_original/y_count}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/u_original/byte_phase}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/u_fsm/state}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/u_fsm/x_count}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/u_fsm/y_count}
puts $fh {log_wave /tb_ov7670_capture_y_stream_compare/u_fsm/byte_phase}

puts $fh {create_wave_config waves_ov7670_capture_y_stream_fsm_compare}
puts $fh {set input_group [add_wave_group {Entrada compartida}]}
puts $fh {add_wave -into $input_group /tb_ov7670_capture_y_stream_compare/pclk /tb_ov7670_capture_y_stream_compare/rst /tb_ov7670_capture_y_stream_compare/enable /tb_ov7670_capture_y_stream_compare/vsync /tb_ov7670_capture_y_stream_compare/href /tb_ov7670_capture_y_stream_compare/data /tb_ov7670_capture_y_stream_compare/seen_pixel_count}
puts $fh {set original_group [add_wave_group {Original}]}
puts $fh {add_wave -into $original_group /tb_ov7670_capture_y_stream_compare/orig_pixel_y /tb_ov7670_capture_y_stream_compare/orig_pixel_valid /tb_ov7670_capture_y_stream_compare/orig_pixel_x /tb_ov7670_capture_y_stream_compare/orig_pixel_y_pos /tb_ov7670_capture_y_stream_compare/orig_frame_active /tb_ov7670_capture_y_stream_compare/orig_frame_done /tb_ov7670_capture_y_stream_compare/orig_overflow}
puts $fh {set fsm_group [add_wave_group {FSM alternativa}]}
puts $fh {add_wave -into $fsm_group /tb_ov7670_capture_y_stream_compare/fsm_pixel_y /tb_ov7670_capture_y_stream_compare/fsm_pixel_valid /tb_ov7670_capture_y_stream_compare/fsm_pixel_x /tb_ov7670_capture_y_stream_compare/fsm_pixel_y_pos /tb_ov7670_capture_y_stream_compare/fsm_frame_active /tb_ov7670_capture_y_stream_compare/fsm_frame_done /tb_ov7670_capture_y_stream_compare/fsm_overflow}
puts $fh {set internal_group [add_wave_group {Internas comparacion}]}
puts $fh {add_wave -into $internal_group /tb_ov7670_capture_y_stream_compare/u_original/x_count /tb_ov7670_capture_y_stream_compare/u_original/y_count /tb_ov7670_capture_y_stream_compare/u_original/byte_phase /tb_ov7670_capture_y_stream_compare/u_fsm/state /tb_ov7670_capture_y_stream_compare/u_fsm/x_count /tb_ov7670_capture_y_stream_compare/u_fsm/y_count /tb_ov7670_capture_y_stream_compare/u_fsm/byte_phase}

puts $fh {save_wave_config $wave_cfg}
puts $fh {run 20 us}
puts $fh {save_wave_config $wave_cfg}
puts $fh {quit}
close $fh

run_cmd [list cmd /c $xsim $snapshot -tclbatch $run_tcl -wdb [file join $sim_dir "xsim_ov7670_capture_y_stream_fsm_compare.wdb"]]

exit 0
