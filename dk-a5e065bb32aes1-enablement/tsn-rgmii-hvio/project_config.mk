# Define the Quartus project name
PROJECT_NAME := top

#Define the Quartus revision names
REVISION_NAMES := \
	tsn_rgmii_hvio \

# Enable functional simulation
SIM_ENABLED := 0
include $(THIS_MK_DIR)/niosv_build.mk
$(foreach revision,$(REVISION_NAMES),$(eval output_files/prep-$(revision).done: nios_mem.hex | $(NIOSV_FW_TARGET)-install))
