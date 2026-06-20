set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize "$script_dir/.."]
set build_dir  [file normalize "$root_dir/build"]

set project_name "spi_master"
set project_dir "$build_dir/$project_name"
set part "xc7a100tcsg324-1"
set top_module "spi_master_top"

set rtl_dir "$root_dir/rtl"
set constr_dir "$root_dir/constraints"

file delete -force $project_dir

create_project $project_name $project_dir -part $part

add_files -fileset sources_1 [glob -nocomplain "$rtl_dir/*.sv"]
add_files -fileset constrs_1 [glob -nocomplain "$constr_dir/*.xdc"]

set_property top $top_module [current_fileset]
update_compile_order -fileset sources_1

puts "SUCCESS: Project created at $project_dir/$project_name.xpr"