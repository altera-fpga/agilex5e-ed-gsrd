#
# SPDX-FileCopyrightText: Copyright (C) 2023-2024 Intel Corporation
# SPDX-License-Identifier: MIT-0
#

package require -exact qsys 23.2


#
# module msgdma2axi4_256
#
set_module_property DESCRIPTION ""
set_module_property NAME msgdma2axi4_256
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME msgdma2axi4_256
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false
set_module_property LOAD_ELABORATION_LIMIT 0
set_module_property PRE_COMP_MODULE_ENABLED false


#
# file sets
#
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL msgdma2axi4_256
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file msgdma2axi4_256.v VERILOG PATH msgdma2axi4_256.v TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL msgdma2axi4_256
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file msgdma2axi4_256.v VERILOG PATH msgdma2axi4_256.v

add_fileset SIM_VHDL SIM_VHDL "" ""
set_fileset_property SIM_VHDL TOP_LEVEL msgdma2axi4_256
set_fileset_property SIM_VHDL ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VHDL ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file msgdma2axi4_256.v VERILOG PATH msgdma2axi4_256.v


#
# parameters
#


#
# display items
#


#
# connection point clock
#
add_interface clock clock end
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""
set_interface_property clock IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property clock SV_INTERFACE_TYPE ""
set_interface_property clock SV_INTERFACE_MODPORT_TYPE ""

add_interface_port clock clk clk Input 1


#
# connection point reset
#
add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
set_interface_property reset ENABLED true
set_interface_property reset EXPORT_OF ""
set_interface_property reset PORT_NAME_MAP ""
set_interface_property reset CMSIS_SVD_VARIABLES ""
set_interface_property reset SVD_ADDRESS_GROUP ""
set_interface_property reset IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property reset SV_INTERFACE_TYPE ""
set_interface_property reset SV_INTERFACE_MODPORT_TYPE ""

add_interface_port reset reset reset Input 1


#
# connection point s0
#
add_interface s0 avalon end
set_interface_property s0 addressGroup 0
set_interface_property s0 addressUnits SYMBOLS
set_interface_property s0 associatedClock clock
set_interface_property s0 associatedReset reset
set_interface_property s0 bitsPerSymbol 8
set_interface_property s0 bridgedAddressOffset ""
set_interface_property s0 bridgesToMaster ""
set_interface_property s0 burstOnBurstBoundariesOnly false
set_interface_property s0 burstcountUnits WORDS
set_interface_property s0 explicitAddressSpan 0
set_interface_property s0 holdTime 0
set_interface_property s0 linewrapBursts false
set_interface_property s0 maximumPendingReadTransactions 16
set_interface_property s0 maximumPendingWriteTransactions 0
set_interface_property s0 minimumResponseLatency 1
set_interface_property s0 readLatency 0
set_interface_property s0 readWaitTime 1
set_interface_property s0 setupTime 0
set_interface_property s0 timingUnits Cycles
set_interface_property s0 transparentBridge false
set_interface_property s0 waitrequestAllowance 0
set_interface_property s0 writeWaitTime 0
set_interface_property s0 ENABLED true
set_interface_property s0 EXPORT_OF ""
set_interface_property s0 PORT_NAME_MAP ""
set_interface_property s0 CMSIS_SVD_VARIABLES ""
set_interface_property s0 SVD_ADDRESS_GROUP ""
set_interface_property s0 IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property s0 SV_INTERFACE_TYPE ""
set_interface_property s0 SV_INTERFACE_MODPORT_TYPE ""

add_interface_port s0 s0_read_address address Input 32
add_interface_port s0 s0_read_read read Input 1
# data width related
add_interface_port s0 s0_read_byteenable byteenable Input 32
# data width related
add_interface_port s0 s0_read_readdata readdata Output 256
add_interface_port s0 s0_read_waitrequest waitrequest Output 1
add_interface_port s0 s0_read_readdatavalid readdatavalid Output 1
# data width related
add_interface_port s0 s0_read_burstcount burstcount Input 8
set_interface_assignment s0 embeddedsw.configuration.isFlash 0
set_interface_assignment s0 embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment s0 embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment s0 embeddedsw.configuration.isPrintableDevice 0


