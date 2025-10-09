
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
export PATH := $(PATH):/usr/sbin

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
INSTALL_ROOT_BINARIES ?= $(THIS_MK_DIR)/install/binaries
INSTALL_ROOT_DESIGNS ?= $(THIS_MK_DIR)/install/designs
INSTALL_ROOT_ARTIFACTS ?= $(THIS_MK_DIR)/install/artifacts
ARCHIVE_NAME ?= $(PROJECT_NAME)

# Set constants
INSTALL_RPT_NAMES := \
	syn.rpt \
	fit.rpt \
	sta.rpt \
	asm.rpt \
	pow.rpt \
	flow.rpt \
	tq.drc.signoff.rpt

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
ALL_SW_TARGET_STEM_NAMES =
ALL_PREP_TARGETS =
ALL_IP_UPGRADE_TARGETS =
ALL_BUILD_TARGETS =
ALL_SW_BUILD_TARGETS =
ALL_SW_CLEAN_TARGETS =
ALL_SW_INSTALL_TARGETS =
ALL_TEST_TARGETS =
ALL_INSTALL_TARGETS =

# Define function to create targets
define create_targets_on_revisions
ALL_TARGET_STEM_NAMES += $(strip $(1))
ALL_PREP_TARGETS += $(addsuffix -prep,$(strip $(1)))
ALL_IP_UPGRADE_TARGETS += $(addsuffix -ip-upgrade,$(strip $(1)))
ALL_BUILD_TARGETS += $(addsuffix -build,$(strip $(1)))
ALL_TEST_TARGETS += $(addsuffix -test,$(strip $(1)))
ALL_INSTALL_TARGETS += $(addsuffix -install,$(strip $(1)))

$(strip $(1))-prep : output_files/prep-$(strip $(1)).done

$(strip $(1))-qsys-ip-file-upgrade: pre-prep
	$(MAKE) --no-print-directory ip-upgrade-helper
	quartus_sh --ip_upgrade $(PROJECT_NAME) -revision $(strip $(1)) -mode all

$(strip $(1))-ip-upgrade: pre-prep | output_files
	chmod a-w $(strip $(1)).qsf
	flock --verbose output_files/ipupgrade.lock $(MAKE) $(strip $(1))-qsys-ip-file-upgrade
	chmod +w $(strip $(1)).qsf

$(strip $(1))-generate-design :

$(strip $(1))-package-design : $(INSTALL_ROOT_DESIGNS)/$(ARCHIVE_NAME).zip

$(strip $(1))-build : output_files/$(strip $(1)).sof

$(strip $(1))-build-sw :

$(strip $(1))-test : $(strip $(1))-build

$(strip $(1))-install-sw: | $(INSTALL_ROOT_BINARIES)

$(strip $(1))-install: $(strip $(1))-install-sof $(strip $(1))-install-rpt $(strip $(1))-install-sw

$(strip $(1))-install-sof : output_files/$(strip $(1)).sof | $(INSTALL_ROOT_BINARIES)
	cp output_files/$(strip $(1)).sof $(INSTALL_ROOT_BINARIES)/$(strip $(1)).sof

$(strip $(1))-install-rpt: output_files/$(strip $(1))-install-rpt.done

output_files/$(strip $(1))-install-rpt.done : | $(INSTALL_ROOT_ARTIFACTS) output_files
	cp -f $(addprefix output_files/$(strip $(1))., $(INSTALL_RPT_NAMES)) $(INSTALL_ROOT_ARTIFACTS)/
	gzip $(addprefix $(INSTALL_ROOT_ARTIFACTS)/$(strip $(1))., $(INSTALL_RPT_NAMES))
	touch $$@

endef

# Create all targets
$(foreach revision,$(REVISION_NAMES),$(eval $(call create_targets_on_revisions,$(revision))))

###############################################################################
#                          UTILITY TARGETS
###############################################################################

output_files $(INSTALL_ROOT_BINARIES) $(INSTALL_ROOT_DESIGNS) $(INSTALL_ROOT_ARTIFACTS):
	mkdir -p $@

output_files/pre-prep.done: | output_files
 	# Write protect QPF so it doesn't get modified when switching revisions
	chmod a-w $(PROJECT_NAME).qpf
	touch $@

