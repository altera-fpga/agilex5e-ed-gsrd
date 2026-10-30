# Yocto Linux eMMC Build
# Required inputs: REVISION, INSTALL_ROOT_BINARIES, INSTALL_ROOT_ARTIFACTS
# Entry targets: clean-sw, build-sw, install-sw

THIS_MK_ABSPATH := $(abspath $(lastword $(MAKEFILE_LIST)))
THIS_MK_DIR := $(dir $(THIS_MK_ABSPATH))

SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c
.SECONDEXPANSION:
.SUFFIXES:

ifeq ($(strip $(INSTALL_ROOT_BINARIES)),)
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before yocto_linux_emmc.mk was parsed)
endif

ifeq ($(strip $(INSTALL_ROOT_ARTIFACTS)),)
$(error ERROR: INSTALL_ROOT_ARTIFACTS was not defined before yocto_linux_emmc.mk was parsed)
endif

ifeq ($(strip $(REVISION)),)
$(error ERROR: REVISION was not set. Pass REVISION=<revision> on the command line)
endif

include $(THIS_MK_DIR)/sw_build_common.mk

ifdef KAS_CUSTOM_LINUX_DTB
  YOCTO_EMMC_OPTIONAL_DTB := $(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/$(KAS_CUSTOM_LINUX_DTB)
else
  YOCTO_EMMC_OPTIONAL_DTB :=
endif


YOCTO_EMMC_IMAGE_DIR := $(KAS_YOCTO_IMAGE_DIR)
YOCTO_EMMC_WIC       := $(YOCTO_EMMC_IMAGE_DIR)/gsrd-console-image-$(KAS_MACHINE).rootfs.wic
YOCTO_EMMC_SPL_HEX   := $(YOCTO_EMMC_IMAGE_DIR)/u-boot-spl-dtb.hex

$(YOCTO_EMMC_WIC): output_files/$(REVISION).core.rbf
	cd software/yocto_linux && ./build.sh $(abspath $<) emmc

output_files/%_yocto_linux_emmc.sof : output_files/%.sof $(YOCTO_EMMC_WIC)
	quartus_pfg -c -o hps_path=$(YOCTO_EMMC_SPL_HEX) $< $@

$(INSTALL_ROOT_BINARIES)/%_yocto_linux_emmc.sof : output_files/%_yocto_linux_emmc.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@

$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/sdimage.tar.gz: $(YOCTO_EMMC_WIC) | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	tar -chzf $@ -C $(dir $<) $(notdir $<)

$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/sdimage.tar.gz.md5sum: \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/sdimage.tar.gz
	cd $(dir $@) && md5sum $(notdir $(basename $@)) > $(notdir $@)

$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/%: $(YOCTO_EMMC_IMAGE_DIR)/% | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	cp -f $< $@

YOCTO_EMMC_ARTIFACT_FILES := \
	u-boot-spl \
	u-boot-spl.dtb \
	u-boot-spl.map \
	u-boot \
	u-boot.dtb \
	$(KAS_LINUX_DTB) \
	console-image-minimal-$(KAS_MACHINE).rootfs.cpio.gz.u-boot \
	gsrd-console-image-$(KAS_MACHINE).rootfs.cpio.gz.u-boot

$(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_emmc/%: $(YOCTO_EMMC_IMAGE_DIR)/% | $(INSTALL_ROOT_ARTIFACTS)
	mkdir -p $(dir $@)
	cp -f $< $@

.PHONY: emmc-postprocess
emmc-postprocess: output_files/$(REVISION)_yocto_linux_emmc.sof output_files/$(REVISION).sof
	cp -f software/yocto_linux/scripts/* $(YOCTO_EMMC_IMAGE_DIR)
	cp -f output_files/$(REVISION)_yocto_linux_emmc.sof $(YOCTO_EMMC_IMAGE_DIR)
	cp -f output_files/$(REVISION).sof $(YOCTO_EMMC_IMAGE_DIR)

	cd $(YOCTO_EMMC_IMAGE_DIR) && \
		./uboot_bin.sh && \
		cp $(REVISION)_yocto_linux_emmc.sof ghrd.sof && \
		quartus_pfg -c qspi_helper.pfg && \
		quartus_pfg -c ghrd.sof ghrd.jic -o device=MT25QU128 -o flash_loader=A5ED065BB32AE6SR0 -o hps_path=u-boot-spl-dtb.hex -o mode=ASX4 -o hps=1 && \
		quartus_pfg -o hps=ON -c -o hps_path=u-boot-spl-dtb.hex $(REVISION).sof ghrd.rbf

	mkdir -p $(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc
	cp -f $(YOCTO_EMMC_IMAGE_DIR)/qspi_helper.pfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/
	cp -f $(YOCTO_EMMC_IMAGE_DIR)/uboot_bin.sh $(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/
	cp -f $(YOCTO_EMMC_IMAGE_DIR)/u-boot.bin $(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/
	cp -f $(YOCTO_EMMC_IMAGE_DIR)/u-boot-spl $(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/
	cp -f $(YOCTO_EMMC_IMAGE_DIR)/qspi_helper.hps.jic $(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/
	cp -f $(YOCTO_EMMC_IMAGE_DIR)/ghrd.hps.jic $(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/
	cp -f $(YOCTO_EMMC_IMAGE_DIR)/ghrd.core.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/
	cp -f $(YOCTO_EMMC_IMAGE_DIR)/ghrd.hps.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/

.PHONY: clean-sw
clean-sw:
	cd software/yocto_linux && ./clean_build.sh

.PHONY: build-sw
build-sw: $(YOCTO_EMMC_WIC)

YOCTO_EMMC_INSTALL_FILES := \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/sdimage.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/sdimage.tar.gz.md5sum \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/console-image-minimal-$(KAS_MACHINE).rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/console-image-minimal-$(KAS_MACHINE).rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/gsrd-console-image-$(KAS_MACHINE).rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/gsrd-console-image-$(KAS_MACHINE).rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/Image \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/kernel.itb \
	$(YOCTO_EMMC_OPTIONAL_DTB) \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/u-boot-spl-dtb.bin \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/u-boot-spl-dtb.hex \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/boot.scr.uimg \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/u-boot.itb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_emmc/uboot.env \
	$(INSTALL_ROOT_BINARIES)/$(REVISION)_yocto_linux_emmc.sof

.PHONY: install-sw
install-sw : \
	$(YOCTO_EMMC_INSTALL_FILES) \
	emmc-postprocess \
	$(addprefix $(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_emmc/, $(YOCTO_EMMC_ARTIFACT_FILES))
