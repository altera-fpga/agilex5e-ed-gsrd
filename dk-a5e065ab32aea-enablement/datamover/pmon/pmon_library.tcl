# (C) 2001-2025 Altera Corporation. All rights reserved.
# Your use of Altera Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files from any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License Subscription 
# Agreement, Altera IP License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the applicable 
# agreement for further details.


######################################################################
# Performance Monitor IP – System Console library
######################################################################
#
# FILE DESCRIPTION
# --------------------
# This file contains:
# - System Console functions to interact with Performance Monitor IP on hardware over a JTAG connection
#
# DISCLAIMERS
# --------------------
# Performance Monitor IP is provided as a beta version. Its functionality and System Console functions are subject to
# change in future releases. Any scripts using this library will need updating if
# function names and behaviors change in future releases.
#
# UNSUPPORTED FEATURES
# --------------------
# 1) Not all metrics can be provided in a single run of the application
# 2) Supports a maximum of (2^16)-3 outstanding transactions for accurate latency metrics
# 3) Only supports maximum and minimum latency in advanced latency mode. Otherwise, it will provide the max number of outstanding transactions.
# 4) Requires no traffic gaps on read or write channels greater (2^16)-1 cycles to measure efficiency accurately
# 5) Size of counters are 48 bits by default but can be configured to anything in the range [33,63].
# 6) Requires at least 2 transactions on an AXI4 subchannel to measure efficiency for the subchannel
# 7) Does not support metric configuration mid traffic
# 8) Reading metrics mid traffic will provide an approximation rather than an exact value.
# 9) Supports a maximum of 64 Unit Monitors in the system
#
# LIBRARY USAGE
# ------------------
# 1) Ensure your design is loaded in system console
# 2) Source this script in system console
#
# SETUP CHECKLIST
# ------------------
# 1) Ensure the Enable performance monitoring option in the example design is set to true OR in standalone usage ensure the option Remote access via JTAG is enabled in pmon.
# 2) Ensure that the design is programmed on board
#
# EXAMPLE USAGE
# --------------------
# Recommended sequence of function calls to configure the Performance Monitor and extract metrics:
# pmon_set_<config> {index} {umon} or _all #set the metric configuration on desired AXI4 PMONs
# pmon_reset_counter_data_all       #clear counters and internal state of all Performance Monitors
# #RUN TRAFFIC OVER THE INTERFACE
# pmon_read {index} {umon} or _all  #read metrics on desired AXI4 PMONs and present in human readable format.
#
# FUNCTIONS
# ------------------
#internal doc          _pmon_discover {index} : Performs the discovery process for PMON JTAG <index>
# pmon_discover_all : Performs the discovery process for all PMON JTAGs for all monitors and intialize all top level list variables.Called automatically when loading library and needed for all following functions.
#internal doc          _pmon_choose {index} {umon} : Chooses which unit monitor based on PMON <index> and monitor <umon> to set top level variables to for functions. Returns -1 if the id chosen is not valid and prints and error message.
# pmon_print_info {index} : Prints parameters and path of given PMON JTAG <index>.
# pmon_freeze {index} {umon}: Sets Freeze field of UCTRL register of PMON <index> Unit monitor <umon> to 1
# pmon_unfreeze {index} {umon}: Sets Freeze field of UCTRL register of PMON <index> Unit monitor <umon> to 0
# pmon_reset_counter_control {index} {umon}: Reset counter metric configuration for PMON <index> unit monitor <umon>
# pmon_reset_counter_data {index} {umon}: Reset counter data for PMON <index> unit monitor <umon>. This must be called after calling the pmon_set function.
# pmon_reset_status {index} {umon}: Clears the status bits of PMON <index> unit monitor <umon>
# pmon_print_status {index} {umon}: Prints out the overflow status of each counter in PMON <index> unit monitor <umon>
# pmon_print_counter_control {index} {umon}: Prints out the counter control register of each counter of PMON <index> unit monitor <umon> with its address in memory
# pmon_print_counter_data {index} {umon}: Prints out the counter data register of each counter of PMON <index> unit monitor <umon> with its address in memory
# pmon_get_counter_control {index} {umon}: Returns a list of the counter control register values of PMON <index> unit monitor <umon>
# pmon_get_counter_data {index} {umon}: Returns a list of the counter data register values of PMON <index> unit monitor <umon>
# pmon_get_status {index} {umon}: Returns a list overflow status of each counter in PMON <index> unit monitor <umon>
# pmon_num_ins : Returns the number of PMON instances in design.
#internal doc          _pmon_total_umon : Returns the total number of unit monitors in design.
# pmon_num_umon {index} : Returns the number of unit monitors of PMON instance <index>.
# pmon_define_configs {index} : Initializes library supported PMON configurations.
# pmon_set {config} {index} {umon}: Sets counter control of PMON <index> unit monitor <umon> based on the provided {config} argument (Defined in pmon_define_configs).
# pmon_read {index} {umon}: Read the derived metrics of PMON <index> unit monitor <umon> based on the currently set configuration of the monitor.
# pmon_help {option}: Display information about the PMON library.
# pmon_check_viol {index} {umon}: Debug function, checks if max outstanding transactions or traffic gap violations were found after reading results and prints errors. Checking traffic gap or outstanding transaction violations corrupts counter data so ensure all data is collected before checking violations.
#
# NOTES
# --------------------
# Appending _all (available on any set, read, reset or check function) will call the function for all unit monitors in the design.
# If efficiency or latency metrics look to have possible errors run pmon_check_viol_all for possible usage violations of PMON after reading results.
#
# METRIC DEFINITIONS
# --------------------
# Read Latency: AR acceptance to R last response
# Write Latency: AW acceptance to B response
# Read Efficiency: #of R data beats / Cycles from first AR acceptance to last R transaction
# Write Efficiency: #of W data beats / Cycles from first AW|W acceptance to last B transaction
# Total Traffic Duration: Cycles from first AR|AW|W acceptance to last R|B transaction
# Average Number of Data transactions per cycle: (#of W data beats + #of R Data Beats) / Total Traffic Duration
# Subchannel Efficiency: #of transactions on subchannel / First to last transaction on subchannel
# Subchannel Backpressure: #of cycles with XVALID = 1 and XREADY = 0 / First to last transaction on subchannel
# Expected Transactions on subchannel: R is based on ARLEN, W is based AWLEN and B is based on number of transactions on the AW subchannel
#
# CONFIG ARGUMENTS
# -------------------------
# empty : Sets all counters to an idle state and clears all filters.
# basic_eff : Set metrics for Read efficiency, Write efficiency, and Average Data transactions per cycle of the AXI4 Interface.
# ch_eff : Set metrics for efficiency of the AR, R, AW, W subchannels of the AXI4 Interface.
# ch_bp : Set metrics for back pressure of the AR, R, AW, W subchannels of the AXI4 Interface.
# basic_rw : Set metrics for the Read, Write efficiency and average latencies of the AXI4 Interface.
# wo : Set metrics for AXI4 subchannel (AW,W,B) efficiency, transactions, average write burst length, expected write data transactions and average write latency of the AXI4 Interface.
# ro : Set metrics for AXI4 subchannel (AR,R) efficiency, transactions, back pressure, average read burst length, expected read data transactions and average read latency of the AXI4 Interface.
# diag : Set metrics for number of AXI4 subchannel transactions (AR,R,AW,W,B), expected R,W transactions, and total traffic duration of the AXI4 Interface.
# primary : Set metrics for AXI4 subchannel (AR,AW,W) efficiency, transactions, average read and write latency of the AXI4 Interface.
# secondary : Set metrics for AXI4 subchannel (R,B) efficiency, transactions, backpressure, expected R and B transactions of the AXI4 Interface.
# basic_lat : Set metrics for Read & Write average latencies, maximum outstanding transactions, average burst lengths of the AXI4 Interface.


namespace eval ::pmon_lib:: {
    namespace export pmon_discover_all
    namespace export pmon_num_ins
    namespace export pmon_num_umon
    namespace export pmon_print_info
    namespace export pmon_freeze
    namespace export pmon_unfreeze
    namespace export pmon_reset_counter_control
    namespace export pmon_reset_counter_data
    namespace export pmon_print_status
    namespace export pmon_get_status
    namespace export pmon_reset_status
    namespace export pmon_print_counter_control
    namespace export pmon_get_counter_control
    namespace export pmon_print_counter_data
    namespace export pmon_get_counter_data
    namespace export pmon_read
    namespace export pmon_read_all
    namespace export pmon_reset_counter_data_all
    namespace export pmon_reset_counter_control_all
    namespace export pmon_reset_status_all
    namespace export pmon_check_viol
    namespace export pmon_check_viol_all
    namespace export pmon_help
    namespace export pmon_set
    namespace export pmon_set_all
    namespace export pmon_define_configs
}

set pmon_inst_list [lsearch -glob -inline -all [get_service_paths master] *pmon_jamb*]

if {[llength $pmon_inst_list] == 0} {
   puts "Error : Performance Monitor remote JTAG interface not found"
   puts "Ensure .sof is loaded and JTAG access is functional before loading Performance Monitor System console library"
   set claim_pmon_jamb_path_list ""
   return
} else {
    puts "Performance Monitor remote JTAG interface(s) found"
    set claim_pmon_jamb_path_list [claim_service master [lindex $pmon_inst_list 0] {} {}]
    for {set i 1} {$i < [llength $pmon_inst_list]} {incr i} {
        lappend claim_pmon_jamb_path_list [claim_service master [lindex $pmon_inst_list $i] {} {}]
    }
}

variable PMON_BAR_list [list]
variable PMON_JAMB_list [list]
variable PMON_INST_list [list]
variable PMON_UMON_list [list]

variable NumCntr_list [list]
variable UnitCntrCtrlAdr_offset_list  [list]
variable CntrWidth_list [list]
variable UnitCntrDataAdr_offset_list [list]
variable UnitStatAdr_offset_list [list]
variable UCAddress_list [list]
variable UnitType_list [list]
variable Settings_list [list]
variable UnitID_list [list]

