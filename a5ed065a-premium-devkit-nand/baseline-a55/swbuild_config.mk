# Extract variables from machine.yml and bsp.yml (included by kas.yml)
MACHINE_YML_PATH := software/yocto_linux/kas/machine.yml
BSP_YML_PATH := software/yocto_linux/kas/bsp.yml

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

# Only convert .dts → .dtb if the variable is set
ifeq ($(strip $(KAS_CUSTOM_LINUX_DTS_FILE)),)
  KAS_CUSTOM_LINUX_DTB :=
else
  KAS_CUSTOM_LINUX_DTB := $(basename $(KAS_CUSTOM_LINUX_DTS_FILE)).dtb
endif

# Required DTS → DTB
KAS_LINUX_DTB := $(basename $(KAS_LINUX_DTS_FILE)).dtb

# Yocto deploy image path
KAS_YOCTO_IMAGE_DIR := software/yocto_linux/build/tmp/deploy/images/$(KAS_MACHINE)

ifeq ($(strip $(INSTALL_ROOT_BINARIES)),)
  $(error ERROR: INSTALL_ROOT_BINARIES was not defined before swconfig.mk was parsed)
endif

# Get the first revision name from REVISION_NAMES (defined in Makefile/project_config.mk)
REVISION := $(firstword $(REVISION_NAMES))

#
# Optional DTS installation files (so Make does not error when empty)
#
ifdef KAS_CUSTOM_LINUX_DTB
  YOCTO_NAND_OPTIONAL_DTB := $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/$(KAS_CUSTOM_LINUX_DTB)
else
  YOCTO_NAND_OPTIONAL_DTB :=
endif

###############################################################################
#                           Generic Targets
###############################################################################
# Create the core RBF files from the SOF files
output_files/%.core.rbf : output_files/%.sof
	quartus_pfg -c $< output_files/$*.rbf -o hps=ON

###############################################################################
#                           SW Build Targets
###############################################################################

# HPS Debug Software Build
###############################################################################
SW_HPS_DEBUG_TARGET := software-hps_debug
RBF_NAME := ghrd
# Do not add HPS to the SW build target. Instead make it a part of the SOF install
# target. This is because other SW builds require this SOF
# ALL_SW_TARGET_STEM_NAMES += $(SW_HPS_DEBUG_TARGET)
define create_hps_debug_targets_on_revisions
$(strip $(1))-install-sof : $(INSTALL_ROOT_BINARIES)/$(strip $(1))_hps_debug.sof $(strip $(1))-install-core-rbf

.PHONY: $(strip $(1))-install-core-rbf
$(strip $(1))-install-core-rbf : output_files/$(strip $(1)).sof  | $(INSTALL_ROOT_BINARIES)
	quartus_pfg -c output_files/$(strip $(1)).sof output_files/ghrd.rbf -o hps=ON -o hps_core_only=ON
	cp -f output_files/ghrd.rbf $(INSTALL_ROOT_BINARIES)/$(RBF_NAME).core.rbf
endef
$(foreach revision,$(REVISION_NAMES),$(eval $(call create_hps_debug_targets_on_revisions,$(revision))))
clean-sw: $(SW_HPS_DEBUG_TARGET)-clean-sw

# Build the SW
software/hps_debug/hps_wipe.ihex:
	cd software/hps_debug && ./build.sh

# HPS Debug FSBL insertion into the SOF
# Create the debug SOF specific SOFs using the hps_debug SW
ifneq ($(RESTORE_INSTALL),1)
output_files/%_hps_debug.sof : output_files/%.sof software/hps_debug/hps_wipe.ihex
	quartus_pfg -c -o hps_path=software/hps_debug/hps_wipe.ihex $< $@

$(INSTALL_ROOT_BINARIES)/%_hps_debug.sof : output_files/%_hps_debug.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@
endif

.PHONY: $(SW_HPS_DEBUG_TARGET)-clean-sw
$(SW_HPS_DEBUG_TARGET)-clean-sw:
	cd software/hps_debug && ./clean_build.sh

.PHONY: $(SW_HPS_DEBUG_TARGET)-build-sw
$(SW_HPS_DEBUG_TARGET)-build-sw : software/hps_debug/hps_wipe.ihex

.PHONY: $(SW_HPS_DEBUG_TARGET)-install-sw
$(SW_HPS_DEBUG_TARGET)-install-sw : $(INSTALL_ROOT_BINARIES)/%_hps_debug.sof


# Yocto Linux Software Build for NAND
###############################################################################
SW_YOCTO_LINUX_NAND_TARGET := software-yocto_linux_nand
ALL_SW_TARGET_STEM_NAMES += $(SW_YOCTO_LINUX_NAND_TARGET)

YOCTO_NAND_IMAGE_DIR := $(KAS_YOCTO_IMAGE_DIR)

$(KAS_YOCTO_IMAGE_DIR)/console-image-minimal-$(KAS_MACHINE).rootfs_nand.ubifs \
$(KAS_YOCTO_IMAGE_DIR)/u-boot-spl-dtb.hex: output_files/$(REVISION)_hps_debug.core.rbf
	cd software/yocto_linux && ./build.sh $(abspath $<) nand

