# Ejecutar desde Tcl Console con TU proyecto abierto. No crea hardware ni BD.
set capture_constraints_dir [file normalize [file join [file dirname [info script]] .. constraints]]
if {![llength [get_projects -quiet]]} {error "Abrir primero el proyecto de captura o su integracion Zynq."}
if {[get_property PART [current_project]] ne "xc7z010clg400-1"} {
    error "Estos pines se prepararon para Arty Z7-10 / xc7z010clg400-1."
}
# Retirar del proyecto la referencia antigua, incluso si el archivo ya no existe.
foreach capture_old_xdc [get_files -quiet *pclk_ordenado_ruta.xdc] {
    remove_files $capture_old_xdc
}
foreach capture_xdc_name {camara_botones_arty_z7.xdc} {
    set capture_xdc_path [file join $capture_constraints_dir $capture_xdc_name]
    if {![file isfile $capture_xdc_path]} {error "No existe: $capture_xdc_path"}
    set capture_xdc [get_files -quiet $capture_xdc_path]
    if {![llength $capture_xdc]} {
        add_files -fileset constrs_1 -norecurse $capture_xdc_path
        set capture_xdc [get_files $capture_xdc_path]
    }
    # Los XDC no son fuentes de simulacion. Sus flags son sintesis/implementacion.
    set_property USED_IN_IMPLEMENTATION true $capture_xdc
    set_property USED_IN_SYNTHESIS true $capture_xdc
    set_property PROCESSING_ORDER NORMAL $capture_xdc
}
# Si el top sigue siendo el VHDL de captura, conservar los otros generics y
# asegurar 100 MHz. Vivado puede haber guardado antes el antiguo valor de 125.
# Cuando el top sea el BD, FCLK y el generic de su instancia se configuran alli.
if {[get_property TOP [get_filesets sources_1]] eq "captura_uart_top"} {
    set capture_generics [get_property GENERIC [get_filesets sources_1]]
    if {![regsub {CLK_FREQ_HZ=[^ ]+} $capture_generics {CLK_FREQ_HZ=100000000} capture_generics]} {
        append capture_generics { CLK_FREQ_HZ=100000000}
    }
    set_property GENERIC [string trim $capture_generics] [get_filesets sources_1]
}
puts "CONSTRAINT_AGREGADO: unico XDC, PCLK en JA7 y D5 en JA3; BTN0/BTN1."
puts "Integracion PS pendiente: FCLK_CLK0=100 MHz, TX interno y nombres externos coincidentes."