proc ::pmon_lib::_pmon_discover { {index 0} } {
    upvar claim_pmon_jamb_path claim_pmon_jamb_path
    upvar pmon_inst_list pmon_inst_list

    variable PMON_INST
    set PMON_INST [lindex $pmon_inst_list $index]

    variable PMON_JAMB
    set PMON_JAMB $claim_pmon_jamb_path

    variable PMON_BAR
    set PMON_BAR 0
    set PMON_BAR [format 0x%x $PMON_BAR]

    set PMON_GDIS_H [master_read_32 $claim_pmon_jamb_path [expr {$PMON_BAR + 0x4}] 1]
    set AccessType [expr {($PMON_GDIS_H >> 29) & 0x7}]
    set AccessType [format 0x%x $AccessType]

    set PMON_GDIS_L [master_read_32 $claim_pmon_jamb_path 0x0 1]
    set BlockStride [expr {($PMON_GDIS_L >> 8) & 0xff}]
    set BlockStride [format 0x%x $BlockStride]

    set MaxBlocks [expr {($PMON_GDIS_L >> 16) & 0x3ff}]
    set MaxBlocks [format 0x%x $MaxBlocks]
    variable PMON_UMON
    set PMON_UMON [expr $MaxBlocks]

    set PMON_GCADR_L [master_read_32 $claim_pmon_jamb_path 0x8 1]
    set PMON_GCADR_H [master_read_32 $claim_pmon_jamb_path 0xc 1]
    set GCAddress [expr {($PMON_GCADR_H << 32) | $PMON_GCADR_L}]
    set GCAddress [format 0x%x $GCAddress]

    variable NumCntr_mon [list]
    variable UnitCntrCtrlAdr_offset_mon [list]
    variable CntrWidth_mon [list]
    variable UnitCntrDataAdr_offset_mon [list]
    variable UnitStatAdr_offset_mon [list]
    variable UCAddress_mon [list]
    variable UnitType_mon [list]
    variable Settings_mon [list]
    variable UnitID_mon [list]

    for {set i 1} {$i <= $MaxBlocks} {incr i} {
        set unit_monitor_0_base_addr [expr {$PMON_BAR + (($BlockStride << 3) *$i) }]
        set unit_monitor_0_base_addr [format 0x%x $unit_monitor_0_base_addr]

        set pmon_udis_l_addr [expr {$unit_monitor_0_base_addr + 0x0}]
        set PMON_UDIS_L [master_read_32 $claim_pmon_jamb_path $pmon_udis_l_addr 1]
        variable NumCntr
        set NumCntr [expr {($PMON_UDIS_L >> 0) & 0xff}]

        set PMON_UDIS_L [master_read_32 $claim_pmon_jamb_path $pmon_udis_l_addr 1]
        variable UnitCntrCtrlAdr_offset
        set UnitCntrCtrlAdr_offset [expr {($PMON_UDIS_L >> 8) & 0xff}]
        set UnitCntrCtrlAdr_offset [format 0x%x $UnitCntrCtrlAdr_offset]

        set PMON_UDIS_L [master_read_32 $claim_pmon_jamb_path $pmon_udis_l_addr 1]
        variable CntrWidth
        set CntrWidth [expr {($PMON_UDIS_L >> 16) & 0xff}]

        variable UnitCntrDataAdr_offset
        set UnitCntrDataAdr_offset [expr {($PMON_UDIS_L >> 24) & 0xff}]
        set UnitCntrDataAdr_offset [format 0x%x $UnitCntrDataAdr_offset]

        set pmon_udis_h_addr [expr {$unit_monitor_0_base_addr + 0x4}]
        set PMON_UDIS_H [master_read_32 $claim_pmon_jamb_path $pmon_udis_h_addr 1]
        variable UnitStatAdr_offset
        set UnitStatAdr_offset [expr {$PMON_UDIS_H & 0xff}]
        set UnitStatAdr_offset [format 0x%x $UnitStatAdr_offset ]

        set pmon_ucadr_l_addr [expr {$unit_monitor_0_base_addr + 0x8}]
        set pmon_ucadr_h_addr [expr {$unit_monitor_0_base_addr + 0xc}]
        set PMON_UCADR_L [master_read_32 $claim_pmon_jamb_path $pmon_ucadr_l_addr 1]
        set PMON_UCADR_H [master_read_32 $claim_pmon_jamb_path $pmon_ucadr_h_addr 1]
        variable UCAddress
        set UCAddress [expr {($PMON_UCADR_H << 32) | $PMON_UCADR_L}]
        set UCAddress [format 0x%x $UCAddress]

        set pmon_udit_l_addr [expr {$unit_monitor_0_base_addr + 0x10}]
        set PMON_UDIT_L [master_read_32 $claim_pmon_jamb_path $pmon_udit_l_addr 1]
        variable UnitType
        set UnitType [expr {($PMON_UDIT_L >> 0) & 0xffff}]
        if {$UnitType == 0} {
            set UnitType "AXI4"
        } else {
            set UnitType "Unknown"
        }
        variable Settings
        set Settings [expr {($PMON_UDIT_L >> 8) & 0xff}]


        set PMON_UDIT_L [master_read_32 $claim_pmon_jamb_path $pmon_udit_l_addr 1]
        variable UnitID
        set UnitID [expr {($PMON_UDIT_L >> 16) & 0xffff}]


        lappend NumCntr_mon $NumCntr
        lappend UnitCntrCtrlAdr_offset_mon $UnitCntrCtrlAdr_offset
        lappend CntrWidth_mon $CntrWidth
        lappend UnitCntrDataAdr_offset_mon $UnitCntrDataAdr_offset
        lappend UnitStatAdr_offset_mon $UnitStatAdr_offset
        lappend UCAddress_mon $UCAddress
        lappend UnitType_mon $UnitType
        lappend Settings_mon $Settings
        lappend UnitID_mon $UnitID
    }
}

proc ::pmon_lib::_pmon_total_umon {} {

    variable PMON_UMON_list
    set num_umon_total 0
    foreach i $PMON_UMON_list {
        set num_umon_total [expr {$num_umon_total + $i}]
    }
    return $num_umon_total
}

proc ::pmon_lib::pmon_discover_all {} {
    upvar claim_pmon_jamb_path_list claim_pmon_jamb_path_list
    upvar pmon_inst_list pmon_inst_list
    puts "PMON Discovery process beginning"

    variable PMON_BAR_list [list]
    variable PMON_JAMB_list [list]
    variable PMON_INST_list [list]
    variable PMON_UMON_list [list]

    variable NumCntr_list [list]
    variable UnitCntrCtrlAdr_offset_list [list]
    variable CntrWidth_list [list]
    variable UnitCntrDataAdr_offset_list [list]
    variable UnitStatAdr_offset_list [list]
    variable UCAddress_list [list]
    variable UnitType_list [list]
    variable Settings_list [list]
    variable UnitID_list [list]

    foreach claim_pmon_jamb_path $claim_pmon_jamb_path_list {
        set i [lsearch $claim_pmon_jamb_path_list $claim_pmon_jamb_path]

        _pmon_discover $i
        variable PMON_BAR
        variable PMON_JAMB
        variable PMON_INST
        variable PMON_UMON

        variable NumCntr_mon
        variable UnitCntrCtrlAdr_offset_mon
        variable CntrWidth_mon
        variable UnitCntrDataAdr_offset_mon
        variable UnitStatAdr_offset_mon
        variable UCAddress_mon
        variable UnitType_mon
        variable Settings_mon
        variable UnitID_mon

        lappend PMON_BAR_list $PMON_BAR
        lappend PMON_JAMB_list $PMON_JAMB
        lappend PMON_INST_list $PMON_INST
        lappend PMON_UMON_list $PMON_UMON

        lappend NumCntr_list $NumCntr_mon
        lappend UnitCntrCtrlAdr_offset_list $UnitCntrCtrlAdr_offset_mon
        lappend CntrWidth_list $CntrWidth_mon
        lappend UnitCntrDataAdr_offset_list $UnitCntrDataAdr_offset_mon
        lappend UnitStatAdr_offset_list $UnitStatAdr_offset_mon
        lappend UCAddress_list $UCAddress_mon
        lappend UnitType_list $UnitType_mon
        lappend Settings_list $Settings_mon
        lappend UnitID_list $UnitID_mon
    }

    variable num_pmon
    set num_pmon [llength $pmon_inst_list]
    set num_umon_total [_pmon_total_umon]


    if {$num_pmon < [llength $claim_pmon_jamb_path_list]} {
        puts "WARNING: number of discovered unit monitors ($num_pmon) is fewer than the number of PMON JTAGs ([llength $claim_pmon_jamb_path_list])"
        puts "Please ensure EXPORT_JTAG is set for each instance of PMON"
    } else {
        puts "PMON Discovery process complete discovered $num_pmon PMON Instances found with a total of $num_umon_total unit monitors"
        puts "PMON instances are indexed in order of JTAG path. To obtain PMON instance info please call pmon_print_info <pmon_index>"
    }

}



proc ::pmon_lib::_pmon_choose {{index 0} {umon -65} args} {

    variable claim_pmon_jamb_path
    variable PMON_JAMB
    variable PMON_JAMB_list
    set claim_pmon_jamb_path [lindex $PMON_JAMB_list $index]

    if {[llength $PMON_JAMB_list] == 0} {
        puts "PMON JTAG list empty run pmon_discover_all"
        return -1
    } elseif {$claim_pmon_jamb_path == ""} {
        puts "Index chosen is outside list of available PMON JTAGs"
        set max_index [expr [llength $PMON_JAMB_list] - 1 ]
        puts "Please choose an index between 0 and $max_index"
        return -1
    }

    set PMON_JAMB [lindex $PMON_JAMB_list $index]

    variable PMON_INST
    variable PMON_INST_list
    set PMON_INST [lindex $PMON_INST_list $index]

    variable PMON_BAR
    variable PMON_BAR_list
    set PMON_BAR [lindex $PMON_BAR_list $index]

    variable PMON_UMON
    variable PMON_UMON_list
    set PMON_UMON [lindex $PMON_UMON_list $index]



    if {$umon == -65} {
        puts "Please choose a unit monitor for PMON instance $index"
        puts "PMON instance $index has a total of $PMON_UMON monitors"
        return -1
    } elseif {$umon < 0} {
        puts "Negative indexing for unit monitors is not supported"
        return -1
    } elseif {$umon >= $PMON_UMON} {
        puts "Unit Monitor $umon not found, please choose a valid Unit Monitor index."
        puts "PMON instance $index has a total of $PMON_UMON monitor(s)"
        return -1
    }

    variable NumCntr
    variable NumCntr_list
    set NumCntr_mon [lindex $NumCntr_list $index]
    set NumCntr [lindex $NumCntr_mon $umon]

    variable UnitCntrCtrlAdr_offset
    variable UnitCntrCtrlAdr_offset_list
    set UnitCntrCtrlAdr_offset [lindex $UnitCntrCtrlAdr_offset_list $index]

    variable CntrWidth
    variable CntrWidth_list
    set CntrWidth [lindex $CntrWidth_list $index]

    variable UnitCntrDataAdr_offset
    variable UnitCntrDataAdr_offset_list
    set UnitCntrDataAdr_offset [lindex $UnitCntrDataAdr_offset_list $index]

    variable UnitStatAdr_offset
    variable UnitStatAdr_offset_list
    set UnitStatAdr_offset [lindex $UnitStatAdr_offset_list $index]

    variable UCAddress
    variable UCAddress_list
    set UCAddress [lindex $UCAddress_list $index]

    variable UnitType
    variable UnitType_list
    set UnitType [lindex $UnitType_list $index]

    variable Settings
    variable Settings_list
    set Settings [lindex $Settings_list $index]

    variable UnitID
    variable UnitID_list
    set UnitID [lindex $UnitID_list $index]

    return 1
}


proc ::pmon_lib::pmon_num_umon {{index 0}} {

    variable PMON_UMON
    set is_valid [_pmon_choose $index 0]
    if {$is_valid == -1} {
        return -1
    }
    return $PMON_UMON
}


proc ::pmon_lib::pmon_print_info {{index 0}} {

    variable PMON_JAMB
    variable PMON_INST
    variable PMON_BAR
    variable PMON_UMON
    variable NumCntr
    variable UnitCntrCtrlAdr_offset
    variable CntrWidth
    variable UnitCntrDataAdr_offset
    variable UnitStatAdr_offset
    variable UCAddress
    variable UnitType
    variable UnitID
    variable Settings


    set is_valid [_pmon_choose $index 0]

    if {$is_valid == -1} {
        return
    }
    puts "PMON $index"
    puts "Number of monitors : $PMON_UMON"
    puts "JAMB path: $PMON_JAMB"
    puts "PMON instance path: $PMON_INST"

    for {set umon 0} {$umon < $PMON_UMON} {incr umon} {
        set is_valid [_pmon_choose $index $umon]

        if {$is_valid == -1} {
            return
        }

        puts "Unit Monitor $umon"
        puts "   Number of counters: $NumCntr"
        puts "   Counter Width: $CntrWidth bits"
        puts "   Unit Type: $UnitType"
        puts "   Unit ID: $UnitID"
        if {$Settings >> 7}{
            puts "   Advanced Latency is enabled"
        }
    }
}

proc ::pmon_lib::pmon_freeze {{index 0} {umon -65} args} {


    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return
    }

    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable UnitID

    set pmon_uctrl_l_addr [expr {$UCAddress + $PMON_BAR}]
    set pmon_uctrl_l_addr [format 0x%x $pmon_uctrl_l_addr]
    set PMON_UCTRL_L [master_read_32 $claim_pmon_jamb_path $pmon_uctrl_l_addr 1]
    set PMON_UCTRL_L [format 0x%x $PMON_UCTRL_L]
    set Freeze [expr {$PMON_UCTRL_L & 0x1}]
    set Rst_Ctrl [expr {$PMON_UCTRL_L >> 8 & 0x1}]
    set Rst_Cntr [expr {$PMON_UCTRL_L >> 9 & 0x1}]

    set PMON_UCTRL_L [master_read_32 $claim_pmon_jamb_path $pmon_uctrl_l_addr 1]
    set PMON_UCTRL_L [expr {$PMON_UCTRL_L | 0x1}]

    master_write_32 $claim_pmon_jamb_path $pmon_uctrl_l_addr $PMON_UCTRL_L
    puts "Freeze PMON $index : Unit Monitor $umon (Unit ID: $UnitID)"
}



