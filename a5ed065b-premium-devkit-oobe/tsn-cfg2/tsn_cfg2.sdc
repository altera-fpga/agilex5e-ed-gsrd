# Set the default time format
set_time_format -unit ns -decimal_places 3

# Create shorthand names for clocks
set MAIN_CLOCK [get_clocks {u_tsn_cfg2_top|u_shell_subsys|u_clocks_and_resets|clks_and_rsts|u_sys_pll|iopll_0_outclk0}]

# Create a virtual clock for the MAIN_CLOCK for use with IO timing
create_clock -name MAIN_CLOCK_virt -period [get_clock_info -period $MAIN_CLOCK]

# Set a loose/small output delay for LED PIOs to complete the I/O constraint requirement.
set_output_delay -source_latency_included -clock [get_clocks MAIN_CLOCK_virt] [expr {0.1 * [get_clock_info -period MAIN_CLOCK_virt]}] [get_ports {fpga_user_leds[*]}]
set_multicycle_path -from $MAIN_CLOCK -to [get_clocks MAIN_CLOCK_virt] -setup -end 3
set_multicycle_path -from $MAIN_CLOCK -to [get_clocks MAIN_CLOCK_virt] -hold -end 2

# Set a loose/small input delay for DIPSW and button PIOs to complete the I/O constraint requirement.
set_input_delay -source_latency_included -clock [get_clocks MAIN_CLOCK_virt] [expr {0.1 * [get_clock_info -period MAIN_CLOCK_virt]}] [get_ports {fpga_user_push_buttons[*]}]
set_input_delay -source_latency_included -clock [get_clocks MAIN_CLOCK_virt] [expr {0.1 * [get_clock_info -period MAIN_CLOCK_virt]}] [get_ports {fpga_user_switches[*]}]

# Set asynchronous clock groups between hps_internal_osc and system main clock.
set_clock_groups -asynchronous -group [get_clocks {hps_internal_osc}] -group $MAIN_CLOCK

# Set multicycle path for warm_reset_handshake signal
set_multicycle_path 2 -setup -from [get_registers {*|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst~intosc_clk.reg}] -to [get_registers {*|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst~intosc_clk.reg}]
set_multicycle_path 1 -hold -from [get_registers {*|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst~intosc_clk.reg}] -to [get_registers {*|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst~intosc_clk.reg}]

# Use -no_synchronizer for the following intra-clock false paths
set_false_path -no_synchronizer -from [get_registers {*|u_clocks_and_resets|clks_and_rsts|fpga_reset_n_sync|dreg[1]}] -to [get_registers {*|altera_reset_synchronizer_int_chain[1]}]
set_false_path -no_synchronizer -from [get_registers {*|u_fabric_subsys|rst_controller|r_sync_rst}] -to [get_registers {*|altera_reset_synchronizer_int_chain[1]}]

###############################################################################
# TSN Config2 Timing Constraints                                              #
###############################################################################

# Create virtual clock for FPGA RGMII RXCLK input port
# Edge-aligned input clk. There is no external PHY delay added in clock path
create_clock -name FPGA_RGMII_RXCLK -period 125MHz [get_ports fpga_rgmii_rx_clk]
create_clock -name FPGA_RGMII_RXCLK_VIR -period 125MHz

#------------------------------------------------------------------------------
# Set input delay for FPGA RGMII I/O Interface
set rxd_to_clk_board_skew_max 0.02
set rxd_to_clk_board_skew_min -0.02
set rxctl_to_clk_board_skew_max 0.02
set rxctl_to_clk_board_skew_min -0.02

set ext_tco_min 0.15
set ext_tco_max 0.5

set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr $rxctl_to_clk_board_skew_max + $ext_tco_max] [get_ports fpga_rgmii_rx_ctl]
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr $rxctl_to_clk_board_skew_min + $ext_tco_min] [get_ports fpga_rgmii_rx_ctl]
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr $rxctl_to_clk_board_skew_max + $ext_tco_max] [get_ports fpga_rgmii_rx_ctl] -clock_fall -add_delay
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr $rxctl_to_clk_board_skew_min + $ext_tco_min] [get_ports fpga_rgmii_rx_ctl] -clock_fall -add_delay

