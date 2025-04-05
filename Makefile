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
WORK_ROOT := $(abspath $(THIS_MK_DIR)/work)
INSTALL_RELATIVE_ROOT ?= install
INSTALL_ROOT ?= $(abspath $(THIS_MK_DIR)/$(INSTALL_RELATIVE_ROOT))

PYTHON3 ?= python3
VENV_DIR := venv
VENV_PY := $(VENV_DIR)/bin/python
VENV_PIP := $(VENV_DIR)/bin/pip
ifneq ($(https_proxy),)
PIP_PROXY := --proxy $(https_proxy)
else
PIP_PROXY :=
endif
VENV_PIP_INSTALL := $(VENV_PIP) install $(PIP_PROXY) --timeout 90 --trusted-host pypi.org --trusted-host files.pythonhosted.org

##############################################################################
# Set default goal before any targets. The default goal here is "test"
##############################################################################
DEFAULT_TARGET := all

.DEFAULT_GOAL := default
.PHONY: default
default: $(DEFAULT_TARGET)


##############################################################################
# Makefile starts here
##############################################################################


###############################################################################
#                          Design Targets
###############################################################################

# Initialize variables
ALL_TARGET_STEM_NAMES =
ALL_PRE_PREP_TARGETS =
ALL_PREP_TARGETS =
ALL_IP_UPGRADE_TARGETS =
ALL_GENERATE_DESIGN_TARGETS =
ALL_PACKAGE_DESIGN_TARGETS =
ALL_BUILD_TARGETS =
ALL_SW_BUILD_TARGETS =
ALL_TEST_TARGETS =
ALL_INSTALL_SOF_TARGETS =
ALL_TARGET_ALL_NAMES =

