# Yocto Linux NAND Build
# Required inputs: REVISION, INSTALL_ROOT_BINARIES, INSTALL_ROOT_ARTIFACTS
# Entry targets: clean-sw, build-sw, install-sw

THIS_MK_ABSPATH := $(abspath $(lastword $(MAKEFILE_LIST)))
THIS_MK_DIR := $(dir $(THIS_MK_ABSPATH))

SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
.SECONDEXPANSION:
.SUFFIXES:

ifeq ($(strip $(INSTALL_ROOT_BINARIES)),)
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before yocto_linux_nand.mk was parsed)
endif

ifeq ($(strip $(INSTALL_ROOT_ARTIFACTS)),)
$(error ERROR: INSTALL_ROOT_ARTIFACTS was not defined before yocto_linux_nand.mk was parsed)
endif

ifeq ($(strip $(REVISION)),)
$(error ERROR: REVISION was not set. Pass REVISION=<revision> on the command line)
endif

include $(THIS_MK_DIR)/sw_build_common.mk

ifdef KAS_CUSTOM_LINUX_DTB
  YOCTO_NAND_OPTIONAL_DTB := $(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/$(KAS_CUSTOM_LINUX_DTB)
else
  YOCTO_NAND_OPTIONAL_DTB :=
endif


YOCTO_NAND_IMAGE_DIR := $(KAS_YOCTO_IMAGE_DIR)

$(KAS_YOCTO_IMAGE_DIR)/console-image-minimal-$(KAS_MACHINE).rootfs_nand.ubifs \
$(KAS_YOCTO_IMAGE_DIR)/u-boot-spl-dtb.hex: output_files/$(REVISION).core.rbf
	cd software/yocto_linux && ./build.sh $(abspath $<) nand

output_files/%_yocto_linux_nand.sof : output_files/%.sof $(KAS_YOCTO_IMAGE_DIR)/console-image-minimal-$(KAS_MACHINE).rootfs_nand.ubifs
	quartus_pfg -c -o hps_path=$(KAS_YOCTO_IMAGE_DIR)/u-boot-spl-dtb.hex $< $@

$(INSTALL_ROOT_BINARIES)/%_yocto_linux_nand.sof : output_files/%_yocto_linux_nand.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@

$(INSTALL_ROOT_BINARIES)/software/yocto_linux_nand/%: $(YOCTO_NAND_IMAGE_DIR)/% | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	cp -f $< $@

YOCTO_NAND_ARTIFACT_FILES := \
	u-boot-spl \
	u-boot-spl.dtb \
	u-boot-spl.map \
	u-boot \
	u-boot.dtb \
	$(KAS_LINUX_DTB) \
	console-image-minimal-$(KAS_MACHINE).rootfs.cpio.gz.u-boot

$(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_nand/%: $(YOCTO_NAND_IMAGE_DIR)/% | $(INSTALL_ROOT_ARTIFACTS)
	mkdir -p $(dir $@)
	cp -f $< $@

.PHONY: nand-postprocess
nand-postprocess: output_files/$(REVISION)_yocto_linux_nand.sof output_files/$(REVISION).sof
	cp -f software/yocto_linux/scripts/* $(YOCTO_NAND_IMAGE_DIR)
	cp -f output_files/$(REVISION)_yocto_linux_nand.sof $(YOCTO_NAND_IMAGE_DIR)
	cp -f output_files/$(REVISION).sof $(YOCTO_NAND_IMAGE_DIR)

	cd $(YOCTO_NAND_IMAGE_DIR) && \
		./uboot_bin.sh && \
		ubinize -o root.ubi -p 1024KiB -m 8192 -s 8192 ubinize_nand.cfg && \
		cp $(REVISION)_yocto_linux_nand.sof ghrd.sof && \
		quartus_pfg -c qspi_helper.pfg && \
		quartus_pfg -c ghrd.sof ghrd.jic -o device=MT25QU128 -o flash_loader=A5ED065AB32AE1V -o hps_path=u-boot-spl-dtb.hex -o mode=ASX4 -o hps=1 && \
		quartus_pfg -o hps=ON -c -o hps_path=u-boot-spl-dtb.hex $(REVISION).sof ghrd.rbf

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

.PHONY: clean-sw
clean-sw:
	cd software/yocto_linux && ./clean_build.sh

.PHONY: build-sw
build-sw: $(KAS_YOCTO_IMAGE_DIR)/console-image-minimal-$(KAS_MACHINE).rootfs_nand.ubifs

YOCTO_NAND_INSTALL_FILES := \
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
	$(INSTALL_ROOT_BINARIES)/$(REVISION)_yocto_linux_nand.sof

.PHONY: install-sw
install-sw : \
	$(YOCTO_NAND_INSTALL_FILES) \
	nand-postprocess \
	$(addprefix $(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_nand/, $(YOCTO_NAND_ARTIFACT_FILES))
