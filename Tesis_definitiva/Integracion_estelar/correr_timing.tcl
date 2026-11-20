set project_dir [file normalize [lindex $argv 0]]
set evidence [file normalize [lindex $argv 1]]
set fase [lindex $argv 2]
source [file join [file dirname [info script]] agrupar_fallos.tcl]
file mkdir $evidence
open_project [file join $project_dir Tesis_definitiva.xpr]
set src [file join $project_dir Tesis_definitiva.srcs sources_1 new]
set names {g5_star_catalog_pkg g5_pair_lookup_pkg g5_ray_lut_pkg star_identifier enviar_matches_uart}
if {$fase eq "actitud"} {
    lappend names attitude_math_pkg unsigned_iterative_divider normalize4 attitude_triad enviar_actitud_uart
}
foreach name $names {
    set path [file join $src ${name}.vhd]
    if {[llength [get_files -quiet $path]] == 0} {
        add_files -norecurse $path
    }
}
update_compile_order -fileset sources_1
set module_runs [get_runs -quiet design_1_top_star_tracker_0_0_synth_1]
if {[llength $module_runs]} {reset_run $module_runs}
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {![string match "*Complete*" [get_property STATUS [get_runs synth_1]]]} {error "Sintesis: [get_property STATUS [get_runs synth_1]]"}
open_run synth_1
report_timing_summary -report_unconstrained -file [file join $evidence timing_sintesis.rpt]
report_utilization -file [file join $evidence utilizacion_sintesis.rpt]
close_design
launch_runs impl_1 -to_step route_design -jobs 8
wait_on_run impl_1
if {![string match "*Complete*" [get_property STATUS [get_runs impl_1]]]} {error "Implementacion: [get_property STATUS [get_runs impl_1]]"}
open_run impl_1
set run_dir [get_property DIRECTORY [get_runs impl_1]]
file copy -force [file join $run_dir design_1_wrapper_routed.dcp] [file join $evidence diseno_ruteado.dcp]
report_timing_summary -report_unconstrained -file [file join $evidence timing_ruteado.rpt]
report_timing_summary -report_unconstrained -rpx [file join $evidence timing_ruteado.rpx]
report_utilization -file [file join $evidence utilizacion_ruteada.rpt]
report_route_status -file [file join $evidence estado_ruteo.rpt]
report_timing -max_paths 10 -file [file join $evidence rutas_criticas.rpt]
report_cdc -details -file [file join $evidence cdc.rpt]
agrupar_fallos [file join $evidence destinos_setup.tsv]
puts "REPORTES_TIMING_LISTOS"
