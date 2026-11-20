set project [file normalize [lindex $argv 0]]
set evidence [file normalize [lindex $argv 1]]
file mkdir $evidence
open_project $project
set impl [get_runs impl_1]
set status [get_property STATUS $impl]
if {![string match "*route_design Complete*" $status] && $status ne "Out-of-date"} {
    error "impl_1 debe tener un ruteo completo. Estado: $status"
}
set synth_status [get_property STATUS [get_runs synth_1]]
if {![string match "*Complete*" $synth_status]} {
    error "Se necesita una sintesis vigente. Estado: $synth_status"
}
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true $impl
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore $impl
if {[get_property STATUS $impl] eq "Out-of-date"} {
    reset_run $impl
}
launch_runs $impl -to_step {phys_opt_design (Post-Route)} -jobs 2
wait_on_run $impl
set status [get_property STATUS $impl]
if {![string match -nocase "*phys_opt_design*complete*" $status]} {
    error "Posruteo: $status"
}
open_run $impl
report_timing_summary -report_unconstrained -file [file join $evidence timing_impl_1.rpt]
puts "POSRUTEO_INTEGRADO_EN_IMPL_1"
close_project
