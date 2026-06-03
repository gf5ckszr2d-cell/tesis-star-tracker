set repo_root [file normalize [file join [file dirname [info script]] ".." ".."]]
set sim_dir [file join $repo_root "sim_build" "xsim_ov7670_init_config"]
set run_tcl [file join $sim_dir "run_ov7670_init_config.tcl"]
set wave_cfg [file join $repo_root "Scripts" "waves_ov7670_init_config.wcfg"]
set snapshot "tb_ov7670_init_config_snapshot"

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

set rtl_files [list \
    [file join $repo_root "Protocolo de comunicacion" "rtl" "i2c_master.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_init_config.vhd"] \
]
set tb_file [file join $repo_root "Configuracion camara" "tb" "tb_ov7670_init_config.vhd"]

foreach rtl_file $rtl_files {
    run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $rtl_file]
}
run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $tb_file]

run_cmd [list cmd /c $xelab --debug typical --relax --mt 2 -L xil_defaultlib --snapshot $snapshot xil_defaultlib.tb_ov7670_init_config]

set fh [open $run_tcl w]
puts $fh [list set wave_cfg $wave_cfg]

puts $fh {log_wave /tb_ov7670_init_config/clk}
puts $fh {log_wave /tb_ov7670_init_config/rst}
puts $fh {log_wave /tb_ov7670_init_config/start}
puts $fh {log_wave /tb_ov7670_init_config/init_busy}
puts $fh {log_wave /tb_ov7670_init_config/init_done}
puts $fh {log_wave /tb_ov7670_init_config/init_error}
puts $fh {log_wave /tb_ov7670_init_config/current_step}

puts $fh {log_wave /tb_ov7670_init_config/ctrl_i2c_start}
puts $fh {log_wave /tb_ov7670_init_config/ctrl_i2c_rw}
puts $fh {log_wave /tb_ov7670_init_config/ctrl_i2c_tx_byte0}
puts $fh {log_wave /tb_ov7670_init_config/ctrl_i2c_tx_byte1}
puts $fh {log_wave /tb_ov7670_init_config/ctrl_i2c_tx_count}
puts $fh {log_wave /tb_ov7670_init_config/i2c_busy}
puts $fh {log_wave /tb_ov7670_init_config/i2c_done}
puts $fh {log_wave /tb_ov7670_init_config/i2c_ack_error}

puts $fh {log_wave /tb_ov7670_init_config/SCL}
puts $fh {log_wave /tb_ov7670_init_config/SDA}
puts $fh {log_wave /tb_ov7670_init_config/sda_slave_drive}

puts $fh {log_wave /tb_ov7670_init_config/u_init_config/state}
puts $fh {log_wave /tb_ov7670_init_config/u_init_config/config_index}
puts $fh {log_wave /tb_ov7670_init_config/u_init_config/delay_count}
puts $fh {log_wave /tb_ov7670_init_config/u_init_config/i2c_start_reg}
puts $fh {log_wave /tb_ov7670_init_config/u_init_config/i2c_rw_reg}
puts $fh {log_wave /tb_ov7670_init_config/u_init_config/i2c_tx_byte0_reg}
puts $fh {log_wave /tb_ov7670_init_config/u_init_config/i2c_tx_byte1_reg}
puts $fh {log_wave /tb_ov7670_init_config/u_init_config/i2c_tx_count_reg}
puts $fh {log_wave /tb_ov7670_init_config/u_init_config/done_reg}
puts $fh {log_wave /tb_ov7670_init_config/u_init_config/error_reg}

puts $fh {log_wave /tb_ov7670_init_config/u_i2c_master/state}
puts $fh {log_wave /tb_ov7670_init_config/u_i2c_master/phase}
puts $fh {log_wave /tb_ov7670_init_config/u_i2c_master/bit_index}
puts $fh {log_wave /tb_ov7670_init_config/u_i2c_master/scl_reg}
puts $fh {log_wave /tb_ov7670_init_config/u_i2c_master/sda_drive_low}
puts $fh {log_wave /tb_ov7670_init_config/u_i2c_master/busy_reg}
puts $fh {log_wave /tb_ov7670_init_config/u_i2c_master/done_reg}
puts $fh {log_wave /tb_ov7670_init_config/u_i2c_master/ack_error_reg}

puts $fh {create_wave_config waves_ov7670_init_config}
puts $fh {set control_group [add_wave_group {Control init}]}
puts $fh {add_wave -into $control_group /tb_ov7670_init_config/clk /tb_ov7670_init_config/rst /tb_ov7670_init_config/start /tb_ov7670_init_config/init_busy /tb_ov7670_init_config/init_done /tb_ov7670_init_config/init_error /tb_ov7670_init_config/current_step}
puts $fh {set handshake_group [add_wave_group {Handshake I2C}]}
puts $fh {add_wave -into $handshake_group /tb_ov7670_init_config/ctrl_i2c_start /tb_ov7670_init_config/ctrl_i2c_rw /tb_ov7670_init_config/ctrl_i2c_tx_byte0 /tb_ov7670_init_config/ctrl_i2c_tx_byte1 /tb_ov7670_init_config/ctrl_i2c_tx_count /tb_ov7670_init_config/i2c_busy /tb_ov7670_init_config/i2c_done /tb_ov7670_init_config/i2c_ack_error}
puts $fh {set bus_group [add_wave_group {Bus I2C}]}
puts $fh {add_wave -into $bus_group /tb_ov7670_init_config/SCL /tb_ov7670_init_config/SDA /tb_ov7670_init_config/sda_slave_drive}
puts $fh {set init_fsm_group [add_wave_group {FSM init_config}]}
puts $fh {add_wave -into $init_fsm_group /tb_ov7670_init_config/u_init_config/state /tb_ov7670_init_config/u_init_config/config_index /tb_ov7670_init_config/u_init_config/delay_count /tb_ov7670_init_config/u_init_config/i2c_start_reg /tb_ov7670_init_config/u_init_config/i2c_rw_reg /tb_ov7670_init_config/u_init_config/i2c_tx_byte0_reg /tb_ov7670_init_config/u_init_config/i2c_tx_byte1_reg /tb_ov7670_init_config/u_init_config/i2c_tx_count_reg /tb_ov7670_init_config/u_init_config/done_reg /tb_ov7670_init_config/u_init_config/error_reg}
puts $fh {set i2c_fsm_group [add_wave_group {FSM i2c_master}]}
puts $fh {add_wave -into $i2c_fsm_group /tb_ov7670_init_config/u_i2c_master/state /tb_ov7670_init_config/u_i2c_master/phase /tb_ov7670_init_config/u_i2c_master/bit_index /tb_ov7670_init_config/u_i2c_master/scl_reg /tb_ov7670_init_config/u_i2c_master/sda_drive_low /tb_ov7670_init_config/u_i2c_master/busy_reg /tb_ov7670_init_config/u_i2c_master/done_reg /tb_ov7670_init_config/u_i2c_master/ack_error_reg}

puts $fh {save_wave_config $wave_cfg}
puts $fh {run 25 ms}
puts $fh {save_wave_config $wave_cfg}
puts $fh {quit}
close $fh

run_cmd [list cmd /c $xsim $snapshot -tclbatch $run_tcl -wdb [file join $sim_dir "xsim_ov7670_init_config.wdb"]]

exit 0