proc ::pmon_lib::pmon_unfreeze {{index 0} {umon -65} args} {

    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return
    }
    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable UnitID

    set pmon_uctrl_l_addr [expr {$UCAddress + $PMON_BAR}]
    set pmon_uctrl_l_addr [format 0x%x $pmon_uctrl_l_addr]
    set PMON_UCTRL_L [master_read_32 $claim_pmon_jamb_path $pmon_uctrl_l_addr 1]
    set PMON_UCTRL_L [format 0x%x $PMON_UCTRL_L]
    set Freeze [expr {$PMON_UCTRL_L & 0x1}]
    set Rst_Ctrl [expr {$PMON_UCTRL_L >> 8 & 0x1}]
    set Rst_Cntr [expr {$PMON_UCTRL_L >> 9 & 0x1}]

    set PMON_UCTRL_L [master_read_32 $claim_pmon_jamb_path $pmon_uctrl_l_addr 1]
    set PMON_UCTRL_L [expr {$PMON_UCTRL_L & 0xFFFFFFFE}]

    master_write_32 $claim_pmon_jamb_path $pmon_uctrl_l_addr $PMON_UCTRL_L
    puts "Unfreeze PMON $index : Unit Monitor $umon (Unit ID: $UnitID)"
}




proc ::pmon_lib::pmon_reset_counter_control {{index 0} {umon -65} args} {

    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return
    }
    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable UnitID

    set pmon_uctrl_l_addr [expr {$UCAddress + $PMON_BAR}]
    set pmon_uctrl_l_addr [format 0x%x $pmon_uctrl_l_addr]
    set PMON_UCTRL_L [master_read_32 $claim_pmon_jamb_path $pmon_uctrl_l_addr 1]
    set PMON_UCTRL_L [format 0x%x $PMON_UCTRL_L]
    set Freeze [expr {$PMON_UCTRL_L & 0x1}]
    set Rst_Ctrl [expr {$PMON_UCTRL_L >> 8 & 0x1}]
    set Rst_Cntr [expr {$PMON_UCTRL_L >> 9 & 0x1}]

    set PMON_UCTRL_L [master_read_32 $claim_pmon_jamb_path $pmon_uctrl_l_addr 1]
    set PMON_UCTRL_L [expr {$PMON_UCTRL_L | 0x100}]

    master_write_32 $claim_pmon_jamb_path $pmon_uctrl_l_addr $PMON_UCTRL_L
    puts "PMON $index : Unit Monitor $umon (Unit ID: $UnitID) counter controls cleared"
}



proc ::pmon_lib::pmon_reset_counter_data {{index 0} {umon -65} args} {

    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return
    }
    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable UnitID

    set pmon_uctrl_l_addr [expr {$UCAddress + $PMON_BAR}]
    set pmon_uctrl_l_addr [format 0x%x $pmon_uctrl_l_addr]
    set PMON_UCTRL_L [master_read_32 $claim_pmon_jamb_path $pmon_uctrl_l_addr 1]
    set PMON_UCTRL_L [format 0x%x $PMON_UCTRL_L]
    set Freeze [expr {$PMON_UCTRL_L & 0x1}]
    set Rst_Ctrl [expr {$PMON_UCTRL_L >> 8 & 0x1}]
    set Rst_Cntr [expr {$PMON_UCTRL_L >> 9 & 0x1}]

    set PMON_UCTRL_L [master_read_32 $claim_pmon_jamb_path $pmon_uctrl_l_addr 1]
    set PMON_UCTRL_L [expr {$PMON_UCTRL_L | 0x200}]

    master_write_32 $claim_pmon_jamb_path $pmon_uctrl_l_addr $PMON_UCTRL_L
    puts "PMON $index : Unit Monitor $umon (Unit ID: $UnitID) counter data cleared and internal state reset"
}


proc ::pmon_lib::pmon_print_status {{index 0} {umon -65} args} {

    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return
    }
    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable NumCntr
    variable UnitStatAdr_offset

    set NUM_COUNTERS $NumCntr
    set pmon_usts_l_addr [expr {$UCAddress +$PMON_BAR + $UnitStatAdr_offset}]
    set pmon_usts_l_addr [format 0x%x $pmon_usts_l_addr]
    puts "Unit Status register at addr $pmon_usts_l_addr"
    set PMON_USTS_L [master_read_32 $claim_pmon_jamb_path $pmon_usts_l_addr 1]
    for {set i 0} {$i < $NUM_COUNTERS} {incr i} {

        set Cntr_Ov_i [expr {$PMON_USTS_L >> $i & 0x1}]
        set Cntr_Ov_i [format %b $Cntr_Ov_i]

        puts "Counter $i overflow : $Cntr_Ov_i"
    }
}


proc ::pmon_lib::pmon_get_status {{index 0} {umon -65} args} {

    set counter_status [list]
    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return $counter_status
    }
    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable NumCntr
    variable UnitStatAdr_offset



    set NUM_COUNTERS $NumCntr
    set pmon_usts_l_addr [expr {$UCAddress +$PMON_BAR + $UnitStatAdr_offset}]
    set pmon_usts_l_addr [format 0x%x $pmon_usts_l_addr]
    set PMON_USTS_L [master_read_32 $claim_pmon_jamb_path $pmon_usts_l_addr 1]
    for {set i 0} {$i < $NUM_COUNTERS} {incr i} {

        set Cntr_Ov_i [expr {$PMON_USTS_L >> $i & 0x1}]
        set Cntr_Ov_i [format 0b%b $Cntr_Ov_i]

        lappend counter_status $Cntr_Ov_i
    }
    return $counter_status
}

proc ::pmon_lib::pmon_reset_status {{index 0} {umon -65} args} {

    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return
    }
    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable NumCntr
    variable UnitStatAdr_offset
    variable UnitID

    set NUM_COUNTERS $NumCntr
    set pmon_usts_l_addr [expr {$UCAddress +$PMON_BAR + $UnitStatAdr_offset}]
    set pmon_usts_l_addr [format 0x%x $pmon_usts_l_addr]
    set PMON_USTS_L 0x00FF
    master_write_32 $claim_pmon_jamb_path $pmon_usts_l_addr $PMON_USTS_L
    puts "PMON $index : Unit Monitor $umon (Unit ID: $UnitID) status cleared"
}


proc ::pmon_lib::pmon_print_counter_control {{index 0} {umon -65} args} {

    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return
    }
    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable NumCntr
    variable UnitCntrCtrlAdr_offset

    set NUM_COUNTERS $NumCntr
    set stride 0x8
    set hioffset 0x4
    set pmon_ucctl_l_0_addr [expr {$UCAddress + $PMON_BAR +$UnitCntrCtrlAdr_offset}]
    for {set i 0} {$i < $NUM_COUNTERS} {incr i} {
        set pmon_ucctl_l_i_addr [expr {$pmon_ucctl_l_0_addr + $i*$stride}]
        set pmon_ucctl_l_i_addr [format 0x%x $pmon_ucctl_l_i_addr]

        set PMON_UCCTL_L [master_read_32 $claim_pmon_jamb_path $pmon_ucctl_l_i_addr 1]

        set event_sel [expr {$PMON_UCCTL_L & 0xff}]
    	set umask [expr {($PMON_UCCTL_L >> 8) & 0xff}]
        set cntr_rst [expr {($PMON_UCCTL_L >> 17) & 0x1}]
        set edge [expr {($PMON_UCCTL_L >> 18) & 0x1}]
        set invert [expr {($PMON_UCCTL_L >> 23) & 0x1}]
        set thresh [expr {($PMON_UCCTL_L >> 24) & 0xff}]


        set event_sel [format 0x%x $event_sel]
    	set umask [format 0x%x $umask]
        set cntr_rst [format 0x%x $cntr_rst]
        set edge [format 0x%x $edge]
        set invert [format 0x%x $invert]
        set thresh [format 0x%x $thresh]

        puts "Counter control $i at addr $pmon_ucctl_l_i_addr UCCTL_L : $PMON_UCCTL_L"
        puts "event_sel : $event_sel"
        puts "umask : $umask"
        puts "cntr_rst : $cntr_rst"
        puts "edge : $edge"
        puts "invert : $invert"
        puts "thresh : $thresh"

        set pmon_ucctl_h_i_addr [expr {$pmon_ucctl_l_0_addr + $i*$stride + $hioffset}]
        set pmon_ucctl_h_i_addr [format 0x%x $pmon_ucctl_h_i_addr]

        set PMON_UCCTL_H [master_read_32 $claim_pmon_jamb_path $pmon_ucctl_h_i_addr 1]

        set max [expr {$PMON_UCCTL_H & 0x01}]
        set max [format 0x%x $max]

        puts "counter control $i at addr $pmon_ucctl_h_i_addr UCCTL_H : $PMON_UCCTL_H"
        puts "max : $max"

    }
}

proc ::pmon_lib::pmon_get_counter_control {{index 0} {umon -65} args} {

    set counter_control [list]
    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return $counter_control
    }
    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable NumCntr
    variable UnitCntrCtrlAdr_offset

    set NUM_COUNTERS $NumCntr
    set stride 0x8
    set hioffset 0x4
    set pmon_ucctl_l_0_addr [expr {$UCAddress + $PMON_BAR +$UnitCntrCtrlAdr_offset}]
    for {set i 0} {$i < $NUM_COUNTERS} {incr i} {
        set pmon_ucctl_l_i_addr [expr {$pmon_ucctl_l_0_addr + $i*$stride}]
        set pmon_ucctl_l_i_addr [format 0x%x $pmon_ucctl_l_i_addr]

        set PMON_UCCTL_L [master_read_32 $claim_pmon_jamb_path $pmon_ucctl_l_i_addr 1]

        set pmon_ucctl_h_i_addr [expr {$pmon_ucctl_l_0_addr + $i*$stride + $hioffset}]
        set pmon_ucctl_h_i_addr [format 0x%x $pmon_ucctl_h_i_addr]

        set PMON_UCCTL_H [master_read_32 $claim_pmon_jamb_path $pmon_ucctl_h_i_addr 1]

        set PMON_UCCTL [expr {$PMON_UCCTL_H << 32 | $PMON_UCCTL_L}]
        set PMON_UCCTL [format 0x%x $PMON_UCCTL]
        lappend counter_control $PMON_UCCTL
    }
    return $counter_control
}


proc ::pmon_lib::pmon_print_counter_data {{index 0} {umon -65} args} {

    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return
    }
    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable NumCntr
    variable UnitCntrDataAdr_offset

    set NUM_COUNTERS $NumCntr
    set stride 0x8
    set pmon_ucdata_l_0_addr [expr {$UCAddress + $PMON_BAR + $UnitCntrDataAdr_offset}]
    for {set i 0} {$i < $NUM_COUNTERS} {incr i} {
        set pmon_ucdata_l_i_addr [expr {$pmon_ucdata_l_0_addr + $i*$stride}]
        set pmon_ucdata_h_i_addr [expr {$pmon_ucdata_l_0_addr + $i*$stride + 0x4}]
        set pmon_ucdata_l_i_addr [format 0x%x $pmon_ucdata_l_i_addr]
        set pmon_ucdata_h_i_addr [format 0x%x $pmon_ucdata_h_i_addr]

        set PMON_UCDATA_L [master_read_32 $claim_pmon_jamb_path $pmon_ucdata_l_i_addr 1]
        set PMON_UCDATA_H [master_read_32 $claim_pmon_jamb_path $pmon_ucdata_h_i_addr 1]
        set PMON_UCDATA [expr {$PMON_UCDATA_H << 32 | $PMON_UCDATA_L}]
        set PMON_UCDATA [format 0x%x $PMON_UCDATA]

        puts "Counter $i at addr $pmon_ucdata_l_i_addr : $PMON_UCDATA"
    }

}

proc ::pmon_lib::_pmon_overdet {{status [list]} {pos [list]} args} {
    set out_str ""
    foreach counter $pos {
        if {[lindex $status $counter]} {
            set out_str "Overflow detected"
            return $out_str
        } else {
            set out_str ""
        }
    }
    return $out_str
}

