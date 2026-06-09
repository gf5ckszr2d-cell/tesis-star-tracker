set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".."]]
set project_path [file normalize [file join $script_dir "star_tracker_top" "star_tracker_top.xpr"]]

set main_bit_dir [file normalize [file join $repo_root "Top" "bitstreams"]]
set debug_bit_dir [file normalize [file join $repo_root "test_tops" "bitstreams"]]

file mkdir $main_bit_dir
file mkdir $debug_bit_dir

open_project $project_path

proc build_bitstream {top_name constrset_name bit_path} {
    set_property top $top_name [get_filesets sources_1]
    update_compile_order -fileset sources_1

    set_property constrset $constrset_name [get_runs synth_1]
    set_property constrset $constrset_name [get_runs impl_1]

    reset_run synth_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
        error "Synthesis failed for $top_name"
    }

    set_property constrset $constrset_name [get_runs impl_1]
    reset_run impl_1
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
        error "Implementation/bitstream failed for $top_name"
    }

    set run_bit [get_property DIRECTORY [get_runs impl_1]]/$top_name.bit
    if {![file exists $run_bit]} {
        error "Expected bitstream was not generated: $run_bit"
    }

    file copy -force $run_bit $bit_path
    puts "BITSTREAM_READY: $bit_path"
}

build_bitstream \
    star_tracker_top \
    constrs_star_tracker_top \
    [file join $main_bit_dir "star_tracker_top_nexys.bit"]

build_bitstream \
    init_config_i2c_test_top \
    constrs_init_config_i2c_test_top \
    [file join $debug_bit_dir "init_config_i2c_test_top_nexys_debug.bit"]

set_property top star_tracker_top [get_filesets sources_1]
set_property constrset constrs_star_tracker_top [get_runs synth_1]
set_property constrset constrs_star_tracker_top [get_runs impl_1]
update_compile_order -fileset sources_1

close_project
exit 0