# Yocto Linux FSBL insertion into the SOF
output_files/%_yocto_linux_nand.sof : output_files/%.sof $(KAS_YOCTO_IMAGE_DIR)/console-image-minimal-$(KAS_MACHINE).rootfs_nand.ubifs
	quartus_pfg -c -o hps_path=$(KAS_YOCTO_IMAGE_DIR)/u-boot-spl-dtb.hex $< $@

# Copy the SOF files to the install directory
$(INSTALL_ROOT_BINARIES)/%_yocto_linux_nand.sof : output_files/%_yocto_linux_nand.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@

# Copy the Yocto Linux images to the install directory
$(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/%: $(YOCTO_NAND_IMAGE_DIR)/% | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	cp -f $< $@

# Copy required files to artifacts directory
YOCTO_NAND_ARTIFACT_FILES := \
	u-boot-spl \
	u-boot-spl.dtb \
	u-boot-spl.map \
	u-boot \
	$(KAS_LINUX_DTB) \
	console-image-minimal-$(KAS_MACHINE).rootfs.cpio.gz.u-boot

$(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_nand/%: $(YOCTO_NAND_IMAGE_DIR)/% | $(INSTALL_ROOT_ARTIFACTS)
	mkdir -p $(dir $@)
	cp -f $< $@

.PHONY: nand-postprocess
nand-postprocess: output_files/$(REVISION)_hps_debug.sof
	cp -f software/yocto_linux/scripts/* $(YOCTO_NAND_IMAGE_DIR)
	cp -f output_files/$(REVISION)_yocto_linux_nand.sof $(YOCTO_NAND_IMAGE_DIR)
	cp -f output_files/$(REVISION)_hps_debug.sof $(YOCTO_NAND_IMAGE_DIR)

	# run uboot script, create UBI images and generate uboot only JIC for NAND
	cd $(YOCTO_NAND_IMAGE_DIR) && \
		./uboot_bin.sh && \
		ubinize -o root.ubi -p 1024KiB -m 8192 -s 8192 ubinize_nand.cfg && \
		cp $(REVISION)_yocto_linux_nand.sof ghrd.sof && \
		quartus_pfg -c qspi_helper.pfg && \
		quartus_pfg -c ghrd.sof ghrd.jic -o device=MT25QU128 -o flash_loader=A5ED065AB32AE1V -o hps_path=u-boot-spl-dtb.hex -o mode=ASX4 -o hps=1 && \
		quartus_pfg -o hps=ON -c -o hps_path=u-boot-spl-dtb.hex $(REVISION)_hps_debug.sof ghrd.rbf

	mkdir -p $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand
	cp -f $(YOCTO_NAND_IMAGE_DIR)/root.ubi $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/
	cp -f $(YOCTO_NAND_IMAGE_DIR)/qspi_helper.pfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/
	cp -f $(YOCTO_NAND_IMAGE_DIR)/uboot_bin.sh $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/
	cp -f $(YOCTO_NAND_IMAGE_DIR)/u-boot.bin $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/
	cp -f $(YOCTO_NAND_IMAGE_DIR)/u-boot-spl $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/
	cp -f $(YOCTO_NAND_IMAGE_DIR)/qspi_helper.hps.jic $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/
	cp -f $(YOCTO_NAND_IMAGE_DIR)/ghrd.hps.jic $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/
	cp -f $(YOCTO_NAND_IMAGE_DIR)/ubinize_nand.cfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/
	echo 'ubinize -o root.ubi -p 1024KiB -m 8192 -s 8192 ubinize_nand.cfg' > $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/ubinize.txt
	cp -f $(YOCTO_NAND_IMAGE_DIR)/ghrd.core.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/
	cp -f $(YOCTO_NAND_IMAGE_DIR)/ghrd.hps.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/

.PHONY: $(SW_YOCTO_LINUX_NAND_TARGET)-clean-sw
$(SW_YOCTO_LINUX_NAND_TARGET)-clean-sw:
	cd software/yocto_linux && ./clean_build.sh

.PHONY: $(SW_YOCTO_LINUX_NAND_TARGET)-build-sw
$(SW_YOCTO_LINUX_NAND_TARGET)-build-sw: $(KAS_YOCTO_IMAGE_DIR)/console-image-minimal-$(KAS_MACHINE).rootfs_nand.ubifs

.PHONY: $(SW_YOCTO_LINUX_NAND_TARGET)-install-sw
$(SW_YOCTO_LINUX_NAND_TARGET)-install-sw : \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/console-image-minimal-$(KAS_MACHINE).rootfs_nand.ubifs \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/console-image-minimal-$(KAS_MACHINE).rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/console-image-minimal-$(KAS_MACHINE).rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/Image \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/kernel.itb \
	$(YOCTO_NAND_OPTIONAL_DTB) \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/u-boot-spl-dtb.bin \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/u-boot-spl-dtb.hex \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/boot.scr.uimg \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/u-boot.itb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/uboot.env \
	$(INSTALL_ROOT_BINARIES)/$(REVISION)_yocto_linux_nand.sof \
	nand-postprocess \
	$(addprefix $(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_nand/, $(YOCTO_NAND_ARTIFACT_FILES))