# pmon_get_counter_data : Returns a list of the counter data register values
proc ::pmon_lib::pmon_get_counter_data {{index 0} {umon -65} args} {

    set counter_data [list]
    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return
    }
    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable NumCntr
    variable UnitCntrDataAdr_offset

    set NUM_COUNTERS $NumCntr
    set stride 0x8
    set pmon_ucdata_l_0_addr [expr {$UCAddress + $PMON_BAR + $UnitCntrDataAdr_offset}]
    for {set i 0} {$i < $NUM_COUNTERS} {incr i} {
        set pmon_ucdata_l_i_addr [expr {$pmon_ucdata_l_0_addr + $i*$stride}]
        set pmon_ucdata_h_i_addr [expr {$pmon_ucdata_l_0_addr + $i*$stride + 0x4}]
        set pmon_ucdata_l_i_addr [format 0x%x $pmon_ucdata_l_i_addr]
        set pmon_ucdata_h_i_addr [format 0x%x $pmon_ucdata_h_i_addr]

        set PMON_UCDATA_L [master_read_32 $claim_pmon_jamb_path $pmon_ucdata_l_i_addr 1]
        set PMON_UCDATA_H [master_read_32 $claim_pmon_jamb_path $pmon_ucdata_h_i_addr 1]
        set PMON_UCDATA [expr {$PMON_UCDATA_H << 32 | $PMON_UCDATA_L}]
        set PMON_UCDATA [format 0x%x $PMON_UCDATA]

        lappend counter_data $PMON_UCDATA
    }
    return $counter_data
}

