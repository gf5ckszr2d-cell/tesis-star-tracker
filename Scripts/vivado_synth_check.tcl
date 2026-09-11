set repo_root [file normalize [file join [file dirname [info script]] ".."]]
set report_dir [file join $repo_root "sim_build" "vivado_synth_check"]

file mkdir $report_dir

set_part xc7a100tcsg324-1

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
    [file join $repo_root "Configuracion camara" "rtl" "unsigned_iterative_divider.vhd"] \
    [file join $repo_root "Configuracion camara" "rtl" "frame_star_centroid.vhd"] \
    [file join $repo_root "Top" "rtl" "star_tracker_top.vhd"] \
]

read_vhdl -vhdl2008 $rtl_files
read_xdc [list [file join $repo_root "Top" "constraints" "star_tracker_top_nexys.xdc"]]

synth_design -top star_tracker_top -part xc7a100tcsg324-1

report_utilization -file [file join $report_dir "utilization_synth.rpt"]
report_timing_summary -max_paths 10 -file [file join $report_dir "timing_synth.rpt"]
set worst_setup_path [get_timing_paths -delay_type max -max_paths 1]
set worst_hold_path [get_timing_paths -delay_type min -max_paths 1]
set cdc_report [report_cdc -details -return_string]
set methodology_report [report_methodology -return_string]

set fh [open [file join $report_dir "cdc_synth.rpt"] w]
puts $fh $cdc_report
close $fh

set fh [open [file join $report_dir "methodology_synth.rpt"] w]
puts $fh $methodology_report
close $fh

set async_regs [get_cells -hier -quiet -filter {ASYNC_REG == TRUE}]
if {[llength $async_regs] < 12} {
    error "Expected at least 12 ASYNC_REG synchronizer registers, found [llength $async_regs]"
}

if {[regexp {TIMING-10} $methodology_report]} {
    error "TIMING-10 remains in methodology report; inspect $report_dir/methodology_synth.rpt"
}

if {[regexp {input delay is missing on cam_(data|href|vsync)} $methodology_report]} {
    error "A camera input is missing its delay constraint; inspect $report_dir/methodology_synth.rpt"
}

if {[regexp -line {CDC-[0-9]+[ \t]+(Warning|Critical)} $cdc_report]} {
    error "Unsafe CDC result detected; inspect $report_dir/cdc_synth.rpt"
}

if {[llength $worst_setup_path] == 0 || [llength $worst_hold_path] == 0} {
    error "Timing paths were not found; inspect $report_dir/timing_synth.rpt"
}

set worst_setup_slack [get_property SLACK [lindex $worst_setup_path 0]]
set worst_hold_slack [get_property SLACK [lindex $worst_hold_path 0]]
if {$worst_setup_slack < 0.0 || $worst_hold_slack < 0.0} {
    error "Timing failed: WNS=$worst_setup_slack ns, WHS=$worst_hold_slack ns"
}

puts "SYNTH_CHECK_PASS: [llength $async_regs] ASYNC_REG registers"
puts "SYNTH_TIMING_PASS: WNS=$worst_setup_slack ns, WHS=$worst_hold_slack ns"
puts "SYNTH_REPORTS: $report_dir"

exit 0
