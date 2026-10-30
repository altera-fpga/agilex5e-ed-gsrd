# Yocto Linux Mainline QSPI Build
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
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before yocto_linux_mainline_qspi.mk was parsed)
endif

ifeq ($(strip $(INSTALL_ROOT_ARTIFACTS)),)
$(error ERROR: INSTALL_ROOT_ARTIFACTS was not defined before yocto_linux_mainline_qspi.mk was parsed)
endif

ifeq ($(strip $(REVISION)),)
$(error ERROR: REVISION was not set. Pass REVISION=<revision> on the command line)
endif

include $(THIS_MK_DIR)/yocto_linux_mainline_kas.mk

ifdef KAS_CUSTOM_LINUX_DTB
  YOCTO_MAINLINE_QSPI_OPTIONAL_DTB := $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/$(KAS_CUSTOM_LINUX_DTB)
else
  YOCTO_MAINLINE_QSPI_OPTIONAL_DTB :=
endif

include $(THIS_MK_DIR)/sw_build_common.mk

###############################################################################
#                           SW Build Targets
###############################################################################

YOCTO_MAINLINE_QSPI_IMAGE_DIR := software/yocto_linux_mainline/build/tmp/deploy/images/$(KAS_MACHINE)

$(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/console-image-minimal-$(KAS_MACHINE).rootfs_nor.ubifs \
$(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/u-boot-spl-dtb.hex: output_files/$(REVISION).core.rbf
	cd software/yocto_linux_mainline && ./build.sh $(abspath $<) qspi

# Yocto Linux Mainline FSBL insertion into the SOF
output_files/%_yocto_linux_mainline_qspi.sof : output_files/%.sof $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/console-image-minimal-$(KAS_MACHINE).rootfs_nor.ubifs
	quartus_pfg -c -o hps_path=$(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/u-boot-spl-dtb.hex $< $@

# Copy the SOF files to the install directory
$(INSTALL_ROOT_BINARIES)/%_yocto_linux_mainline_qspi.sof : output_files/%_yocto_linux_mainline_qspi.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@

# Copy the Yocto Linux images to the install directory
$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/%: $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/% | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	cp -f $< $@

# Copy required files to artifacts directory
YOCTO_MAINLINE_QSPI_ARTIFACT_FILES := \
	u-boot-spl \
	u-boot-spl.dtb \
	u-boot-spl.map \
	u-boot \
	u-boot.dtb \
	$(KAS_LINUX_DTB) \
	console-image-minimal-$(KAS_MACHINE).rootfs.cpio.gz.u-boot

$(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_mainline_qspi/%: $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/% | $(INSTALL_ROOT_ARTIFACTS)
	mkdir -p $(dir $@)
	cp -f $< $@

.PHONY: mainline-qspi-postprocess
mainline-qspi-postprocess: output_files/$(REVISION)_yocto_linux_mainline_qspi.sof output_files/$(REVISION).sof
	cp -f software/yocto_linux_mainline/scripts/* $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)
	cp -f output_files/$(REVISION)_yocto_linux_mainline_qspi.sof $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)
	cp -f output_files/$(REVISION).sof $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)

	# run uboot script, create UBI images and run quartus_pfg
	cd $(YOCTO_MAINLINE_QSPI_IMAGE_DIR) && \
		./uboot_bin.sh && \
		ubinize -o hps.bin -p 65536 -m 1 -s 1 ubinize_nor.cfg && \
		cp $(REVISION)_yocto_linux_mainline_qspi.sof ghrd.sof && \
		quartus_pfg -c qspi_boot.pfg && \
		quartus_pfg -o hps=ON -c -o hps_path=u-boot-spl-dtb.hex $(REVISION).sof ghrd.rbf

	mkdir -p $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi
	cp -f $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/hps.bin $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/
	cp -f $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/qspi_boot.pfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/
	cp -f $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/uboot_bin.sh $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/
	cp -f $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/u-boot.bin $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/
	cp -f $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/u-boot-spl $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/
	cp -f $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/ubinize_nor.cfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/
	echo 'ubinize -o hps.bin -p 65536 -m 1 -s 1 ubinize_nor.cfg' > $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/ubinize.txt
	cp -f $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/qspi_boot.hps.jic $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/
	cp -f $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/qspi_boot.rpd $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/
	cp -f $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/ghrd.core.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/
	cp -f $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/ghrd.hps.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/

.PHONY: clean-sw
clean-sw:
	cd software/yocto_linux_mainline && ./clean_build.sh

.PHONY: build-sw
build-sw: $(YOCTO_MAINLINE_QSPI_IMAGE_DIR)/console-image-minimal-$(KAS_MACHINE).rootfs_nor.ubifs

YOCTO_MAINLINE_QSPI_INSTALL_FILES := \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/console-image-minimal-$(KAS_MACHINE).rootfs_nor.ubifs \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/console-image-minimal-$(KAS_MACHINE).rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/console-image-minimal-$(KAS_MACHINE).rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/console-image-minimal-$(KAS_MACHINE).rootfs.jffs2 \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/Image \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/kernel.itb \
	$(YOCTO_MAINLINE_QSPI_OPTIONAL_DTB) \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/u-boot-spl-dtb.bin \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/u-boot-spl-dtb.hex \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/boot.scr.uimg \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/u-boot.itb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_mainline_qspi/uboot.env \
	$(INSTALL_ROOT_BINARIES)/$(REVISION)_yocto_linux_mainline_qspi.sof

.PHONY: install-sw
install-sw : \
	$(YOCTO_MAINLINE_QSPI_INSTALL_FILES) \
	mainline-qspi-postprocess \
	$(addprefix $(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_mainline_qspi/, $(YOCTO_MAINLINE_QSPI_ARTIFACT_FILES))
