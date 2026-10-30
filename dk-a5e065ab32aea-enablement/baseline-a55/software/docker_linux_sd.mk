# Docker Linux SD Build
# Required inputs: REVISION, INSTALL_ROOT_BINARIES, INSTALL_ROOT_ARTIFACTS
# Entry targets: clean-sw, build-sw, install-sw

THIS_MK_ABSPATH := $(abspath $(lastword $(MAKEFILE_LIST)))
THIS_MK_DIR := $(dir $(THIS_MK_ABSPATH))

# Enable pipefail for all commands
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

# Enable second expansion
.SECONDEXPANSION:

# Clear all built in suffixes
.SUFFIXES:

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

# Only convert .dts -> .dtb if the variable is set
ifeq ($(strip $(KAS_CUSTOM_LINUX_DTS_FILE)),)
  KAS_CUSTOM_LINUX_DTB :=
else
  KAS_CUSTOM_LINUX_DTB := $(basename $(KAS_CUSTOM_LINUX_DTS_FILE)).dtb
endif

# Required DTS -> DTB
KAS_LINUX_DTB := $(basename $(KAS_LINUX_DTS_FILE)).dtb

# Docker deploy image path
KAS_DOCKER_IMAGE_DIR := software/docker_linux/build/tmp/deploy/images/$(KAS_MACHINE)

# Inputs validation
ifeq ($(strip $(INSTALL_ROOT_BINARIES)),)
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before docker_linux_sd.mk was parsed)
endif

ifeq ($(strip $(INSTALL_ROOT_ARTIFACTS)),)
$(error ERROR: INSTALL_ROOT_ARTIFACTS was not defined before docker_linux_sd.mk was parsed)
endif

ifeq ($(strip $(REVISION)),)
$(error ERROR: REVISION was not set. Pass REVISION=<revision> on the command line)
endif

