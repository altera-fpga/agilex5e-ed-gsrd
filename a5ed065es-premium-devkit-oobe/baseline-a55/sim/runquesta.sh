#! /bin/bash
# Determine the path to the bash script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Toplevel design directory
DESIGN_ROOT_DIR="$(realpath $SCRIPT_DIR/..)"

# Toplevel sim script generation
SIM_SCRIPT_GEN_DIR=$DESIGN_ROOT_DIR/baseline_top/sim

# # TOP-LEVEL TEMPLATE - BEGIN
# #
# # QSYS_SIMDIR is used in the Quartus-generated IP simulation script to
# # construct paths to the files required to simulate the IP in your Quartus
# # project. By default, the IP script assumes that you are launching the
# # simulator from the IP script location. If launching from another
# # location, set QSYS_SIMDIR to the output directory you specified when you
# # generated the IP script, relative to the directory from which you launch
# # the simulator.
# #
# set QSYS_SIMDIR <script generation output directory>
# #
# # Source the generated IP simulation script.
# source $QSYS_SIMDIR/mentor/msim_setup.tcl
# #
# # Set any compilation options you require (this is unusual).
# set USER_DEFINED_COMPILE_OPTIONS <compilation options>
# set USER_DEFINED_VHDL_COMPILE_OPTIONS <compilation options for VHDL>
# set USER_DEFINED_VERILOG_COMPILE_OPTIONS <compilation options for Verilog>
# #
# # Call command to compile the Quartus EDA simulation library.
# dev_com
# #
# # Call command to compile the Quartus-generated IP simulation files.
# com
# #
# # Add commands to compile all design files and testbench files, including
# # the top level. (These are all the files required for simulation other
# # than the files compiled by the Quartus-generated IP simulation script)
# #
# vlog <compilation options> <design and testbench files>
# #
# # Set the top-level simulation or testbench module/entity name, which is
# # used by the elab command to elaborate the top level.
# #
# set TOP_LEVEL_NAME <simulation top>
# #
# # Set any elaboration options you require.
# set USER_DEFINED_ELAB_OPTIONS <elaboration options>
# #
# # Call command to elaborate your design and testbench.
# elab
# #
# # Run the simulation.
# run -a
# #
# # Report success to the shell.
# exit -code 0
# #
# # TOP-LEVEL TEMPLATE - END

vsim -c -do " 
	set QSYS_SIMDIR $SIM_SCRIPT_GEN_DIR; 
	source $SIM_SCRIPT_GEN_DIR/mentor/msim_setup.tcl; 
	set TOP_LEVEL_NAME testbench; 
	dev_com; 
	com; 
	vlog $DESIGN_ROOT_DIR/src/debounce.sv; 
	vlog $DESIGN_ROOT_DIR/src/clocks_and_resets.sv; 
	vlog $DESIGN_ROOT_DIR/baseline_a55.sv; 
	vlog -timescale 1ps/1ps ./baseline_a55_tb.sv;  
	vlog $DESIGN_ROOT_DIR/ip/shell_subsys/sys_pll/sim/sys_pll.v; 
	vlog $DESIGN_ROOT_DIR/ip/shell_subsys/user_rst_clkgate/sim/user_rst_clkgate.v; 
	vlog $DESIGN_ROOT_DIR/ip/shell_subsys/user_rst_clkgate/intel_user_rst_clkgate_101/sim/intel_user_rst_clkgate.sv; 
	vlog $DESIGN_ROOT_DIR/ip/shell_subsys/sys_pll/altera_iopll_2100/synth/sys_pll_altera_iopll_2100_*.v; 
	set USER_DEFINED_ELAB_OPTIONS \"-suppress 14408,16154 -voptargs=-svext=+adta\"; 
	elab;	
	run -all; 
	exit -code 0"



