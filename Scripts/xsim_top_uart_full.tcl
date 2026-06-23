set repo_root [file normalize [file join [file dirname [info script]] ".."]]
set sim_dir [file join $repo_root "sim_build" "xsim_top_uart_full"]
set run_tcl [file join $sim_dir "run_top_uart_full.tcl"]
set wdb_file [file join $sim_dir "xsim_top_uart_full.wdb"]
set wave_cfg [file join $repo_root "Scripts" "waves_star_tracker_top.wcfg"]
set snapshot "tb_star_tracker_top_snapshot"

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
    [file join $repo_root "Protocolo de comunicacion" "rtl" "i2c_master.vhd"] \
    [file join $repo_root "Protocolo de comunicacion" "rtl" "uart_tx.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_xclk_gen.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_init_config.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_runtime_config.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_capture_y_stream.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_capture_store.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "framebuffer_y_bram.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_uart_dump.vhd"] \
    [file join $repo_root "Top" "rtl" "star_tracker_top.vhd"] \
]

set tb_file [file join $repo_root "Top" "tb" "tb_star_tracker_top.vhd"]

foreach rtl_file $rtl_files {
    run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $rtl_file]
}

run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $tb_file]

run_cmd [list cmd /c $xelab --debug typical --relax --mt 2 -L xil_defaultlib -L unisim -L unimacro -L secureip --snapshot $snapshot xil_defaultlib.tb_star_tracker_top]

set fh [open $run_tcl w]
puts $fh [list set wave_cfg $wave_cfg]
foreach signal {
    /tb_star_tracker_top/clk /tb_star_tracker_top/rst
    /tb_star_tracker_top/start_btn /tb_star_tracker_top/busy
    /tb_star_tracker_top/ok /tb_star_tracker_top/fail
    /tb_star_tracker_top/cam_xclk /tb_star_tracker_top/SCL
    /tb_star_tracker_top/SDA /tb_star_tracker_top/uut/xclk_locked
    /tb_star_tracker_top/uut/xclk_ready /tb_star_tracker_top/uut/init_start
    /tb_star_tracker_top/uut/init_busy /tb_star_tracker_top/uut/init_done
    /tb_star_tracker_top/uut/init_error
    /tb_star_tracker_top/btn_config /tb_star_tracker_top/sw
    /tb_star_tracker_top/runtime_write_count
    /tb_star_tracker_top/uut/runtime_busy /tb_star_tracker_top/uut/runtime_done
    /tb_star_tracker_top/uut/runtime_error /tb_star_tracker_top/uut/runtime_active_param
    /tb_star_tracker_top/uut/i2c_runtime_owner
    /tb_star_tracker_top/cam_pclk /tb_star_tracker_top/cam_vsync
    /tb_star_tracker_top/cam_href /tb_star_tracker_top/cam_data
    /tb_star_tracker_top/pixel_valid /tb_star_tracker_top/frame_done
    /tb_star_tracker_top/pixel_count /tb_star_tracker_top/led_read_data
    /tb_star_tracker_top/uut/fb_wr_en /tb_star_tracker_top/uut/fb_wr_addr
    /tb_star_tracker_top/uut/fb_wr_data /tb_star_tracker_top/uut/fb_rd_addr
    /tb_star_tracker_top/uut/fb_rd_data /tb_star_tracker_top/uut/capture_frame_done
    /tb_star_tracker_top/uut/store_frame_ready /tb_star_tracker_top/uut/store_frame_ready_toggle
    /tb_star_tracker_top/uut/capture_overflow /tb_star_tracker_top/uut/store_overflow
    /tb_star_tracker_top/uut/dump_busy /tb_star_tracker_top/uut/dump_done
    /tb_star_tracker_top/uut/uart_start /tb_star_tracker_top/uut/uart_data
    /tb_star_tracker_top/uut/uart_busy /tb_star_tracker_top/uut/uart_done
    /tb_star_tracker_top/uart_tx_line /tb_star_tracker_top/uart_done_seen
} { puts $fh [list log_wave $signal] }

puts $fh {create_wave_config star_tracker_top}
puts $fh {set g1 [add_wave_group {1. Control y resultado}]}
puts $fh {add_wave -into $g1 /tb_star_tracker_top/clk /tb_star_tracker_top/rst /tb_star_tracker_top/start_btn /tb_star_tracker_top/busy /tb_star_tracker_top/ok /tb_star_tracker_top/fail}
puts $fh {set g2 [add_wave_group {2. XCLK e inicializacion SCCB I2C}]}
puts $fh {add_wave -into $g2 /tb_star_tracker_top/cam_xclk /tb_star_tracker_top/SCL /tb_star_tracker_top/SDA /tb_star_tracker_top/uut/xclk_locked /tb_star_tracker_top/uut/xclk_ready /tb_star_tracker_top/uut/init_start /tb_star_tracker_top/uut/init_busy /tb_star_tracker_top/uut/init_done /tb_star_tracker_top/uut/init_error}
puts $fh {set g3 [add_wave_group {3. Calibracion manual}]}
puts $fh {add_wave -into $g3 /tb_star_tracker_top/btn_config /tb_star_tracker_top/sw /tb_star_tracker_top/runtime_write_count /tb_star_tracker_top/uut/runtime_busy /tb_star_tracker_top/uut/runtime_done /tb_star_tracker_top/uut/runtime_error /tb_star_tracker_top/uut/runtime_active_param /tb_star_tracker_top/uut/i2c_runtime_owner}
puts $fh {set g4 [add_wave_group {4. Captura OV7670 Y}]}
puts $fh {add_wave -into $g4 /tb_star_tracker_top/cam_pclk /tb_star_tracker_top/cam_vsync /tb_star_tracker_top/cam_href /tb_star_tracker_top/cam_data /tb_star_tracker_top/pixel_valid /tb_star_tracker_top/frame_done /tb_star_tracker_top/pixel_count /tb_star_tracker_top/led_read_data}
puts $fh {set g5 [add_wave_group {5. Framebuffer BRAM}]}
puts $fh {add_wave -into $g5 /tb_star_tracker_top/uut/fb_wr_en /tb_star_tracker_top/uut/fb_wr_addr /tb_star_tracker_top/uut/fb_wr_data /tb_star_tracker_top/uut/capture_frame_done /tb_star_tracker_top/uut/store_frame_ready /tb_star_tracker_top/uut/fb_rd_addr /tb_star_tracker_top/uut/fb_rd_data /tb_star_tracker_top/uut/capture_overflow /tb_star_tracker_top/uut/store_overflow}
puts $fh {set g6 [add_wave_group {6. Paquete UART}]}
puts $fh {add_wave -into $g6 /tb_star_tracker_top/uut/dump_busy /tb_star_tracker_top/uut/dump_done /tb_star_tracker_top/uut/uart_start /tb_star_tracker_top/uut/uart_data /tb_star_tracker_top/uut/uart_busy /tb_star_tracker_top/uut/uart_done /tb_star_tracker_top/uart_tx_line /tb_star_tracker_top/uart_done_seen}
puts $fh {save_wave_config $wave_cfg}
puts $fh {run all}
puts $fh {save_wave_config $wave_cfg}
puts $fh {quit}
close $fh

run_cmd [list cmd /c $xsim $snapshot -tclbatch $run_tcl -wdb $wdb_file]

puts ""
puts "============================================================"
puts "SIMULACION GLOBAL COMPLETADA"
puts "WDB:  $wdb_file"
puts "WCFG: $wave_cfg"
puts "============================================================"

exit 0