output_files/prep-%.done: output_files/pre-prep.done | output_files
	chmod a-w $(PROJECT_NAME).qpf
	flock --verbose output_files/ipgenerate.lock quartus_ipgenerate top -c $* --simulation=verilog --synthesis=verilog --simulator=modelsim,vcsmx,riviera,xcelium |& tee output_files/$*.ipgen.rpt
	ip-setup-simulation --quartus-project=top --revision=$* --output-directory=sim_setup_$* --simulator=modelsim,vcsmx,riviera,xcelium |& tee -a output_files/$*.ipgen.rpt
	touch $@

.PHONY: pre-prep
pre-prep: output_files/pre-prep.done

$(INSTALL_ROOT_DESIGNS)/$(ARCHIVE_NAME).zip: pre-prep | $(INSTALL_ROOT_DESIGNS)
 	# Validate metadata in the README.md
	quartus_sh --validate_metadata -file README.md -strict
	rm validate_metadata_log.txt
	zip -r $@ * -x .gitignore "output_files/*" "qdb/*" "dni/*" "tmp-clearbox/*"

.PHONY: package-design
package-design: $(INSTALL_ROOT_DESIGNS)/$(ARCHIVE_NAME).zip

.PHONY: generate-design
generate-design: pre-prep

.PHONY: ip-upgrade
ip-upgrade: $(ALL_IP_UPGRADE_TARGETS)

.PHONY: prep
prep: $(ALL_PREP_TARGETS)

# Support restoring the SOF from the install directory to support
# building the SW outside of building the FPGA design
ifneq ($(RESTORE_INSTALL),1)
output_files/%.sof: output_files/prep-%.done
	quartus_syn top -c $*
	quartus_fit top -c $*
	quartus_sta top -c $* --mode=finalize
	quartus_asm top -c $*
	quartus_pow top -c $*
	mv $*.qpta output_files/$*.qpta
else
output_files/%.sof: $(INSTALL_ROOT_BINARIES)/%.sof
	mkdir -p $(dir $@)
	cp $< $@
endif

# Clean all files
.PHONY: clean
clean : clean-sw
	rm -rf output_files qdb tmp-clearbox dni

# Deep clean using git
.PHONY: dev-clean
dev-clean : clean
	git clean -dfx .

# Build all revisions
.PHONY: build
build : $(ALL_BUILD_TARGETS)

# Run all tests
.PHONY: test
test : $(ALL_TEST_TARGETS)

# Install binaries and designs
.PHONY: install
install : $(ALL_INSTALL_TARGETS)

.PHONY: print-targets
print-targets:
	$(info $(ALL_TARGET_STEM_NAMES))

# Run script to upgrade IP and QSYS files
ip-upgrade-helper:
	qsys-script --qpf=top --script=qsys_update.tcl --system-file=$(wildcard *_top.qsys) --search-path="custom_ip/**/*, $$"

###############################################################################
#                           SW Build Targets
###############################################################################
-include $(THIS_MK_DIR)/swbuild_config.mk
ALL_SW_BUILD_TARGETS += $(addsuffix -build-sw, $(ALL_SW_TARGET_STEM_NAMES))
ALL_SW_CLEAN_TARGETS += $(addsuffix -clean-sw, $(ALL_SW_TARGET_STEM_NAMES))
ALL_SW_INSTALL_TARGETS += $(addsuffix -install-sw, $(ALL_SW_TARGET_STEM_NAMES))

# Build all SW projects
.PHONY: build-sw
build-sw : $(ALL_SW_BUILD_TARGETS)

.PHONY: clean-sw
clean-sw: $(ALL_SW_CLEAN_TARGETS)

.PHONY: install-sw
install-sw: $(ALL_SW_INSTALL_TARGETS)

.PHONY: print-sw-targets
print-sw-targets:
	$(info $(ALL_SW_TARGET_STEM_NAMES))


###############################################################################
#                                HELP
###############################################################################
.PHONY: help
help:
	$(info GHRD Build)
	$(info    Project Directory         : $(PROJECT_DIR_ABS))
	$(info    Prep Targets              : $(ALL_PREP_TARGETS))
	$(info    Build Targets             : $(ALL_BUILD_TARGETS))
	$(info    Install Targets           : $(ALL_INSTALL_TARGETS))
	$(info    Software Build Targets    : $(ALL_SW_BUILD_TARGETS))
	$(info    Software Install Targets  : $(ALL_SW_INSTALL_TARGETS))
