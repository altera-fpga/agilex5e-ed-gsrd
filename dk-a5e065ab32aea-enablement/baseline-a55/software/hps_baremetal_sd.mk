# HPS Baremetal Enablement - DDR, SD boot
# Required inputs: REVISION, INSTALL_ROOT_BINARIES
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

# Inputs validation
ifeq ($(strip $(REVISION)),)
$(error ERROR: REVISION was not set. Pass REVISION=<revision> on the command line)
endif

ifeq ($(strip $(INSTALL_ROOT_BINARIES)),)
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before hps_baremetal_sd.mk was parsed)
endif

# Derived variables
BAREMETAL_SRC_DIR := software/hps_baremetal/baremetal_ddr
# build.sh (BOOT_SOURCE=sd) produces build_sd/hps_baremetal.elf and, when the SD
# tools + FPGA SOF are available, build_sd/hps_baremetal.hps.sd.img plus the SD
# FSBL SOF build_sd/sd_binaries/fsbl_sd.sof. The outputs are copied next to the
# sources as baremetal.elf / baremetal.hps.sd.img / fsbl_sd.sof.
BAREMETAL_BUILD_DIR := $(BAREMETAL_SRC_DIR)/build_sd
BAREMETAL_BUILT_ELF := $(BAREMETAL_BUILD_DIR)/hps_baremetal.elf
BAREMETAL_BUILT_SD  := $(BAREMETAL_BUILD_DIR)/hps_baremetal.hps.sd.img
BAREMETAL_BUILT_FSBL_SOF := $(BAREMETAL_BUILD_DIR)/sd_binaries/fsbl_sd.sof
BAREMETAL_OUT_NAME := baremetal.elf
BAREMETAL_SD_OUT_NAME  := baremetal.hps.sd.img
BAREMETAL_FSBL_SOF_OUT_NAME := fsbl_sd.sof
# FPGA SOF the boot image is assembled from (produced by the Quartus compile).
# The SOF name is owned here (not in build.sh) and passed down as SOF_PATH.
BAREMETAL_SOF := output_files/$(REVISION).sof
# hps_debug SOF used as the base for the SD FSBL SOF. Passed to build.sh as
# HPS_DEBUG_SOF; build.sh falls back to BAREMETAL_SOF if this file is absent,
# so it is not a hard prerequisite.
BAREMETAL_DEBUG_SOF := output_files/$(REVISION)_hps_debug.sof

# Clean target (clean-sw)
.PHONY: clean-sw
clean-sw:
	@echo "--- Cleaning HPS Baremetal (SD) ---"
	cd $(BAREMETAL_SRC_DIR) && rm -rf build_sd $(BAREMETAL_OUT_NAME) $(BAREMETAL_SD_OUT_NAME) $(BAREMETAL_FSBL_SOF_OUT_NAME)

# Build target (build-sw)
.PHONY: build-sw
build-sw: $(BAREMETAL_SRC_DIR)/$(BAREMETAL_OUT_NAME)

# Depends on the key inputs (sources/config) and the FPGA SOF so the SD card
# image and SD FSBL SOF can be assembled.
$(BAREMETAL_SRC_DIR)/$(BAREMETAL_OUT_NAME): \
		$(BAREMETAL_SRC_DIR)/main.c \
		$(BAREMETAL_SRC_DIR)/CMakeLists_sd.txt \
		$(BAREMETAL_SRC_DIR)/build.sh \
		$(BAREMETAL_SOF)
	@echo "--- Building HPS Baremetal Source (SD) ---"
	cd $(BAREMETAL_SRC_DIR) && \
		SOF_PATH=$(abspath $(BAREMETAL_SOF)) \
		SOF_NAME=$(REVISION).sof \
		HPS_DEBUG_SOF=$(abspath $(BAREMETAL_DEBUG_SOF)) \
		./build.sh sd
	cp -f $(BAREMETAL_BUILT_ELF) $@
	@# SD image and SD FSBL SOF are optional (skipped when the SD tools/guestfish
	@# are unavailable).
	@if [ -f $(BAREMETAL_BUILT_SD) ]; then \
		cp -f $(BAREMETAL_BUILT_SD) $(BAREMETAL_SRC_DIR)/$(BAREMETAL_SD_OUT_NAME); \
		echo "--- Copied $(BAREMETAL_SD_OUT_NAME) ---"; \
	else \
		echo "--- No SD image produced; skipping $(BAREMETAL_SD_OUT_NAME) ---"; \
	fi
	@if [ -f $(BAREMETAL_BUILT_FSBL_SOF) ]; then \
		cp -f $(BAREMETAL_BUILT_FSBL_SOF) $(BAREMETAL_SRC_DIR)/$(BAREMETAL_FSBL_SOF_OUT_NAME); \
		echo "--- Copied $(BAREMETAL_FSBL_SOF_OUT_NAME) ---"; \
	else \
		echo "--- No SD FSBL SOF produced; skipping $(BAREMETAL_FSBL_SOF_OUT_NAME) ---"; \
	fi

# Install target (install-sw)
BAREMETAL_INSTALL_ELF := \
	$(INSTALL_ROOT_BINARIES)/software/hps_baremetal/$(BAREMETAL_OUT_NAME)
BAREMETAL_INSTALL_SD := \
	$(INSTALL_ROOT_BINARIES)/software/hps_baremetal/$(BAREMETAL_SD_OUT_NAME)
BAREMETAL_INSTALL_FSBL_SOF := \
	$(INSTALL_ROOT_BINARIES)/software/hps_baremetal/$(BAREMETAL_FSBL_SOF_OUT_NAME)

.PHONY: install-sw
install-sw: $(BAREMETAL_INSTALL_ELF)
	@# SD image / SD FSBL SOF are optional (built only when a SOF and the SD tools
	@# are available); install each that is present so install-sw doesn't fail on
	@# an ELF-only build.
	@if [ -f $(BAREMETAL_SRC_DIR)/$(BAREMETAL_SD_OUT_NAME) ]; then \
		mkdir -p $(dir $(BAREMETAL_INSTALL_SD)); \
		cp -f $(BAREMETAL_SRC_DIR)/$(BAREMETAL_SD_OUT_NAME) $(BAREMETAL_INSTALL_SD); \
		echo "--- Installed $(BAREMETAL_SD_OUT_NAME) ---"; \
	else \
		echo "--- No SD image to install; skipping $(BAREMETAL_SD_OUT_NAME) ---"; \
	fi
	@if [ -f $(BAREMETAL_SRC_DIR)/$(BAREMETAL_FSBL_SOF_OUT_NAME) ]; then \
		mkdir -p $(dir $(BAREMETAL_INSTALL_FSBL_SOF)); \
		cp -f $(BAREMETAL_SRC_DIR)/$(BAREMETAL_FSBL_SOF_OUT_NAME) $(BAREMETAL_INSTALL_FSBL_SOF); \
		echo "--- Installed $(BAREMETAL_FSBL_SOF_OUT_NAME) ---"; \
	else \
		echo "--- No SD FSBL SOF to install; skipping $(BAREMETAL_FSBL_SOF_OUT_NAME) ---"; \
	fi

$(BAREMETAL_INSTALL_ELF): $(BAREMETAL_SRC_DIR)/$(BAREMETAL_OUT_NAME) | $(INSTALL_ROOT_BINARIES)
	@mkdir -p $(dir $@)
	cp -f $< $@
