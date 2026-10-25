# Generic Cadence Genus synthesis script.
# Driven by environment variables set in run_genus.sh:
#   LIB       Liberty file (OSU FreePDK45 gscl45nm.lib)
#   TOP       top-level module
#   FILELIST  file with one RTL path per line
#   SDC       constraints file
#   OUT_DIR   where reports and the netlist are written

proc die {msg} {
    puts "GENUS_FAIL: $msg"
    exit 1
}
proc step {name script} {
    puts "==== STEP: $name"
    if {[catch {uplevel 1 $script} err]} { die "$name: $err" }
}

foreach v {LIB TOP FILELIST SDC OUT_DIR} {
    if {![info exists ::env($v)]} { die "environment variable $v not set" }
}
set LIB      $::env(LIB)
set TOP      $::env(TOP)
set FILELIST $::env(FILELIST)
set SDC      $::env(SDC)
set OUT      $::env(OUT_DIR)

set fh [open $FILELIST r]
set FILES [list]
foreach line [split [read $fh] "\n"] {
    set line [string trim $line]
    if {$line ne "" && ![string match "#*" $line]} { lappend FILES $line }
}
close $fh

# Treat latches and unresolved modules as errors (attributes may not exist in
# every release, so failures to set them are ignored)
catch {set_db hdl_error_on_latch true}
catch {set_db hdl_error_on_blackbox true}

step "read_libs" {
    if {[catch {read_libs $LIB}]} { set_db library $LIB }
}

# Optional physical-aware mode: read the cell LEF and use PLE (physical
# layout estimation) for wire delay instead of zero-wireload
set MODE [expr {[info exists ::env(MODE)] ? $::env(MODE) : "none"}]
if {$MODE eq "ple"} {
    if {![info exists ::env(LEF)]} { die "MODE=ple but LEF not set" }
    step "read_physical" { read_physical -lef $::env(LEF) }
    step "interconnect_mode" { set_db interconnect_mode ple }
}
puts "INTERCONNECT_MODE=[get_db interconnect_mode]"
step "read_hdl" { read_hdl -sv $FILES }
step "elaborate" { elaborate $TOP }

step "check_design_unresolved" {
    check_design -unresolved > $OUT/check_unresolved.rpt
}

step "read_sdc" { read_sdc $SDC }

step "syn_generic" { syn_generic }
step "syn_map"     { syn_map }
step "syn_opt"     { syn_opt }

# Essential reports (failure is fatal)
step "report_area"   { report_area > $OUT/area.rpt }
step "report_timing" {
    if {[catch {report_timing -max_paths 10 > $OUT/timing.rpt}]} {
        report_timing > $OUT/timing.rpt
    }
}
# Optional reports (option names differ between releases). Errors printed by
# Genus between OPTIONAL_BEGIN/OPTIONAL_END are expected attempts, and
# run_genus*.sh does not count them as synthesis errors.
puts "OPTIONAL_BEGIN"
foreach {file cmd} {
    gates.rpt        {report_gates}
    qor.rpt          {report_qor}
    power.rpt        {report_power}
    check_design.rpt {check_design -all}
} {
    if {[catch {eval $cmd > $OUT/$file} err]} { puts "WARNING: $cmd: $err" }
}
# Hold paths (ideal clock): try the known syntaxes in turn
set hold_ok 0
foreach cmd {
    {report_timing -early -max_paths 5}
    {report_timing -hold -max_paths 5}
    {report_timing -check_type hold -max_paths 5}
    {report_timing -early}
    {report_timing -hold}
} {
    if {![catch {eval $cmd > $OUT/hold.rpt}] && [file size $OUT/hold.rpt] > 0} {
        puts "HOLD_REPORT_CMD=$cmd"
        set hold_ok 1
        break
    }
}
if {!$hold_ok} {
    set fh [open $OUT/hold.rpt w]
    puts $fh "Hold analysis not available from report_timing in this Genus mode (none of the tried options were accepted)."
    close $fh
    puts "HOLD_REPORT_CMD=none"
}
puts "OPTIONAL_END"
step "write_netlist" {
    write_hdl > $OUT/${TOP}_mapped.v
    write_sdc > $OUT/${TOP}_mapped.sdc
}
catch {write_sdf > $OUT/${TOP}_mapped.sdf}

puts "GENUS_SYNTH_DONE"
exit 0
