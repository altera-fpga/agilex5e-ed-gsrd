# HPS Baremetal Enablement - OCRAM
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
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before hps_baremetal_ocram.mk was parsed)
endif

# Derived variables
BAREMETAL_OCRAM_SRC_DIR := software/hps_baremetal/baremetal_ocram
# build.sh produces build/hps_baremetal.{elf,bin,hex}; install target expects
# baremetal.elf, baremetal.bin and baremetal.hex (the .bin/.hex are the
# OCRAM-loadable images).
BAREMETAL_OCRAM_BUILT_ELF := $(BAREMETAL_OCRAM_SRC_DIR)/build/hps_baremetal.elf
BAREMETAL_OCRAM_BUILT_BIN := $(BAREMETAL_OCRAM_SRC_DIR)/build/hps_baremetal.bin
BAREMETAL_OCRAM_BUILT_HEX := $(BAREMETAL_OCRAM_SRC_DIR)/build/hps_baremetal.hex
BAREMETAL_OCRAM_OUT_NAME := baremetal.elf
BAREMETAL_OCRAM_OUT_BIN  := baremetal.bin
BAREMETAL_OCRAM_OUT_HEX  := baremetal.hex

# Clean target (clean-sw)
.PHONY: clean-sw
clean-sw:
	@echo "--- Cleaning HPS Baremetal (OCRAM) ---"
	cd $(BAREMETAL_OCRAM_SRC_DIR) && rm -rf build $(BAREMETAL_OCRAM_OUT_NAME) $(BAREMETAL_OCRAM_OUT_BIN) $(BAREMETAL_OCRAM_OUT_HEX)

# Build target (build-sw)
.PHONY: build-sw
build-sw: $(BAREMETAL_OCRAM_SRC_DIR)/$(BAREMETAL_OCRAM_OUT_NAME) \
		$(BAREMETAL_OCRAM_SRC_DIR)/$(BAREMETAL_OCRAM_OUT_BIN) \
		$(BAREMETAL_OCRAM_SRC_DIR)/$(BAREMETAL_OCRAM_OUT_HEX)

$(BAREMETAL_OCRAM_SRC_DIR)/$(BAREMETAL_OCRAM_OUT_NAME): \
		$(BAREMETAL_OCRAM_SRC_DIR)/main.c \
		$(BAREMETAL_OCRAM_SRC_DIR)/CMakeLists.txt \
		$(BAREMETAL_OCRAM_SRC_DIR)/build.sh
	@echo "--- Building HPS Baremetal (OCRAM) ---"
	cd $(BAREMETAL_OCRAM_SRC_DIR) && ./build.sh
	cp -f $(BAREMETAL_OCRAM_BUILT_ELF) $@

# .bin/.hex are produced by the same build.sh run (bm_generate_artifacts); depend
# on the .elf so build.sh runs once, then just copy them out of build/.
$(BAREMETAL_OCRAM_SRC_DIR)/$(BAREMETAL_OCRAM_OUT_BIN): $(BAREMETAL_OCRAM_SRC_DIR)/$(BAREMETAL_OCRAM_OUT_NAME)
	cp -f $(BAREMETAL_OCRAM_BUILT_BIN) $@

$(BAREMETAL_OCRAM_SRC_DIR)/$(BAREMETAL_OCRAM_OUT_HEX): $(BAREMETAL_OCRAM_SRC_DIR)/$(BAREMETAL_OCRAM_OUT_NAME)
	cp -f $(BAREMETAL_OCRAM_BUILT_HEX) $@

# Install target (install-sw)
BAREMETAL_OCRAM_INSTALL_ELF := \
	$(INSTALL_ROOT_BINARIES)/software/hps_baremetal/baremetal_ocram/$(BAREMETAL_OCRAM_OUT_NAME)
BAREMETAL_OCRAM_INSTALL_BIN := \
	$(INSTALL_ROOT_BINARIES)/software/hps_baremetal/baremetal_ocram/$(BAREMETAL_OCRAM_OUT_BIN)
BAREMETAL_OCRAM_INSTALL_HEX := \
	$(INSTALL_ROOT_BINARIES)/software/hps_baremetal/baremetal_ocram/$(BAREMETAL_OCRAM_OUT_HEX)

.PHONY: install-sw
install-sw: $(BAREMETAL_OCRAM_INSTALL_ELF) $(BAREMETAL_OCRAM_INSTALL_BIN) $(BAREMETAL_OCRAM_INSTALL_HEX)

$(BAREMETAL_OCRAM_INSTALL_ELF): $(BAREMETAL_OCRAM_SRC_DIR)/$(BAREMETAL_OCRAM_OUT_NAME) | $(INSTALL_ROOT_BINARIES)
	@mkdir -p $(dir $@)
	cp -f $< $@

$(BAREMETAL_OCRAM_INSTALL_BIN): $(BAREMETAL_OCRAM_SRC_DIR)/$(BAREMETAL_OCRAM_OUT_BIN) | $(INSTALL_ROOT_BINARIES)
	@mkdir -p $(dir $@)
	cp -f $< $@

$(BAREMETAL_OCRAM_INSTALL_HEX): $(BAREMETAL_OCRAM_SRC_DIR)/$(BAREMETAL_OCRAM_OUT_HEX) | $(INSTALL_ROOT_BINARIES)
	@mkdir -p $(dir $@)
	cp -f $< $@
