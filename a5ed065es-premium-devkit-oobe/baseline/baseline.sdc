# Set the default time format
set_time_format -unit ns -decimal_places 3

# Create shorthand names for clocks
set MAIN_CLOCK [get_clocks {u_baseline_top|u_hps_subsys|u_clocks_and_resets|u_sys_pll|iopll_0_outclk0}]

# Create a virtual clock for the MAIN_CLOCK for use with IO timing
create_clock -name MAIN_CLOCK_virt -period [get_clock_info -period $MAIN_CLOCK]

# Set a loose/small output delay for LED PIOs to complete the I/O constraint requirement.
set_output_delay -source_latency_included -clock [get_clocks MAIN_CLOCK_virt] [expr {0.1 * [get_clock_info -period MAIN_CLOCK_virt]}] [get_ports {fpga_led[*]}]
set_multicycle_path -from $MAIN_CLOCK -to [get_clocks MAIN_CLOCK_virt] -setup -end 3
set_multicycle_path -from $MAIN_CLOCK -to [get_clocks MAIN_CLOCK_virt] -hold -end 2

# Set a loose/small input delay for DIPSW and button PIOs to complete the I/O constraint requirement.
set_input_delay -source_latency_included -clock [get_clocks MAIN_CLOCK_virt] [expr {0.1 * [get_clock_info -period MAIN_CLOCK_virt]}] [get_ports {fpga_buttons[*]}]
set_input_delay -source_latency_included -clock [get_clocks MAIN_CLOCK_virt] [expr {0.1 * [get_clock_info -period MAIN_CLOCK_virt]}] [get_ports {fpga_dipsw[*]}]

# Set asynchronous clock groups between hps_internal_osc and system main clock.
set_clock_groups -asynchronous -group [get_clocks {hps_internal_osc}] -group $MAIN_CLOCK

# Use -no_synchronizer for the following intra-clock false paths
set_false_path -no_synchronizer -from [get_registers {*|u_clocks_and_resets|fpga_reset_n_sync|dreg[1]}] -to [get_registers {*|altera_reset_synchronizer_int_chain[1]}]
set_false_path -no_synchronizer -from [get_registers {*|u_core_subsys|rst_controller|r_sync_rst}] -to [get_registers {*|altera_reset_synchronizer_int_chain[1]}]