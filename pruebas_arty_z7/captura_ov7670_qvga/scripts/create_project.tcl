# Integrated Arty project owned entirely by this variant.
source [file join [file dirname [info script]] fuentes.tcl]
set root $captura_root
set pname [file tail $root]
set pdir [file join $root build proyecto]
if {[info exists ::env(CAPTURA_PROJECT_DIR)]} {set pdir [file normalize $::env(CAPTURA_PROJECT_DIR)]}
set pfile [file join $pdir ${pname}.xpr]
set_param board.repoPaths [list [file join $::env(APPDATA) Xilinx Vivado 2025.2 xhub board_store xilinx_board_store XilinxBoardStore Vivado 2025.2 boards]]
if {[llength [get_projects -quiet]]} {error "Close current project first"}
if {[file isfile $pfile]} {
    open_project $pfile
} else {
    create_project $pname $pdir -part xc7z010clg400-1
    set_property board_part digilentinc.com:arty-z7-10:part0:1.1 [current_project]
    set_property target_language VHDL [current_project]
    set_property target_simulator XSim [current_project]
    add_files -norecurse $captura_rtl
    add_files -norecurse [file join $root rtl ov7670_sda_iobuf.vhd]
    set_property file_type VHDL [get_files $captura_rtl]
    update_compile_order -fileset sources_1
    source [file join $root scripts sistema_captura_arm_diagnostico.tcl]
    if {[llength [get_bd_cells -quiet]] == 0} {error "El block design no se ha creado"}
    set bd [get_files -filter {NAME =~ */sistema_captura_arm.bd}]
    validate_bd_design
    generate_target all $bd
    add_files -norecurse [make_wrapper -files $bd -top]
    add_files -fileset constrs_1 -norecurse [file join $root constraints camara_arm_EMIO.xdc]
    add_files -fileset sim_1 -norecurse [file join $root tb tb_captura_uart.vhd]
    set_property file_type {VHDL 2008} [get_files [file join $root tb tb_captura_uart.vhd]]
    set_property top sistema_captura_arm_wrapper [get_filesets sources_1]
    set_property top tb_captura_uart [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
}
set f [open [file join $root build fuentes_proyecto.txt] w]
foreach fs {sources_1 constrs_1 sim_1} {
    foreach source [get_files -of_objects [get_filesets $fs]] {
        set own [file normalize $source]
        if {[string first ${root}/ $own] != 0} {error "Source outside variant: $own"}
        puts $f "$fs\t$own"
    }
}
close $f
puts "PASS_PROYECTO_INDEPENDIENTE: $pfile"
