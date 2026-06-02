set repo_root [file normalize [file join [file dirname [info script]] ".."]]
set sim_dir [file join $repo_root "sim_build" "xsim_top_uart_full"]
set run_tcl [file join $sim_dir "run_top_uart_full.tcl"]
set snapshot "tb_star_tracker_top_uart_full_snapshot"

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
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_capture_y_stream.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_capture_store.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "framebuffer_y_bram.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_uart_dump.vhd"] \
    [file join $repo_root "Top" "rtl" "star_tracker_top.vhd"] \
]

set tb_file [file join $repo_root "Top" "tb" "tb_star_tracker_top_uart_full.vhd"]

foreach rtl_file $rtl_files {
    run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $rtl_file]
}

run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $tb_file]

run_cmd [list cmd /c $xelab --debug typical --relax --mt 2 -L xil_defaultlib -L unisim -L unimacro -L secureip --snapshot $snapshot xil_defaultlib.tb_star_tracker_top_uart_full]

set fh [open $run_tcl w]
puts $fh {log_wave /tb_star_tracker_top_uart_full/clk}
puts $fh {log_wave /tb_star_tracker_top_uart_full/rst}
puts $fh {log_wave /tb_star_tracker_top_uart_full/start_btn}
puts $fh {log_wave /tb_star_tracker_top_uart_full/cam_pclk}
puts $fh {log_wave /tb_star_tracker_top_uart_full/cam_xclk}
puts $fh {log_wave /tb_star_tracker_top_uart_full/cam_vsync}
puts $fh {log_wave /tb_star_tracker_top_uart_full/cam_href}
puts $fh {log_wave /tb_star_tracker_top_uart_full/cam_data}
puts $fh {log_wave /tb_star_tracker_top_uart_full/pixel_valid}
puts $fh {log_wave /tb_star_tracker_top_uart_full/frame_done}
puts $fh {log_wave /tb_star_tracker_top_uart_full/led_read_data}
puts $fh {log_wave /tb_star_tracker_top_uart_full/fail}
puts $fh {log_wave /tb_star_tracker_top_uart_full/ok}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uart_tx_line}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/fb_wr_en}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/fb_wr_addr}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/fb_wr_data}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/fb_rd_addr}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/fb_rd_data}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/capture_frame_done}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/store_frame_ready}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/store_frame_ready_toggle}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/capture_overflow}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/store_overflow}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/dump_busy}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/dump_done}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/uart_start}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/uart_data}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/uart_busy}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/uart_done}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/xclk_locked}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/xclk_ready}
puts $fh {log_wave /tb_star_tracker_top_uart_full/uut/init_start}
puts $fh {run all}
puts $fh {quit}
close $fh

run_cmd [list cmd /c $xsim $snapshot -tclbatch $run_tcl -wdb [file join $sim_dir "xsim_top_uart_full.wdb"]]

exit 0
