set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".."]]
set project_dir [file normalize [file join $script_dir "init_config_i2c_test_top"]]

set project_name "init_config_i2c_test_top"
set part_name "xc7a100tcsg324-1"

create_project -force $project_name $project_dir -part $part_name

set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

add_files -norecurse [list \
    [file join $repo_root "Protocolo de comunicacion" "rtl" "i2c_master.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_init_config.vhd"] \
    [file join $repo_root "test_tops" "rtl" "init_config_i2c_test_top.vhd"] \
]

add_files -fileset sim_1 -norecurse [list \
    [file join $repo_root "test_tops" "tb" "tb_init_config_i2c_test_top.vhd"] \
]

set_property top init_config_i2c_test_top [get_filesets sources_1]
set_property top tb_init_config_i2c_test_top [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

close_project

puts "PROJECT_CREATED: [file join $project_dir ${project_name}.xpr]"
exit 0
