# HPS Debug Build
# Required inputs: REVISION, INSTALL_ROOT_BINARIES
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

# Inputs validation
ifeq ($(strip $(REVISION)),)
$(error ERROR: REVISION was not set. Pass REVISION=<revision> on the command line)
endif

ifeq ($(strip $(INSTALL_ROOT_BINARIES)),)
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before hps_debug.mk was parsed)
endif

$(REVISION)-install-sof : $(INSTALL_ROOT_BINARIES)/$(REVISION)_hps_debug.sof

# Build the SW
software/hps_debug/hps_wipe.ihex:
	cd software/hps_debug && ./build.sh

# HPS Debug FSBL insertion into the SOF
# Create the debug SOF specific SOFs using the hps_debug SW
output_files/%_hps_debug.sof : output_files/%.sof software/hps_debug/hps_wipe.ihex
	quartus_pfg -c -o hps_path=software/hps_debug/hps_wipe.ihex $< $@

$(INSTALL_ROOT_BINARIES)/%_hps_debug.sof : output_files/%_hps_debug.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@

###############################################################################
# Define the mandatory targets for this module (clean-sw, build-sw, install-sw, install-sof)
###############################################################################
.PHONY: clean-sw
clean-sw:
	cd software/hps_debug && ./clean_build.sh

.PHONY: build-sw
build-sw : software/hps_debug/hps_wipe.ihex

.PHONY: install-sw
install-sw : install-sof

.PHONY: install-sof
install-sof : $(INSTALL_ROOT_BINARIES)/$(REVISION)_hps_debug.sof
