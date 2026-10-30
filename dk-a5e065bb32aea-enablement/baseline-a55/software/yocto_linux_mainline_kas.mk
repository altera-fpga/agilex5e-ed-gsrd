# Shared kas variable extraction for yocto_linux_mainline modules.
# Required before include: THIS_MK_DIR

MACHINE_YML_PATH := software/yocto_linux_mainline/kas/machine.yml
BSP_YML_PATH := software/yocto_linux_mainline/kas/bsp.yml

# Extract MACHINE
KAS_MACHINE := $(shell grep -A 10 "machine:" $(MACHINE_YML_PATH) | grep "MACHINE" | sed -E 's/.*MACHINE = "([^"]+)".*/\1/')

# Extract LINUX_DTS_FILE (.dts)
KAS_LINUX_DTS_FILE := $(shell grep -A 10 "machine:" $(MACHINE_YML_PATH) | grep -E '^\s*LINUX_DTS_FILE\s*=' | sed -E 's/.*LINUX_DTS_FILE = "([^"]+)".*/\1/')

# Extract CUSTOM_LINUX_DTS_FILE (optional)
KAS_CUSTOM_LINUX_DTS_FILE := $(shell grep -A 10 "machine:" $(MACHINE_YML_PATH) | grep "CUSTOM_LINUX_DTS_FILE" | sed -E 's/.*CUSTOM_LINUX_DTS_FILE = "([^"]+)".*/\1/')

ifeq ($(strip $(KAS_MACHINE)),)
$(error ERROR: MACHINE not found in $(MACHINE_YML_PATH))
endif

ifeq ($(strip $(KAS_LINUX_DTS_FILE)),)
$(error ERROR: LINUX_DTS_FILE not found in $(MACHINE_YML_PATH))
endif

# Only convert .dts -> .dtb if the variable is set
ifeq ($(strip $(KAS_CUSTOM_LINUX_DTS_FILE)),)
  KAS_CUSTOM_LINUX_DTB :=
else
  KAS_CUSTOM_LINUX_DTB := $(basename $(KAS_CUSTOM_LINUX_DTS_FILE)).dtb
endif

# Required DTS -> DTB
KAS_LINUX_DTB := $(basename $(KAS_LINUX_DTS_FILE)).dtb
