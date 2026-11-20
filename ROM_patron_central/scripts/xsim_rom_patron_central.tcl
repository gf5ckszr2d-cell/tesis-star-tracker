set base [file normalize [file join [file dirname [info script]] ".."]]
set root [file dirname $base]
set salida [file join $base build xsim]
file mkdir $salida
cd $salida
if {[info exists ::env(XILINX_VIVADO)]} {
    set bin [file join $::env(XILINX_VIVADO) bin]
} else {
    set bin [file dirname [file dirname [file dirname [info nameofexecutable]]]]
}
proc ejecutar {comando} {
    set codigo [catch {exec {*}$comando 2>@1} texto]
    puts $texto
    if {$codigo != 0} { error "Fallo: $comando" }
    return $texto
}
set calculador [file join $root Tesis_definitiva Tesis_definitiva Tesis_definitiva.srcs sources_1 imports fuentes calcular_centroides.vhd]
set fuentes [list [file join $base rtl patron_central_pkg.vhd] \
    [file join $base rtl rom_patron_central.vhd] \
    [file join $base rtl coordenadas_inferior_izquierda.vhd] \
    $calculador [file join $base tests tb_rom_patron_central.vhd]]
foreach fuente $fuentes {
    if {![file exists $fuente]} {error "No existe $fuente"}
    ejecutar [list cmd /c [file join $bin xvhdl.bat] --2008 --work work $fuente]
}
ejecutar [list cmd /c [file join $bin xelab.bat] --debug typical --mt 2 work.tb_rom_patron_central -s prueba_rom]
set f [open correr.tcl w]
puts $f {run all}
puts $f {quit}
close $f
set resultado [ejecutar [list cmd /c [file join $bin xsim.bat] prueba_rom -tclbatch correr.tcl]]
if {![string match *PASS_ROM_PATRON_CENTRAL* $resultado]} {error "No se encontro PASS"}
puts "PASS_XSIM_ROM_PATRON_CENTRAL"
exit 0
