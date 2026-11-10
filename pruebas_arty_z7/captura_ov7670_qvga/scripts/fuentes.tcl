# Manifiesto independiente: no agregar star_tracker_top ni directorios completos.
set captura_root [file normalize [file join [file dirname [info script]] ..]]
set captura_rtl [list]
foreach name {i2c_master uart_tx ov7670_init_config ov7670_capture_y_stream frame_capture_store framebuffer_y_bram frame_uart_dump capture_frame_diag captura_xclk captura_uart_top} {
    set source_file [file join $captura_root rtl ${name}.vhd]
    if {![file isfile $source_file]} {error "Fuente de captura inexistente: $source_file"}
    lappend captura_rtl $source_file
}
