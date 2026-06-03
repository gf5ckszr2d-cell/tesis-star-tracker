set repo_root [file normalize [file join [file dirname [info script]] ".." ".."]]
set sim_dir [file join $repo_root "sim_build" "xsim_i2c_master"]
set run_tcl [file join $sim_dir "run_i2c_master.tcl"]
set wave_cfg [file join $repo_root "Scripts" "waves_i2c_master.wcfg"]
set snapshot "tb_i2c_master_snapshot"

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

set rtl_file [file join $repo_root "Protocolo de comunicacion" "rtl" "i2c_master.vhd"]
set tb_file  [file join $repo_root "Protocolo de comunicacion" "tb"  "tb_i2c_master.vhd"]

run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $rtl_file]
run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $tb_file]

run_cmd [list cmd /c $xelab --debug typical --relax --mt 2 -L xil_defaultlib --snapshot $snapshot xil_defaultlib.tb_i2c_master]

set fh [open $run_tcl w]
puts $fh [list set wave_cfg $wave_cfg]
puts $fh {log_wave /tb_i2c_master/clk}
puts $fh {log_wave /tb_i2c_master/rst}
puts $fh {log_wave /tb_i2c_master/start}
puts $fh {log_wave /tb_i2c_master/busy}
puts $fh {log_wave /tb_i2c_master/done}
puts $fh {log_wave /tb_i2c_master/ack_error}
puts $fh {log_wave /tb_i2c_master/SCL}
puts $fh {log_wave /tb_i2c_master/SDA}
puts $fh {log_wave /tb_i2c_master/slave_addr}
puts $fh {log_wave /tb_i2c_master/rw}
puts $fh {log_wave /tb_i2c_master/tx_byte0}
puts $fh {log_wave /tb_i2c_master/tx_byte1}
puts $fh {log_wave /tb_i2c_master/rx_data}
puts $fh {log_wave /tb_i2c_master/uut/state}
puts $fh {log_wave /tb_i2c_master/uut/phase}
puts $fh {log_wave /tb_i2c_master/uut/bit_index}
puts $fh {log_wave /tb_i2c_master/uut/tick_counter}
puts $fh {log_wave /tb_i2c_master/uut/scl_reg}
puts $fh {log_wave /tb_i2c_master/uut/sda_drive_low}
puts $fh {log_wave /tb_i2c_master/uut/busy_reg}
puts $fh {log_wave /tb_i2c_master/uut/done_reg}
puts $fh {log_wave /tb_i2c_master/uut/ack_error_reg}
puts $fh {create_wave_config waves_i2c_master}
puts $fh {set control_group [add_wave_group {Control}]}
puts $fh {add_wave -into $control_group /tb_i2c_master/clk /tb_i2c_master/rst /tb_i2c_master/start /tb_i2c_master/busy /tb_i2c_master/done /tb_i2c_master/ack_error}
puts $fh {set bus_group [add_wave_group {Bus I2C}]}
puts $fh {add_wave -into $bus_group /tb_i2c_master/SCL /tb_i2c_master/SDA}
puts $fh {set io_group [add_wave_group {Entrada/Salida}]}
puts $fh {add_wave -into $io_group /tb_i2c_master/slave_addr /tb_i2c_master/rw /tb_i2c_master/tx_byte0 /tb_i2c_master/tx_byte1 /tb_i2c_master/rx_data}
puts $fh {set fsm_group [add_wave_group {FSM interna}]}
puts $fh {add_wave -into $fsm_group /tb_i2c_master/uut/state /tb_i2c_master/uut/phase /tb_i2c_master/uut/bit_index /tb_i2c_master/uut/tick_counter /tb_i2c_master/uut/scl_reg /tb_i2c_master/uut/sda_drive_low /tb_i2c_master/uut/busy_reg /tb_i2c_master/uut/done_reg /tb_i2c_master/uut/ack_error_reg}
puts $fh {save_wave_config $wave_cfg}
puts $fh {run 2 ms}
puts $fh {save_wave_config $wave_cfg}
puts $fh {quit}
close $fh

run_cmd [list cmd /c $xsim $snapshot -tclbatch $run_tcl -wdb [file join $sim_dir "xsim_i2c_master.wdb"]]

exit 0
