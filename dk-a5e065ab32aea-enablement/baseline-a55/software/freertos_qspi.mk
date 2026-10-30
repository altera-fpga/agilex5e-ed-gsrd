# FreeRTOS Hello World QSPI Build
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
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before freertos_qspi.mk was parsed)
endif

FREERTOS_TOP_FOLDER := software/freertos
HELLO_WORLD_FOLDER := $(FREERTOS_TOP_FOLDER)/hello-world-app

# build folder
BUILD_FOLDER = $(HELLO_WORLD_FOLDER)/build

# JIC/RPD files and build sentinel
HELLO_WORLD_JIC := $(BUILD_FOLDER)/fpga_binaries/qspi_image.jic
HELLO_WORLD_RPD := $(BUILD_FOLDER)/fpga_binaries/qspi_image_jic.rpd
HELLO_WORLD_BUILD_DONE := $(BUILD_FOLDER)/fpga_binaries/build.done

.PHONY: clean-sw
clean-sw:
	rm -rf $(BUILD_FOLDER)
	git clean -fdx $(HELLO_WORLD_FOLDER)

.PHONY: build-sw
build-sw: $(HELLO_WORLD_BUILD_DONE)

$(HELLO_WORLD_BUILD_DONE): output_files/$(REVISION).sof
	$(HELLO_WORLD_FOLDER)/build.sh
	touch $(HELLO_WORLD_BUILD_DONE)

.PHONY: install-sw
install-sw: \
	$(INSTALL_ROOT_BINARIES)/$(HELLO_WORLD_FOLDER)/qspi_image.jic \
	$(INSTALL_ROOT_BINARIES)/$(HELLO_WORLD_FOLDER)/qspi_image_jic.rpd

$(INSTALL_ROOT_BINARIES)/$(HELLO_WORLD_FOLDER)/qspi_image.jic: $(HELLO_WORLD_BUILD_DONE)
	mkdir -p $(dir $@)
	cp -f $(HELLO_WORLD_JIC) $@

$(INSTALL_ROOT_BINARIES)/$(HELLO_WORLD_FOLDER)/qspi_image_jic.rpd: $(HELLO_WORLD_BUILD_DONE)
	mkdir -p $(dir $@)
	cp -f $(HELLO_WORLD_RPD) $@
