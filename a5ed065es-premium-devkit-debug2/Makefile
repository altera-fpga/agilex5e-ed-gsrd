THIS_MK_ABSPATH := $(abspath $(lastword $(MAKEFILE_LIST)))
THIS_MK_DIR := $(dir $(THIS_MK_ABSPATH))

# Enable pipefail for all commands
SHELL=/bin/bash -o pipefail

# Enable second expansion
.SECONDEXPANSION:

# Clear all built in suffixes
.SUFFIXES:

NOOP :=
SPACE := $(NOOP) $(NOOP)
COMMA := ,
HOSTNAME := $(shell hostname)

##############################################################################
# Environment check
##############################################################################

##############################################################################
# Configuration
##############################################################################
# Platform name should be the name of this directory
PLATFORM_NAME ?= $(lastword $(subst /, ,$(abspath $(THIS_MK_DIR))))

# Set defaults
INSTALL_ROOT_BINARIES ?= $(THIS_MK_DIR)/install/designs
INSTALL_ROOT_DESIGNS ?= $(THIS_MK_DIR)/install/binaries
INSTALL_ROOT_ARTIFACTS ?= $(THIS_MK_DIR)/install/artifacts

##############################################################################
# Set default goal before any targets. The default goal here is "test"
##############################################################################
DEFAULT_TARGET := test

.DEFAULT_GOAL := default
.PHONY: default
default: $(DEFAULT_TARGET)

##############################################################################
# Makefile starts here
##############################################################################

# Initialize variables
ALL_TARGET_STEM_NAMES =
ALL_PRE_PREP_TARGETS =
ALL_PREP_TARGETS =
ALL_IP_UPGRADE_TARGETS =
ALL_PACKAGE_DESIGNS_TARGETS =
ALL_BUILD_TARGETS =
ALL_TEST_TARGETS =
ALL_INSTALL_TARGETS =

ALL_SW_TARGET_STEM_NAMES =
ALL_SW_BUILD_TARGETS =

# Define function to create targets
define create_targets_on_subdir
ALL_TARGET_STEM_NAMES += $(strip $(1))
ALL_PRE_PREP_TARGETS += $(strip $(1))-pre-prep
ALL_PREP_TARGETS += $(strip $(1))-prep
ALL_IP_UPGRADE_TARGETS += $(strip $(1))-ip-upgrade
ALL_GENERATE_DESIGN_TARGETS += $(strip $(1))-generate-design
ALL_PACKAGE_DESIGN_TARGETS += $(strip $(1))-package-designs
ALL_BUILD_TARGETS += $(strip $(1))-build
ALL_TEST_TARGETS += $(strip $(1))-test
ALL_INSTALL_TARGETS += $(strip $(1))-install

$(strip $(1))-pre-prep :
	$(MAKE) --no-print-directory -C $(strip $(1)) pre-prep

$(strip $(1))-package-design :
	$(MAKE) --no-print-directory -C $(strip $(1)) package-design ARCHIVE_NAME=$(PLATFORM_NAME)-$(strip $(1)) INSTALL_ROOT_DESIGNS=$(INSTALL_ROOT_DESIGNS) INSTALL_ROOT_BINARIES=$(INSTALL_ROOT_BINARIES)/$(strip $(1)) INSTALL_ROOT_ARTIFACTS=$(INSTALL_ROOT_ARTIFACTS)/$(strip $(1))

$(strip $(1))-prep :
	$(MAKE) --no-print-directory -C $(strip $(1)) prep

$(strip $(1))-ip-upgrade :
	$(MAKE) --no-print-directory -C $(strip $(1)) ip-upgrade

$(strip $(1))-generate-design :
	$(MAKE) --no-print-directory -C $(strip $(1)) generate-design

$(strip $(1))-build :
	$(MAKE) --no-print-directory -C $(strip $(1)) build

$(strip $(1))-build-sw :

$(strip $(1))-test :
	$(MAKE) --no-print-directory -C $(strip $(1)) test

$(strip $(1))-install :
	$(MAKE) --no-print-directory -C $(strip $(1)) install ARCHIVE_NAME=$(PLATFORM_NAME)-$(strip $(1)) INSTALL_ROOT_DESIGNS=$(INSTALL_ROOT_DESIGNS) INSTALL_ROOT_BINARIES=$(INSTALL_ROOT_BINARIES)/$(strip $(1)) INSTALL_ROOT_ARTIFACTS=$(INSTALL_ROOT_ARTIFACTS)/$(strip $(1))

$(strip $(1))-install-sw :

$(strip $(1))-dev-clean :
	$(MAKE) --no-print-directory -C $(strip $(1)) dev-clean

$(strip $(1))-clean :
	$(MAKE) --no-print-directory -C $(strip $(1)) clean

$(strip $(1))-clean-sw :
	$(MAKE) --no-print-directory -C $(strip $(1)) clean-sw

endef

# Define function to create SW targets
define create_sw_targets_on_subdir
ALL_SW_TARGET_STEM_NAMES += $(strip $(1))-$(strip $(2))
ALL_SW_BUILD_TARGETS += $(strip $(1))-$(strip $(2))-build-sw

$(strip $(1))-%-build-sw :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-build-sw INSTALL_ROOT_DESIGNS=$(INSTALL_ROOT_DESIGNS) INSTALL_ROOT_BINARIES=$(INSTALL_ROOT_BINARIES)/$(strip $(1)) INSTALL_ROOT_ARTIFACTS=$(INSTALL_ROOT_ARTIFACTS)/$(strip $(1))

$(strip $(1))-%-install-sw :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-install-sw ARCHIVE_NAME=$(PLATFORM_NAME)-$(strip $(1)) INSTALL_ROOT_DESIGNS=$(INSTALL_ROOT_DESIGNS) INSTALL_ROOT_BINARIES=$(INSTALL_ROOT_BINARIES)/$(strip $(1)) INSTALL_ROOT_ARTIFACTS=$(INSTALL_ROOT_ARTIFACTS)/$(strip $(1))

$(strip $(1))-build-sw : $(strip $(1))-$(strip $(2))-build-sw

$(strip $(1))-install-sw : $(strip $(1))-$(strip $(2))-install-sw

endef

include platform_config.mk

###############################################################################
#                          UTILITY TARGETS
###############################################################################

.PHONY: print-targets
print-targets:
	$(info $(ALL_TARGET_STEM_NAMES))

.PHONY: print-sw-targets
print-sw-targets:
	$(info $(ALL_SW_TARGET_STEM_NAMES))

###############################################################################
#                                HELP
###############################################################################
.PHONY: help
help:
	$(info GHRD Build : Platform $(PLATFORM_NAME))
	$(info    Prep Targets            : $(ALL_PREP_TARGETS))
	$(info    Build Targets           : $(ALL_BUILD_TARGETS))
	$(info    Test Targets           : $(ALL_TEST_TARGETS))
