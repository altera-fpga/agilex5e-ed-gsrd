# Create rules for baseline-a55 subdir
TARGET_SUBDIR := baseline-a55
$(eval $(call create_targets_on_subdir, $(TARGET_SUBDIR)))
$(foreach target,  $(shell make  --no-print-directory -q -C $(TARGET_SUBDIR) print-sw-targets), $(eval $(call create_sw_targets_on_subdir, $(TARGET_SUBDIR), $(target))))

# Create rules for tsn-cfg2 subdir
TARGET_SUBDIR := tsn-cfg2
$(eval $(call create_targets_on_subdir, $(TARGET_SUBDIR)))
$(foreach target,  $(shell make  --no-print-directory -q -C $(TARGET_SUBDIR) print-sw-targets), $(eval $(call create_sw_targets_on_subdir, $(TARGET_SUBDIR), $(target))))