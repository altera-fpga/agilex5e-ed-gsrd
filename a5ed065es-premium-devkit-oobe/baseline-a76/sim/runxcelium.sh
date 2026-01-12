#! /bin/bash
MENTOR_VIP_AE=${MENTOR_VIP_AE:-$QUARTUS_ROOTDIR/../ip/altera/mentor_vip_ae}
export QUESTA_MVC_GCC_LIB=$MENTOR_VIP_AE/common/questa_mvc_core/linux_x86_64_gcc-*_ius
export LD_LIBRARY_PATH=${QUESTA_MVC_GCC_LIB}:${LD_LIBRARY_PATH}
export INCA_64BIT=1

# Determine the path to the bash script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Toplevel design directory
DESIGN_ROOT_DIR="$(realpath $SCRIPT_DIR/..)"

# Toplevel sim script generation
SIM_SCRIPT_GEN_DIR=$DESIGN_ROOT_DIR/sim_setup_baseline_a76

cp -rf $SIM_SCRIPT_GEN_DIR/xcelium/cds.lib $SIM_SCRIPT_GEN_DIR/xcelium/cds_libs $SIM_SCRIPT_GEN_DIR/xcelium/hdl.var .

# # TOP-LEVEL TEMPLATE - BEGIN
# #
# # QSYS_SIMDIR is used in the Quartus-generated IP simulation script to
# # construct paths to the files required to simulate the IP in your Quartus
# # project. By default, the IP script assumes that you are launching the
# # simulator from the IP script location. If launching from another
# # location, set QSYS_SIMDIR to the output directory you specified when you
# # generated the IP script, relative to the directory from which you launch
# # the simulator. In this case, you must also copy the generated files
# # "cds.lib" and "hdl.var" - plus the directory "cds_libs" if generated - 
# # into the location from which you launch the simulator, or incorporate
# # into any existing library setup.
# #
# # Run Quartus-generated IP simulation script once to compile Quartus EDA
# # simulation libraries and Quartus-generated IP simulation files, and copy
# # any ROM/RAM initialization files to the simulation directory.
# # - If necessary, specify any compilation options:
# #   USER_DEFINED_COMPILE_OPTIONS
# #   USER_DEFINED_VHDL_COMPILE_OPTIONS applied to vhdl compiler
# #   USER_DEFINED_VERILOG_COMPILE_OPTIONS applied to verilog compiler
# #
# source <script generation output directory>/xcelium/xcelium_setup.sh \
# SKIP_ELAB=1 \
# SKIP_SIM=1 \
# USER_DEFINED_COMPILE_OPTIONS=<compilation options for your design> \
# USER_DEFINED_VHDL_COMPILE_OPTIONS=<VHDL compilation options for your design> \
# USER_DEFINED_VERILOG_COMPILE_OPTIONS=<Verilog compilation options for your design> \
# QSYS_SIMDIR=<script generation output directory>
# #

source $SIM_SCRIPT_GEN_DIR/xcelium/xcelium_setup.sh \
SKIP_ELAB=1 \
SKIP_SIM=1 \
QSYS_SIMDIR=$SIM_SCRIPT_GEN_DIR
SKIP_DEV_COM=1 \
SKIP_COM=1

# Compile all design files and testbench files, including the top level.
# (These are all the files required for simulation other than the files
# compiled by the IP script)
#
xmvlog -sv $DESIGN_ROOT_DIR/src/debounce.sv 
xmvlog -sv $DESIGN_ROOT_DIR/src/clocks_and_resets.sv
xmvlog -sv $DESIGN_ROOT_DIR/baseline_a76.sv 
xmvlog -sv $DESIGN_ROOT_DIR/sim/baseline_a76_tb.sv 

#
# TOP_LEVEL_NAME is used in this script to set the top-level simulation or
# testbench module/entity name.
#
# Run the IP script again to elaborate and simulate the top level:
# - Specify TOP_LEVEL_NAME and USER_DEFINED_ELAB_OPTIONS.
# - Override the default USER_DEFINED_SIM_OPTIONS. For example, to run
#   until $finish(), set to an empty string: USER_DEFINED_SIM_OPTIONS="".
#

USER_DEFINED_ELAB_OPTIONS="\"\
    -timescale '1ps/1ps' \
  -no_mixed_bus \
  -ENABLE_BIND_WITH_COMMON_PKG \""

USER_DEFINED_SIM_OPTIONS="\"\
  -MESSAGES \
  -sv_root ${QUESTA_MVC_GCC_LIB} \
  -sv_lib libaxi4_IN_SystemVerilog_IUS_full_DVC \""

source $SIM_SCRIPT_GEN_DIR/xcelium/xcelium_setup.sh \
SKIP_FILE_COPY=1 \
SKIP_DEV_COM=1 \
SKIP_COM=1 \
TOP_LEVEL_NAME="'testbench'" \
QSYS_SIMDIR=$SIM_SCRIPT_GEN_DIR \
USER_DEFINED_ELAB_OPTIONS="$USER_DEFINED_ELAB_OPTIONS" \
USER_DEFINED_SIM_OPTIONS="$USER_DEFINED_SIM_OPTIONS"
#
# TOP-LEVEL TEMPLATE - END


