# Set the default time format
set_time_format -unit ns -decimal_places 3

# Create shorthand names for clocks
set MAIN_CLOCK [get_clocks {u_datamover_top|u_shell_subsys|u_clks_and_rsts|clks_and_rsts|u_sys_pll|iopll_0_outclk0}]

# Set asynchronous clock groups between hps_internal_osc, sys pll ref clock, and PLL-generated system main clock.
set_clock_groups -asynchronous -group [get_clocks {hps_internal_osc}] -group $MAIN_CLOCK

# Use -no_synchronizer for the following intra-clock false paths
set_false_path -no_synchronizer -from [get_registers {u_datamover_top|u_shell_subsys|u_clks_and_rsts|clks_and_rsts|fpga_reset_n_sync_0|dreg[1]}] -to [get_registers {u_datamover_top|u_dm_fab_subsys|rst_controller|alt_rst_sync_uq1|altera_reset_synchronizer_int_chain[1]}]

# Set false path for reset synchronizer chain
set_false_path -from [get_registers {u_datamover_top|u_shell_subsys|u_clks_and_rsts|clks_and_rsts|u_sys_pll|iopll_0|tennm_ph2_iopll~pll_ctrl_reg}] -to [get_registers {u_datamover_top|u_shell_subsys|u_clks_and_rsts|clks_and_rsts|fpga_reset_n_sync_0|dreg[0]}]
set_false_path -from [get_registers {u_datamover_top|u_shell_subsys|u_clks_and_rsts|clks_and_rsts|u_sys_pll|iopll_0|tennm_ph2_iopll~pll_ctrl_reg}] -to [get_registers {u_datamover_top|u_shell_subsys|u_clks_and_rsts|clks_and_rsts|fpga_reset_n_sync_0|dreg[1]}]