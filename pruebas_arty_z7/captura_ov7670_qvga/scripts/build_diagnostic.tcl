set root [file normalize [file join [file dirname [info script]] ..]]
set_param board.repoPaths [list [file join $::env(APPDATA) Xilinx Vivado 2025.2 xhub board_store xilinx_board_store XilinxBoardStore Vivado 2025.2 boards]]
set pname [file tail $root]
set pdir [file join $root build proyecto]
if {[info exists ::env(CAPTURA_PROJECT_DIR)]} {set pdir [file normalize $::env(CAPTURA_PROJECT_DIR)]}
open_project [file join $pdir ${pname}.xpr]
if {![llength [get_files -quiet */sccb_runtime_bridge.vhd]]} {
    add_files -norecurse [file join $root rtl sccb_runtime_bridge.vhd]
}
set_property board_part_repo_paths [list [file join $::env(APPDATA) Xilinx Vivado 2025.2 xhub board_store xilinx_board_store XilinxBoardStore Vivado 2025.2 boards]] [current_project]
set bd [get_files -filter {NAME =~ */sistema_captura_arm.bd}]
if {[llength $bd] != 1} {error "No se encontro el block design sistema_captura_arm"}
set_property file_type VHDL [get_files -filter {NAME =~ */rtl/*.vhd}]
update_compile_order -fileset sources_1
open_bd_design $bd
if {[llength [get_bd_cells -quiet]] == 0} {
    puts "Reconstruyendo block design vacio desde Tcl"
    set_property top captura_uart_top [get_filesets sources_1]
    update_compile_order -fileset sources_1
    source [file join $root scripts sistema_captura_arm_diagnostico.tcl]
}
if {[llength [get_bd_cells -quiet]] == 0} {error "El block design sigue vacio"}
set_property top sistema_captura_arm_wrapper [get_filesets sources_1]
validate_bd_design
save_bd_design
reset_target all $bd
set_property synth_checkpoint_mode None $bd
generate_target all $bd
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
set out [file join $root build diagnostico resultados]
file mkdir $out
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $out timing.rpt]
report_cdc -details -file [file join $out cdc.rpt]
report_drc -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]
write_hw_platform -fixed -include_bit -force -file [file join $out sistema_captura_arm_wrapper.xsa]
file copy -force [get_property DIRECTORY [get_runs impl_1]]/sistema_captura_arm_wrapper.bit $out
puts "PASS_BUILD_DIAGNOSTICO"
close_project
