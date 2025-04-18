#****************************************************************************
#
# SPDX-License-Identifier: MIT-0
# SPDX-FileCopyrightText: Copyright (C) 2025 Altera Corporation
#
#****************************************************************************
#
# Sample SDC for Agilex GHRD.
#
#****************************************************************************

set_time_format -unit ns -decimal_places 3

# 100MHz board input clock, 133.3333MHz for EMIF refclk
create_clock -name MAIN_CLOCK -period 10 [get_ports fpga_clk_100]
create_clock -name EMIF_REF_CLOCK -period 100MHz [get_ports emif_hps_emif_ref_clk_0_clk] 
# edge-aligned input clk. There is no Ext PHY added delay in clock path
create_clock -name FPGA_RGMII_RXCLK -period 125MHz [get_ports fpga_rgmii_rx_clk]
create_clock -name FPGA_RGMII_RXCLK_VIR -period 125MHz

###############################
#####   Set Input delay   #####
###############################
# 3665.84 / (6000 mil per 1ns) = 0.61ns
set clk_trace_min 0.61
set clk_trace_max 0.61

# rxctl = 3650.59 / (6000 mil per 1ns) = 0.608ns
# rxd0 = 3677.57 / (6000 mil per 1ns) = 0.61ns
# rxd1 = 3723.49 / (6000 mil per 1ns) = 0.62ns
# rxd2 = 4231.29 / (6000 mil per 1ns) = 0.71ns
# rxd3 = 3706.5 / (6000 mil per 1ns) = 0.62ns
set rxctl_trace_min 0.608
set rxctl_trace_max 0.608
set rxd0_trace_min 0.61
set rxd0_trace_max 0.61
set rxd1_trace_min 0.62
set rxd1_trace_max 0.62
set rxd2_trace_min 0.71
set rxd2_trace_max 0.71
set rxd3_trace_min 0.62
set rxd3_trace_max 0.62

set ext_tco_min 1.5
set ext_tco_max 0.5

set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr {$rxctl_trace_max - $clk_trace_min + $ext_tco_max}] [get_ports fpga_rgmii_rx_ctl]
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr {$rxctl_trace_min - $clk_trace_max + $ext_tco_min}] [get_ports fpga_rgmii_rx_ctl]

set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr {$rxctl_trace_max - $clk_trace_min + $ext_tco_max}] [get_ports fpga_rgmii_rx_ctl] -clock_fall -add_delay
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr {$rxctl_trace_min - $clk_trace_max + $ext_tco_min}] [get_ports fpga_rgmii_rx_ctl] -clock_fall -add_delay

set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr {$rxd0_trace_max - $clk_trace_min + $ext_tco_max}] [get_ports fpga_rgmii_rxd[0]]
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr {$rxd0_trace_min - $clk_trace_max + $ext_tco_min}] [get_ports fpga_rgmii_rxd[0]]

set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr {$rxd0_trace_max - $clk_trace_min + $ext_tco_max}] [get_ports fpga_rgmii_rxd[0]] -clock_fall -add_delay
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr {$rxd0_trace_min - $clk_trace_max + $ext_tco_min}] [get_ports fpga_rgmii_rxd[0]] -clock_fall -add_delay

set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr {$rxd1_trace_max - $clk_trace_min + $ext_tco_max}] [get_ports fpga_rgmii_rxd[1]]
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr {$rxd1_trace_min - $clk_trace_max + $ext_tco_min}] [get_ports fpga_rgmii_rxd[1]]

set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr {$rxd1_trace_max - $clk_trace_min + $ext_tco_max}] [get_ports fpga_rgmii_rxd[1]] -clock_fall -add_delay
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr {$rxd1_trace_min - $clk_trace_max + $ext_tco_min}] [get_ports fpga_rgmii_rxd[1]] -clock_fall -add_delay

set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr {$rxd2_trace_max - $clk_trace_min + $ext_tco_max}] [get_ports fpga_rgmii_rxd[2]]
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr {$rxd2_trace_min - $clk_trace_max + $ext_tco_min}] [get_ports fpga_rgmii_rxd[2]]

set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr {$rxd2_trace_max - $clk_trace_min + $ext_tco_max}] [get_ports fpga_rgmii_rxd[2]] -clock_fall -add_delay
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr {$rxd2_trace_min - $clk_trace_max + $ext_tco_min}] [get_ports fpga_rgmii_rxd[2]] -clock_fall -add_delay

set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr {$rxd3_trace_max - $clk_trace_min + $ext_tco_max}] [get_ports fpga_rgmii_rxd[3]]
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr {$rxd3_trace_min - $clk_trace_max + $ext_tco_min}] [get_ports fpga_rgmii_rxd[3]]

set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr {$rxd3_trace_max - $clk_trace_min + $ext_tco_max}] [get_ports fpga_rgmii_rxd[3]] -clock_fall -add_delay
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr {$rxd3_trace_min - $clk_trace_max + $ext_tco_min}] [get_ports fpga_rgmii_rxd[3]] -clock_fall -add_delay 

## To make sure to consider the immediate posedge at destination 
set_multicycle_path 0 -setup -end -rise_from [get_clocks FPGA_RGMII_RXCLK_VIR] -rise_to [get_clocks FPGA_RGMII_RXCLK]
set_multicycle_path 0 -setup -end -fall_from [get_clocks FPGA_RGMII_RXCLK_VIR] -fall_to [get_clocks FPGA_RGMII_RXCLK]

set_false_path -fall_from [get_clocks FPGA_RGMII_RXCLK_VIR] -rise_to [get_clocks FPGA_RGMII_RXCLK] -setup
set_false_path -rise_from [get_clocks FPGA_RGMII_RXCLK_VIR] -fall_to [get_clocks FPGA_RGMII_RXCLK] -setup
set_false_path -fall_from [get_clocks FPGA_RGMII_RXCLK_VIR] -fall_to [get_clocks FPGA_RGMII_RXCLK] -hold
set_false_path -rise_from [get_clocks FPGA_RGMII_RXCLK_VIR] -rise_to [get_clocks FPGA_RGMII_RXCLK] -hold

set_false_path -from [get_ports {fpga_reset_n}]

# sourcing JTAG related SDC
source ./jtag.sdc

# FPGA IO port constraints
set_false_path -from [get_ports {fpga_button_pio[0]}] -to *
set_false_path -from [get_ports {fpga_button_pio[1]}] -to *
set_false_path -from [get_ports {fpga_button_pio[2]}] -to *
set_false_path -from [get_ports {fpga_button_pio[3]}] -to *
set_false_path -from [get_ports {fpga_dipsw_pio[0]}] -to *
set_false_path -from [get_ports {fpga_dipsw_pio[1]}] -to *
set_false_path -from [get_ports {fpga_dipsw_pio[2]}] -to *
set_false_path -from [get_ports {fpga_dipsw_pio[3]}] -to *
#set_false_path -from [get_ports {fpga_led_pio[0]}] -to *
#set_false_path -from [get_ports {fpga_led_pio[1]}] -to *
#set_false_path -from [get_ports {fpga_led_pio[2]}] -to *
#set_false_path -from [get_ports {fpga_led_pio[3]}] -to *
set_false_path -from * -to [get_ports {fpga_led_pio[0]}]
set_false_path -from * -to [get_ports {fpga_led_pio[1]}]
set_false_path -from * -to [get_ports {fpga_led_pio[2]}]
set_false_path -from * -to [get_ports {fpga_led_pio[3]}]
set_output_delay -clock MAIN_CLOCK 5 [get_ports {fpga_led_pio[3]}] 