proc ::pmon_lib::pmon_read {{index 0} {umon -65} args} {

    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return
    }

    set counter_control [pmon_get_counter_control $index $umon]
    variable pmon_configs
    puts ""
    set config_list [dict keys $pmon_configs]
    if {$config_list == [list]} {
        puts "Please ensure pmon configurations have been loaded by calling pmon_define_configs"
        puts "Please restart and reload the library after adding or removing configurations"
        return
    }
    set match_config ""
    foreach config $config_list {
        set config_cctl [_pmon_config2reg $config]
        if {$config_cctl == $counter_control} {
            set match_config $config
            break
        }
    }

    variable UnitID

    if {$match_config == ""} {
        puts "PMON $index"
        puts "Monitor $umon (Unit ID: $UnitID) unknown configuration detected"
    } elseif {[dict exists $pmon_configs $match_config name]} {
        set config_name [dict get $pmon_configs $match_config name]
        puts "PMON $index"
        puts "Monitor $umon (Unit ID: $UnitID) Configuration detected: $config_name"
    } else {
        puts "Configuration recognized but unnamed"
        puts "PMON $index"
        puts "Monitor $umon (Unit ID: $UnitID) Configuration detected: $match_config"
    }

    variable NumCntr

    set counter_data [pmon_get_counter_data $index $umon]
    for {set i 0} {$i < $NumCntr} {incr i} {
        set PMON_UCDATA_${i} [lindex $counter_data $i]
    }

    set counter_status [pmon_get_status $index $umon]

    switch $match_config {
        empty {
            set total_data 0
            for {set i 0} {$i < $NumCntr} {incr i} {
                set PMON_UCDATA_${i} [lindex $counter_data $i]
                set total_data [expr {$total_data + [lindex $counter_data $i]}]
            }

            set counter_status [pmon_get_status $index $umon]

            if {$total_data} {
                puts "Counter configuration cleared with counter data remaining"
                puts "Please collect data before clearing counter control"
                puts "Counter Data"
                for {set i 0} {$i < $NumCntr} {incr i} {
                    puts "Counter $i : [lindex $counter_data $i] [_pmon_overdet $counter_status $i]"
                }

            } else {
                puts "Counter control not set and no counter data found."
                puts "Please set counter control and run traffic before reading data"
            }
        }
        basic_eff {
            if {$PMON_UCDATA_1 == 0} {
                puts "No Read traffic detected"
                set READ_BAND    0
            } else {
                set READ_BAND    [expr {double($PMON_UCDATA_0)/$PMON_UCDATA_1}]
            }

            if {$PMON_UCDATA_3 == 0} {
                puts "No Write traffic detected"
                set WRITE_BAND    0
            } else {
                set WRITE_BAND   [expr {double($PMON_UCDATA_2)/$PMON_UCDATA_3}]
            }

            if {$PMON_UCDATA_5 == 0} {
                puts "No Traffic detected"
                set AVG_DATA    0
            } else {
                set AVG_DATA [expr {double($PMON_UCDATA_0+$PMON_UCDATA_2)/$PMON_UCDATA_5}]
            }

            set READ_BAND    [expr {100*$READ_BAND}]
            set WRITE_BAND   [expr {100*$WRITE_BAND}]

            set READ_BAND    [format "%.1f" $READ_BAND]
            set WRITE_BAND   [format "%.1f" $WRITE_BAND]
            set AVG_DATA     [format "%.3f" $AVG_DATA]

            puts "Read Efficiency is $READ_BAND % [_pmon_overdet $counter_status {0 1}]"
            puts "Write Efficiency is $WRITE_BAND % [_pmon_overdet $counter_status {2 3}]"
            puts "Average number of data transactions per cycle is $AVG_DATA [_pmon_overdet $counter_status {0 2 5}]"
        }
        ch_eff {
            if {$PMON_UCDATA_1 == 0} {
                puts "No AR subchannel traffic detected"
                set AR_BAND    0
            } else {
                set AR_BAND [expr {double($PMON_UCDATA_0)/$PMON_UCDATA_1}]
            }

            if {$PMON_UCDATA_3 == 0} {
                puts "No R subchannel traffic detected"
                set R_BAND    0
            } else {
                set R_BAND   [expr {double($PMON_UCDATA_2)/$PMON_UCDATA_3}]
            }

            if {$PMON_UCDATA_5 == 0} {
                puts "No AW subchannel traffic detected"
                set AW_BAND    0
            } else {
                set AW_BAND [expr {double($PMON_UCDATA_4)/$PMON_UCDATA_5}]
            }

            if {$PMON_UCDATA_7 == 0} {
                puts "No W subchannel traffic detected"
                set W_BAND    0
            } else {
                set W_BAND  [expr {double($PMON_UCDATA_6)/$PMON_UCDATA_7}]
            }

            set AR_BAND [expr {100*$AR_BAND}]
            set R_BAND  [expr {100*$R_BAND}]
            set AW_BAND [expr {100*$AW_BAND}]
            set W_BAND  [expr {100*$W_BAND}]

            set AR_BAND [format "%.1f" $AR_BAND]
            set R_BAND  [format "%.1f" $R_BAND]
            set AW_BAND [format "%.1f" $AW_BAND]
            set W_BAND  [format "%.1f" $W_BAND]


            puts "Efficiency of AR subchannel is $AR_BAND % [_pmon_overdet $counter_status {0 1}]"
            puts "Efficiency of R subchannel is  $R_BAND  % [_pmon_overdet $counter_status {2 3}]"
            puts "Efficiency of AW subchannel is $AW_BAND % [_pmon_overdet $counter_status {4 5}]"
            puts "Efficiency of W subchannel is  $W_BAND  % [_pmon_overdet $counter_status {6 7}]"
        }
        ch_bp {
            if {$PMON_UCDATA_1 == 0} {
               set AR_BCK_BAND 0
               puts "No AR subchannel traffic detected"
            } else {
               set AR_BCK_BAND    [expr {double($PMON_UCDATA_0)/$PMON_UCDATA_1}]
            }
            if {$PMON_UCDATA_3 == 0} {
               set R_BCK_BAND 0
               puts "No R subchannel traffic detected"
            } else {
               set R_BCK_BAND    [expr {double($PMON_UCDATA_2)/$PMON_UCDATA_3}]
            }
            if {$PMON_UCDATA_5 == 0} {
               set AW_BCK_BAND 0
               puts "No AW subchannel traffic detected"
            } else {
               set AW_BCK_BAND    [expr {double($PMON_UCDATA_4)/$PMON_UCDATA_5}]
            }
            if {$PMON_UCDATA_7 == 0} {
               set W_BCK_BAND 0
               puts "No W subchannel traffic detected"
            } else {
               set W_BCK_BAND    [expr {double($PMON_UCDATA_6)/$PMON_UCDATA_7}]
            }

            set AR_BCK_BAND [expr {100*$AR_BCK_BAND}]
            set R_BCK_BAND  [expr {100*$R_BCK_BAND}]
            set AW_BCK_BAND [expr {100*$AW_BCK_BAND}]
            set W_BCK_BAND  [expr {100*$W_BCK_BAND}]

            set AR_BCK_BAND [format "%.1f" $AR_BCK_BAND]
            set R_BCK_BAND  [format "%.1f" $R_BCK_BAND]
            set AW_BCK_BAND [format "%.1f" $AW_BCK_BAND]
            set W_BCK_BAND  [format "%.1f" $W_BCK_BAND]

            puts "AR subchannel backpressure is $AR_BCK_BAND % of cycles [_pmon_overdet $counter_status {0 1}]"
            puts "R  subchannel backpressure is $R_BCK_BAND % of cycles [_pmon_overdet $counter_status {2 3}]"
            puts "AW subchannel backpressure is $AW_BCK_BAND % of cycles [_pmon_overdet $counter_status {4 5}]"
            puts "W  subchannel backpressure is $W_BCK_BAND % of cycles [_pmon_overdet $counter_status {6 7}]"
        }
        basic_rw {
            if {$PMON_UCDATA_1 == 0} {
                puts "No Read traffic detected"
                set READ_BAND    0
            } else {
                set READ_BAND    [expr {double($PMON_UCDATA_0)/$PMON_UCDATA_1}]
            }

            if {$PMON_UCDATA_3 == 0} {
                puts "No Write traffic detected"
                set WRITE_BAND    0
            } else {
                set WRITE_BAND   [expr {double($PMON_UCDATA_2)/$PMON_UCDATA_3}]
            }

            set READ_BAND    [expr {100*$READ_BAND}]
            set WRITE_BAND   [expr {100*$WRITE_BAND}]

            set READ_BAND    [format "%.1f" $READ_BAND]
            set WRITE_BAND   [format "%.1f" $WRITE_BAND]

            puts "Read Efficiency is  $READ_BAND % [_pmon_overdet $counter_status {0 1}]"
            puts "Write Efficiency is $WRITE_BAND % [_pmon_overdet $counter_status {2 3}]"

            if {$PMON_UCDATA_4 > 0} {
                set AVG_RD_LAT [expr {double($PMON_UCDATA_5)/$PMON_UCDATA_4}]
                set AVG_RD_LAT [format "%.1f" $AVG_RD_LAT]
                puts "Average Read Latency is  $AVG_RD_LAT cycles [_pmon_overdet $counter_status {4 5}]"
            } else {
                puts "Cannot calculate average read latency"
                set AVG_RD_LAT 0
            }

            if {$PMON_UCDATA_6 > 0} {
                set AVG_WR_LAT [expr {double($PMON_UCDATA_7)/$PMON_UCDATA_6}]
                set AVG_WR_LAT [format "%.1f" $AVG_WR_LAT]
                puts "Average Write Latency is  $AVG_WR_LAT cycles [_pmon_overdet $counter_status {6 7}]"
            } else {
                puts "Cannot calculate average write latency"
                set AVG_WR_LAT 0
            }
        }
        wo {
            if {$PMON_UCDATA_2 == 0} {
                puts "No AW traffic detected"
                set AW_BAND    0
            } else {
                set AW_BAND [expr {double($PMON_UCDATA_5)/$PMON_UCDATA_2}]
            }

            if {$PMON_UCDATA_1 == 0} {
                puts "No W traffic detected"
                set W_BAND    0
            } else {
                set W_BAND  [expr {double($PMON_UCDATA_4)/$PMON_UCDATA_1}]
            }

            if {$PMON_UCDATA_0 == 0} {
                puts "No B traffic detected"
                set B_BAND    0
            } else {
                set B_BAND  [expr {double($PMON_UCDATA_7)/$PMON_UCDATA_0}]
            }

            set AW_BAND [expr {100*$AW_BAND}]
            set W_BAND  [expr {100*$W_BAND}]
            set B_BAND  [expr {100*$B_BAND}]

            set AW_BAND [format "%.1f" $AW_BAND]
            set W_BAND  [format "%.1f" $W_BAND]
            set B_BAND  [format "%.1f" $B_BAND]

            puts "AW subchannel transactions [format "%d" $PMON_UCDATA_5] [_pmon_overdet $counter_status {5}]"
            puts "W  subchannel transactions [format "%d" $PMON_UCDATA_4] [_pmon_overdet $counter_status {4}]"
            puts "B  subchannel transactions [format "%d" $PMON_UCDATA_7] [_pmon_overdet $counter_status {7}]"

            puts "Efficiency of AW subchannel is $AW_BAND % [_pmon_overdet $counter_status {2 5}]"
            puts "Efficiency of W subchannel is  $W_BAND  % [_pmon_overdet $counter_status {1 4}]"
            puts "Efficiency of B subchannel is  $B_BAND  % [_pmon_overdet $counter_status {0 7}]"

            puts "Expected W subchannel transactions [format "%d" $PMON_UCDATA_3] [_pmon_overdet $counter_status {3}]"

            if {$PMON_UCDATA_5 == 0} {
                puts "Can not calculate average write burst length or write latency due to lacking traffic"
                set AVG_BURST    0
                set AVG_WR_LAT   0
            } else {
                set AVG_BURST [expr {double($PMON_UCDATA_3)/$PMON_UCDATA_5}]
                set AVG_BURST [format "%.2f" $AVG_BURST]
                puts "Average Write Burst length $AVG_BURST [_pmon_overdet $counter_status {3 5}]"
                set AVG_WR_LAT [expr {double($PMON_UCDATA_6)/$PMON_UCDATA_5}]
                set AVG_WR_LAT [format "%.1f" $AVG_WR_LAT]
                puts "Average Write Latency is  $AVG_WR_LAT cycles [_pmon_overdet $counter_status {5 6}]"
            }
        }
        ro {
            if {$PMON_UCDATA_0 == 0} {
                puts "No AR traffic detected"
                set AR_BAND    0
                set AR_BCK     0
            } else {
                set AR_BAND [expr {double($PMON_UCDATA_2)/$PMON_UCDATA_0}]
                set AR_BCK  [expr {double($PMON_UCDATA_4)/$PMON_UCDATA_0}]
            }

            if {$PMON_UCDATA_1 == 0} {
                puts "No R traffic detected"
                set R_BAND    0
                set R_BCK     0
            } else {
                set R_BAND [expr {double($PMON_UCDATA_3)/$PMON_UCDATA_1}]
                set R_BCK  [expr {double($PMON_UCDATA_5)/$PMON_UCDATA_1}]
            }

            set AR_BAND [expr {100*$AR_BAND}]
            set R_BAND  [expr {100*$R_BAND}]
            set AR_BCK  [expr {100*$AR_BCK}]
            set R_BCK   [expr {100*$R_BCK}]


            set AR_BAND [format "%.1f" $AR_BAND]
            set R_BAND  [format "%.1f" $R_BAND]
            set AR_BCK  [format "%.1f" $AR_BCK]
            set R_BCK   [format "%.1f" $R_BCK]

            puts "AR subchannel transactions [format "%d" $PMON_UCDATA_2] [_pmon_overdet $counter_status {2}]"
            puts "R  subchannel transactions [format "%d" $PMON_UCDATA_3] [_pmon_overdet $counter_status {3}]"

            puts "Efficiency of AR subchannel is $AR_BAND % [_pmon_overdet $counter_status {0 2}]"
            puts "Efficiency of R subchannel is  $R_BAND % [_pmon_overdet $counter_status {1 3}]"

            puts "AR subchannel backpressure is $AR_BCK % of cycles [_pmon_overdet $counter_status {0 4}]"
            puts "R  subchannel backpressure is $R_BCK % of cycles [_pmon_overdet $counter_status {1 5}]"

            puts "Expected R subchannel transactions [format "%d" $PMON_UCDATA_6] [_pmon_overdet $counter_status {6}]"

            if {$PMON_UCDATA_2 == 0} {
                puts "Can not calculate average read burst length or read latency due to lacking traffic"
                set AVG_BURST    0
                set AVG_RD_LAT   0
            } else {
                set AVG_BURST [expr {double($PMON_UCDATA_3)/$PMON_UCDATA_2}]
                set AVG_BURST [format "%.2f" $AVG_BURST]
                puts "Average Read Burst length $AVG_BURST [_pmon_overdet $counter_status {2 3}]"
                set AVG_RD_LAT [expr {double($PMON_UCDATA_7)/$PMON_UCDATA_2}]
                set AVG_RD_LAT [format "%.1f" $AVG_RD_LAT]
                puts "Average Read Latency is  $AVG_RD_LAT cycles [_pmon_overdet $counter_status {2 7}]"
            }
        }
        diag {
            puts "AR subchannel transactions [format "%d" $PMON_UCDATA_0] [_pmon_overdet $counter_status {0}]"
            puts "R  subchannel transactions [format "%d" $PMON_UCDATA_1] [_pmon_overdet $counter_status {1}]"
            puts "AW subchannel transactions [format "%d" $PMON_UCDATA_2] [_pmon_overdet $counter_status {2}]"
            puts "W  subchannel transactions [format "%d" $PMON_UCDATA_3] [_pmon_overdet $counter_status {3}]"
            puts "B  subchannel transactions [format "%d" $PMON_UCDATA_4] [_pmon_overdet $counter_status {4}]"
            puts "Expected R subchannel transactions [format "%d" $PMON_UCDATA_5] [_pmon_overdet $counter_status {5}]"
            puts "Expected W subchannel transactions [format "%d" $PMON_UCDATA_6] [_pmon_overdet $counter_status {6}]"
            puts "Total traffic duration [format "%d" $PMON_UCDATA_7] cycles [_pmon_overdet $counter_status {7}]"
        }
        primary {
            if {$PMON_UCDATA_0 == 0} {
                puts "No AR traffic detected"
                set AR_BAND    0
            } else {
                set AR_BAND [expr {double($PMON_UCDATA_3)/$PMON_UCDATA_0}]
            }

            if {$PMON_UCDATA_1 == 0} {
                puts "No AW traffic detected"
                set AW_BAND    0
            } else {
                set AW_BAND [expr {double($PMON_UCDATA_4)/$PMON_UCDATA_1}]
            }

            if {$PMON_UCDATA_2 == 0} {
                puts "No W traffic detected"
                set W_BAND    0
            } else {
                set W_BAND [expr {double($PMON_UCDATA_5)/$PMON_UCDATA_2}]
            }

            set AR_BAND [expr {100*$AR_BAND}]
            set AW_BAND [expr {100*$AW_BAND}]
            set W_BAND  [expr {100*$W_BAND}]

            set AR_BAND [format "%.1f" $AR_BAND]
            set AW_BAND [format "%.1f" $AW_BAND]
            set W_BAND  [format "%.1f" $W_BAND]

            puts "AR subchannel transactions [format "%d" $PMON_UCDATA_3] [_pmon_overdet $counter_status {3}]"
            puts "AW subchannel transactions [format "%d" $PMON_UCDATA_4] [_pmon_overdet $counter_status {4}]"
            puts "W  subchannel transactions [format "%d" $PMON_UCDATA_5] [_pmon_overdet $counter_status {5}]"

            puts "Efficiency of AR subchannel is $AR_BAND % [_pmon_overdet $counter_status {0 3}]"
            puts "Efficiency of AW subchannel is $AW_BAND % [_pmon_overdet $counter_status {1 4}]"
            puts "Efficiency of W  subchannel is $W_BAND % [_pmon_overdet $counter_status {2 5}]"

            if {$PMON_UCDATA_3 == 0} {
                puts "Can not calculate average read latency due to lacking traffic"
                set AVG_RD_LAT   0
            } else {
                set AVG_RD_LAT [expr {double($PMON_UCDATA_6)/$PMON_UCDATA_3}]
                set AVG_RD_LAT [format "%.1f" $AVG_RD_LAT]
                puts "Average Read Latency is $AVG_RD_LAT cycles [_pmon_overdet $counter_status {3 6}]"
            }

            if {$PMON_UCDATA_4 == 0} {
                puts "Can not calculate average write burst length or write latency due to lacking traffic"
                set AVG_BURST    0
                set AVG_WR_LAT   0
            } else {
                set AVG_BURST [expr {double($PMON_UCDATA_5)/$PMON_UCDATA_4}]
                set AVG_BURST [format "%.2f" $AVG_BURST]
                puts "Average Write Burst length $AVG_BURST [_pmon_overdet $counter_status {4 5}]"
                set AVG_WR_LAT [expr {double($PMON_UCDATA_7)/$PMON_UCDATA_4}]
                set AVG_WR_LAT [format "%.1f" $AVG_WR_LAT]
                puts "Average Write Latency is $AVG_WR_LAT cycles [_pmon_overdet $counter_status {4 7}]"
            }
        }
        secondary {
            if {$PMON_UCDATA_0 == 0} {
                puts "No R traffic detected"
                set R_BAND    0
                set R_BCK     0
            } else {
                set R_BAND [expr {double($PMON_UCDATA_2)/$PMON_UCDATA_0}]
                set R_BCK  [expr {double($PMON_UCDATA_4)/$PMON_UCDATA_0}]
            }

            if {$PMON_UCDATA_1 == 0} {
                puts "No B traffic detected"
                set B_BAND    0
                set B_BCK     0
            } else {
                set B_BAND [expr {double($PMON_UCDATA_3)/$PMON_UCDATA_1}]
                set B_BCK  [expr {double($PMON_UCDATA_5)/$PMON_UCDATA_1}]
            }

            set R_BAND [expr {100*$R_BAND}]
            set R_BCK  [expr {100*$R_BCK}]
            set B_BAND [expr {100*$B_BAND}]
            set B_BCK  [expr {100*$B_BCK}]

            set R_BAND [format "%.1f" $R_BAND]
            set R_BCK  [format "%.1f" $R_BCK]
            set B_BAND [format "%.1f" $B_BAND]
            set B_BCK  [format "%.1f" $B_BCK]

            puts "R subchannel transactions [format "%d" $PMON_UCDATA_2] [_pmon_overdet $counter_status {2}]"
            puts "B subchannel transactions [format "%d" $PMON_UCDATA_3] [_pmon_overdet $counter_status {3}]"

            puts "Efficiency of R subchannel is $R_BAND % [_pmon_overdet $counter_status {0 2}]"
            puts "Efficiency of B subchannel is $B_BAND % [_pmon_overdet $counter_status {1 3}]"

            puts "R subchannel backpressure is $R_BCK % of cycles [_pmon_overdet $counter_status {0 4}]"
            puts "B subchannel backpressure is $B_BCK % of cycles [_pmon_overdet $counter_status {1 5}]"

            puts "Expected R subchannel transactions [format "%d" $PMON_UCDATA_6] [_pmon_overdet $counter_status {6}]"
            puts "Expected B subchannel transactions [format "%d" $PMON_UCDATA_7] [_pmon_overdet $counter_status {7}]"
        }
        basic_lat {
            variable Settings
            set ADV_LAT [expr {$Settings >> 7}]
            if {$ADV_LAT} {
                puts "Maximum read latency observed for traffic run is [format "%d" $PMON_UCDATA_0] [_pmon_overdet $counter_status {0}] cycles"
            } else {
                puts "Maximum number of outstanding reads for traffic run is [format "%d" $PMON_UCDATA_0] [_pmon_overdet $counter_status {0}]"
            }
            if {$PMON_UCDATA_4 > 0} {
                set AVG_RD_LAT [expr {double($PMON_UCDATA_5)/$PMON_UCDATA_4}]
                set AVG_RD_LAT [format "%.1f" $AVG_RD_LAT]
                puts "Average Read Latency is  $AVG_RD_LAT cycles [_pmon_overdet $counter_status {4 5}]"
                set AVG_RD_BURST [expr {double($PMON_UCDATA_1)/$PMON_UCDATA_4}]
                set AVG_RD_BURST [format "%.2f" $AVG_RD_BURST]
                puts "Average Read Burst length $AVG_RD_BURST [_pmon_overdet $counter_status {1 4}]"
            } else {
                puts "Cannot calculate average read latency or read burst length due to lacking traffic"
                set AVG_RD_BURST 0
                set AVG_RD_LAT   0
            }
            if {$ADV_LAT} {
                puts "Maximum write latency observed for traffic run is [format "%d" $PMON_UCDATA_2] [_pmon_overdet $counter_status {2}] cycles"
            } else {
                puts "Maximum number of outstanding write responses for traffic run is [format "%d" $PMON_UCDATA_2] [_pmon_overdet $counter_status {2}]"
            }
            if {$PMON_UCDATA_6 > 0} {
                set AVG_WR_LAT [expr {double($PMON_UCDATA_7)/$PMON_UCDATA_6}]
                set AVG_WR_LAT [format "%.1f" $AVG_WR_LAT]
                puts "Average Write Latency is  $AVG_WR_LAT cycles [_pmon_overdet $counter_status {6 7}]"
                set AVG_WR_BURST [expr {double($PMON_UCDATA_3)/$PMON_UCDATA_6}]
                set AVG_WR_BURST [format "%.2f" $AVG_WR_BURST]
                puts "Average Write Burst length $AVG_WR_BURST [_pmon_overdet $counter_status {3 6}]"
            } else {
                puts "Can not calculate average write latency or write burst length due to lacking traffic"
                set AVG_WR_BURST  0
                set AVG_WR_LAT    0
            }
        }

        full_lat {
            variable Settings
            set ADV_LAT [expr {$Settings >> 7}]
            set incorrect_min_read_lat ""
            if {$PMON_UCDATA_1 == 0} {
                set incorrect_min_read_lat "Measured minimum latency is incorrect. You must call the function pmon_set before pmon_reset_counter_data"
            } 
            set incorrect_min_write_lat ""
            if {$PMON_UCDATA_3 == 0} {
                set incorrect_min_write_lat "Measured minimum latency is incorrect. You must call the function pmon_set before pmon_reset_counter_data"
            } 
            if {$ADV_LAT} {
                puts "Maximum read latency observed for traffic run is [format "%d" $PMON_UCDATA_0] [_pmon_overdet $counter_status {0}] cycles"
                puts "Minimum read latency observed for traffic run is [format "%d" $PMON_UCDATA_1] [_pmon_overdet $counter_status {0}] cycles. $incorrect_min_read_lat"
            } else {
                puts "Maximum number of outstanding reads for traffic run is [format "%d" $PMON_UCDATA_0] [_pmon_overdet $counter_status {0}]"
            }
            if {$PMON_UCDATA_4 > 0} {
                set AVG_RD_LAT [expr {double($PMON_UCDATA_5)/$PMON_UCDATA_4}]
                set AVG_RD_LAT [format "%.1f" $AVG_RD_LAT]
                puts "Average Read Latency is  $AVG_RD_LAT cycles [_pmon_overdet $counter_status {4 5}]"
            } else {
                puts "Cannot calculate average read latency due to lacking traffic"
                set AVG_RD_BURST 0
                set AVG_RD_LAT   0
            }
            if {$ADV_LAT} {
                puts "Maximum write latency observed for traffic run is [format "%d" $PMON_UCDATA_2] [_pmon_overdet $counter_status {2}] cycles"
                puts "Minimum write latency observed for traffic run is [format "%d" $PMON_UCDATA_3] [_pmon_overdet $counter_status {2}] cycles. $incorrect_min_write_lat"
            } else {
                puts "Maximum number of outstanding write responses for traffic run is [format "%d" $PMON_UCDATA_2] [_pmon_overdet $counter_status {2}]"
            }
            if {$PMON_UCDATA_6 > 0} {
                set AVG_WR_LAT [expr {double($PMON_UCDATA_7)/$PMON_UCDATA_6}]
                set AVG_WR_LAT [format "%.1f" $AVG_WR_LAT]
                puts "Average Write Latency is  $AVG_WR_LAT cycles [_pmon_overdet $counter_status {6 7}]"
            } else {
                puts "Can not calculate average write latency due to lacking traffic"
                set AVG_WR_BURST  0
                set AVG_WR_LAT    0
            }
        }

        default {
            puts "No counter data interpretation defined in pmon_read for this configuration"
            set total_data 0
            for {set i 0} {$i < $NumCntr} {incr i} {
                set total_data [expr {$total_data + [lindex $counter_data $i]}]
            }

            set counter_status [pmon_get_status $index $umon]

            if {$total_data} {
                puts "Counter Data"
                for {set i 0} {$i < $NumCntr} {incr i} {
                    puts "Counter $i : [lindex $counter_data $i] [_pmon_overdet $counter_status $i]"
                }

            } else {
                puts "No counter data found."
                puts "Please set counter control and run traffic before reading data"
            }
        }

    }
}


