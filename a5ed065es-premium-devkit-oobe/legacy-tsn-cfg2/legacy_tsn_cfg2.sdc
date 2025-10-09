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

set_clock_groups -asynchronous -group {2_5M_2MUX1 25M_2MUX1} -group {FPGA_RGMII_RXCLK}

###############################
#####   Set Output delay  #####
###############################
create_generated_clock -divide_by 1 -name emac1_phy_txclk_o_hio [get_registers *sundancemesa_hps_inst~int_emac1_clk.reg] -master_clock [get_clocks int_emac1_clk] -source [get_nodes *sundancemesa_hps_inst~int_emac1_clk]
create_generated_clock -name rgmii_tx_clk -source [get_pins soc_inst|subsys_hps|agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst|emac1_phy_txclk_o_hio] -master_clock [get_clocks emac1_phy_txclk_o_hio] [get_ports fpga_rgmii_tx_clk]

set_clock_groups -logically_exclusive -group 2_5M_2MUX1 -group 25M_2MUX1 -group emac1_phy_txclk_o_hio
set_clock_groups -asynchronous -group {2_5M_2MUX1 25M_2MUX1} -group {rgmii_tx_clk}

set_output_delay -clock [get_clocks rgmii_tx_clk] -max -0.6 [get_ports fpga_rgmii_tx_ctl]
set_output_delay -clock [get_clocks rgmii_tx_clk] -min -2.0 [get_ports fpga_rgmii_tx_ctl]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -max -0.6 [get_ports fpga_rgmii_tx_ctl] -add_delay
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -min -2.0 [get_ports fpga_rgmii_tx_ctl] -add_delay

set_output_delay -clock [get_clocks rgmii_tx_clk] -max -0.6 [get_ports fpga_rgmii_txd[0]]
set_output_delay -clock [get_clocks rgmii_tx_clk] -min -2.0 [get_ports fpga_rgmii_txd[0]]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -max -0.6 [get_ports fpga_rgmii_txd[0]] -add_delay
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -min -2.0 [get_ports fpga_rgmii_txd[0]] -add_delay

set_output_delay -clock [get_clocks rgmii_tx_clk] -max -0.6 [get_ports fpga_rgmii_txd[1]]
set_output_delay -clock [get_clocks rgmii_tx_clk] -min -2.0 [get_ports fpga_rgmii_txd[1]]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -max -0.6 [get_ports fpga_rgmii_txd[1]] -add_delay
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -min -2.0 [get_ports fpga_rgmii_txd[1]] -add_delay

set_output_delay -clock [get_clocks rgmii_tx_clk] -max -0.6 [get_ports fpga_rgmii_txd[2]]
set_output_delay -clock [get_clocks rgmii_tx_clk] -min -2.0 [get_ports fpga_rgmii_txd[2]]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -max -0.6 [get_ports fpga_rgmii_txd[2]] -add_delay
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -min -2.0 [get_ports fpga_rgmii_txd[2]] -add_delay

set_output_delay -clock [get_clocks rgmii_tx_clk] -max -0.6 [get_ports fpga_rgmii_txd[3]]
set_output_delay -clock [get_clocks rgmii_tx_clk] -min -2.0 [get_ports fpga_rgmii_txd[3]]
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -max -0.6 [get_ports fpga_rgmii_txd[3]] -add_delay
set_output_delay -clock [get_clocks rgmii_tx_clk] -clock_fall -min -2.0 [get_ports fpga_rgmii_txd[3]] -add_delay

set_false_path -setup -rise_from [get_clocks emac1_phy_txclk_o_hio] -fall_to [get_clocks rgmii_tx_clk]
set_false_path -setup -fall_from [get_clocks emac1_phy_txclk_o_hio] -rise_to [get_clocks rgmii_tx_clk]
set_false_path -hold  -rise_from [get_clocks emac1_phy_txclk_o_hio] -rise_to [get_clocks rgmii_tx_clk]
set_false_path -hold  -fall_from [get_clocks emac1_phy_txclk_o_hio] -fall_to [get_clocks rgmii_tx_clk]

set_multicycle_path 0 -setup -end -rise_from [get_clocks emac1_phy_txclk_o_hio] -rise_to [get_clocks rgmii_tx_clk]
set_multicycle_path 0 -setup -end -fall_from [get_clocks emac1_phy_txclk_o_hio] -fall_to [get_clocks rgmii_tx_clk]

set_false_path -to [get_ports {fpga_rgmii_tx_clk}]

set_max_skew -to [get_ports "emac1_md*"] 5
set_input_delay  -clock [get_clocks emac1_mdc_clk] -source_latency_included -max 20 [get_ports emac1_mdio]
set_input_delay  -clock [get_clocks emac1_mdc_clk] -source_latency_included -min 0  [get_ports emac1_mdio]

set_false_path -no_synchronizer -from [get_registers {fpga_reset_n_sync|dreg[1]}] -to [get_registers {*|altera_reset_synchronizer_int_chain[1]}]
set_false_path -to [get_registers *fpga_reset_n_sync*]

# sourcing JTAG related SDC
source ./jtag.sdc

# FPGA IO port constraints
set_false_path -from [get_ports {fpga_reset_n}]
set_false_path -from [get_ports {fpga_button_pio[0]}] -to *
set_false_path -from [get_ports {fpga_button_pio[1]}] -to *
set_false_path -from [get_ports {fpga_button_pio[2]}] -to *
set_false_path -from [get_ports {fpga_button_pio[3]}] -to *
set_false_path -from [get_ports {fpga_dipsw_pio[0]}] -to *
set_false_path -from [get_ports {fpga_dipsw_pio[1]}] -to *
set_false_path -from [get_ports {fpga_dipsw_pio[2]}] -to *
set_false_path -from [get_ports {fpga_dipsw_pio[3]}] -to *
set_false_path -from * -to [get_ports {fpga_led_pio[0]}]
set_false_path -from * -to [get_ports {fpga_led_pio[1]}]
set_false_path -from * -to [get_ports {fpga_led_pio[2]}]
set_false_path -from * -to [get_ports {fpga_led_pio[3]}]
set_output_delay -clock MAIN_CLOCK 5 [get_ports {fpga_led_pio[0]}]
set_output_delay -clock MAIN_CLOCK 5 [get_ports {fpga_led_pio[1]}]
set_output_delay -clock MAIN_CLOCK 5 [get_ports {fpga_led_pio[2]}]
set_output_delay -clock MAIN_CLOCK 5 [get_ports {fpga_led_pio[3]}]
