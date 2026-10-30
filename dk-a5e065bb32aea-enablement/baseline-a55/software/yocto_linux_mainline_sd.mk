# Yocto Linux Mainline SD Build
# Required inputs: REVISION, INSTALL_ROOT_BINARIES, INSTALL_ROOT_ARTIFACTS
# Optional inputs: RESTORE_INSTALL
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

ifeq ($(strip $(INSTALL_ROOT_BINARIES)),)
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before yocto_linux_mainline_sd.mk was parsed)
endif

ifeq ($(strip $(INSTALL_ROOT_ARTIFACTS)),)
$(error ERROR: INSTALL_ROOT_ARTIFACTS was not defined before yocto_linux_mainline_sd.mk was parsed)
endif

ifeq ($(strip $(REVISION)),)
$(error ERROR: REVISION was not set. Pass REVISION=<revision> on the command line)
endif

include $(THIS_MK_DIR)/yocto_linux_mainline_kas.mk

ifdef KAS_CUSTOM_LINUX_DTB
  YOCTO_MAINLINE_SD_OPTIONAL_DTB := $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/$(KAS_CUSTOM_LINUX_DTB)
else
  YOCTO_MAINLINE_SD_OPTIONAL_DTB :=
endif

include $(THIS_MK_DIR)/sw_build_common.mk

###############################################################################
#                           SW Build Targets
###############################################################################

YOCTO_MAINLINE_SD_IMAGE_DIR := software/yocto_linux_mainline/build/tmp/deploy/images/$(KAS_MACHINE)
YOCTO_MAINLINE_SD_WIC       := $(YOCTO_MAINLINE_SD_IMAGE_DIR)/gsrd-console-image-$(KAS_MACHINE).rootfs.wic
YOCTO_MAINLINE_SD_SPL_HEX   := $(YOCTO_MAINLINE_SD_IMAGE_DIR)/u-boot-spl-dtb.hex

# Build the Yocto mainline image (depends on $(REVISION) RBF)
$(YOCTO_MAINLINE_SD_WIC): output_files/$(REVISION).core.rbf
	cd software/yocto_linux_mainline && ./build.sh $(abspath $<) sd

# FSBL insertion into SOF
output_files/%_yocto_linux_mainline_sd.sof : output_files/%.sof $(YOCTO_MAINLINE_SD_WIC)
	quartus_pfg -c -o hps_path=$(YOCTO_MAINLINE_SD_SPL_HEX) $< $@

# Copy SOF files to install dir
$(INSTALL_ROOT_BINARIES)/%_yocto_linux_mainline_sd.sof : output_files/%_yocto_linux_mainline_sd.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@

# Create sdimage.tar.gz from the WIC
$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/sdimage.tar.gz: $(YOCTO_MAINLINE_SD_WIC) | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	tar -chzf $@ -C $(dir $<) $(notdir $<)

# Create MD5 checksum
$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/sdimage.tar.gz.md5sum: \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/sdimage.tar.gz
	cd $(dir $@) && md5sum $(notdir $(basename $@)) > $(notdir $@)

# Copy Yocto artifacts to install dir
$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/%: $(YOCTO_MAINLINE_SD_IMAGE_DIR)/% | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	cp -f $< $@

# Copy required files to artifacts directory
YOCTO_MAINLINE_SD_ARTIFACT_FILES := \
	u-boot-spl \
	u-boot-spl.dtb \
	u-boot-spl.map \
	u-boot \
	u-boot.dtb \
	$(KAS_LINUX_DTB) \
	console-image-minimal-$(KAS_MACHINE).rootfs.cpio.gz.u-boot \
	gsrd-console-image-$(KAS_MACHINE).rootfs.cpio.gz.u-boot

$(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_mainline_sd/%: $(YOCTO_MAINLINE_SD_IMAGE_DIR)/% | $(INSTALL_ROOT_ARTIFACTS)
	mkdir -p $(dir $@)
	cp -f $< $@

.PHONY: mainline-sd-postprocess
mainline-sd-postprocess: output_files/$(REVISION)_yocto_linux_mainline_sd.sof output_files/$(REVISION).sof
	cp -f software/yocto_linux_mainline/scripts/* $(YOCTO_MAINLINE_SD_IMAGE_DIR)
	cp -f output_files/$(REVISION)_yocto_linux_mainline_sd.sof $(YOCTO_MAINLINE_SD_IMAGE_DIR)
	cp -f output_files/$(REVISION).sof $(YOCTO_MAINLINE_SD_IMAGE_DIR)

	# run uboot script and quartus_pfg to generate uboot only JIC
	cd $(YOCTO_MAINLINE_SD_IMAGE_DIR) && \
		./uboot_bin.sh && \
		cp $(REVISION)_yocto_linux_mainline_sd.sof ghrd.sof && \
		quartus_pfg -c qspi_helper.pfg && \
		quartus_pfg -c ghrd.sof ghrd.jic -o device=MT25QU128 -o flash_loader=A5ED065BB32AE4S -o hps_path=u-boot-spl-dtb.hex -o mode=ASX4 -o hps=1 && \
		quartus_pfg -o hps=ON -c -o hps_path=u-boot-spl-dtb.hex $(REVISION).sof ghrd.rbf

	mkdir -p $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd
	cp -f $(YOCTO_MAINLINE_SD_IMAGE_DIR)/qspi_helper.pfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/
	cp -f $(YOCTO_MAINLINE_SD_IMAGE_DIR)/uboot_bin.sh $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/
	cp -f $(YOCTO_MAINLINE_SD_IMAGE_DIR)/u-boot.bin $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/
	cp -f $(YOCTO_MAINLINE_SD_IMAGE_DIR)/u-boot-spl $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/
	cp -f $(YOCTO_MAINLINE_SD_IMAGE_DIR)/qspi_helper.hps.jic $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/
	cp -f $(YOCTO_MAINLINE_SD_IMAGE_DIR)/ghrd.core.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/
	cp -f $(YOCTO_MAINLINE_SD_IMAGE_DIR)/ghrd.hps.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/

.PHONY: clean-sw
clean-sw:
	cd software/yocto_linux_mainline && ./clean_build.sh

.PHONY: build-sw
build-sw: $(YOCTO_MAINLINE_SD_WIC)

YOCTO_MAINLINE_SD_INSTALL_FILES := \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/sdimage.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/sdimage.tar.gz.md5sum \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/console-image-minimal-$(KAS_MACHINE).rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/console-image-minimal-$(KAS_MACHINE).rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/gsrd-console-image-$(KAS_MACHINE).rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/gsrd-console-image-$(KAS_MACHINE).rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/Image \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/kernel.itb \
	$(YOCTO_MAINLINE_SD_OPTIONAL_DTB) \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/u-boot-spl-dtb.bin \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/u-boot-spl-dtb.hex \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/boot.scr.uimg \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/u-boot.itb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_sd/uboot.env \
	$(INSTALL_ROOT_BINARIES)/$(REVISION)_yocto_linux_mainline_sd.sof

.PHONY: install-sw
install-sw : \
	$(YOCTO_MAINLINE_SD_INSTALL_FILES) \
	mainline-sd-postprocess \
	$(addprefix $(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_mainline_sd/, $(YOCTO_MAINLINE_SD_ARTIFACT_FILES))
