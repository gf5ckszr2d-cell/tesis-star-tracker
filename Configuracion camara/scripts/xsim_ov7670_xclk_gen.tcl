set repo_root [file normalize [file join [file dirname [info script]] ".." ".."]]
set sim_dir [file join $repo_root "sim_build" "xsim_ov7670_xclk_gen"]
set run_tcl [file join $sim_dir "run_ov7670_xclk_gen.tcl"]
set wave_cfg [file join $repo_root "Scripts" "waves_ov7670_xclk_gen.wcfg"]
set snapshot "tb_ov7670_xclk_gen_snapshot"

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

set rtl_file [file join $repo_root "Configuracion camara" "rtl" "ov7670_xclk_gen.vhd"]
set tb_file [file join $repo_root "Configuracion camara" "tb" "tb_ov7670_xclk_gen.vhd"]

run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $rtl_file]
run_cmd [list cmd /c $xvhdl --2008 --relax -work xil_defaultlib $tb_file]

run_cmd [list cmd /c $xelab --debug typical --relax --mt 2 -L xil_defaultlib -L unisim -L secureip --snapshot $snapshot xil_defaultlib.tb_ov7670_xclk_gen]

set fh [open $run_tcl w]
puts $fh [list set wave_cfg $wave_cfg]

puts $fh {log_wave /tb_ov7670_xclk_gen/clk_100mhz}
puts $fh {log_wave /tb_ov7670_xclk_gen/rst}
puts $fh {log_wave /tb_ov7670_xclk_gen/xclk}
puts $fh {log_wave /tb_ov7670_xclk_gen/locked}
puts $fh {log_wave /tb_ov7670_xclk_gen/uut/clkfb}
puts $fh {log_wave /tb_ov7670_xclk_gen/uut/clkfb_buf}
puts $fh {log_wave /tb_ov7670_xclk_gen/uut/xclk_mmcm}

puts $fh {create_wave_config waves_ov7670_xclk_gen}
puts $fh {set control_group [add_wave_group {Control y estado}]}
puts $fh {add_wave -into $control_group /tb_ov7670_xclk_gen/clk_100mhz /tb_ov7670_xclk_gen/rst /tb_ov7670_xclk_gen/locked}
puts $fh {set output_group [add_wave_group {Salida de camara}]}
puts $fh {add_wave -into $output_group /tb_ov7670_xclk_gen/xclk}
puts $fh {set internal_group [add_wave_group {Relojes internos MMCM}]}
puts $fh {add_wave -into $internal_group /tb_ov7670_xclk_gen/uut/clkfb /tb_ov7670_xclk_gen/uut/clkfb_buf /tb_ov7670_xclk_gen/uut/xclk_mmcm}

puts $fh {save_wave_config $wave_cfg}
puts $fh {run 50 us}
puts $fh {save_wave_config $wave_cfg}
puts $fh {quit}
close $fh

run_cmd [list cmd /c $xsim $snapshot -tclbatch $run_tcl -wdb [file join $sim_dir "xsim_ov7670_xclk_gen.wdb"]]

exit 0
