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
VENV_PIP_INSTALL := $(VENV_PIP) install $(PIP_PROXY) --no-cache-dir --timeout 120 --retries 20 --trusted-host pypi.org --trusted-host files.pythonhosted.org

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
ALL_TEST_TARGETS =
ALL_INSTALL_TARGETS =
ALL_CLEAN_TARGETS =
ALL_DEV_CLEAN_TARGETS =
ALL_TARGET_ALL_NAMES =

ALL_SW_TARGET_STEM_NAMES =
ALL_SW_BUILD_TARGETS =
ALL_SW_INSTALL_TARGETS =

# Define function to create targets
define create_targets_on_subdir
ALL_TARGET_STEM_NAMES += $(addprefix $(strip $(1))-,$(strip $(3)))
ALL_PRE_PREP_TARGETS += $(addsuffix -pre-prep,$(addprefix $(strip $(1))-,$(strip $(3))))
ALL_PREP_TARGETS += $(addsuffix -prep,$(addprefix $(strip $(1))-,$(strip $(3))))
ALL_IP_UPGRADE_TARGETS += $(addsuffix -ip-upgrade,$(addprefix $(strip $(1))-,$(strip $(3))))
ALL_GENERATE_DESIGN_TARGETS += $(addsuffix -generate-design,$(addprefix $(strip $(1))-,$(strip $(3))))
ALL_PACKAGE_DESIGN_TARGETS += $(addsuffix -package-design,$(addprefix $(strip $(1))-,$(strip $(3))))
ALL_BUILD_TARGETS += $(addsuffix -build,$(addprefix $(strip $(1))-,$(strip $(3))))
ALL_TEST_TARGETS += $(addsuffix -test,$(addprefix $(strip $(1))-,$(strip $(3))))
ALL_INSTALL_TARGETS += $(addsuffix -install,$(addprefix $(strip $(1))-,$(strip $(3))))
ALL_CLEAN_TARGETS += $(addsuffix -clean,$(addprefix $(strip $(1))-,$(strip $(3))))
ALL_DEV_CLEAN_TARGETS += $(addsuffix -dev-clean,$(addprefix $(strip $(1))-,$(strip $(3))))
ALL_TARGET_ALL_NAMES += $(addsuffix -all,$(addprefix $(strip $(1))-,$(strip $(3))))


$(strip $(1))-%-pre-prep : venv
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-pre-prep

$(strip $(1))-%-prep : venv
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-prep

$(strip $(1))-%-ip-upgrade : venv
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-ip-upgrade

$(strip $(1))-%-generate-design : venv
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-generate-design

$(strip $(1))-%-package-design :
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-package-design INSTALL_ROOT_DESIGNS=$(INSTALL_ROOT)/$(strip $(4))/designs INSTALL_ROOT_BINARIES=$(INSTALL_ROOT)/$(strip $(4))/binaries/$(strip $(1)) INSTALL_ROOT_ARTIFACTS=$(INSTALL_ROOT)/artifacts/$(strip $(1))

$(strip $(1))-%-build :
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-build

$(strip $(1))-%-build-sw :
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-build-sw

$(strip $(1))-%-install-sw :
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-install-sw INSTALL_ROOT_DESIGNS=$(INSTALL_ROOT)/$(strip $(4))/designs INSTALL_ROOT_BINARIES=$(INSTALL_ROOT)/$(strip $(4))/binaries/$(strip $(1)) INSTALL_ROOT_ARTIFACTS=$(INSTALL_ROOT)/artifacts/$(strip $(1))

$(strip $(1))-%-test :
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-test

$(strip $(1))-%-install :
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-install INSTALL_ROOT_DESIGNS=$(INSTALL_ROOT)/$(strip $(4))/designs INSTALL_ROOT_BINARIES=$(INSTALL_ROOT)/$(strip $(4))/binaries/$(strip $(1)) INSTALL_ROOT_ARTIFACTS=$(INSTALL_ROOT)/artifacts/$(strip $(1))

$(strip $(1))-%-clean :
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-clean

$(strip $(1))-%-clean-sw :
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-clean-sw

$(strip $(1))-%-dev-clean :
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-dev-clean

.PHONY: $(addsuffix -all,$(addprefix $(strip $(1))-,$(strip $(3))))
$(addsuffix -all,$(addprefix $(strip $(1))-,$(strip $(3)))): venv
	$(MAKE) $(addsuffix -pre-prep,$(addprefix $(strip $(1))-,$(strip $(3))))
	$(MAKE) $(addsuffix -generate-design,$(addprefix $(strip $(1))-,$(strip $(3))))
	$(MAKE) $(addsuffix -package-design,$(addprefix $(strip $(1))-,$(strip $(3))))
	$(MAKE) $(addsuffix -prep,$(addprefix $(strip $(1))-,$(strip $(3))))
	$(MAKE) $(addsuffix -build,$(addprefix $(strip $(1))-,$(strip $(3))))
	$(MAKE) $(addsuffix -test,$(addprefix $(strip $(1))-,$(strip $(3))))
	$(MAKE) $(addsuffix -install,$(addprefix $(strip $(1))-,$(strip $(3))))
	$(MAKE) $(addsuffix -build-sw,$(addprefix $(strip $(1))-,$(strip $(3))))
	$(MAKE) $(addsuffix -install-sw,$(addprefix $(strip $(1))-,$(strip $(3))))
