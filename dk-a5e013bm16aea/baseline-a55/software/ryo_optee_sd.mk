# Roll-your-own OPTEE SD Build
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

ifeq ($(strip $(REVISION)),)
$(error ERROR: REVISION was not set. Pass REVISION=<revision> on the command line)
endif

ifeq ($(strip $(INSTALL_ROOT_BINARIES)),)
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before ryo_optee_sd.mk was parsed)
endif

ifeq ($(strip $(INSTALL_ROOT_ARTIFACTS)),)
$(error ERROR: INSTALL_ROOT_ARTIFACTS was not defined before ryo_optee_sd.mk was parsed)
endif

RYO_OPTEE_DIR := software/ryo_optee
RYO_OPTEE_IMAGE_DIR := $(RYO_OPTEE_DIR)/sd_image
RYO_OPTEE_INSTALL_BIN_DIR := $(INSTALL_ROOT_BINARIES)/$(RYO_OPTEE_DIR)
RYO_OPTEE_INSTALL_ARTI_DIR := $(INSTALL_ROOT_ARTIFACTS)/$(RYO_OPTEE_DIR)

$(RYO_OPTEE_IMAGE_DIR)/sdcard.img:
	export PATH=$(PATH):$(abspath software/ryo_optee/genimage/bin) && cd software/ryo_optee && ./ryo_optee_sd.sh

$(RYO_OPTEE_INSTALL_BIN_DIR)/sdcard.img: $(RYO_OPTEE_IMAGE_DIR)/sdcard.img
	mkdir -p $(dir $@)
	cp -f $(RYO_OPTEE_IMAGE_DIR)/sdcard.img $@

.PHONY: install-artifacts
install-artifacts:
	mkdir -p $(RYO_OPTEE_INSTALL_BIN_DIR)
	mkdir -p $(RYO_OPTEE_INSTALL_ARTI_DIR)
	cp $(RYO_OPTEE_DIR)/optee_os/out/agilex5/core/tee-pager_v2.bin $(RYO_OPTEE_INSTALL_ARTI_DIR)/tee-pager_v2.bin
	cp $(RYO_OPTEE_DIR)/arm-trusted-firmware/build/agilex5/release/bl31.bin $(RYO_OPTEE_INSTALL_BIN_DIR)/bl31.bin
	cp $(RYO_OPTEE_DIR)/u-boot-socfpga/u-boot.itb $(RYO_OPTEE_INSTALL_ARTI_DIR)/u-boot.itb
	cp $(RYO_OPTEE_DIR)/u-boot-socfpga/spl/u-boot-spl-dtb.hex $(RYO_OPTEE_INSTALL_ARTI_DIR)/u-boot-spl-dtb.hex
	cp $(RYO_OPTEE_DIR)/u-boot-socfpga/spl/u-boot-spl-dtb.hex $(RYO_OPTEE_INSTALL_BIN_DIR)/u-boot-spl-dtb.hex
	cp $(RYO_OPTEE_DIR)/linux-socfpga/arch/arm64/boot/Image $(RYO_OPTEE_INSTALL_ARTI_DIR)/Image
	cp $(RYO_OPTEE_DIR)/linux-socfpga/arch/arm64/boot/dts/intel/socfpga_agilex5_socdk_013b.dtb $(RYO_OPTEE_INSTALL_ARTI_DIR)/socfpga_agilex5_socdk_013b.dtb
	cp $(RYO_OPTEE_DIR)/ghrd_sd.hps.jic $(RYO_OPTEE_INSTALL_BIN_DIR)/ghrd_sd.hps.jic

.PHONY: clean-sw
clean-sw:
	cd software/ryo_optee && ./clean_build.sh

.PHONY: build-sw
build-sw: $(RYO_OPTEE_IMAGE_DIR)/sdcard.img

.PHONY: install-sw
install-sw: $(RYO_OPTEE_INSTALL_BIN_DIR)/sdcard.img install-artifacts
