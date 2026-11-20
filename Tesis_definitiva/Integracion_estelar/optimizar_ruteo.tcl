set dcp [file normalize [lindex $argv 0]]
set evidence [file normalize [lindex $argv 1]]
file mkdir $evidence
source [file join [file dirname [info script]] agrupar_fallos.tcl]
open_checkpoint $dcp
phys_opt_design -directive AggressiveExplore
write_checkpoint -force [file join $evidence diseno_ruteado.dcp]
report_timing_summary -report_unconstrained -file [file join $evidence timing_ruteado.rpt]
report_timing_summary -report_unconstrained -rpx [file join $evidence timing_ruteado.rpx]
report_utilization -file [file join $evidence utilizacion_ruteada.rpt]
report_route_status -file [file join $evidence estado_ruteo.rpt]
report_timing -max_paths 10 -file [file join $evidence rutas_criticas.rpt]
report_cdc -details -file [file join $evidence cdc.rpt]
agrupar_fallos [file join $evidence destinos_setup.tsv]
puts "REPORTES_POSRUTEO_LISTOS"