proc ::pmon_lib::pmon_num_ins {} {
    variable PMON_JAMB_list
    set num_mon [llength $PMON_JAMB_list]
    return $num_mon
}


proc ::pmon_lib::pmon_read_all {} {

    variable PMON_JAMB_list
    if {[llength $PMON_JAMB_list] == 0} {
        puts "PMON JTAG list empty run pmon_discover_all"
    }
    for {set index 0} {$index < [pmon_num_ins]} {incr index} {
        for {set umon 0} {$umon < [pmon_num_umon $index]} {incr umon} {
            pmon_read $index $umon
        }
    }
}

proc ::pmon_lib::pmon_reset_counter_data_all {} {

    variable PMON_JAMB_list
    if {[llength $PMON_JAMB_list] == 0} {
        puts "PMON JTAG list empty run pmon_discover_all"
    }
    for {set index 0} {$index < [pmon_num_ins]} {incr index} {
        for {set umon 0} {$umon < [pmon_num_umon $index]} {incr umon} {
            pmon_reset_counter_data $index $umon
        }
    }
}

proc ::pmon_lib::pmon_reset_counter_control_all {} {

    variable PMON_JAMB_list
    if {[llength $PMON_JAMB_list] == 0} {
        puts "PMON JTAG list empty run pmon_discover_all"
    }
    for {set index 0} {$index < [pmon_num_ins]} {incr index} {
        for {set umon 0} {$umon < [pmon_num_umon $index]} {incr umon} {
            pmon_reset_counter_control $index $umon
        }
    }
}

proc ::pmon_lib::pmon_reset_status_all {} {

    variable PMON_JAMB_list
    if {[llength $PMON_JAMB_list] == 0} {
        puts "PMON JTAG list empty run pmon_discover_all"
    }
    for {set index 0} {$index < [pmon_num_ins]} {incr index} {
        for {set umon 0} {$umon < [pmon_num_umon $index]} {incr umon} {
            pmon_reset_status $index $umon
        }
    }
}


proc ::pmon_lib::pmon_check_viol {{index 0} {umon -65} args} {

    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return
    }
    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable NumCntr
    variable UnitCntrCtrlAdr_offset
    variable Settings
    set ADV_LAT [expr {$Settings >> 7}]

    set PMON_EVENT_COUNTER_IDLE           0x00
    set PMON_EVENT_CLOCK_TICKS            0x01
    set PMON_EVENT_CLOCK_TICKS_AR2AR      0x02
    set PMON_EVENT_CLOCK_TICKS_R2R        0x03
    set PMON_EVENT_CLOCK_TICKS_AW2AW      0x04
    set PMON_EVENT_CLOCK_TICKS_W2W        0x05
    set PMON_EVENT_CLOCK_TICKS_B2B        0x06
    set PMON_EVENT_CLOCK_TICKS_AR2R       0x07
    set PMON_EVENT_CLOCK_TICKS_AWW2B      0x08
    set PMON_EVENT_CLOCK_TICKS_ARAWW2RB   0x09

    set PMON_EVENT_READ_OCCUPANCY         0x10
    set PMON_EVENT_READ_LENGTH            0x11
    set PMON_EVENT_READ_BYTES             0x12
    set PMON_EVENT_TOTAL_READ_LATENCY     0x13

    set PMON_EVENT_WRITE_OCCUPANCY        0x18
    set PMON_EVENT_RESP_OCCUPANCY         0x19
    set PMON_EVENT_WRITE_LENGTH           0x1a
    set PMON_EVENT_WRITE_BYTES            0x1b
    set PMON_EVENT_TOTAL_WRITE_LATENCY    0x1c

    set PMON_EVENT_CLOCK_TICKS_OVFL       0xf0
    set PMON_EVENT_PMON_LAT_DEBUG         0xff

    puts "Checking traffic violations for PMON $index : Unit Monitor $umon"
    pmon_freeze $index $umon
    puts "Collecting monitor configuration and state..."
    after 1000
    set counter_control_initial [pmon_get_counter_control $index $umon]
    set counter_data_initial [pmon_get_counter_data $index $umon]
    pmon_reset_counter_control $index $umon

    set stride 0x8
    set hioffset 0x4

    set pmon_ucctl_l_0_addr [expr {$UCAddress + $UnitCntrCtrlAdr_offset + $PMON_BAR}]
    set pmon_ucctl_l_0_addr [format 0x%x $pmon_ucctl_l_0_addr]
    set cntr_rst 0x0
    set edge 0x0
    set invert 0x0
    set thresh 0x0
    set counter_control [list]

    for {set i 0x0} {$i < $NumCntr} {incr i} {
        set initial_event [expr { [lindex $counter_control_initial $i] & 0xFF}]

        if {$initial_event <= $PMON_EVENT_CLOCK_TICKS_ARAWW2RB && $initial_event >= $PMON_EVENT_CLOCK_TICKS_AR2AR} {
            set event_sel [expr $PMON_EVENT_CLOCK_TICKS_OVFL]
            set subevent [expr $initial_event - 0x02]
            set umask [expr {1 << $subevent}]
        } elseif {$initial_event == $PMON_EVENT_TOTAL_READ_LATENCY} {
            set event_sel [expr $PMON_EVENT_PMON_LAT_DEBUG]
            set umask [expr {1 << 0x4}]
        } elseif {$initial_event == $PMON_EVENT_TOTAL_WRITE_LATENCY} {
            set event_sel [expr $PMON_EVENT_PMON_LAT_DEBUG]
            set umask [expr {1 << 0x5}]
        } else {
            set event_sel [expr $PMON_EVENT_COUNTER_IDLE]
            set umask 0x00
        }

        set UCCTL_L_i [expr {$thresh << 24 | $invert << 23 | $edge << 18 | $cntr_rst << 17 | $umask << 8 | $event_sel}]
        set UCCTL_L_i [format 0x%x $UCCTL_L_i]

        set pmon_ucctl_l_i_addr [expr {$pmon_ucctl_l_0_addr + $i*$stride}]
        set pmon_ucctl_l_i_addr [format 0x%x $pmon_ucctl_l_i_addr]

        master_write_32 $claim_pmon_jamb_path $pmon_ucctl_l_i_addr $UCCTL_L_i

    }

    set counter_control [pmon_get_counter_control $index $umon]

    set empty_controls 0x0
    for {set i 0} {$i < $NumCntr} {incr i} {
        if {[lindex $counter_control_initial $i] == 0x0} {
            incr empty_controls
        }
    }

    if {$empty_controls == $NumCntr} {
        puts "Violations would have no impact on data collected, counter controls cleared and checks skipped"
        pmon_unfreeze $index $umon
        return
    }

    puts "Traffic violation checks set"
    pmon_unfreeze $index $umon
    puts "Collecting data..."
    after 1000
    pmon_freeze $index $umon

    set counter_data [pmon_get_counter_data $index $umon]
    set no_viol 0x0

    for {set i 0} {$i < $NumCntr} {incr i} {
        set event [expr {[lindex $counter_control $i] & 0xFF}]
        set umask [expr {[lindex $counter_control $i] & 0xFF00}]
        set umask [expr {$umask >> 8}]
        if {[lindex $counter_data $i] != [lindex $counter_data_initial $i]} {
            if {$event == $PMON_EVENT_CLOCK_TICKS_OVFL} {

                set subchannel_gap_subevents [expr {1 << 0x4}]

                if {$umask <= $subchannel_gap_subevents} {
                    if {$umask == 0b1} {
                        set subchannel "AR (Read Address)"
                    } elseif {$umask == 0b10} {
                        set subchannel "R (Read Data)"
                    } elseif {$umask == 0b100} {
                        set subchannel "AW (Write Address)"
                    } elseif {$umask == 0b1000} {
                        set subchannel "W (Write Data)"
                    } elseif {$umask == 0b10000} {
                        set subchannel "B (Write Response)"
                    } else {
                        set subchannel "Unknown"
                    }
                    puts "$subchannel subchannel gap violation detected."
                    puts "Efficiency and backpressure metrics regarding the $subchannel subchannel may be inaccurate"
                } elseif {$umask == 0b100000} {
                    puts "Read Traffic gap violation detected (can occur from initial AR to R or R to R)"
                    puts "Read Efficiency metrics may be inaccurate"
                } elseif {$umask == 0b1000000} {
                    puts "Write Traffic gap violation detected (can occur from initial AW|W to B or B to B)"
                    puts "Write Efficiency metrics may be inaccurate"
                } elseif {$umask == 0b10000000} {
                    puts "Overall Traffic gap violation detected (can occur from initial AR|AW|W to R|B or R|B to R|B)"
                    puts "Overall Efficiency and total traffic duration metrics may be inaccurate"
                }


            } elseif {$event == $PMON_EVENT_PMON_LAT_DEBUG && $umask == 0b10000 } {
                if {$ADV_LAT} {
                    puts "Maximum read latency of a transaction exceeds limit"
                } else {
                    puts "Number of outstanding read transactions violated"
                }
                puts "Read Latency Metrics may be inaccurate"
            } elseif {$event == $PMON_EVENT_PMON_LAT_DEBUG && $umask == 0b100000} {
                if {$ADV_LAT} {
                    puts "Maximum write latency of a transaction exceeds limit"
                } else {
                    puts "Number of outstanding write transactions violated"
                }
                puts "Write Latency Metrics may be inaccurate"
            } else {
                puts "Error: No violation check set but counter is incrementing"
            }
        } else {
            incr no_viol
        }
    }

    if {$no_viol == $NumCntr} {
        puts "No traffic violations detected"
    }

    pmon_reset_counter_control $index $umon
    pmon_unfreeze $index $umon
}

