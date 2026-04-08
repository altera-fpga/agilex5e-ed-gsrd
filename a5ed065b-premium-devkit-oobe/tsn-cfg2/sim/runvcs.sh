#!/usr/bin/env bash
set -eo pipefail

# Determine the path to the bash script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Toplevel design directory
DESIGN_ROOT_DIR="$(realpath $SCRIPT_DIR/..)"

# Toplevel sim script generation
SIM_SCRIPT_GEN_DIR=$DESIGN_ROOT_DIR/sim_setup_tsn_cfg2

if [ ! -f synopsys_sim.setup ]; then

cp $SIM_SCRIPT_GEN_DIR/synopsys/vcsmx/synopsys_sim.setup .

fi

# TOP-LEVEL TEMPLATE - BEGIN
#
# QSYS_SIMDIR is used in the Quartus-generated IP simulation script to
# construct paths to the files required to simulate the IP in your Quartus
# project. By default, the IP script assumes that you are launching the
# simulator from the IP script location. If launching from another
# location, set QSYS_SIMDIR to the output directory you specified when you
# generated the IP script, relative to the directory from which you launch
# the simulator. In this case, you must also copy the generated library
# setup "synopsys_sim.setup" into the location from which you launch the
# simulator, or incorporate into any existing library setup.
#
# Run Quartus-generated IP simulation script once to compile Quartus EDA
# simulation libraries and Quartus-generated IP simulation files, and copy
# any ROM/RAM initialization files to the simulation directory.
#
# - If necessary, specify any compilation options:
#   USER_DEFINED_COMPILE_OPTIONS
#   USER_DEFINED_VHDL_COMPILE_OPTIONS applied to vhdl compiler
#   USER_DEFINED_VERILOG_COMPILE_OPTIONS applied to verilog compiler
#
if [ ! -f vcs_libs_comp.done ]; then
source $SIM_SCRIPT_GEN_DIR/synopsys/vcsmx/vcsmx_setup.sh \
SKIP_ELAB=1 \
SKIP_SIM=1 \
QSYS_SIMDIR=$SIM_SCRIPT_GEN_DIR

touch vcs_libs_comp.done
fi

#
# Compile all design files and testbench files, including the top level.
# (These are all the files required for simulation other than the files
# compiled by the IP script)
#
vlogan -sverilog $DESIGN_ROOT_DIR/src/debounce.sv
vlogan -sverilog $DESIGN_ROOT_DIR/src/clocks_and_resets.sv
vlogan -sverilog $DESIGN_ROOT_DIR/tsn_cfg2.sv
vlogan -sverilog $DESIGN_ROOT_DIR/sim/hps_h2f_pkg.sv
vlogan -sverilog $DESIGN_ROOT_DIR/sim/hps_h2f_lw_pkg.sv
vlogan -sverilog $DESIGN_ROOT_DIR/sim/tsn_cfg2_tb.sv
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
  -full64 \
  -timescale=1ns/1ns \
  +vpi -debug_access+r+w+nomemcbk +vcs+lic+wait \""

source $SIM_SCRIPT_GEN_DIR/synopsys/vcsmx/vcsmx_setup.sh \
SKIP_FILE_COPY=1 \
SKIP_DEV_COM=1 \
SKIP_COM=1 \
TOP_LEVEL_NAME="'-top testbench'" \
QSYS_SIMDIR=$SIM_SCRIPT_GEN_DIR \
USER_DEFINED_ELAB_OPTIONS="$USER_DEFINED_ELAB_OPTIONS" \
USER_DEFINED_SIM_OPTIONS="'-l transcript'"
#
# TOP-LEVEL TEMPLATE - END

# Check simulation results for errors
if [ -f transcript ]; then
    if grep -qiE "(FAIL|Error|Fatal)" transcript; then
        echo "ERROR: Simulation failed! Check transcript for details."
        exit 1
    else
        echo "Simulation completed successfully."
        exit 0
    fi
else
    echo "ERROR: Transcript file not found!"
    exit 1
fi