# Optional DTS installation files (so Make does not error when empty)
ifdef KAS_CUSTOM_LINUX_DTB
  DOCKER_SD_OPTIONAL_DTB := $(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/$(KAS_CUSTOM_LINUX_DTB)
else
  DOCKER_SD_OPTIONAL_DTB :=
endif

# Include common build targets and recipes
include $(THIS_MK_DIR)/sw_build_common.mk

###############################################################################
#                           SW Build Targets
###############################################################################

# Docker Linux Software Build for SD
###############################################################################

DOCKER_SD_IMAGE_DIR := $(KAS_DOCKER_IMAGE_DIR)
DOCKER_SD_WIC       := $(DOCKER_SD_IMAGE_DIR)/gsrd-console-image-$(KAS_MACHINE).rootfs.wic
DOCKER_SD_SPL_HEX   := $(DOCKER_SD_IMAGE_DIR)/u-boot-spl-dtb.hex

# Build the Docker Linux image (depends on $(REVISION) RBF)
$(DOCKER_SD_WIC): output_files/$(REVISION).core.rbf
	cd software/docker_linux && ./build.sh $(abspath $<) sd

# FSBL insertion into SOF
output_files/%_docker_linux_sd.sof : output_files/%.sof $(DOCKER_SD_WIC)
	quartus_pfg -c -o hps_path=$(DOCKER_SD_SPL_HEX) $< $@

# Copy SOF files to install dir
$(INSTALL_ROOT_BINARIES)/%_docker_linux_sd.sof : output_files/%_docker_linux_sd.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@

# Create sdimage.tar.gz from the WIC
$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/sdimage.tar.gz: $(DOCKER_SD_WIC) | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	tar -chzf $@ -C $(dir $<) $(notdir $<)

# Create MD5 checksum
$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/sdimage.tar.gz.md5sum: \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/sdimage.tar.gz
	cd $(dir $@) && md5sum $(notdir $(basename $@)) > $(notdir $@)

# Copy Docker Linux artifacts to install dir
$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/%: $(DOCKER_SD_IMAGE_DIR)/% | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	cp -f $< $@

# Copy required files to artifacts directory
DOCKER_SD_ARTIFACT_FILES := \
	u-boot-spl \
	u-boot-spl.dtb \
	u-boot-spl.map \
	u-boot \
	u-boot.dtb \
	$(KAS_LINUX_DTB) \
	console-image-minimal-$(KAS_MACHINE).rootfs.cpio.gz.u-boot \
	gsrd-console-image-$(KAS_MACHINE).rootfs.cpio.gz.u-boot

$(INSTALL_ROOT_ARTIFACTS)/software/docker_linux_sd/%: $(DOCKER_SD_IMAGE_DIR)/% | $(INSTALL_ROOT_ARTIFACTS)
	mkdir -p $(dir $@)
	cp -f $< $@

.PHONY: docker-sd-postprocess
docker-sd-postprocess: output_files/$(REVISION)_docker_linux_sd.sof output_files/$(REVISION).sof
	cp -f software/docker_linux/scripts/* $(DOCKER_SD_IMAGE_DIR)
	cp -f output_files/$(REVISION)_docker_linux_sd.sof $(DOCKER_SD_IMAGE_DIR)
	cp -f output_files/$(REVISION).sof $(DOCKER_SD_IMAGE_DIR)

	# run uboot script and quartus_pfg to generate uboot only JIC
	cd $(DOCKER_SD_IMAGE_DIR) && \
		./uboot_bin.sh && \
		cp $(REVISION)_docker_linux_sd.sof ghrd.sof && \
		quartus_pfg -c qspi_helper.pfg && \
		quartus_pfg -c ghrd.sof ghrd.jic -o device=MT25QU128 -o flash_loader=A5ED065AB32AE1V -o hps_path=u-boot-spl-dtb.hex -o mode=ASX4 -o hps=1 && \
		quartus_pfg -o hps=ON -c -o hps_path=u-boot-spl-dtb.hex $(REVISION).sof ghrd.rbf

	mkdir -p $(INSTALL_ROOT_BINARIES)/software/docker_linux_sd
	cp -f $(DOCKER_SD_IMAGE_DIR)/qspi_helper.pfg $(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/
	cp -f $(DOCKER_SD_IMAGE_DIR)/uboot_bin.sh $(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/
	cp -f $(DOCKER_SD_IMAGE_DIR)/u-boot.bin $(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/
	cp -f $(DOCKER_SD_IMAGE_DIR)/u-boot-spl $(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/
	cp -f $(DOCKER_SD_IMAGE_DIR)/qspi_helper.hps.jic $(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/
	cp -f $(DOCKER_SD_IMAGE_DIR)/ghrd.hps.jic $(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/
	cp -f $(DOCKER_SD_IMAGE_DIR)/ghrd.core.rbf $(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/
	cp -f $(DOCKER_SD_IMAGE_DIR)/ghrd.hps.rbf $(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/


###############################################################################
# Define the mandatory targets for this module (clean-sw, build-sw, install-sw)
###############################################################################

# Clean target (clean-sw)
.PHONY: clean-sw
clean-sw:
	cd software/docker_linux && ./clean_build.sh

# Build target (build-sw)
.PHONY: build-sw
build-sw: $(DOCKER_SD_WIC)

# Install target (install-sw)
DOCKER_SD_INSTALL_FILES := \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/sdimage.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/sdimage.tar.gz.md5sum \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/console-image-minimal-$(KAS_MACHINE).rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/console-image-minimal-$(KAS_MACHINE).rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/gsrd-console-image-$(KAS_MACHINE).rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/gsrd-console-image-$(KAS_MACHINE).rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/Image \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/kernel.itb \
	$(DOCKER_SD_OPTIONAL_DTB) \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/u-boot-spl-dtb.bin \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/u-boot-spl-dtb.hex \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/boot.scr.uimg \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/u-boot.itb \
	$(INSTALL_ROOT_BINARIES)/software/docker_linux_sd/uboot.env \
	$(INSTALL_ROOT_BINARIES)/$(REVISION)_docker_linux_sd.sof

.PHONY: install-sw
install-sw : \
	$(DOCKER_SD_INSTALL_FILES) \
	docker-sd-postprocess \
	$(addprefix $(INSTALL_ROOT_ARTIFACTS)/software/docker_linux_sd/, $(DOCKER_SD_ARTIFACT_FILES))
