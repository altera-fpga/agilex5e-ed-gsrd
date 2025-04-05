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
INSTALL_ROOT ?= $(THIS_MK_DIR)

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
ALL_SW_BUILD_TARGETS =
ALL_TEST_TARGETS =
ALL_INSTALL_SOF_TARGETS =

# Define function to create targets
define create_targets_on_subdir
ALL_TARGET_STEM_NAMES += $(addprefix $(strip $(1))-,$(strip $(2)))
ALL_PRE_PREP_TARGETS += $(addsuffix -pre-prep,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_PREP_TARGETS += $(addsuffix -prep,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_IP_UPGRADE_TARGETS += $(addsuffix -ip-upgrade,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_GENERATE_DESIGN_TARGETS += $(addsuffix -generate-design,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_PACKAGE_DESIGN_TARGETS += $(addsuffix -package-designs,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_BUILD_TARGETS += $(addsuffix -build,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_SW_BUILD_TARGETS += $(addsuffix -sw-build,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_TEST_TARGETS += $(addsuffix -test,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_INSTALL_SOF_TARGETS += $(addsuffix -install-sof,$(addprefix $(strip $(1))-,$(strip $(2))))

$(strip $(1))-%-pre-prep :
	$(MAKE) --no-print-directory -C $(strip $(1)) pre-prep

$(strip $(1))-%-package-design :
	$(MAKE) --no-print-directory -C $(strip $(1)) package-design ARCHIVE_NAME=$(PLATFORM_NAME)-$(strip $(1)) INSTALL_ROOT=$(INSTALL_ROOT)

$(strip $(1))-%-prep :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-prep

$(strip $(1))-%-ip-upgrade :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-ip-upgrade

$(strip $(1))-%-generate-design :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-generate-design

$(strip $(1))-%-build :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-build

$(strip $(1))-%-sw-build :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-sw-build

$(strip $(1))-%-test :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-test

$(strip $(1))-%-install-sof :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-install-sof ARCHIVE_NAME=$(PLATFORM_NAME)-$(strip $(1)) INSTALL_ROOT=$(INSTALL_ROOT)
endef

# Create rules for legacy-baseline subdir
TARGET_SUBDIR := legacy-baseline
TARGET_SUBDIR_TARGETS := $(shell make  --no-print-directory -q -C $(TARGET_SUBDIR) print-targets)
$(eval $(call create_targets_on_subdir, $(TARGET_SUBDIR), $(TARGET_SUBDIR_TARGETS)))


###############################################################################
#                          UTILITY TARGETS
###############################################################################

.PHONY: print-targets
print-targets:
	$(info $(ALL_TARGET_STEM_NAMES))


###############################################################################
#                                HELP
###############################################################################
.PHONY: help
help:
	$(info GHRD Build : Platform $(PLATFORM_NAME))
	$(info    Prep Targets            : $(ALL_PREP_TARGETS))
	$(info    Build Targets           : $(ALL_BUILD_TARGETS))
	$(info    Test Targets           : $(ALL_TEST_TARGETS))


