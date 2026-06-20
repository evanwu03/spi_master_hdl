
# scripts/build.tcl
set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize "$script_dir/.."]
set build_dir  [file normalize "$root_dir/build"]

set top_module "spi_master_top"
set part "xc7a100tcsg324-1"

set rtl_dir    "$root_dir/rtl"
set constr_dir "$root_dir/constraints"

file mkdir $build_dir

# Clean previous outputs
file delete -force "$build_dir/reports"
file mkdir "$build_dir/reports"

# Read RTL
set sv_files [glob -nocomplain "$rtl_dir/*.sv"]

if {[llength $sv_files] == 0} {
    error "No .sv files found in $rtl_dir"
}


# Non-project build
read_verilog -sv $sv_files

# Read constraints
set xdc_files [glob -nocomplain "$constr_dir/*.xdc"]

if {[llength $xdc_files] == 0} {
    puts "WARNING: No .xdc files found in $constr_dir"
} else {
    read_xdc $xdc_files
}

# Synthesis
synth_design -top $top_module -part $part

# Implementation
opt_design
place_design
route_design

# Reports
report_timing_summary -file "$build_dir/reports/timing_summary.rpt"
report_utilization -file "$build_dir/reports/utilization_flat.rpt"
report_utilization -hierarchical -file "$build_dir/reports/utilization_hier.rpt"

report_clock_utilization -file "$build_dir/reports/clock_utilization.rpt"
report_io -file "$build_dir/reports/io.rpt"

# Outputs
write_checkpoint -force "$build_dir/${top_module}_routed.dcp"
write_bitstream -force "$build_dir/${top_module}.bit"

puts "SUCCESS: Bitstream and reports generated in $build_dir"