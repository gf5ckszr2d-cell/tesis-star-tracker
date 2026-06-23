# Simulacion integrada: init + runtime config + i2c_master.
set section_dir [file normalize [file join [file dirname [info script]] ".."]]
set repo_root [file normalize [file join $section_dir ".." ".."]]
set sim_dir [file join $repo_root "sim_build" "camera_config_integration"]
set run_tcl [file join $sim_dir "run_camera_config_integration.tcl"]
set wdb_file [file join $sim_dir "camera_config_integration.wdb"]
set wave_cfg [file join $section_dir "scripts" "waves_camera_config_integration.wcfg"]
set snapshot "tb_camera_config_integration_snapshot"

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
lappend sources [file join $repo_root "Protocolo de comunicacion" "rtl" "i2c_master.vhd"]
lappend sources [file join $repo_root "Configuracion camara" "rtl" "ov7670_init_config.vhd"]
lappend sources [file join $repo_root "Configuracion camara" "rtl" "ov7670_runtime_config.vhd"]
lappend sources [file join $section_dir "rtl" "camera_config_integration_top.vhd"]
lappend sources [file join $section_dir "tb" "tb_camera_config_integration_top.vhd"]

foreach source $sources {
    run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $source]
}
run_cmd [list cmd /c $xelab --debug typical --relax --mt 2 -L xil_defaultlib --snapshot $snapshot xil_defaultlib.tb_camera_config_integration_top]

set fh [open $run_tcl w]
puts $fh [list set wave_cfg $wave_cfg]
foreach signal {
    /tb_camera_config_integration_top/clk
    /tb_camera_config_integration_top/rst
    /tb_camera_config_integration_top/init_start
    /tb_camera_config_integration_top/runtime_enable
    /tb_camera_config_integration_top/config_btn
    /tb_camera_config_integration_top/param_sel
    /tb_camera_config_integration_top/param_value
    /tb_camera_config_integration_top/SCL
    /tb_camera_config_integration_top/SDA
    /tb_camera_config_integration_top/init_busy
    /tb_camera_config_integration_top/init_done
    /tb_camera_config_integration_top/init_error
    /tb_camera_config_integration_top/init_current_step
    /tb_camera_config_integration_top/runtime_busy
    /tb_camera_config_integration_top/runtime_done
    /tb_camera_config_integration_top/runtime_error
    /tb_camera_config_integration_top/runtime_active_param
    /tb_camera_config_integration_top/i2c_busy
    /tb_camera_config_integration_top/i2c_done
    /tb_camera_config_integration_top/i2c_ack_error
    /tb_camera_config_integration_top/i2c_runtime_owner
    /tb_camera_config_integration_top/transaction_count
    /tb_camera_config_integration_top/uut/selected_start
    /tb_camera_config_integration_top/uut/selected_byte0
    /tb_camera_config_integration_top/uut/selected_byte1
    /tb_camera_config_integration_top/uut/u_i2c/state
    /tb_camera_config_integration_top/uut/u_init/state
    /tb_camera_config_integration_top/uut/u_runtime/state
} { puts $fh [list log_wave $signal] }

puts $fh {create_wave_config camera_config_integration}
puts $fh {set g1 [add_wave_group {1. Control de prueba}]}
puts $fh {add_wave -into $g1 /tb_camera_config_integration_top/clk /tb_camera_config_integration_top/rst /tb_camera_config_integration_top/init_start /tb_camera_config_integration_top/transaction_count}
puts $fh {set g2 [add_wave_group {2. Inicializacion ROM}]}
puts $fh {add_wave -into $g2 /tb_camera_config_integration_top/init_busy /tb_camera_config_integration_top/init_done /tb_camera_config_integration_top/init_error /tb_camera_config_integration_top/init_current_step /tb_camera_config_integration_top/uut/u_init/state}
puts $fh {set g3 [add_wave_group {3. Configuracion runtime}]}
puts $fh {add_wave -into $g3 /tb_camera_config_integration_top/runtime_enable /tb_camera_config_integration_top/config_btn /tb_camera_config_integration_top/param_sel /tb_camera_config_integration_top/param_value /tb_camera_config_integration_top/runtime_busy /tb_camera_config_integration_top/runtime_done /tb_camera_config_integration_top/runtime_error /tb_camera_config_integration_top/runtime_active_param /tb_camera_config_integration_top/uut/u_runtime/state}
puts $fh {set g4 [add_wave_group {4. Arbitraje I2C}]}
puts $fh {add_wave -into $g4 /tb_camera_config_integration_top/i2c_runtime_owner /tb_camera_config_integration_top/uut/selected_start /tb_camera_config_integration_top/uut/selected_byte0 /tb_camera_config_integration_top/uut/selected_byte1 /tb_camera_config_integration_top/i2c_busy /tb_camera_config_integration_top/i2c_done /tb_camera_config_integration_top/i2c_ack_error}
puts $fh {set g5 [add_wave_group {5. Bus SCCB I2C}]}
puts $fh {add_wave -into $g5 /tb_camera_config_integration_top/SCL /tb_camera_config_integration_top/SDA /tb_camera_config_integration_top/uut/u_i2c/state}
puts $fh {save_wave_config $wave_cfg}
puts $fh {run all}
puts $fh {save_wave_config $wave_cfg}
puts $fh {quit}
close $fh

set sim_command [list cmd /c $xsim $snapshot -tclbatch $run_tcl -wdb $wdb_file]
puts "RUN: $sim_command"
set sim_failed [catch {exec {*}$sim_command 2>@1} sim_output]
puts $sim_output
if {$sim_failed || [string first "PASS_CAMERA_CONFIG_INTEGRATION" $sim_output] < 0} {
    error "La simulacion integrada de configuracion no alcanzo su PASS final"
}
puts "PASS: simulacion integrada de configuracion terminada"
puts "WDB:  $wdb_file"
puts "WCFG: $wave_cfg"
exit 0
