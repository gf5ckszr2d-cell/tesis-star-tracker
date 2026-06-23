set section_dir [file normalize [file join [file dirname [info script]] ".."]]
set repo_root [file normalize [file join $section_dir ".." ".."]]
set sim_dir [file join $repo_root "sim_build" "capture_storage_integration"]
set wave_cfg [file join $section_dir "scripts" "waves_capture_storage_integration.wcfg"]
set wdb_file [file join $sim_dir "capture_storage_integration.wdb"]
if {![file exists $wdb_file]} { error "Ejecuta primero xsim_capture_storage_integration.tcl" }
cd $sim_dir
exec {C:/AMDDesignTools/2025.2/Vivado/bin/xsim.bat} +    tb_capture_storage_integration_snapshot +    -gui +    -wdb $wdb_file +    -view $wave_cfg &
