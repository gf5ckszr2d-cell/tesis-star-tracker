set repo_root [file normalize [file join [file dirname [info script]] ".." ".."]]
set sim_dir [file join $repo_root "sim_build" "xsim_ov7670_runtime_config"]
set run_tcl [file join $sim_dir "run_ov7670_runtime_config.tcl"]
set wave_cfg [file join $repo_root "Scripts" "waves_ov7670_runtime_config.wcfg"]
set snapshot "tb_ov7670_runtime_config_snapshot"

file mkdir $sim_dir
cd $sim_dir

if {[info exists ::env(XILINX_VIVADO)]} {
    set vivado_bin [file join $::env(XILINX_VIVADO) "bin"]
} else {
    set vivado_bin [file dirname [file dirname [file dirname [info nameofexecutable]]]]
}
set xvhdl [file join $vivado_bin "xvhdl.bat"]
set xelab [file join $vivado_bin "xelab.bat"]
set xsim  [file join $vivado_bin "xsim.bat"]

proc run_cmd {cmd_list} {
    puts "RUN: $cmd_list"
    set result [catch {exec {*}$cmd_list 2>@1} output]
    puts $output
    if {$result != 0} {
        error "Command failed: $cmd_list"
    }
}

set rtl_file [file join $repo_root "Configuracion camara" "rtl" "ov7670_runtime_config.vhd"]
set tb_file  [file join $repo_root "Configuracion camara" "tb"  "tb_ov7670_runtime_config.vhd"]

run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $rtl_file]
run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $tb_file]

run_cmd [list cmd /c $xelab --debug typical --relax --mt 2 -L xil_defaultlib --snapshot $snapshot xil_defaultlib.tb_ov7670_runtime_config]

set fh [open $run_tcl w]
puts $fh [list set wave_cfg $wave_cfg]

puts $fh {log_wave /tb_ov7670_runtime_config/clk}
puts $fh {log_wave /tb_ov7670_runtime_config/rst}
puts $fh {log_wave /tb_ov7670_runtime_config/enable}
puts $fh {log_wave /tb_ov7670_runtime_config/config_btn}
puts $fh {log_wave /tb_ov7670_runtime_config/param_sel}
puts $fh {log_wave /tb_ov7670_runtime_config/param_value}
puts $fh {log_wave /tb_ov7670_runtime_config/i2c_start}
puts $fh {log_wave /tb_ov7670_runtime_config/i2c_rw}
puts $fh {log_wave /tb_ov7670_runtime_config/i2c_tx_byte0}
puts $fh {log_wave /tb_ov7670_runtime_config/i2c_tx_byte1}
puts $fh {log_wave /tb_ov7670_runtime_config/i2c_tx_count}
puts $fh {log_wave /tb_ov7670_runtime_config/i2c_busy}
puts $fh {log_wave /tb_ov7670_runtime_config/i2c_done}
puts $fh {log_wave /tb_ov7670_runtime_config/i2c_ack_error}
puts $fh {log_wave /tb_ov7670_runtime_config/busy}
puts $fh {log_wave /tb_ov7670_runtime_config/done}
puts $fh {log_wave /tb_ov7670_runtime_config/error}
puts $fh {log_wave /tb_ov7670_runtime_config/active_param}
puts $fh {log_wave /tb_ov7670_runtime_config/write_count}

puts $fh {log_wave /tb_ov7670_runtime_config/uut/state}
puts $fh {log_wave /tb_ov7670_runtime_config/uut/btn_meta}
puts $fh {log_wave /tb_ov7670_runtime_config/uut/btn_sync}
puts $fh {log_wave /tb_ov7670_runtime_config/uut/btn_prev}
puts $fh {log_wave /tb_ov7670_runtime_config/uut/latched_sel}
puts $fh {log_wave /tb_ov7670_runtime_config/uut/latched_value}
puts $fh {log_wave /tb_ov7670_runtime_config/uut/write_index}
puts $fh {log_wave /tb_ov7670_runtime_config/uut/write_count}

puts $fh {create_wave_config waves_ov7670_runtime_config}
puts $fh {set ctrl_group [add_wave_group {Control manual}]}
puts $fh {add_wave -into $ctrl_group /tb_ov7670_runtime_config/clk /tb_ov7670_runtime_config/rst /tb_ov7670_runtime_config/enable /tb_ov7670_runtime_config/config_btn /tb_ov7670_runtime_config/param_sel /tb_ov7670_runtime_config/param_value}
puts $fh {set i2c_group [add_wave_group {Solicitud I2C}]}
puts $fh {add_wave -into $i2c_group /tb_ov7670_runtime_config/i2c_start /tb_ov7670_runtime_config/i2c_rw /tb_ov7670_runtime_config/i2c_tx_byte0 /tb_ov7670_runtime_config/i2c_tx_byte1 /tb_ov7670_runtime_config/i2c_tx_count /tb_ov7670_runtime_config/i2c_busy /tb_ov7670_runtime_config/i2c_done /tb_ov7670_runtime_config/i2c_ack_error}
puts $fh {set status_group [add_wave_group {Estado}]}
puts $fh {add_wave -into $status_group /tb_ov7670_runtime_config/busy /tb_ov7670_runtime_config/done /tb_ov7670_runtime_config/error /tb_ov7670_runtime_config/active_param /tb_ov7670_runtime_config/write_count}
puts $fh {set fsm_group [add_wave_group {FSM interna}]}
puts $fh {add_wave -into $fsm_group /tb_ov7670_runtime_config/uut/state /tb_ov7670_runtime_config/uut/btn_meta /tb_ov7670_runtime_config/uut/btn_sync /tb_ov7670_runtime_config/uut/btn_prev /tb_ov7670_runtime_config/uut/latched_sel /tb_ov7670_runtime_config/uut/latched_value /tb_ov7670_runtime_config/uut/write_index /tb_ov7670_runtime_config/uut/write_count}

puts $fh {save_wave_config $wave_cfg}
puts $fh {run 2 ms}
puts $fh {save_wave_config $wave_cfg}
puts $fh {quit}
close $fh

run_cmd [list cmd /c $xsim $snapshot -tclbatch $run_tcl -wdb [file join $sim_dir "xsim_ov7670_runtime_config.wdb"]]

exit 0
