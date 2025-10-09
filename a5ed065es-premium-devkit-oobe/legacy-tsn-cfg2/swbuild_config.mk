###############################################################################
#                           Generic Targets
###############################################################################
# Create the core RBF files from the SOF files
output_files/%.core.rbf : output_files/%.sof
	quartus_pfg -c $< output_files/$*.rbf -o hps=ON

###############################################################################
#                           SW Build Targets
###############################################################################

# HPS Debug Software Build
###############################################################################
SW_HPS_DEBUG_TARGET := software-hps_debug
# Do not add HPS to the SW build target. Instead make it a part of the SOF install
# target. This is because other SW builds require this SOF
# ALL_SW_TARGET_STEM_NAMES += $(SW_HPS_DEBUG_TARGET)
define create_hps_debug_targets_on_revisions
$(strip $(1))-install-sof : $(INSTALL_ROOT_BINARIES)/$(strip $(1))_hps_debug.sof
endef
$(foreach revision,$(REVISION_NAMES),$(eval $(call create_hps_debug_targets_on_revisions,$(revision))))
clean-sw: $(SW_HPS_DEBUG_TARGET)-clean-sw

# Build the SW
software/hps_debug/hps_wipe.ihex:
	cd software/hps_debug && ./build.sh

# HPS Debug FSBL insertion into the SOF
# Create the debug SOF specific SOFs using the hps_debug SW
ifneq ($(RESTORE_INSTALL),1)
output_files/%_hps_debug.sof : output_files/%.sof software/hps_debug/hps_wipe.ihex
	quartus_pfg -c -o hps_path=software/hps_debug/hps_wipe.ihex $< $@

$(INSTALL_ROOT_BINARIES)/%_hps_debug.sof : output_files/%_hps_debug.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@
endif

.PHONY: $(SW_HPS_DEBUG_TARGET)-clean-sw
$(SW_HPS_DEBUG_TARGET)-clean-sw:
	cd software/hps_debug && ./clean_build.sh

.PHONY: $(SW_HPS_DEBUG_TARGET)-build-sw
$(SW_HPS_DEBUG_TARGET)-build-sw : software/hps_debug/hps_wipe.ihex

.PHONY: $(SW_HPS_DEBUG_TARGET)-install-sw
$(SW_HPS_DEBUG_TARGET)-install-sw : $(INSTALL_ROOT_BINARIES)/%_hps_debug.sof
