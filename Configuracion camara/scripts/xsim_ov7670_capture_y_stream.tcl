set repo_root [file normalize [file join [file dirname [info script]] ".." ".."]]
set sim_dir [file join $repo_root "sim_build" "xsim_ov7670_capture_y_stream"]
set run_tcl [file join $sim_dir "run_ov7670_capture_y_stream.tcl"]
set wave_cfg [file join $repo_root "Scripts" "waves_ov7670_capture_y_stream.wcfg"]
set snapshot "tb_ov7670_capture_y_stream_snapshot"

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

set rtl_file [file join $repo_root "Configuracion camara" "rtl" "ov7670_capture_y_stream.vhd"]
set tb_file  [file join $repo_root "Configuracion camara" "tb"  "tb_ov7670_capture_y_stream.vhd"]

run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $rtl_file]
run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $tb_file]

run_cmd [list cmd /c $xelab --debug typical --relax --mt 2 -L xil_defaultlib --snapshot $snapshot xil_defaultlib.tb_ov7670_capture_y_stream]

set fh [open $run_tcl w]
puts $fh [list set wave_cfg $wave_cfg]

puts $fh {log_wave /tb_ov7670_capture_y_stream/pclk}
puts $fh {log_wave /tb_ov7670_capture_y_stream/rst}
puts $fh {log_wave /tb_ov7670_capture_y_stream/enable}
puts $fh {log_wave /tb_ov7670_capture_y_stream/vsync}
puts $fh {log_wave /tb_ov7670_capture_y_stream/href}
puts $fh {log_wave /tb_ov7670_capture_y_stream/data}
puts $fh {log_wave /tb_ov7670_capture_y_stream/pixel_y}
puts $fh {log_wave /tb_ov7670_capture_y_stream/pixel_valid}
puts $fh {log_wave /tb_ov7670_capture_y_stream/pixel_x}
puts $fh {log_wave /tb_ov7670_capture_y_stream/pixel_y_pos}
puts $fh {log_wave /tb_ov7670_capture_y_stream/frame_active}
puts $fh {log_wave /tb_ov7670_capture_y_stream/frame_done}
puts $fh {log_wave /tb_ov7670_capture_y_stream/overflow}
puts $fh {log_wave /tb_ov7670_capture_y_stream/seen_pixel_count}

puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/x_count}
puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/y_count}
puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/byte_phase}
puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/href_active}
puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/vsync_active}
puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/href_active_prev}
puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/frame_active_reg}
puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/pixel_y_reg}
puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/pixel_valid_reg}
puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/pixel_x_reg}
puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/pixel_y_pos_reg}
puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/frame_done_reg}
puts $fh {log_wave /tb_ov7670_capture_y_stream/uut/overflow_reg}

puts $fh {create_wave_config waves_ov7670_capture_y_stream}
puts $fh {set control_group [add_wave_group {Control}]}
puts $fh {add_wave -into $control_group /tb_ov7670_capture_y_stream/pclk /tb_ov7670_capture_y_stream/rst /tb_ov7670_capture_y_stream/enable /tb_ov7670_capture_y_stream/seen_pixel_count}
puts $fh {set camera_group [add_wave_group {Entrada OV7670}]}
puts $fh {add_wave -into $camera_group /tb_ov7670_capture_y_stream/vsync /tb_ov7670_capture_y_stream/href /tb_ov7670_capture_y_stream/data}
puts $fh {set output_group [add_wave_group {Salida Y stream}]}
puts $fh {add_wave -into $output_group /tb_ov7670_capture_y_stream/pixel_y /tb_ov7670_capture_y_stream/pixel_valid /tb_ov7670_capture_y_stream/pixel_x /tb_ov7670_capture_y_stream/pixel_y_pos /tb_ov7670_capture_y_stream/frame_active /tb_ov7670_capture_y_stream/frame_done /tb_ov7670_capture_y_stream/overflow}
puts $fh {set internal_group [add_wave_group {Internas captura}]}
puts $fh {add_wave -into $internal_group /tb_ov7670_capture_y_stream/uut/x_count /tb_ov7670_capture_y_stream/uut/y_count /tb_ov7670_capture_y_stream/uut/byte_phase /tb_ov7670_capture_y_stream/uut/href_active /tb_ov7670_capture_y_stream/uut/vsync_active /tb_ov7670_capture_y_stream/uut/href_active_prev}
puts $fh {set regs_group [add_wave_group {Registros salida}]}
puts $fh {add_wave -into $regs_group /tb_ov7670_capture_y_stream/uut/frame_active_reg /tb_ov7670_capture_y_stream/uut/pixel_y_reg /tb_ov7670_capture_y_stream/uut/pixel_valid_reg /tb_ov7670_capture_y_stream/uut/pixel_x_reg /tb_ov7670_capture_y_stream/uut/pixel_y_pos_reg /tb_ov7670_capture_y_stream/uut/frame_done_reg /tb_ov7670_capture_y_stream/uut/overflow_reg}

puts $fh {save_wave_config $wave_cfg}
puts $fh {run 20 us}
puts $fh {save_wave_config $wave_cfg}
puts $fh {quit}
close $fh

run_cmd [list cmd /c $xsim $snapshot -tclbatch $run_tcl -wdb [file join $sim_dir "xsim_ov7670_capture_y_stream.wdb"]]

exit 0