set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr $rxd_to_clk_board_skew_max + $ext_tco_max] [get_ports fpga_rgmii_rxd[*]]
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr $rxd_to_clk_board_skew_min + $ext_tco_min] [get_ports fpga_rgmii_rxd[*]]
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -max [expr $rxd_to_clk_board_skew_max + $ext_tco_max] [get_ports fpga_rgmii_rxd[*]] -clock_fall -add_delay
set_input_delay -clock [get_clocks FPGA_RGMII_RXCLK_VIR]  -source_latency_included -min [expr $rxd_to_clk_board_skew_min + $ext_tco_min] [get_ports fpga_rgmii_rxd[*]] -clock_fall -add_delay

## Set multicycle to consider the immediate posedge at destination
set_multicycle_path 0 -setup -end -rise_from [get_clocks FPGA_RGMII_RXCLK_VIR] -rise_to [get_clocks FPGA_RGMII_RXCLK]
set_multicycle_path 0 -setup -end -fall_from [get_clocks FPGA_RGMII_RXCLK_VIR] -fall_to [get_clocks FPGA_RGMII_RXCLK]

set_false_path -fall_from [get_clocks FPGA_RGMII_RXCLK_VIR] -rise_to [get_clocks FPGA_RGMII_RXCLK] -setup
set_false_path -rise_from [get_clocks FPGA_RGMII_RXCLK_VIR] -fall_to [get_clocks FPGA_RGMII_RXCLK] -setup
set_false_path -fall_from [get_clocks FPGA_RGMII_RXCLK_VIR] -fall_to [get_clocks FPGA_RGMII_RXCLK] -hold
set_false_path -rise_from [get_clocks FPGA_RGMII_RXCLK_VIR] -rise_to [get_clocks FPGA_RGMII_RXCLK] -hold

set_clock_groups -asynchronous -group {2_5M_2MUX1_0 25M_2MUX1_0} -group {FPGA_RGMII_RXCLK}

#------------------------------------------------------------------------------
# Set output delay for FPGA RGMII I/O Interface
# Set input delay for FPGA RGMII I/O Interface
set txd_to_clk_board_skew_max 0.02
set txd_to_clk_board_skew_min -0.02
set txctl_to_clk_board_skew_max 0.02
set txctl_to_clk_board_skew_min -0.02

set ext_thold_min -2.7
set ext_tsetup_min -0.9

create_generated_clock -divide_by 1 -name emac1_phy_txclk_o_hio [get_registers *sundancemesa_hps_inst~int_emac1_clk.reg] -master_clock [get_clocks int_emac1_clk] -source [get_nodes *sundancemesa_hps_inst~int_emac1_clk]
# create_generated_clock -name rgmii_tx_clk -source [get_pins u_tsn_cfg2_top|u_shell_subsys|u_hps_subsys|u_agilex_hps|intel_agilex_5_soc_inst|sm_hps|sundancemesa_hps_inst|emac1_phy_txclk_o_hio] -master_clock [get_clocks emac1_phy_txclk_o_hio] [get_ports fpga_rgmii_tx_clk]

