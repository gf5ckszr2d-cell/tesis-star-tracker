# Volatile FPGA + ARM load; artifacts belong to THIS variant.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build diagnostico resultados]
set bit [file join $out sistema_captura_arm_wrapper.bit]
set elf [file join $out receptor_ov7670_test.elf]
set psinit [file join $out ps7_init.tcl]
foreach f [list $bit $elf $psinit] {if {![file isfile $f]} {error "Missing artifact: $f"}}
connect -url tcp:127.0.0.1:3121
targets -set -filter {name =~ "APU"}
rst -system
after 1000
targets -set -filter {name =~ "ARM*#0"}
source $psinit
ps7_init
fpga -file $bit
ps7_post_config
after 200
dow $elf
con
puts "ARM_RUNNING: [file tail $root]; COM3 115200"
