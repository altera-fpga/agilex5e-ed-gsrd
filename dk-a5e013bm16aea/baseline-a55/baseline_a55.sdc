# Set the default time format
set_time_format -unit ns -decimal_places 3

# Create shorthand names for clocks
set MAIN_CLOCK [get_clocks {u_baseline_top|u_shell_subsys|u_clks_and_rsts|clks_and_rsts|u_sys_pll|iopll_0_outclk0}]

# Create a virtual clock for the MAIN_CLOCK for use with IO timing
create_clock -name MAIN_CLOCK_virt -period [get_clock_info -period $MAIN_CLOCK]

# Set a loose/small output delay for LED PIOs to complete the I/O constraint requirement.
set_output_delay -source_latency_included -clock [get_clocks MAIN_CLOCK_virt] [expr {0.1 * [get_clock_info -period MAIN_CLOCK_virt]}] [get_ports {fpga_user_leds[*]}]
set_multicycle_path -from $MAIN_CLOCK -to [get_clocks MAIN_CLOCK_virt] -setup -end 3
set_multicycle_path -from $MAIN_CLOCK -to [get_clocks MAIN_CLOCK_virt] -hold -end 2

# Set a loose/small input delay for button PIOs to complete the I/O constraint requirement.
set_input_delay -source_latency_included -clock [get_clocks MAIN_CLOCK_virt] [expr {0.1 * [get_clock_info -period MAIN_CLOCK_virt]}] [get_ports {fpga_user_push_buttons[*]}]

# Set asynchronous clock groups between hps_internal_osc and system main clock.
set_clock_groups -asynchronous -group [get_clocks {hps_internal_osc}] -group $MAIN_CLOCK

# Set multicycle path for warm_reset_handshake signal
set_multicycle_path 2 -setup -from [get_registers {*|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst~intosc_clk.reg}] -to [get_registers {*|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst~intosc_clk.reg}]
set_multicycle_path 1 -hold -from [get_registers {*|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst~intosc_clk.reg}] -to [get_registers {*|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst~intosc_clk.reg}]

# Use -no_synchronizer for the following intra-clock false paths
set_false_path -no_synchronizer -from [get_registers {*|u_clks_and_rsts|clks_and_rsts|fpga_reset_n_sync|dreg[1]}] -to [get_registers {*|altera_reset_synchronizer_int_chain[1]}]
set_false_path -no_synchronizer -from [get_registers {*|u_fabric_subsys|rst_controller|r_sync_rst}] -to [get_registers {*|altera_reset_synchronizer_int_chain[1]}]
