set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".."]]
set project_dir [file normalize [file join $script_dir "star_tracker_top"]]

set project_name "star_tracker_top"
set part_name "xc7a100tcsg324-1"

create_project -force $project_name $project_dir -part $part_name

set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

set rtl_files [list \
    [file join $repo_root "Protocolo de comunicacion" "rtl" "i2c_master.vhd"] \
    [file join $repo_root "Protocolo de comunicacion" "rtl" "uart_tx.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_xclk_gen.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_init_config.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_capture_y_stream.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_capture_y_stream_fsm.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_capture_store.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "framebuffer_y_bram.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_uart_dump.vhd"] \
    [file join $repo_root "test_tops" "rtl" "init_config_i2c_test_top.vhd"] \
    [file join $repo_root "Top" "rtl" "star_tracker_top.vhd"] \
]

set tb_files [list \
    [file join $repo_root "Protocolo de comunicacion" "tb" "tb_i2c_master.vhd"] \
    [file join $repo_root "Protocolo de comunicacion" "tb" "tb_uart_tx.vhd"] \
    [file join $repo_root "Configuracion camara" "tb" "tb_ov7670_xclk_gen.vhd"] \
    [file join $repo_root "Configuracion camara" "tb" "tb_ov7670_init_config.vhd"] \
    [file join $repo_root "Configuracion camara" "tb" "tb_ov7670_capture_y_stream.vhd"] \
    [file join $repo_root "Configuracion camara" "tb" "tb_ov7670_capture_y_stream_fsm.vhd"] \
    [file join $repo_root "Configuracion camara" "tb" "tb_ov7670_capture_y_stream_compare.vhd"] \
    [file join $repo_root "Configuracion camara" "tb" "tb_framebuffer_y_bram.vhd"] \
    [file join $repo_root "test_tops" "tb" "tb_init_config_i2c_test_top.vhd"] \
    [file join $repo_root "Top" "tb" "tb_star_tracker_top.vhd"] \
    [file join $repo_root "Top" "tb" "tb_star_tracker_top_uart_full.vhd"] \
]

add_files -norecurse $rtl_files
add_files -fileset sim_1 -norecurse $tb_files
set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]

set star_xdc [file join $repo_root "Top" "constraints" "star_tracker_top_nexys.xdc"]
set init_xdc [file join $repo_root "test_tops" "constraints" "init_config_i2c_test_top_nexys_debug.xdc"]

add_files -fileset constrs_1 -norecurse $star_xdc
set_property name constrs_star_tracker_top [get_filesets constrs_1]

create_fileset -constrset constrs_init_config_i2c_test_top
add_files -fileset constrs_init_config_i2c_test_top -norecurse $init_xdc

set_property top star_tracker_top [get_filesets sources_1]
set_property top tb_star_tracker_top_uart_full [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "PROJECT_CREATED: [file join $project_dir ${project_name}.xpr]"
puts "DEFAULT_SYNTH_TOP: star_tracker_top"
puts "ALT_SYNTH_TOP: init_config_i2c_test_top"
puts "CONSTRAINT_SET_MAIN: constrs_star_tracker_top"
puts "CONSTRAINT_SET_INIT_DEBUG: constrs_init_config_i2c_test_top"

close_project
exit 0
