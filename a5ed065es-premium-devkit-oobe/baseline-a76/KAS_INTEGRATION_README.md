# Dynamic swbuild_config.mk using bsp.yml variables

## Summary

The swbuild_config.mk has been updated to dynamically read configuration from bsp.yml instead of using hardcoded values. Variables are extracted directly from bsp.yml (which is included by kas.yml) at Makefile parse time.

## Implementation Approach

### Direct Variable Extraction
Variables are extracted directly from bsp.yml using shell commands in the Makefile:

```makefile
# Extract MACHINE from bsp.yml
KAS_MACHINE := $(shell grep -A 10 "machine:" $(BSP_YML_PATH) 2>/dev/null | grep "MACHINE" | sed 's/.*MACHINE = "\(.*\)".*/\1/')

# Extract DTS_NAME from bsp.yml
KAS_DTS_NAME := $(shell grep -A 10 "machine:" $(BSP_YML_PATH) 2>/dev/null | grep "DTS_NAME" | sed 's/.*DTS_NAME = "\(.*\)".*/\1/')

# Check if variables were successfully extracted
ifeq ($(KAS_MACHINE),)
$(error ERROR: Failed to extract MACHINE from software/yocto_linux/bsp.yml)
endif
```

### Advantages
- **No file dependencies**: Doesn't require kas_vars.mk to exist
- **Fail-fast validation**: Makefile errors immediately if bsp.yml is missing or malformed
- **CI-friendly**: Works in any environment with grep and sed
- **Parse-time resolution**: Variables are set when Makefile is loaded
- **Clear error messages**: Tells you exactly what's missing

## Generated Variables

From bsp.yml configuration:
```yaml
machine:
  MACHINE = "agilex5e"
  DTS_NAME = "socfpga_agilex5_socdk_a0"
```

The Makefile automatically extracts and computes:
```makefile
KAS_MACHINE := agilex5e
KAS_DTS_NAME := socfpga_agilex5_socdk_a0
KAS_DTS_BASE_NAME := socfpga_agilex5_socdk
KAS_DTS_VANILLA_NAME := socfpga_agilex5_socdk_vanilla
KAS_YOCTO_IMAGE_DIR := software/yocto_linux/build/tmp/deploy/images/$(KAS_MACHINE)
KAS_VANILLA_DTB_PATH := devicetree/$(KAS_DTS_VANILLA_NAME).dtb
```

### Optional Helper Script
The `extract_kas_vars.sh` script can still be used to generate a kas_vars.mk file for reference:
```bash
./extract_kas_vars.sh > kas_vars.mk
```

However, the Makefile no longer depends on this file.

**Before (Hardcoded)**:
```makefile
YOCTO_SD_IMAGE_DIR := software/yocto_linux/build/tmp/deploy/images/agilex5e
devicetree/socfpga_agilex5_vanilla.dtb
console-image-minimal-agilex5e.rootfs.tar.gz
```

**After (Dynamic)**:
```makefile
YOCTO_SD_IMAGE_DIR := $(KAS_YOCTO_IMAGE_DIR)
$(KAS_VANILLA_DTB_PATH)
console-image-minimal-$(KAS_MACHINE).rootfs.tar.gz
```

## Benefits

1. **Single Source of Truth**: Configuration comes from bsp.yml (included by kas.yml)
2. **SoC Agnostic**: Works with any SoC by changing bsp.yml variables
3. **Fail-Fast Validation**: Immediately errors if bsp.yml is missing or invalid
4. **Consistent Naming**: DTB naming matches Yocto device-tree recipe logic
5. **No Build Dependencies**: Works immediately without generating intermediate files
6. **CI-Friendly**: No file locking or generation issues in CI environments
7. **Clear Error Messages**: Tells you exactly what configuration is missing

## Usage

### Normal Build
Just run make as usual - variables are extracted automatically:
```bash
make software-yocto_linux_sd-build-sw
```

### Verifying Variables
To see what values are being used:
```bash
make -n software-yocto_linux_sd-build-sw | grep "KAS_MACHINE"
```

### Optional: Generate Reference File
For documentation or debugging:
```bash
./extract_kas_vars.sh > kas_vars.mk
cat kas_vars.mk
```

All hardcoded "agilex5e" and device tree references have been replaced with KAS variables that adapt automatically to bsp.yml configuration.