# Define function to create targets
define create_targets_on_subdir
ALL_TARGET_STEM_NAMES += $(addprefix $(strip $(1))-,$(strip $(2)))
ALL_PRE_PREP_TARGETS += $(addsuffix -pre-prep,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_PREP_TARGETS += $(addsuffix -prep,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_IP_UPGRADE_TARGETS += $(addsuffix -ip-upgrade,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_GENERATE_DESIGN_TARGETS += $(addsuffix -generate-design,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_PACKAGE_DESIGN_TARGETS += $(addsuffix -package-design,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_BUILD_TARGETS += $(addsuffix -build,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_SW_BUILD_TARGETS += $(addsuffix -sw-build,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_TEST_TARGETS += $(addsuffix -test,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_INSTALL_SOF_TARGETS += $(addsuffix -install-sof,$(addprefix $(strip $(1))-,$(strip $(2))))
ALL_TARGET_ALL_NAMES += $(addsuffix -all,$(addprefix $(strip $(1))-,$(strip $(2))))


$(strip $(1))-%-pre-prep : venv
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-pre-prep

$(strip $(1))-%-prep : venv
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-prep

$(strip $(1))-%-ip-upgrade : venv
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-ip-upgrade

$(strip $(1))-%-generate-design : venv
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-generate-design

$(strip $(1))-%-package-design :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-package-design INSTALL_ROOT=$(INSTALL_ROOT)/$(strip $(3))

$(strip $(1))-%-build :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-build

$(strip $(1))-%-sw-build :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-sw-build

$(strip $(1))-%-test :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-test

$(strip $(1))-%-install-sof :
	$(MAKE) --no-print-directory -C $(strip $(1)) $$*-install-sof INSTALL_ROOT=$(INSTALL_ROOT)/$(strip $(3))

.PHONY: $(addsuffix -all,$(addprefix $(strip $(1))-,$(strip $(2))))
$(addsuffix -all,$(addprefix $(strip $(1))-,$(strip $(2)))): venv
	$(MAKE) $(addsuffix -pre-prep,$(addprefix $(strip $(1))-,$(strip $(2))))
	$(MAKE) $(addsuffix -generate-design,$(addprefix $(strip $(1))-,$(strip $(2))))
	$(MAKE) $(addsuffix -package-design,$(addprefix $(strip $(1))-,$(strip $(2))))
	$(MAKE) $(addsuffix -prep,$(addprefix $(strip $(1))-,$(strip $(2))))
	$(MAKE) $(addsuffix -build,$(addprefix $(strip $(1))-,$(strip $(2))))
	$(MAKE) $(addsuffix -sw-build,$(addprefix $(strip $(1))-,$(strip $(2))))
	$(MAKE) $(addsuffix -test,$(addprefix $(strip $(1))-,$(strip $(2))))
	$(MAKE) $(addsuffix -install-sof,$(addprefix $(strip $(1))-,$(strip $(2))))

endef

# Create rules for subdirs
TARGET_SUBDIR := \
	a5ed065es-premium-devkit-oobe \
	a5ed065es-premium-devkit-nand \
	a5ed065es-premium-devkit-emmc \
	a5ed065es-premium-devkit-debug2 \
	a5ed065es-modular-devkit-som

# Create the subdir recipes by recurinsively calling the create_targets_on_subdir on each TARGET_SUBDIR
define create_subdir_targets
$(foreach target, $(shell make  --no-print-directory -q -C $(1) print-targets), $(eval $(call create_targets_on_subdir, $(1), $(target), designs)))
endef
$(foreach subdir,$(TARGET_SUBDIR),$(eval $(call create_subdir_targets,$(subdir))))

###############################################################################
#                          UTILITY TARGETS
###############################################################################
# Deep clean using git
.PHONY: dev-clean
dev-clean :
	rm -rf $(INSTALL_ROOT) $(WORK_ROOT)
	git clean -dfx --exclude=/.vscode --exclude=.lfsconfig

# Using git
.PHONY: dev-update
dev-update :
	git pull
	git submodule update --init --recursive

.PHONY: clean
clean:
	rm -rf $(INSTALL_ROOT) $(WORK_ROOT)
	git clean -dfx --exclude=/.vscode --exclude=.lfsconfig --exclude=$(VENV_DIR)

# Prep workspace
venv:
	$(PYTHON3) -m venv $(VENV_DIR)
	$(VENV_PIP_INSTALL) --upgrade pip
	$(VENV_PIP_INSTALL) -r requirements.txt


.PHONY: venv-freeze
venv-freeze:
	$(VENV_PIP) freeze > requirements.txt
	sed -i -e 's/==/~=/g' requirements.txt

.PHONY: prepare-tools
prepare-tools : venv

# Include not_shipped Makefile if present
-include not_shipped/Makefile.mk

###############################################################################
#                          Toplevel Targets
###############################################################################
.PHONY: pre-prep
pre-prep: $(ALL_PRE_PREP_TARGETS)

.PHONY: prep
prep: $(ALL_PREP_TARGETS)

.PHONY: ip-upgrade
ip-upgrade: $(ALL_IP_UPGRADE_TARGETS)

.PHONY: generate-designs
generate-designs: $(ALL_GENERATE_DESIGN_TARGETS)

.PHONY: package-designs
package-designs: $(ALL_PACKAGE_DESIGN_TARGETS)

# Build options
.PHONY: build
build: $(ALL_BUILD_TARGETS)

# SW-Build options
.PHONY: sw-build
sw-build: $(ALL_SW_BUILD_TARGETS)

# Run all tests
.PHONY: test
test : build

.PHONY: install-sof
install-sof: $(ALL_INSTALL_SOF_TARGETS)

.PHONY: all
all: $(ALL_TARGET_ALL_NAMES)

###############################################################################
#                                HELP
###############################################################################
.PHONY: help
help:
	$(info GHRD Build)
	$(info ----------------)
	$(info    All Targets             : $(ALL_TARGET_ALL_NAMES))
	$(info    Stem names              : $(ALL_TARGET_STEM_NAMES))
	$(info    Pre-Prep Targets        : $(ALL_PRE_PREP_TARGETS))
	$(info    Prep Targets            : $(ALL_PREP_TARGETS))
	$(info    Build Targets           : $(ALL_BUILD_TARGETS))
	$(info    Test Targets            : $(ALL_TEST_TARGETS))
	$(info    Package Targets 	      : $(ALL_PACKAGE_DESIGN_TARGETS))

