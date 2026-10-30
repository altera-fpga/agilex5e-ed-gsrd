# HPS AMP Bao Build (linux_freertos config)
# Required inputs: REVISION, INSTALL_ROOT_BINARIES, INSTALL_ROOT_ARTIFACTS
# Entry targets: clean-sw, build-sw, install-sw
# Board vars from sw_build_common.mk: FLASH_LOADER (QSPI JIC)

THIS_MK_ABSPATH := $(abspath $(lastword $(MAKEFILE_LIST)))
THIS_MK_DIR := $(dir $(THIS_MK_ABSPATH))

# Enable pipefail for all commands
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

# Enable second expansion
.SECONDEXPANSION:

# Clear all built in suffixes
.SUFFIXES:

ifeq ($(strip $(REVISION)),)
$(error ERROR: REVISION was not set. Pass REVISION=<revision> on the command line)
endif

ifeq ($(strip $(INSTALL_ROOT_BINARIES)),)
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before amp_bao_linux_freertos.mk was parsed)
endif

ifeq ($(strip $(INSTALL_ROOT_ARTIFACTS)),)
$(error ERROR: INSTALL_ROOT_ARTIFACTS was not defined before amp_bao_linux_freertos.mk was parsed)
endif

include $(THIS_MK_DIR)/sw_build_common.mk

BAO_CONFIG := linux_freertos
BAO_SOLUTION_DIR := software/amp_bao
BAO_FPGA_RBF ?= $(abspath $(THIS_MK_DIR)../output_files/$(REVISION).core.rbf)

BAO_OUT         := $(BAO_SOLUTION_DIR)/build/$(BAO_CONFIG)/out
BAO_SCRIPTS     := $(BAO_SOLUTION_DIR)/scripts
BAO_SPL_HEX     := $(BAO_OUT)/u-boot-spl-dtb.hex
BAO_INSTALL_BIN := $(INSTALL_ROOT_BINARIES)/software/amp_bao/$(BAO_CONFIG)

BAO_BINARIES := \
	sdimage.img.tar.gz \
	sdimage.img.tar.gz.md5sum \
	Image \
	linux.bin \
	u-boot.itb \
	bao.bin \
	linux.dtb \
	u-boot-spl-dtb.hex \
	boot.scr.uimg

BAO_ARTIFACTS := \
	freertos.elf \
	freertos.bin \
	bl31.bin \
	rootfs.ext4 \
	u-boot-spl \
	u-boot-spl.dtb \
	u-boot-spl.map \
	u-boot

$(BAO_OUT)/sdimage.img:
	$(MAKE) -C $(BAO_SOLUTION_DIR) CONFIG=$(BAO_CONFIG) \
	    $(if $(wildcard $(BAO_FPGA_RBF)),FPGA_RBF=$(BAO_FPGA_RBF)) sdcard

$(INSTALL_ROOT_BINARIES)/software/amp_bao/$(BAO_CONFIG)/%: \
        $(BAO_OUT)/sdimage.img | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	cp -f $(BAO_OUT)/$* $@

$(INSTALL_ROOT_BINARIES)/software/amp_bao/$(BAO_CONFIG)/boot.scr.uimg: \
        $(BAO_OUT)/sdimage.img | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	cp -f $(BAO_OUT)/boot.scr $@

$(INSTALL_ROOT_BINARIES)/software/amp_bao/$(BAO_CONFIG)/sdimage.img.tar.gz: \
        $(BAO_OUT)/sdimage.img | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	tar -chzf $@ -C $(BAO_OUT) sdimage.img

$(INSTALL_ROOT_BINARIES)/software/amp_bao/$(BAO_CONFIG)/sdimage.img.tar.gz.md5sum: \
        $(INSTALL_ROOT_BINARIES)/software/amp_bao/$(BAO_CONFIG)/sdimage.img.tar.gz
	cd $(dir $@) && md5sum $(notdir $(basename $@)) > $(notdir $@)

$(INSTALL_ROOT_ARTIFACTS)/software/amp_bao/$(BAO_CONFIG)/%: \
        $(BAO_OUT)/sdimage.img | $(INSTALL_ROOT_ARTIFACTS)
	mkdir -p $(dir $@)
	cp -f $(BAO_OUT)/$* $@

# FSBL insertion into SOF
output_files/%_amp_bao_linux_freertos.sof : output_files/%.sof $(BAO_OUT)/sdimage.img
	quartus_pfg -c -o hps_path=$(BAO_SPL_HEX) $< $@

$(INSTALL_ROOT_BINARIES)/%_amp_bao_linux_freertos.sof : output_files/%_amp_bao_linux_freertos.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@

.PHONY: amp-bao-linux-freertos-postprocess
amp-bao-linux-freertos-postprocess: output_files/$(REVISION)_amp_bao_linux_freertos.sof output_files/$(REVISION).sof
	cp -f $(BAO_SCRIPTS)/qspi_helper.pfg $(BAO_SCRIPTS)/uboot_bin.sh $(BAO_OUT)/
	chmod +x $(BAO_OUT)/uboot_bin.sh
	cp -f output_files/$(REVISION)_amp_bao_linux_freertos.sof $(BAO_OUT)/
	cp -f output_files/$(REVISION).sof $(BAO_OUT)/

	# run uboot script and quartus_pfg to generate uboot only JIC
	cd $(BAO_OUT) && \
		./uboot_bin.sh && \
		cp $(REVISION)_amp_bao_linux_freertos.sof ghrd.sof && \
		quartus_pfg -c qspi_helper.pfg && \
		quartus_pfg -c ghrd.sof ghrd.jic -o device=MT25QU128 -o flash_loader=$(FLASH_LOADER) -o hps_path=u-boot-spl-dtb.hex -o mode=ASX4 -o hps=1 && \
		quartus_pfg -o hps=ON -c -o hps_path=u-boot-spl-dtb.hex $(REVISION).sof ghrd.rbf

	mkdir -p $(BAO_INSTALL_BIN)
	cp -f $(BAO_OUT)/qspi_helper.pfg $(BAO_INSTALL_BIN)/
	cp -f $(BAO_OUT)/uboot_bin.sh $(BAO_INSTALL_BIN)/
	cp -f $(BAO_OUT)/u-boot.bin $(BAO_INSTALL_BIN)/
	cp -f $(BAO_OUT)/u-boot-spl $(BAO_INSTALL_BIN)/
	cp -f $(BAO_OUT)/qspi_helper.hps.jic $(BAO_INSTALL_BIN)/
	cp -f $(BAO_OUT)/ghrd.hps.jic $(BAO_INSTALL_BIN)/
	cp -f $(BAO_OUT)/ghrd.core.rbf $(BAO_INSTALL_BIN)/
	cp -f $(BAO_OUT)/ghrd.hps.rbf $(BAO_INSTALL_BIN)/

.PHONY: clean-sw
clean-sw:
	$(MAKE) -C $(BAO_SOLUTION_DIR) CONFIG=$(BAO_CONFIG) clean

.PHONY: build-sw
build-sw: $(BAO_OUT)/sdimage.img

.PHONY: install-sw
install-sw: \
	$(addprefix $(INSTALL_ROOT_BINARIES)/software/amp_bao/$(BAO_CONFIG)/, $(BAO_BINARIES)) \
	$(addprefix $(INSTALL_ROOT_ARTIFACTS)/software/amp_bao/$(BAO_CONFIG)/, $(BAO_ARTIFACTS)) \
	$(INSTALL_ROOT_BINARIES)/$(REVISION)_amp_bao_linux_freertos.sof \
	amp-bao-linux-freertos-postprocess