proc ::pmon_lib::pmon_check_viol_all {} {

    variable PMON_JAMB_list
    if {[llength $PMON_JAMB_list] == 0} {
        puts "PMON JTAG list empty run pmon_discover_all"
    }

    for {set index 0} {$index < [pmon_num_ins]} {incr index} {
        for {set umon 0} {$umon < [pmon_num_umon $index]} {incr umon} {
            puts ""
            pmon_check_viol $index $umon
        }
    }
}

proc ::pmon_lib::pmon_help {{in_str ""} args} {

    switch $in_str {
        config {
            puts "Here is a list of all configuration arguments that can be provided to the pmon_set function as well as which metrics they provide once read from using pmon_read."
            variable pmon_configs
            set config_list [dict keys $pmon_configs]
            if {$config_list == [list]} {
                puts "Please ensure pmon configurations have been loaded by calling pmon_define_configs"
                puts "Please restart and reload the library after adding or removing configurations"
                return
            }
            foreach config $config_list {
                if {[dict exists $pmon_configs $config name]} {
                    set config_name [dict get $pmon_configs $config name]
                } else {
                    set config_name "No name"
                }
                if {[dict exists $pmon_configs $config desc]} {
                    set config_desc [dict get $pmon_configs $config desc]
                } else {
                    set config_desc "No description provided"
                }
                puts "$config: $config_name: $config_desc"
                puts ""
            }
            return
        }
        flow {
            puts "Recommended sequence of function calls to configure the Performance Monitor and extract metrics :"
            puts "pmon_set {config} {index} {umon} or pmon_set_all {config} will set the metric configuration on desired AXI4 PMONs"
            puts "pmon_reset_counter_data_all will clear counters and internal state of all Performance Monitors. This MUST be called after pmon_set."
            puts "RUN TRAFFIC OVER THE INTERFACE"
            puts "pmon_read {index} {umon} or pmon_read_all will read metrics on desired AXI4 PMONs and present in human readable format."
            return
        }
        metric {
            puts "Read Latency: AR acceptance to R last response"
            puts "Write Latency: AW acceptance to B response"
            puts "Read Efficiency: # of R data beats / Cycles from first AR acceptance to last R transaction"
            puts "Write Efficiency: # of W data beats / Cycles from first AW|W acceptance to last B transaction"
            puts "Total Traffic Duration: Cycles from first AR|AW|W acceptance to last R|B transaction"
            puts "Average Number of Data transactions per cycle: (# of W data beats + # of R Data Beats) / Total Traffic Duration"
            puts "Subchannel Efficiency: # of transactions on subchannel / First to last transaction on subchannel"
            puts "Subchannel Backpressure: # of cycles with XVALID = 1 and XREADY = 0 / First to last transaction on subchannel"
            puts "Expected Transactions on subchannel: R is based on ARLEN, W is based AWLEN and B is based on number of transactions on the AW subchannel"
            return
        }
        function {
            puts "pmon_discover_all : Performs the discovery process for all PMON JTAGs for all monitors and intialize all top level list variables. Called automatically when loading library and needed for all following functions."
            puts "pmon_print_info {index} : Prints parameters and path of given PMON JTAG <index>."
            puts "pmon_freeze {index} {umon}: Sets Freeze field of UCTRL register of PMON <index> Unit monitor <umon> to 1"
            puts "pmon_unfreeze {index} {umon}: Sets Freeze field of UCTRL register of PMON <index> Unit monitor <umon> to 0"
            puts "pmon_reset_counter_control {index} {umon}: Reset counter metric configuration for PMON <index> unit monitor <umon>"
            puts "pmon_reset_counter_data {index} {umon}: Reset counter data for PMON <index> unit monitor <umon>. This must be called after calling the pmon_set function."
            puts "pmon_reset_status {index} {umon}: Clears the status bits of PMON <index> unit monitor <umon>"
            puts "pmon_print_status {index} {umon}: Prints out the overflow status of each counter in PMON <index> unit monitor <umon>"
            puts "pmon_print_counter_control {index} {umon}: Prints out the counter control register of each counter of PMON <index> unit monitor <umon> with its address in memory"
            puts "pmon_print_counter_data {index} {umon}: Prints out the counter data register of each counter of PMON <index> unit monitor <umon> with its address in memory"
            puts "pmon_get_counter_control {index} {umon}: Returns a list of the counter control register values of PMON <index> unit monitor <umon>"
            puts "pmon_get_counter_data {index} {umon}: Returns a list of the counter data register values of PMON <index> unit monitor <umon>"
            puts "pmon_get_status {index} {umon}: Returns a list overflow status of each counter in PMON <index> unit monitor <umon>"
            puts "pmon_num_ins : Returns the number of PMON instances in design."
            puts "pmon_num_umon {index} : Returns the number of unit monitors of PMON instance <index>."
            puts "pmon_define_configs {index} : Initializes library supported PMON configurations. Called automatically when loading library and needed for all following functions."
            puts "pmon_set {config} {index} {umon}: Sets counter control of PMON <index> unit monitor <umon> based on the provided <config> argument."
            puts "pmon_read {index} {umon}: Read the derived metrics of PMON <index> unit monitor <umon> based on the currently set configuration of the monitor."
            puts "pmon_help {option}: Display information about the PMON library."
            puts "pmon_check_viol {index} {umon}: Debug function, checks if max outstanding transactions or traffic gap violations were found after reading results and prints errors. Checking traffic gap or outstanding transaction violations corrupts counter data so ensure all data is collected before checking violations."
            puts "NOTE: Appending _all (available on any set, read, reset or check function) to a function will call the function for all unit monitors in the design."
        }
        default {
            puts "Welcome to the pmon_help function."
            puts "Below is a list of possible arguments and what they can help you with in using this library."
            puts "config - Provides a list of all pmon configurations that can be set using the pmon_set function."
            puts "flow - Provides an example of the user flow of the library."
            puts "metric - Provides the definitions for each metric presented by the library."
            puts "function - Provides a brief summary for each function imported by the library for users."
            return
        }
    }
}

