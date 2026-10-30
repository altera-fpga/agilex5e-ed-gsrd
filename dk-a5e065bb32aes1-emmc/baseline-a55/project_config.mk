# Define the Quartus project name
PROJECT_NAME := top

#Define the Quartus revision names
REVISION_NAMES := \
	baseline_a55 \

# Define the base revision
BASE_REVISION := $(firstword $(REVISION_NAMES))

# Enable functional simulation
SIM_ENABLED := 0
include $(THIS_MK_DIR)/niosv_build.mk
$(foreach revision,$(REVISION_NAMES),$(eval output_files/prep-$(revision).done: nios_mem.hex | $(NIOSV_FW_TARGET)-install))
