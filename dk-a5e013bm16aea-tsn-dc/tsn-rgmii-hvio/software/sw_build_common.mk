THIS_MK_ABSPATH := $(abspath $(lastword $(MAKEFILE_LIST)))
THIS_MK_DIR := $(dir $(THIS_MK_ABSPATH))

# Enable pipefail for all commands
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

# Enable second expansion
.SECONDEXPANSION:

# Clear all built in suffixes
.SUFFIXES:

# ---------------------------------------------------------------------------
# Design-specific board overrides (edit these per design as needed)
# ---------------------------------------------------------------------------
# FPGA device OPN used by yocto_* JIC helper generation (quartus_pfg flash_loader)
FLASH_LOADER := A5ED013BM16AE4SCS

# QSPI Yocto image basename (console-image-minimal or core-image-minimal)
YOCTO_QSPI_IMAGE := console-image-minimal

# ---------------------------------------------------------------------------
# Shared kas / yocto variable extraction
# ---------------------------------------------------------------------------
# Extract variables from machine.yml and bsp.yml (included by kas.yml)
MACHINE_YML_PATH := software/yocto_linux/kas/machine.yml
BSP_YML_PATH := software/yocto_linux/kas/bsp.yml

# Extract MACHINE
KAS_MACHINE := $(shell grep -A 10 "machine:" $(MACHINE_YML_PATH) | grep "MACHINE" | sed -E 's/.*MACHINE = "([^"]+)".*/\1/')

# Customer-facing machine name: strip known board suffixes (noop when absent)
KAS_MACHINE_STRIP := $(shell echo "$(KAS_MACHINE)" | sed -E 's/_(013b|de25_nano)$$//')

# Extract LINUX_DTS_FILE (.dts)
KAS_LINUX_DTS_FILE := $(shell grep -A 10 "machine:" $(MACHINE_YML_PATH) | grep -E '^\s*LINUX_DTS_FILE\s*=' | sed -E 's/.*LINUX_DTS_FILE = "([^"]+)".*/\1/')

# Extract CUSTOM_LINUX_DTS_FILE (optional)
KAS_CUSTOM_LINUX_DTS_FILE := $(shell grep -A 10 "machine:" $(MACHINE_YML_PATH) | grep "CUSTOM_LINUX_DTS_FILE" | sed -E 's/.*CUSTOM_LINUX_DTS_FILE = "([^"]+)".*/\1/')

ifeq ($(strip $(KAS_MACHINE)),)
$(error ERROR: MACHINE not found in $(MACHINE_YML_PATH))
endif

ifeq ($(strip $(KAS_LINUX_DTS_FILE)),)
$(error ERROR: LINUX_DTS_FILE not found in $(MACHINE_YML_PATH))
endif

ifeq ($(strip $(FLASH_LOADER)),)
$(error ERROR: FLASH_LOADER was not set in sw_build_common.mk)
endif

ifeq ($(strip $(YOCTO_QSPI_IMAGE)),)
$(error ERROR: YOCTO_QSPI_IMAGE was not set in sw_build_common.mk)
endif

# Only convert .dts -> .dtb if the variable is set
ifeq ($(strip $(KAS_CUSTOM_LINUX_DTS_FILE)),)
  KAS_CUSTOM_LINUX_DTB :=
else
  KAS_CUSTOM_LINUX_DTB := $(basename $(KAS_CUSTOM_LINUX_DTS_FILE)).dtb
endif

# Required DTS -> DTB
KAS_LINUX_DTB := $(basename $(KAS_LINUX_DTS_FILE)).dtb

# Yocto deploy image path
KAS_YOCTO_IMAGE_DIR := software/yocto_linux/build/tmp/deploy/images/$(KAS_MACHINE)
