set here [file normalize [file dirname [info script]]]
set evidencia [file normalize [lindex $argv 0]]
set fase [lindex $argv 1]
set rtl [file join [file dirname $here] Tesis_definitiva Tesis_definitiva.srcs sources_1 new]
set sim [file join $evidencia sim]
file mkdir $sim
cd $sim
set bin [file join $::env(XILINX_VIVADO) bin]
proc ejecutar {programa args} {
    global bin
    set command [list cmd /c [file join $bin ${programa}.bat] {*}$args]
    if {[catch {exec {*}$command 2>@1} result]} {puts $result; error $command}
    puts $result
    return $result
}
set fuentes {g5_star_catalog_pkg g5_pair_lookup_pkg g5_ray_lut_pkg star_identifier}
set banco tb_identificacion
set marca PASS_IDENTIFICACION_CENTRAL
if {$fase eq "actitud"} {
    lappend fuentes attitude_math_pkg unsigned_iterative_divider normalize4 attitude_triad enviar_actitud_uart
    set banco tb_actitud
    set marca PASS_ACTITUD_UART
}
foreach name $fuentes {
    ejecutar xvhdl --2008 [file join $rtl ${name}.vhd]
}
ejecutar xvhdl --2008 [file join $sim escenas_pkg.vhd] [file join $here ${banco}.vhd]
ejecutar xelab work.$banco -s prueba
set fh [open sim.tcl w]
puts $fh {run all}
puts $fh {quit}
close $fh
set res [ejecutar xsim prueba -tclbatch sim.tcl]
if {![string match *$marca* $res]} {error "Simulation failed: $marca"}
