# Set the default time format
set_time_format -unit ns -decimal_places 3

# Create shorthand names for clocks
set MAIN_CLOCK [get_clocks {u_desktop_linux_dp_top|u_shell_subsys|u_clocks_and_resets|u_sys_pll|iopll_0_outclk0}]
set MGMT_CLOCK [get_clocks {u_desktop_linux_dp_top|u_shell_subsys|u_clocks_and_resets|u_sys_pll|iopll_0_outclk1}]
set AUX_CLOCK [get_clocks {u_desktop_linux_dp_top|u_shell_subsys|u_clocks_and_resets|u_sys_pll|iopll_0_outclk2}]

# Create a virtual clock for the MAIN_CLOCK for use with IO timing
create_clock -name MAIN_CLOCK_virt -period [get_clock_info -period $MAIN_CLOCK]
create_clock -period "150 MHz" -name {clk150} [get_ports {dp_gts_refclk_150_clk}]

# Set a loose/small output delay for LED PIOs to complete the I/O constraint requirement.
set_output_delay -source_latency_included -clock [get_clocks MAIN_CLOCK_virt] [expr {0.1 * [get_clock_info -period MAIN_CLOCK_virt]}] [get_ports {fpga_user_leds[*]}]
set_multicycle_path -from $MAIN_CLOCK -to [get_clocks MAIN_CLOCK_virt] -setup -end 3
set_multicycle_path -from $MAIN_CLOCK -to [get_clocks MAIN_CLOCK_virt] -hold -end 2

# Set false path for DIPSW and button PIOs to complete the I/O constraint requirement.
set_false_path -from [get_ports {fpga_user_push_buttons[*]}]
set_false_path -from [get_ports {fpga_user_switches[*]}]

# Set multicycle path for warm_reset_handshake signal
set_multicycle_path 2 -setup -from [get_registers {*|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst~intosc_clk.reg}] -to [get_registers {*|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst~intosc_clk.reg}]
set_multicycle_path 1 -hold -from [get_registers {*|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst~intosc_clk.reg}] -to [get_registers {*|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst~intosc_clk.reg}]

set_false_path -to [get_registers {*|system_reset_extend_inst|reset_sync[0]}]
set_false_path -hold -to [get_registers {*|aux_reset_sync_inst|dreg[0]}]
set_false_path -hold -to [get_registers {*|aux_reset_sync_inst|dreg[1]}]
set_false_path -hold -to [get_registers {*|mgmt_reset_sync_inst|dreg[0]}]
set_false_path -hold -to [get_registers {*|mgmt_reset_sync_inst|dreg[1]}]
set_false_path -hold -to [get_registers {*|sys_reset_sync_inst|dreg[0]}]
set_false_path -hold -to [get_registers {*|sys_reset_sync_inst|dreg[1]}]

# Constraint DisplayPort Aux port, HPD
# - AUX interface is transferring at 1Mbps
set_false_path -to [get_ports dp_tx_aux_oe]
set_false_path -to [get_ports dp_tx_aux_out]