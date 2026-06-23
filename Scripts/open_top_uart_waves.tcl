# Abre en la GUI actual las ondas ya generadas por xsim_top_uart_full.tcl.
set repo_root [file normalize [file join [file dirname [info script]] ".."]]
set sim_dir [file join $repo_root "sim_build" "xsim_top_uart_full"]
set wave_cfg [file join $repo_root "Scripts" "waves_star_tracker_top.wcfg"]
set wdb_file [file join $sim_dir "xsim_top_uart_full.wdb"]
set snapshot "tb_star_tracker_top_snapshot"

if {![file exists $wdb_file]} {
    error "No existe el WDB. Ejecuta primero Scripts/xsim_top_uart_full.tcl"
}

if {![file exists $wave_cfg]} {
    error "No existe la configuracion de ondas: $wave_cfg"
}

cd $sim_dir
exec {C:/AMDDesignTools/2025.2/Vivado/bin/xsim.bat} +    $snapshot +    -gui +    -wdb $wdb_file +    -view $wave_cfg &

puts "XSim lanzado con las ondas del top: $wdb_file"
