# Simulacion integrada: captura Y + almacenamiento + BRAM.
set section_dir [file normalize [file join [file dirname [info script]] ".."]]
set repo_root [file normalize [file join $section_dir ".." ".."]]
set sim_dir [file join $repo_root "sim_build" "capture_storage_integration"]
set run_tcl [file join $sim_dir "run_capture_storage_integration.tcl"]
set wdb_file [file join $sim_dir "capture_storage_integration.wdb"]
set wave_cfg [file join $section_dir "scripts" "waves_capture_storage_integration.wcfg"]
set snapshot "tb_capture_storage_integration_snapshot"

file mkdir $sim_dir
cd $sim_dir

if {[info exists ::env(XILINX_VIVADO)]} {
    set vivado_bin [file join $::env(XILINX_VIVADO) "bin"]
} else {
    set vivado_bin [file dirname [file dirname [file dirname [info nameofexecutable]]]]
}
set xvhdl [file join $vivado_bin "xvhdl.bat"]
set xelab [file join $vivado_bin "xelab.bat"]
set xsim [file join $vivado_bin "xsim.bat"]

proc run_cmd {command} {
    puts "RUN: $command"
    set failed [catch {exec {*}$command 2>@1} output]
    puts $output
    if {$failed} { error "Fallo el comando: $command" }
}

set sources [list]
lappend sources [file join $repo_root "Configuracion camara" "rtl" "ov7670_capture_y_stream.vhd"]
lappend sources [file join $repo_root "Configuracion camara" "rtl" "frame_capture_store.vhd"]
lappend sources [file join $repo_root "Configuracion camara" "rtl" "framebuffer_y_bram.vhd"]
lappend sources [file join $section_dir "rtl" "capture_storage_integration_top.vhd"]
lappend sources [file join $section_dir "tb" "tb_capture_storage_integration_top.vhd"]

foreach source $sources {
    run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $source]
}
run_cmd [list cmd /c $xelab --debug typical --relax --mt 2 -L xil_defaultlib --snapshot $snapshot xil_defaultlib.tb_capture_storage_integration_top]

set fh [open $run_tcl w]
puts $fh [list set wave_cfg $wave_cfg]
foreach signal {
    /tb_capture_storage_integration_top/pclk
    /tb_capture_storage_integration_top/rst
    /tb_capture_storage_integration_top/enable
    /tb_capture_storage_integration_top/arm_capture
    /tb_capture_storage_integration_top/cam_vsync
    /tb_capture_storage_integration_top/cam_href
    /tb_capture_storage_integration_top/cam_data
    /tb_capture_storage_integration_top/pixel_y
    /tb_capture_storage_integration_top/pixel_valid
    /tb_capture_storage_integration_top/pixel_x
    /tb_capture_storage_integration_top/pixel_y_pos
    /tb_capture_storage_integration_top/frame_active
    /tb_capture_storage_integration_top/frame_done
    /tb_capture_storage_integration_top/pixel_count
    /tb_capture_storage_integration_top/wr_en
    /tb_capture_storage_integration_top/wr_addr
    /tb_capture_storage_integration_top/wr_data
    /tb_capture_storage_integration_top/write_count
    /tb_capture_storage_integration_top/capture_busy
    /tb_capture_storage_integration_top/frame_ready
    /tb_capture_storage_integration_top/frame_ready_toggle
    /tb_capture_storage_integration_top/capture_overflow
    /tb_capture_storage_integration_top/store_overflow
    /tb_capture_storage_integration_top/rd_addr
    /tb_capture_storage_integration_top/rd_data
    /tb_capture_storage_integration_top/uut/u_capture/state
    /tb_capture_storage_integration_top/uut/u_store/state
} { puts $fh [list log_wave $signal] }

puts $fh {create_wave_config capture_storage_integration}
puts $fh {set g1 [add_wave_group {1. Control y sincronizacion}]}
puts $fh {add_wave -into $g1 /tb_capture_storage_integration_top/pclk /tb_capture_storage_integration_top/rst /tb_capture_storage_integration_top/enable /tb_capture_storage_integration_top/arm_capture /tb_capture_storage_integration_top/cam_vsync /tb_capture_storage_integration_top/cam_href}
puts $fh {set g2 [add_wave_group {2. Extraccion de luminancia Y}]}
puts $fh {add_wave -into $g2 /tb_capture_storage_integration_top/cam_data /tb_capture_storage_integration_top/pixel_y /tb_capture_storage_integration_top/pixel_valid /tb_capture_storage_integration_top/pixel_x /tb_capture_storage_integration_top/pixel_y_pos /tb_capture_storage_integration_top/frame_active /tb_capture_storage_integration_top/frame_done /tb_capture_storage_integration_top/pixel_count /tb_capture_storage_integration_top/uut/u_capture/state}
puts $fh {set g3 [add_wave_group {3. Escritura espacial BRAM}]}
puts $fh {add_wave -into $g3 /tb_capture_storage_integration_top/wr_en /tb_capture_storage_integration_top/wr_addr /tb_capture_storage_integration_top/wr_data /tb_capture_storage_integration_top/write_count /tb_capture_storage_integration_top/capture_busy /tb_capture_storage_integration_top/frame_ready /tb_capture_storage_integration_top/frame_ready_toggle /tb_capture_storage_integration_top/uut/u_store/state}
puts $fh {set g4 [add_wave_group {4. Lectura y resultado}]}
puts $fh {add_wave -into $g4 /tb_capture_storage_integration_top/rd_addr /tb_capture_storage_integration_top/rd_data /tb_capture_storage_integration_top/capture_overflow /tb_capture_storage_integration_top/store_overflow}
puts $fh {save_wave_config $wave_cfg}
puts $fh {run all}
puts $fh {save_wave_config $wave_cfg}
puts $fh {quit}
close $fh

set sim_command [list cmd /c $xsim $snapshot -tclbatch $run_tcl -wdb $wdb_file]
puts "RUN: $sim_command"
set sim_failed [catch {exec {*}$sim_command 2>@1} sim_output]
puts $sim_output
if {$sim_failed || [string first "PASS_CAPTURE_STORAGE_INTEGRATION" $sim_output] < 0} {
    error "La simulacion integrada de captura no alcanzo su PASS final"
}
puts "PASS: simulacion integrada de captura y almacenamiento terminada"
puts "WDB:  $wdb_file"
puts "WCFG: $wave_cfg"
exit 0
