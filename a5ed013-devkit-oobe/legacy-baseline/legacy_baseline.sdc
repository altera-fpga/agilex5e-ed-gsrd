#****************************************************************************
#
# SPDX-License-Identifier: MIT-0
# Copyright(c) 2019-2021 Intel Corporation.
#
#****************************************************************************
#
# Sample SDC for Agilex GHRD.
#
#****************************************************************************

set_time_format -unit ns -decimal_places 3

# 100MHz board input clock, 166.6667MHz for EMIF refclk
create_clock -name MAIN_CLOCK -period 10 [get_ports fpga_clk_100]

set_false_path -no_synchronizer -from [get_registers {fpga_reset_n_sync|dreg[1]}] -to [get_registers {*|altera_reset_synchronizer_int_chain[1]}]
set_false_path -to [get_registers *fpga_reset_n_sync*]

# sourcing JTAG related SDC
source ./jtag.sdc

# FPGA IO port constraints
set_false_path -from [get_ports {fpga_button_pio}] -to *
set_false_path -from * -to [get_ports {fpga_led_pio[0]}]
set_false_path -from * -to [get_ports {fpga_led_pio[1]}]
set_output_delay -clock MAIN_CLOCK 5 [get_ports {fpga_led_pio[0]}]
set_output_delay -clock MAIN_CLOCK 5 [get_ports {fpga_led_pio[1]}]
