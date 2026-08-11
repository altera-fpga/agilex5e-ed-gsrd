# load design
design_load output_files/datamover.sof

source pmon/pmon_library.tcl
namespace import ::pmon_lib::*


# load pmon library and discover PMON blocks in the design
puts "PMON Library loaded"
pmon_discover_all
pmon_define_configs
puts "Call pmon_help for more information"

# reset PMON counters
pmon_reset_counter_control_all
pmon_reset_counter_data_all

# set PMON config to basic_eff and read counter values in a loop
pmon_set_all basic_eff

while {1} {
    puts [pmon_read 0 0]
    puts [pmon_read 1 0]
    puts [pmon_read 2 0]
    puts [pmon_read 3 0]
}