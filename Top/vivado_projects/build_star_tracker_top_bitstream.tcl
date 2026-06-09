set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".."]]
set project_path [file normalize [file join $script_dir "star_tracker_top" "star_tracker_top.xpr"]]
set bit_dir [file normalize [file join $repo_root "Top" "bitstreams"]]
set bit_path [file join $bit_dir "star_tracker_top_nexys.bit"]

file mkdir $bit_dir

open_project $project_path

set_property top star_tracker_top [get_filesets sources_1]
set_property constrset constrs_star_tracker_top [get_runs synth_1]
set_property constrset constrs_star_tracker_top [get_runs impl_1]
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed for star_tracker_top"
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation/bitstream failed for star_tracker_top"
}

set run_bit [get_property DIRECTORY [get_runs impl_1]]/star_tracker_top.bit
if {![file exists $run_bit]} {
    error "Expected bitstream was not generated: $run_bit"
}

file copy -force $run_bit $bit_path
puts "BITSTREAM_READY: $bit_path"

close_project
exit 0