#
# connection point s1
#
add_interface s1 avalon end
set_interface_property s1 addressGroup 0
set_interface_property s1 addressUnits SYMBOLS
set_interface_property s1 associatedClock clock
set_interface_property s1 associatedReset reset
set_interface_property s1 bitsPerSymbol 8
set_interface_property s1 bridgedAddressOffset ""
set_interface_property s1 bridgesToMaster ""
set_interface_property s1 burstOnBurstBoundariesOnly false
set_interface_property s1 burstcountUnits WORDS
set_interface_property s1 explicitAddressSpan 0
set_interface_property s1 holdTime 0
set_interface_property s1 linewrapBursts false
set_interface_property s1 maximumPendingReadTransactions 0
set_interface_property s1 maximumPendingWriteTransactions 0
set_interface_property s1 minimumResponseLatency 1
set_interface_property s1 readLatency 0
set_interface_property s1 readWaitTime 1
set_interface_property s1 setupTime 0
set_interface_property s1 timingUnits Cycles
set_interface_property s1 transparentBridge false
set_interface_property s1 waitrequestAllowance 0
set_interface_property s1 writeWaitTime 0
set_interface_property s1 ENABLED true
set_interface_property s1 EXPORT_OF ""
set_interface_property s1 PORT_NAME_MAP ""
set_interface_property s1 CMSIS_SVD_VARIABLES ""
set_interface_property s1 SVD_ADDRESS_GROUP ""
set_interface_property s1 IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property s1 SV_INTERFACE_TYPE ""
set_interface_property s1 SV_INTERFACE_MODPORT_TYPE ""

add_interface_port s1 s1_write_address address Input 32
add_interface_port s1 s1_write_write write Input 1
# data width related
add_interface_port s1 s1_write_byteenable byteenable Input 32
# data width related
add_interface_port s1 s1_write_writedata writedata Input 256
add_interface_port s1 s1_write_waitrequest waitrequest Output 1
# data width related
add_interface_port s1 s1_write_burstcount burstcount Input 8
set_interface_assignment s1 embeddedsw.configuration.isFlash 0
set_interface_assignment s1 embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment s1 embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment s1 embeddedsw.configuration.isPrintableDevice 0


#
# connection point m0
#
add_interface m0 axi4 start
set_interface_property m0 associatedClock clock
set_interface_property m0 associatedReset reset
set_interface_property m0 readIssuingCapability 16
set_interface_property m0 writeIssuingCapability 16
set_interface_property m0 combinedIssuingCapability 32
set_interface_property m0 issuesINCRBursts true
set_interface_property m0 issuesWRAPBursts false
set_interface_property m0 issuesFIXEDBursts false
set_interface_property m0 ENABLED true
set_interface_property m0 EXPORT_OF ""
set_interface_property m0 PORT_NAME_MAP ""
set_interface_property m0 CMSIS_SVD_VARIABLES ""
set_interface_property m0 SVD_ADDRESS_GROUP ""
set_interface_property m0 IPXACT_REGISTER_MAP_VARIABLES ""
set_interface_property m0 SV_INTERFACE_TYPE ""
set_interface_property m0 SV_INTERFACE_MODPORT_TYPE ""

add_interface_port m0 m0_araddr araddr Output 32
add_interface_port m0 m0_arburst arburst Output 2
add_interface_port m0 m0_arcache arcache Output 4
add_interface_port m0 m0_arid arid Output 1
add_interface_port m0 m0_arlen arlen Output 8
add_interface_port m0 m0_arlock arlock Output 1
add_interface_port m0 m0_arprot arprot Output 3
add_interface_port m0 m0_arready arready Input 1
add_interface_port m0 m0_arsize arsize Output 3
add_interface_port m0 m0_arvalid arvalid Output 1
add_interface_port m0 m0_awaddr awaddr Output 32
add_interface_port m0 m0_awburst awburst Output 2
add_interface_port m0 m0_awcache awcache Output 4
add_interface_port m0 m0_awid awid Output 1
add_interface_port m0 m0_awlen awlen Output 8
add_interface_port m0 m0_awlock awlock Output 1
add_interface_port m0 m0_awprot awprot Output 3
add_interface_port m0 m0_awready awready Input 1
add_interface_port m0 m0_awsize awsize Output 3
add_interface_port m0 m0_awvalid awvalid Output 1
add_interface_port m0 m0_bid bid Input 1
add_interface_port m0 m0_bready bready Output 1
add_interface_port m0 m0_bresp bresp Input 2
add_interface_port m0 m0_bvalid bvalid Input 1
# data width related
add_interface_port m0 m0_rdata rdata Input 256
add_interface_port m0 m0_rid rid Input 1
add_interface_port m0 m0_rlast rlast Input 1
add_interface_port m0 m0_rready rready Output 1
add_interface_port m0 m0_rresp rresp Input 2
add_interface_port m0 m0_rvalid rvalid Input 1
# data width related
add_interface_port m0 m0_wdata wdata Output 256
add_interface_port m0 m0_wlast wlast Output 1
add_interface_port m0 m0_wready wready Input 1
# data width related
add_interface_port m0 m0_wstrb wstrb Output 32
add_interface_port m0 m0_wvalid wvalid Output 1

