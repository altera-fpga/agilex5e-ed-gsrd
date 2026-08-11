#
# SPDX-License-Identifier: MIT-0
# SPDX-FileCopyrightText: Copyright (C) 2025 Altera Corporation
#

# 
# request TCL package from ACDS 25.3.1
# 
package require -exact qsys 25.3.1


# 
# module clocks_and_resets
# 
set_module_property DESCRIPTION ""
set_module_property NAME u_clocks_and_resets
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property BSP_CPU false
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME clocks_and_resets
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true

# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH generate_fileset
set_fileset_property QUARTUS_SYNTH TOP_LEVEL clocks_and_resets
 
add_fileset SIM_VERILOG SIM_VERILOG generate_fileset
set_fileset_property SIM_VERILOG TOP_LEVEL clocks_and_resets

proc generate_fileset {entity_name} {
add_fileset_file clocks_and_resets.sv SYSTEM_VERILOG PATH ../src/clocks_and_resets.sv TOP_LEVEL_FILE
}

# 
# parameters
# 


# 
# display items
# 


# 
# connection point fpga_clk_100
# 
add_interface fpga_clk_100 clock end
set_interface_property fpga_clk_100 ENABLED true
set_interface_property fpga_clk_100 EXPORT_OF ""
set_interface_property fpga_clk_100 PORT_NAME_MAP ""
set_interface_property fpga_clk_100 CMSIS_SVD_VARIABLES ""
set_interface_property fpga_clk_100 SVD_ADDRESS_GROUP ""
set_interface_property fpga_clk_100 IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property fpga_clk_100 SV_INTERFACE_TYPE ""
set_interface_property fpga_clk_100 SV_INTERFACE_MODPORT_TYPE ""

add_interface_port fpga_clk_100 fpga_clk_100 clk Input 1


# 
# connection point fpga_reset_n
# 
add_interface fpga_reset_n reset end
set_interface_property fpga_reset_n associatedClock ""
set_interface_property fpga_reset_n synchronousEdges NONE
set_interface_property fpga_reset_n ENABLED true
set_interface_property fpga_reset_n EXPORT_OF ""
set_interface_property fpga_reset_n PORT_NAME_MAP ""
set_interface_property fpga_reset_n CMSIS_SVD_VARIABLES ""
set_interface_property fpga_reset_n SVD_ADDRESS_GROUP ""
set_interface_property fpga_reset_n IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property fpga_reset_n SV_INTERFACE_TYPE ""
set_interface_property fpga_reset_n SV_INTERFACE_MODPORT_TYPE ""

add_interface_port fpga_reset_n fpga_reset_n reset_n Input 1


# 
# connection point h2f_reset_in
# 
add_interface h2f_reset_in reset end
set_interface_property h2f_reset_in associatedClock ""
set_interface_property h2f_reset_in synchronousEdges NONE
set_interface_property h2f_reset_in ENABLED true
set_interface_property h2f_reset_in EXPORT_OF ""
set_interface_property h2f_reset_in PORT_NAME_MAP ""
set_interface_property h2f_reset_in CMSIS_SVD_VARIABLES ""
set_interface_property h2f_reset_in SVD_ADDRESS_GROUP ""
set_interface_property h2f_reset_in IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property h2f_reset_in SV_INTERFACE_TYPE ""
set_interface_property h2f_reset_in SV_INTERFACE_MODPORT_TYPE ""

add_interface_port h2f_reset_in h2f_reset_in reset Input 1


# 
# connection point system_clock
# 
add_interface system_clock clock start
set_interface_property system_clock associatedDirectClock ""
set_interface_property system_clock ENABLED true
set_interface_property system_clock EXPORT_OF ""
set_interface_property system_clock PORT_NAME_MAP ""
set_interface_property system_clock CMSIS_SVD_VARIABLES ""
set_interface_property system_clock SVD_ADDRESS_GROUP ""
set_interface_property system_clock IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property system_clock SV_INTERFACE_TYPE ""
set_interface_property system_clock SV_INTERFACE_MODPORT_TYPE ""

add_interface_port system_clock system_clock clk Output 1


# 
# connection point system_reset_n
# 
add_interface system_reset_n reset start
set_interface_property system_reset_n associatedClock system_clock
set_interface_property system_reset_n associatedDirectReset ""
set_interface_property system_reset_n associatedResetSinks h2f_reset_in
set_interface_property system_reset_n synchronousEdges DEASSERT
set_interface_property system_reset_n ENABLED true
set_interface_property system_reset_n EXPORT_OF ""
set_interface_property system_reset_n PORT_NAME_MAP ""
set_interface_property system_reset_n CMSIS_SVD_VARIABLES ""
set_interface_property system_reset_n SVD_ADDRESS_GROUP ""
set_interface_property system_reset_n IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property system_reset_n SV_INTERFACE_TYPE ""
set_interface_property system_reset_n SV_INTERFACE_MODPORT_TYPE ""

add_interface_port system_reset_n system_reset_n reset_n Output 1