#create_generated_clock -name rgmii_txpll_clk -source [get_pins u_rgmii_txclk_pll|iopll_0|tennm_ph2_iopll|ref_clk0] -master [get_clocks emac1_phy_txclk_o_hio] [get_pins u_rgmii_txclk_pll|iopll_0|tennm_ph2_iopll|out_clk[0]]
#create_generated_clock -name rgmii_tx_clk -source [get_pins u_rgmii_txclk_pll|iopll_0|tennm_ph2_iopll|ref_clk0] -master [get_clocks emac1_phy_txclk_o_hio] [get_pins u_rgmii_txclk_pll|iopll_0|tennm_ph2_iopll|out_clk[0]]
#create_generated_clock -name rgmii_tx_clk -source [get_pins u_rgmii_txclk_pll|iopll_0|tennm_ph2_iopll|out_clk[0]] [get_ports {fpga_rgmii_tx_clk}]
create_generated_clock -name rgmii_tx_clk -source [get_pins {ddr_gpio_inst|gpio_0|core|i_loop[0].altera_gpio_bit_i|out_path.out_path_fr.fr_out_data_ddio|dataout}] -master_clock [get_clocks emac1_phy_txclk_o_hio] [get_ports {fpga_rgmii_tx_clk}]

set_clock_groups -logically_exclusive -group 2_5M_2MUX1_0 -group 25M_2MUX1_0 -group emac1_phy_txclk_o_hio
set_clock_groups -asynchronous -group {2_5M_2MUX1_0 25M_2MUX1_0} -group {rgmii_tx_clk}

set_output_delay -clock [get_clocks rgmii_tx_clk] -max [expr $txd_to_clk_board_skew_max + $ext_tsetup_min] [get_ports fpga_rgmii_tx_ctl]
set_output_delay -clock [get_clocks rgmii_tx_clk] -min [expr $txd_to_clk_board_skew_min + $ext_thold_min]  [get_ports fpga_rgmii_tx_ctl]
set_output_delay -clock [get_clocks rgmii_tx_clk] -max [expr $txd_to_clk_board_skew_max + $ext_tsetup_min] [get_ports fpga_rgmii_tx_ctl] -clock_fall -add_delay
set_output_delay -clock [get_clocks rgmii_tx_clk] -min [expr $txd_to_clk_board_skew_min + $ext_thold_min]  [get_ports fpga_rgmii_tx_ctl] -clock_fall -add_delay

set_output_delay -clock [get_clocks rgmii_tx_clk] -max [expr $txd_to_clk_board_skew_max + $ext_tsetup_min] [get_ports fpga_rgmii_txd[*]]
set_output_delay -clock [get_clocks rgmii_tx_clk] -min [expr $txd_to_clk_board_skew_min + $ext_thold_min]  [get_ports fpga_rgmii_txd[*]]
set_output_delay -clock [get_clocks rgmii_tx_clk] -max [expr $txd_to_clk_board_skew_max + $ext_tsetup_min] [get_ports fpga_rgmii_txd[*]] -clock_fall -add_delay
set_output_delay -clock [get_clocks rgmii_tx_clk] -min [expr $txd_to_clk_board_skew_min + $ext_thold_min]  [get_ports fpga_rgmii_txd[*]] -clock_fall -add_delay

set_false_path -setup -rise_from [get_clocks emac1_phy_txclk_o_hio] -fall_to [get_clocks rgmii_tx_clk]
set_false_path -setup -fall_from [get_clocks emac1_phy_txclk_o_hio] -rise_to [get_clocks rgmii_tx_clk]
set_false_path -hold  -rise_from [get_clocks emac1_phy_txclk_o_hio] -rise_to [get_clocks rgmii_tx_clk]
set_false_path -hold  -fall_from [get_clocks emac1_phy_txclk_o_hio] -fall_to [get_clocks rgmii_tx_clk]

set_multicycle_path 0 -setup -end -rise_from [get_clocks emac1_phy_txclk_o_hio] -rise_to [get_clocks rgmii_tx_clk]
set_multicycle_path 0 -setup -end -fall_from [get_clocks emac1_phy_txclk_o_hio] -fall_to [get_clocks rgmii_tx_clk]

set_max_skew -to [get_ports "*emac1_md*"] 5
set_input_delay  -clock [get_clocks emac1_mdc_clk] -source_latency_included -max 20 [get_ports fpga_emac1_mdio]
set_input_delay  -clock [get_clocks emac1_mdc_clk] -source_latency_included -min 0  [get_ports fpga_emac1_mdio]