proc ::pmon_lib::pmon_define_configs {} {

    variable pmon_configs [dict create]

    set PMON_EVENT_COUNTER_IDLE           0x00
    set PMON_EVENT_CLOCK_TICKS            0x01
    set PMON_EVENT_CLOCK_TICKS_AR2AR      0x02
    set PMON_EVENT_CLOCK_TICKS_R2R        0x03
    set PMON_EVENT_CLOCK_TICKS_AW2AW      0x04
    set PMON_EVENT_CLOCK_TICKS_W2W        0x05
    set PMON_EVENT_CLOCK_TICKS_B2B        0x06
    set PMON_EVENT_CLOCK_TICKS_AR2R       0x07
    set PMON_EVENT_CLOCK_TICKS_AWW2B      0x08
    set PMON_EVENT_CLOCK_TICKS_ARAWW2RB   0x09

    set PMON_EVENT_READ_OCCUPANCY         0x10
    set PMON_EVENT_READ_LENGTH            0x11
    set PMON_EVENT_READ_BYTES             0x12
    set PMON_EVENT_TOTAL_READ_LATENCY     0x13

    set PMON_EVENT_WRITE_OCCUPANCY        0x18
    set PMON_EVENT_RESP_OCCUPANCY         0x19
    set PMON_EVENT_WRITE_LENGTH           0x1a
    set PMON_EVENT_WRITE_BYTES            0x1b
    set PMON_EVENT_TOTAL_WRITE_LATENCY    0x1c

    set PMON_EVENT_PMON_LAT_DEBUG         0xff

    variable Settings

    # If adding a new config ensure the number of counter control defined matches the number of counters (8) in the same order
    variable pmon_configs [dict create \
        "empty" [dict create \
          name "Empty" \
          desc "Sets all counters to an idle state and clears all filters." \
          ucctl_dict [dict create \
            ucctl_0 [dict create   event_sel $PMON_EVENT_COUNTER_IDLE           umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_1 [dict create   event_sel $PMON_EVENT_COUNTER_IDLE           umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_2 [dict create   event_sel $PMON_EVENT_COUNTER_IDLE           umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_3 [dict create   event_sel $PMON_EVENT_COUNTER_IDLE           umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_4 [dict create   event_sel $PMON_EVENT_COUNTER_IDLE           umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_5 [dict create   event_sel $PMON_EVENT_COUNTER_IDLE           umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_6 [dict create   event_sel $PMON_EVENT_COUNTER_IDLE           umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_7 [dict create   event_sel $PMON_EVENT_COUNTER_IDLE           umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
          ]\
        ] \
        "basic_eff" [dict create \
          name "Basic Efficiency" \
          desc "Set metrics for Read efficiency, Write efficiency, and Average Data transactions per cycle of the AXI4 Interface." \
          ucctl_dict [dict create \
            ucctl_0 [dict create   event_sel $PMON_EVENT_READ_OCCUPANCY         umask 0b00001000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_1 [dict create   event_sel $PMON_EVENT_CLOCK_TICKS_AR2R       umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_2 [dict create   event_sel $PMON_EVENT_WRITE_OCCUPANCY        umask 0b00001000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_3 [dict create   event_sel $PMON_EVENT_CLOCK_TICKS_AWW2B      umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_4 [dict create   event_sel $PMON_EVENT_COUNTER_IDLE           umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_5 [dict create   event_sel $PMON_EVENT_CLOCK_TICKS_ARAWW2RB   umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_6 [dict create   event_sel $PMON_EVENT_COUNTER_IDLE           umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_7 [dict create   event_sel $PMON_EVENT_COUNTER_IDLE           umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
          ] \
        ] \
        "ch_eff" [dict create \
          name "AXI4 subchannel efficiency" \
          desc "Set metrics for efficiency of the AR, R, AW, W subchannels of the AXI4 Interface." \
          ucctl_dict [dict create \
            ucctl_0 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_1 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_AR2AR        umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_2 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00001000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_3 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_R2R          umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_4 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_5 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_AW2AW        umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_6 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00001000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_7 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_W2W          umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
          ] \
        ] \
        "ch_bp" [dict create \
          name "AXI4 subchannel backpressure" \
          desc "Set metrics for backpressure of the AR, R, AW, W subchannels of the AXI4 Interface." \
          ucctl_dict [dict create \
            ucctl_0 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00000100   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_1 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_AR2AR        umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_2 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00100000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_3 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_R2R          umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_4 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00000100   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_5 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_AW2AW        umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_6 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00100000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_7 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_W2W          umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
          ] \
        ] \
        "basic_rw" [dict create \
          name "Basic Read/Write" \
          desc "Set metrics for the Read, Write efficiency and average latencies of the AXI4 Interface." \
          ucctl_dict [dict create \
            ucctl_0 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00001000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_1 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_AR2R         umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_2 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00001000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_3 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_AWW2B        umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_4 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_5 [dict create event_sel $PMON_EVENT_TOTAL_READ_LATENCY       umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_6 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_7 [dict create event_sel $PMON_EVENT_TOTAL_WRITE_LATENCY      umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
          ] \
        ] \
        "wo" [dict create \
          name "Write Only" \
          desc "Set metrics for AXI4 subchannel (AW,W,B) efficiency, transactions, average write burst length, expected write data transactions and average write latency of the AXI4 Interface." \
          ucctl_dict [dict create \
            ucctl_0 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_B2B          umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_1 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_W2W          umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_2 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_AW2AW        umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_3 [dict create event_sel $PMON_EVENT_WRITE_LENGTH             umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_4 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00001000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_5 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_6 [dict create event_sel $PMON_EVENT_TOTAL_WRITE_LATENCY      umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_7 [dict create event_sel $PMON_EVENT_RESP_OCCUPANCY           umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
          ] \
        ] \
        "ro" [dict create \
          name "Read Only" \
          desc "Set metrics for AXI4 subchannel (AR,R) efficiency, transactions, backpressure, average read burst length, expected read data transactions and average read latency of the AXI4 Interface." \
          ucctl_dict [dict create \
            ucctl_0 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_AR2AR        umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_1 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_R2R          umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_2 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_3 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00001000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_4 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00000100   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_5 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00100000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_6 [dict create event_sel $PMON_EVENT_READ_LENGTH              umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_7 [dict create event_sel $PMON_EVENT_TOTAL_READ_LATENCY       umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
          ] \
        ] \
        "diag" [dict create \
          name "Diagnostics" \
          desc "Set metrics for number of AXI4 subchannel transactions (AR,R,AW,W,B), expected R,W transactions, and total traffic duration of the AXI4 Interface." \
          ucctl_dict [dict create \
            ucctl_0 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_1 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00001000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_2 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_3 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00001000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_4 [dict create event_sel $PMON_EVENT_RESP_OCCUPANCY           umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_5 [dict create event_sel $PMON_EVENT_READ_LENGTH              umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_6 [dict create event_sel $PMON_EVENT_WRITE_LENGTH             umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_7 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_ARAWW2RB     umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
          ] \
        ] \
        "primary" [dict create \
          name "Primary Side" \
          desc "Set metrics for AXI4 subchannel (AR,AW,W) efficiency, transactions, average read and write latency of the AXI4 Interface." \
          ucctl_dict [dict create \
            ucctl_0 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_AR2AR        umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_1 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_AW2AW        umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_2 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_W2W          umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_3 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_4 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_5 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00001000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_6 [dict create event_sel $PMON_EVENT_TOTAL_READ_LATENCY       umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_7 [dict create event_sel $PMON_EVENT_TOTAL_WRITE_LATENCY      umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
          ] \
        ] \
        "secondary" [dict create \
          name "Secondary Side" \
          desc "Set metrics for AXI4 subchannel (R,B) efficiency, transactions, backpressure, expected R and B transactions of the AXI4 Interface." \
          ucctl_dict [dict create \
            ucctl_0 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_R2R          umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_1 [dict create event_sel $PMON_EVENT_CLOCK_TICKS_B2B          umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_2 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00001000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_3 [dict create event_sel $PMON_EVENT_RESP_OCCUPANCY           umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_4 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00100000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_5 [dict create event_sel $PMON_EVENT_RESP_OCCUPANCY           umask 0b00000100   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_6 [dict create event_sel $PMON_EVENT_READ_LENGTH              umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_7 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
          ] \
        ] \
        "basic_lat" [dict create \
          name "Basic Latency" \
          desc "Set metrics for Read & Write average latencies, maximum outstanding transactions and average burst lengths of the AXI4 Interface." \
          ucctl_dict [dict create \
            ucctl_0 [dict create event_sel $PMON_EVENT_TOTAL_READ_LATENCY       umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 1] \
            ucctl_1 [dict create event_sel $PMON_EVENT_READ_LENGTH              umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_2 [dict create event_sel $PMON_EVENT_TOTAL_WRITE_LATENCY      umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 1] \
            ucctl_3 [dict create event_sel $PMON_EVENT_WRITE_LENGTH             umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_4 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_5 [dict create event_sel $PMON_EVENT_TOTAL_READ_LATENCY       umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_6 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_7 [dict create event_sel $PMON_EVENT_TOTAL_WRITE_LATENCY      umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
          ] \
        ] \
        "full_lat" [dict create \
          name "Full Latency" \
          desc "Set metrics for average Read & Write latencies and maximum outstanding transactions of the AXI4 Interface." \
          ucctl_dict [dict create \
            ucctl_0 [dict create event_sel $PMON_EVENT_TOTAL_READ_LATENCY       umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 1] \
            ucctl_1 [dict create event_sel $PMON_EVENT_TOTAL_READ_LATENCY       umask 0b00000000   cntr_rst 0   edge 0   inv 1   thresh 0   max 1] \
            ucctl_2 [dict create event_sel $PMON_EVENT_TOTAL_WRITE_LATENCY      umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 1] \
            ucctl_3 [dict create event_sel $PMON_EVENT_TOTAL_WRITE_LATENCY      umask 0b00000000   cntr_rst 0   edge 0   inv 1   thresh 0   max 1] \
            ucctl_4 [dict create event_sel $PMON_EVENT_READ_OCCUPANCY           umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_5 [dict create event_sel $PMON_EVENT_TOTAL_READ_LATENCY       umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_6 [dict create event_sel $PMON_EVENT_WRITE_OCCUPANCY          umask 0b00000001   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
            ucctl_7 [dict create event_sel $PMON_EVENT_TOTAL_WRITE_LATENCY      umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0] \
          ] \
        ]
    ]
    if {$Settings >> 7} {
        dict set pmon_configs basic_lat desc "Set metrics for average and maximum Read & Write latencies and average burst lengths of the AXI4 Interface."
        dict set pmon_configs full_lat desc "Set metrics for maximum, minimum and average Read & Write latencies of the AXI4 Interface."
    }
    puts "PMON available configurations have been defined"
}

proc ::pmon_lib::_pmon_config2reg {{config ""}} {

    set counter_control [list]

    if {$config == ""} {
        "No config chosen"
        return $counter_control
    }

    variable pmon_configs

    if {[dict exists $pmon_configs $config]} {
        if {[dict exists $pmon_configs $config ucctl_dict]} {
            set cctl_regs [dict get $pmon_configs $config ucctl_dict]
        } else {
            puts "Chosen counter configuration option $config does not have any counter controls defined"
            puts "Please ensure pmon_define_configs has been called after making updates"
            return $counter_control
        }
    } else {
        puts "Chosen counter configuration option $config does not match any existing option"
        puts "Please call pmon_help config for a list of existing configs"
        return $counter_control
    }

    for {set i 0} {$i < [dict size $cctl_regs]} {incr i} {
        if {[dict exists $cctl_regs ucctl_$i]} {
            set cctl_fields [dict get $cctl_regs ucctl_$i]
        } else {
            puts "Counter control $i is not defined in $config, setting counter to idle"
            set cctl_fields [dict create   event_sel $PMON_EVENT_COUNTER_IDLE   umask 0b00000000   cntr_rst 0   edge 0   inv 0   thresh 0   max 0]
        }
        if {[dict exists $cctl_fields event_sel]} {
            set event_sel [dict get $cctl_fields event_sel]
        } else {
            puts "Event select is not defined for counter control $i, setting event to idle"
            set event_sel $PMON_EVENT_COUNTER_IDLE
        }
        if {[dict exists $cctl_fields umask]} {
            set umask [dict get $cctl_fields umask]
        } else {
            puts "Subevent select is not defined for counter control $i, setting field to 0"
            set umask 0b00000000
        }
        if {[dict exists $cctl_fields cntr_rst]} {
            set cntr_rst [dict get $cctl_fields cntr_rst]
        } else {
            puts "Counter reset is not defined for counter control $i, setting field to 0"
            set cntr_rst 0
        }
        if {[dict exists $cctl_fields edge]} {
            set edge [dict get $cctl_fields edge]
        } else {
            puts "Edge detect is not defined for counter control $i, setting field to 0"
            set edge 0
        }
        if {[dict exists $cctl_fields inv]} {
            set inv [dict get $cctl_fields inv]
        } else {
            puts "Invert is not defined for counter control $i, setting field to 0"
            set inv 0
        }
        if {[dict exists $cctl_fields thresh]} {
            set thresh [dict get $cctl_fields thresh]
        } else {
            puts "Threshold is not defined for counter control $i, setting field to 0"
            set thresh 0
        }
        if {[dict exists $cctl_fields max]} {
            set max [dict get $cctl_fields max]
        } else {
            puts "Max is not defined for counter control $i, setting field to 0"
            set max 0
        }
        set UCCTL_L_i [expr {[expr {$thresh & 0xff}] << 24 | [expr {$inv & 0b1}] << 23 | [expr {$edge & 0b1}] << 18 | [expr {$cntr_rst & 0b1}] << 17 | [expr {$umask & 0xff}] << 8 | [expr {$event_sel & 0xff}]}]
        set UCCTL_L_i [format 0x%x $UCCTL_L_i]

        set UCCTL_H_i [expr {[expr {$max & 0b1}]}]
        set UCCTL_H_i [format 0x%x $UCCTL_H_i]
        set UCCTL_i [expr {$UCCTL_H_i << 32 | $UCCTL_L_i}]
        set UCCTL_i [format 0x%x $UCCTL_i]
        lappend counter_control $UCCTL_i
    }
    return $counter_control
}

proc ::pmon_lib::pmon_set {{config ""} {index 0} {umon -65} args} {

    if {$config == ""} {
        puts "No counter configuration chosen"
        puts "Please call pmon_help config for a list of existing configurations"
        return
    }

    if {$index == "all"} {
        puts "Please call pmon_set_all {config} to set all monitors"
        return
    }

    set is_valid [_pmon_choose $index $umon]
    if {$is_valid == -1} {
        return
    }

    variable pmon_configs

    if {[dict exists $pmon_configs $config]} {
        if {[dict exists $pmon_configs $config ucctl_dict]} {
            set cctl_regs [dict get $pmon_configs $config ucctl_dict]
        } else {
            puts "Chosen counter configuration option $config does not have any counter controls defined"
            puts "Please restart and reload the library after adding new configuratiuons"
            return
        }
    } else {
        puts "Chosen counter configuration option $config does not match any existing option"
        puts "Please call pmon_help config for a list of existing configurations"
        return
    }

    pmon_reset_counter_control $index $umon
    pmon_reset_status $index $umon
    pmon_freeze $index $umon

    variable claim_pmon_jamb_path
    variable PMON_BAR
    variable UCAddress
    variable NumCntr
    variable UnitCntrCtrlAdr_offset
    variable UnitID

    set cctl_regs [_pmon_config2reg $config]

    if {[llength $cctl_regs] < $NumCntr} {
        puts "Configuration $config only defines [llength $cctl_regs] counter controls while there are $NumCntr counters in the chosen unit monitor"
        puts "Undefined counters will be set to idle state"
    }

    set stride 0x8
    set hioffset 0x4
    set pmon_ucctl_l_0_addr [expr {$UCAddress + $PMON_BAR +$UnitCntrCtrlAdr_offset}]

    for {set i 0} {$i < $NumCntr} {incr i} {

        set UCCTL_i [lindex $cctl_regs $i]

        if {$UCCTL_i == ""} {
            puts "Counter $i is beyond range of defined counter controls; setting to idle"
            set $UCCTL_i 0x0
        }

        set UCCTL_L_i [expr {$UCCTL_i & 0xffffffff}]
        set UCCTL_H_i [expr {$UCCTL_i >> 32 & 0xffffffff}]

        set pmon_ucctl_l_i_addr [expr {$pmon_ucctl_l_0_addr + $i*$stride}]
        set pmon_ucctl_h_i_addr [expr {$pmon_ucctl_l_i_addr + $hioffset}]

        set pmon_ucctl_l_i_addr [format 0x%x $pmon_ucctl_l_i_addr]
        set pmon_ucctl_h_i_addr [format 0x%x $pmon_ucctl_h_i_addr]

        master_write_32 $claim_pmon_jamb_path $pmon_ucctl_l_i_addr $UCCTL_L_i
        master_write_32 $claim_pmon_jamb_path $pmon_ucctl_h_i_addr $UCCTL_H_i
    }
    if {[dict exists $pmon_configs $config name]} {
        set config_name [dict get $pmon_configs $config name]
    } else {
        set config_name $config
    }
    puts "Counter controls for PMON $index : Unit Monitor $umon (Unit ID: $UnitID) set to $config_name configuration"
    pmon_unfreeze $index $umon
}


proc ::pmon_lib::pmon_set_all {{config ""} args} {
    if {$config == ""} {
        puts "No counter configuration chosen"
        puts "Please call pmon_help config for a list of existing configurations"
        return
    }

    variable PMON_JAMB_list
    if {[llength $PMON_JAMB_list] == 0} {
        puts "PMON JTAG list empty run pmon_discover_all"
    }

    for {set index 0} {$index < [pmon_num_ins]} {incr index} {
        for {set umon 0} {$umon < [pmon_num_umon $index]} {incr umon} {
            puts ""
            pmon_set $config $index $umon
        }
    }
}