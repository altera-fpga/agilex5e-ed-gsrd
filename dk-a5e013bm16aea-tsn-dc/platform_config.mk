# Create rules for tsn-rgmii-hvio subdir
DESIGN_SUBDIRS := tsn-rgmii-hvio
$(foreach subdir,$(DESIGN_SUBDIRS),$(eval $(call create_targets_on_subdir, $(subdir))))
$(foreach subdir,$(DESIGN_SUBDIRS),$(foreach target,$(shell make --no-print-directory -q -C $(subdir) print-sw-targets),$(eval $(call create_sw_targets_on_subdir, $(subdir),$(target)))))
