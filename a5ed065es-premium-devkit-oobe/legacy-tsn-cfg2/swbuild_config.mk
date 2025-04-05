###############################################################################
#                           SW Build Targets
###############################################################################
software/hps_debug/hps_wipe.ihex:
	cd software/hps_debug && ./build.sh

legacy_tsn_cfg2-sw-build : software/hps_debug/hps_wipe.ihex

.PHONY: clean-software-hps_debug
clean-software-hps_debug:
	rm -rf software/hps_debug/gcc-arm software/hps_debug/hps_wipe.ihex software/hps_debug/hps_wipe.bin software/hps_debug/hps_wipe.elf software/hps_debug/hps_wipe.objdump
clean: clean-software-hps_debug

###############################################################################
#                           FSBL insertion into SOF
###############################################################################

# Create the debug SOF specific SOFs using the hps_debug SW
output_files/legacy_tsn_cfg2_hps_debug.sof : output_files/legacy_tsn_cfg2.sof software/hps_debug/hps_wipe.ihex
	quartus_pfg -c -o hps_path=software/hps_debug/hps_wipe.ihex $< $@

legacy_tsn_cfg2_hps_debug-install-sof : output_files/legacy_tsn_cfg2_hps_debug.sof | $(INSTALL_ROOT)
	cp $< $(INSTALL_ROOT)/$(ARCHIVE_NAME)-$(notdir $<)

# Link the legacy_tsn_cfg2_hps_debug.sof to the legacy_tsn_cfg2.sof install recipe
legacy_tsn_cfg2-install-sof : legacy_tsn_cfg2_hps_debug-install-sof
# Add the legacy_tsn_cfg2_hps_debug.sof to the all install SOF recipe
ALL_INSTALL_SOF_TARGETS += legacy_tsn_cfg2_hps_debug-install-sof

