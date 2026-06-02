set repo_root [file normalize [file join [file dirname [info script]] ".."]]

set_part xc7a100tcsg324-1

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

read_vhdl $rtl_files
read_xdc [list [file join $repo_root "Constraints" "nexys.xdc"]]

synth_design -top star_tracker_top -part xc7a100tcsg324-1

report_utilization
report_timing_summary -max_paths 10

exit 0
