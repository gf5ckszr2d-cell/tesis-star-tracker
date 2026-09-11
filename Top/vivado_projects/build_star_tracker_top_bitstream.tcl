set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".." ".."]]
set bit_dir [file normalize [file join $repo_root "Top" "bitstreams"]]
set bit_path [file join $bit_dir "star_tracker_top_nexys.bit"]
set build_dir [file normalize [file join $repo_root "sim_build" "vivado_bitstream"]]
set report_dir [file join $build_dir "reports"]
set part_name "xc7a100tcsg324-1"

file mkdir $bit_dir
file mkdir $report_dir
cd $build_dir

set rtl_files [list \
    [file join $repo_root "Protocolo de comunicacion" "rtl" "i2c_master.vhd"] \
    [file join $repo_root "Protocolo de comunicacion" "rtl" "uart_tx.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_xclk_gen.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_init_config.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_runtime_config.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "ov7670_capture_y_stream.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_capture_store.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "framebuffer_y_bram.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_uart_dump.vhd"] \
    [file join $repo_root "Top" "rtl" "star_tracker_top.vhd"] \
]

read_vhdl -vhdl2008 $rtl_files
read_xdc [file join $repo_root "Top" "constraints" "star_tracker_top_nexys.xdc"]
synth_design -top star_tracker_top -part $part_name

report_utilization -file [file join $report_dir "utilization_synth.rpt"]
set cdc_report [report_cdc -details -return_string]
set fh [open [file join $report_dir "cdc_synth.rpt"] w]
puts $fh $cdc_report
close $fh
report_methodology -file [file join $report_dir "methodology_synth.rpt"]

opt_design
place_design
phys_opt_design
route_design

set drc_report [report_drc -ruledecks {default} -return_string]
set methodology_report [report_methodology -return_string]
set timing_report [report_timing_summary -delay_type min_max -max_paths 20 -return_string]

set fh [open [file join $report_dir "drc_routed.rpt"] w]
puts $fh $drc_report
close $fh

set fh [open [file join $report_dir "methodology_routed.rpt"] w]
puts $fh $methodology_report
close $fh

set fh [open [file join $report_dir "timing_routed.rpt"] w]
puts $fh $timing_report
close $fh

report_utilization -file [file join $report_dir "utilization_routed.rpt"]

foreach forbidden_rule {CFGBVS-1 PLCK-12 PLIO-9 TIMING-10} {
    if {[regexp $forbidden_rule "$drc_report\n$methodology_report"]} {
        error "$forbidden_rule remains after implementation; inspect reports in $report_dir"
    }
}

if {[regexp {input delay is missing on cam_(data|href|vsync)} $methodology_report]} {
    error "A camera input is missing its delay constraint; inspect $report_dir/methodology_routed.rpt"
}

if {[regexp -line {CDC-[0-9]+[ \t]+(Warning|Critical)} $cdc_report]} {
    error "Unsafe CDC result detected; inspect $report_dir/cdc_synth.rpt"
}

if {[regexp {Timing constraints are not met} $timing_report]} {
    error "Timing constraints are not met; inspect $report_dir/timing_routed.rpt"
}

write_bitstream -force $bit_path
puts "BITSTREAM_READY: $bit_path"
puts "IMPLEMENTATION_REPORTS: $report_dir"

exit 0
