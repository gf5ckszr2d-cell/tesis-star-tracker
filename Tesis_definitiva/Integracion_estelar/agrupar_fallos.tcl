proc agrupar_fallos {archivo} {
    set salida [open $archivo w]
    puts $salida "margen_ns\tdestinos\torigen_peor\tdestino_peor"
    set origenes {}
    set destinos {}
    set margenes {}
    set conteos {}
    foreach ruta [get_timing_paths -quiet -delay_type max -max_paths 10000 -nworst 1 -slack_lesser_than 0] {
        set destino [get_property ENDPOINT_PIN $ruta]
        set grupo [regsub -all {\[[^\]]*\]} $destino {[]}]
        dict incr conteos $grupo
        if {![dict exists $margenes $grupo]} {
            dict set origenes $grupo [get_property STARTPOINT_PIN $ruta]
            dict set destinos $grupo $destino
            dict set margenes $grupo [get_property SLACK $ruta]
        }
    }
    dict for {grupo margen} $margenes {
        puts $salida "$margen\t[dict get $conteos $grupo]\t[dict get $origenes $grupo]\t[dict get $destinos $grupo]"
    }
    close $salida
}
