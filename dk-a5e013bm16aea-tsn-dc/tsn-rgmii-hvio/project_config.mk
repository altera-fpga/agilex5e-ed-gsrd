# Define the Quartus project name
PROJECT_NAME := top

#Define the Quartus revision names
REVISION_NAMES := \
	tsn_rgmii_hvio \

# Define the base revision
BASE_REVISION := $(firstword $(REVISION_NAMES))

# Enable functional simulation
SIM_ENABLED := 1