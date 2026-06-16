set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".."]]
set project_dir [file normalize [file join $script_dir "star_tracker_top"]]

set project_name "star_tracker_top"
set part_name "xc7a100tcsg324-1"
set preferred_board_parts [list \
    "digilentinc.com:nexys-a7-100t:part0:1.3" \
    "digilentinc.com:nexys-a7-100t:part0:1.0" \
]

create_project -force $project_name $project_dir -part $part_name

set selected_board_part ""
foreach board_part $preferred_board_parts {
    set matches [get_board_parts -quiet $board_part]
    if {[llength $matches] > 0} {
        set selected_board_part [lindex $matches 0]
        break
    }
}

if {$selected_board_part ne ""} {
    set_property board_part $selected_board_part [current_project]
    puts "BOARD_PART: $selected_board_part"
} else {
    puts "BOARD_PART_WARNING: Nexys A7-100T board files not found; using FPGA part $part_name"
}

set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

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

set tb_files [list \
    [file join $repo_root "Protocolo de comunicacion" "tb" "tb_i2c_master.vhd"] \
    [file join $repo_root "Protocolo de comunicacion" "tb" "tb_uart_tx.vhd"] \
    [file join $repo_root "Configuracion camara" "tb" "tb_ov7670_xclk_gen.vhd"] \
    [file join $repo_root "Configuracion camara" "tb" "tb_ov7670_init_config.vhd"] \
    [file join $repo_root "Configuracion camara" "tb" "tb_ov7670_runtime_config.vhd"] \
    [file join $repo_root "Configuracion camara" "tb" "tb_ov7670_capture_y_stream.vhd"] \
    [file join $repo_root "Configuracion camara" "tb" "tb_framebuffer_y_bram.vhd"] \
    [file join $repo_root "Top" "tb" "tb_star_tracker_top.vhd"] \
]

add_files -norecurse $rtl_files
add_files -fileset sim_1 -norecurse $tb_files
set_property file_type {VHDL 2008} [get_files -filter {FILE_TYPE == VHDL}]

set star_xdc [file join $repo_root "Top" "constraints" "star_tracker_top_nexys.xdc"]

add_files -fileset constrs_1 -norecurse $star_xdc
set_property name constrs_star_tracker_top [get_filesets constrs_1]

set_property top star_tracker_top [get_filesets sources_1]
set_property top tb_star_tracker_top [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "PROJECT_CREATED: [file join $project_dir ${project_name}.xpr]"
puts "DEFAULT_SYNTH_TOP: star_tracker_top"
puts "CONSTRAINT_SET_MAIN: constrs_star_tracker_top"

close_project
exit 0
