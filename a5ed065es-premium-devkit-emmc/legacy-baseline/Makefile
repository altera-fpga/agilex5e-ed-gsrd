
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
PROJECT_DIR_ABS := $(abspath $(THIS_MK_DIR))

# Name of all the revisions
PROJECT_NAME :=
REVISION_NAMES :=

include $(THIS_MK_DIR)/project_config.mk
ifeq ($(PROJECT_NAME),)
$(error PROJECT_NAME is not defined in project_config.mk)
endif
ifeq ($(REVISION_NAMES),)
$(error REVISION_NAMES is not defined in project_config.mk)
endif

# Set defaults
INSTALL_ROOT ?= $(THIS_MK_DIR)
ARCHIVE_NAME ?= $(PROJECT_NAME)
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
ALL_PREP_TARGETS =
ALL_IP_UPGRADE_TARGETS =
ALL_BUILD_TARGETS =
ALL_SW_BUILD_TARGETS =
ALL_TEST_TARGETS =
ALL_INSTALL_SOF_TARGETS =

# Define function to create targets
define create_targets_on_revisions
ALL_TARGET_STEM_NAMES += $(strip $(1))
ALL_PREP_TARGETS += $(addsuffix -prep,$(strip $(1)))
ALL_IP_UPGRADE_TARGETS += $(addsuffix -ip-upgrade,$(strip $(1)))
ALL_BUILD_TARGETS += $(addsuffix -build,$(strip $(1)))
ALL_SW_BUILD_TARGETS += $(addsuffix -sw-build,$(strip $(1)))
ALL_TEST_TARGETS += $(addsuffix -test,$(strip $(1)))
ALL_INSTALL_SOF_TARGETS += $(addsuffix -install-sof,$(strip $(1)))

$(strip $(1))-prep : output_files/prep-$(strip $(1)).done

$(strip $(1))-ip-upgrade: pre-prep | output_files
	flock --verbose output_files/ipupgrade.lock quartus_sh --ip_upgrade $(PROJECT_NAME) -revision $(strip $(1))

$(strip $(1))-generate-design :

$(strip $(1))-package-design : $(INSTALL_ROOT)/$(ARCHIVE_NAME).zip

$(strip $(1))-build : output_files/$(strip $(1)).sof

$(strip $(1))-sw-build :

$(strip $(1))-test : $(strip $(1))-build
$(strip $(1))-install-sof : output_files/$(strip $(1)).sof | $(INSTALL_ROOT)
	cp $$< $(INSTALL_ROOT)/$(ARCHIVE_NAME)-$(strip $(1)).sof
endef

# Create all targets
$(foreach revision,$(REVISION_NAMES),$(eval $(call create_targets_on_revisions,$(revision))))

###############################################################################
#                          UTILITY TARGETS
###############################################################################

output_files $(INSTALL_ROOT):
	mkdir -p $@

output_files/pre-prep.done: | output_files
 	# Write protect QPF so it doesn't get modified when switching revisions
	chmod a-w $(PROJECT_NAME).qpf
	touch $@

output_files/prep-%.done: output_files/pre-prep.done | output_files
	chmod a-w $(PROJECT_NAME).qpf
	flock --verbose output_files/ipgenerate.lock quartus_ipgenerate top -c $* --simulation=verilog --synthesis=verilog
	ip-setup-simulation --quartus-project=top --revision=$* --output-directory=sim_setup_$*
	touch $@

.PHONY: pre-prep
pre-prep: output_files/pre-prep.done

$(INSTALL_ROOT)/$(ARCHIVE_NAME).zip: pre-prep | $(INSTALL_ROOT)
 	# Validate metadata in the README.md
	quartus_sh --validate_metadata -file README.md -strict
	rm validate_metadata_log.txt
	zip -r $@ * -x .gitignore "output_files/*" "qdb/*" "dni/*" "tmp-clearbox/*"

.PHONY: package-design
package-design: $(INSTALL_ROOT)/$(ARCHIVE_NAME).zip

.PHONY: generate-design
generate-design: pre-prep

.PHONY: ip-upgrade
ip-upgrade: $(ALL_IP_UPGRADE_TARGETS)

.PHONY: prep
prep: $(ALL_PREP_TARGETS)

output_files/%.sof: output_files/prep-%.done
	quartus_syn top -c $*
	quartus_fit top -c $*
	quartus_sta top -c $* --mode=finalize
	quartus_asm top -c $*
	quartus_pow top -c $*
	mv $*.qptc output_files/$*.qptc

# Clean all files
.PHONY: clean
clean :
	rm -rf output_files qdb tmp-clearbox dni

# Deep clean using git
.PHONY: dev-clean
dev-clean :
	git clean -dfx .

# Build all revisions
.PHONY: build
build : $(ALL_BUILD_TARGETS)

# Run all tests
.PHONY: test
test : $(ALL_TEST_TARGETS)

.PHONY: print-targets
print-targets:
	$(info $(ALL_TARGET_STEM_NAMES))


###############################################################################
#                           SW Build Targets
###############################################################################
-include $(THIS_MK_DIR)/swbuild_config.mk

# Build all SW projects
.PHONY: sw-build
sw-build : $(ALL_SW_BUILD_TARGETS)

###############################################################################
#                                HELP
###############################################################################
.PHONY: help
help:
	$(info GHRD Build)
	$(info    Project Directory       : $(PROJECT_DIR_ABS))
	$(info    Prep Targets            : $(ALL_PREP_TARGETS))
	$(info    Build Targets           : $(ALL_BUILD_TARGETS))
	$(info    Test Targets            : $(ALL_TEST_TARGETS))
	$(info    Software Build Targets  : $(ALL_SW_BUILD_TARGETS))