endef

# Create targets per SW project on each subdir
define create_sw_targets_on_subdir
ALL_SW_TARGET_STEM_NAMES += $(addprefix $(strip $(1))-,$(strip $(3)))
ALL_SW_BUILD_TARGETS += $(addsuffix -build-sw,$(addprefix $(strip $(1))-,$(strip $(3))))
ALL_SW_INSTALL_TARGETS += $(addsuffix -install-sw,$(addprefix $(strip $(1))-,$(strip $(3))))

$(strip $(1))-%-build-sw :
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-build-sw INSTALL_ROOT_DESIGNS=$(INSTALL_ROOT)/$(strip $(4))/designs INSTALL_ROOT_BINARIES=$(INSTALL_ROOT)/$(strip $(4))/binaries/$(strip $(1)) INSTALL_ROOT_ARTIFACTS=$(INSTALL_ROOT)/artifacts/$(strip $(1))

$(strip $(1))-%-install-sw :
	$(MAKE) --no-print-directory -C $(strip $(2)) $$*-install-sw INSTALL_ROOT_DESIGNS=$(INSTALL_ROOT)/$(strip $(4))/designs INSTALL_ROOT_BINARIES=$(INSTALL_ROOT)/$(strip $(4))/binaries/$(strip $(1)) INSTALL_ROOT_ARTIFACTS=$(INSTALL_ROOT)/artifacts/$(strip $(1))
endef

# Dummy SW build targets
.PHONY: dummy-build-sw
dummy-build-sw:

.PHONY: dummy-install-sw
install-build-sw:


# Create rules for subdirs
TARGET_SUBDIR :=
-include platform_config.mk

# Create the subdir recipes by recursively calling the create_targets_on_subdir on each TARGET_SUBDIR
define create_subdir_targets
$(foreach target, $(shell make  --no-print-directory -q -C $(1) print-targets), $(eval $(call create_targets_on_subdir, $(1),$(1),$(target),$(NOOP))))
endef
$(foreach subdir,$(TARGET_SUBDIR),$(eval $(call create_subdir_targets,$(subdir))))

define create_subdir_sw_targets
$(foreach target, $(shell make  --no-print-directory -q -C $(1) print-sw-targets), $(eval $(call create_sw_targets_on_subdir, $(1),$(1),$(target),$(NOOP))))
endef
$(foreach subdir,$(TARGET_SUBDIR),$(eval $(call create_subdir_sw_targets,$(subdir))))

###############################################################################
#                          UTILITY TARGETS
###############################################################################
# Deep clean using git
.PHONY: dev-clean
dev-clean : $(ALL_DEV_CLEAN_TARGETS)
	rm -rf $(INSTALL_ROOT) $(WORK_ROOT)
	git clean -dfx --exclude=/.vscode --exclude=.lfsconfig

# Using git
.PHONY: dev-update
dev-update :
	git pull
	git submodule update --init --recursive

.PHONY: clean
clean: $(ALL_CLEAN_TARGETS)
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
# Should be included before Toplevel Targets to get all not_shipped dependency targets.
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

# BUILD-Sw options
.PHONY: build-sw
build-sw: $(ALL_SW_BUILD_TARGETS)

# Run all tests
.PHONY: test
test : $(ALL_TEST_TARGETS)

.PHONY: install
install: $(ALL_INSTALL_TARGETS)

.PHONY: install-sw
install-sw: $(ALL_SW_INSTALL_TARGETS)

.PHONY: all
all: $(ALL_TARGET_ALL_NAMES)

###############################################################################
#                                HELP
###############################################################################
.PHONY: print-env
print-env:
	$(MAKE) print-env-int

.PHONY: print-env-int
print-env-int:
	$(info GHRD Build Environment)
	$(info ----------------)
	$(info PATH=$(PATH))
	$(info LD_LIBRARY_PATH=$(LD_LIBRARY_PATH))
	$(info QUARTUS_ROOTDIR=$(QUARTUS_ROOTDIR))
	$(info Quartus Version=$(shell quartus_sh -v | grep Version))
	$(info GCC=$(shell which gcc))

.PHONY: help
help:
	$(info GHRD Build)
	$(info ----------------)
	$(info    all         : Run and "all" target on each of the target designs)
	$(info ----------------)
	$(info    All Targets              : $(ALL_TARGET_ALL_NAMES))
	$(info    Stem names               : $(ALL_TARGET_STEM_NAMES))
	$(info    Package Targets          : $(ALL_PACKAGE_DESIGN_TARGETS))
	$(info    Build Targets            : $(ALL_BUILD_TARGETS))
	$(info    Test Targets             : $(ALL_TEST_TARGETS))
	$(info    Software Build Targets   : $(ALL_SW_BUILD_TARGETS))
	$(info    Software Install Targets : $(ALL_SW_INSTALL_TARGETS))
