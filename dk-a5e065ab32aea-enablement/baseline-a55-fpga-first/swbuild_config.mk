# Recursive SW build entrypoints for per-project makefiles.
# For FPGA First design, only hps_debug is applicable.
# HPS-first software projects (yocto_linux, hps_baremetal, etc.) are not
# included because the FPGA is configured by the SDM before the HPS releases;
# those images are provided by the companion baseline-a55 design.

# Define the list of software projects to build
SW_PROJECT_LIST += \
hps_debug
