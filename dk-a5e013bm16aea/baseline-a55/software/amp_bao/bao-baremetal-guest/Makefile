## SPDX-License-Identifier: Apache-2.0
## Copyright (c) Bao Project and Contributors. All rights reserved.

# Prepare enviroment for baremetal-runtime
SHELL:=bash

NAME:=baremetal
ROOT_DIR:=$(realpath .)
BUILD_DIR:=$(ROOT_DIR)/build/$(PLATFORM)$(if $(BUILD_SUFFIX),-$(BUILD_SUFFIX))
CI_DIR:=$(ROOT_DIR)/ci

# Setup baremetal-runtime build
include $(ROOT_DIR)/setup.mk

# The bare-metal runtime lives in src/ (core/arch/platform/drivers); each VM's
# application overlay lives in its own src-vm{1,2}/ dir selected via APP_SRC_DIR.
APP_SRC_DIR?=$(ROOT_DIR)/src-vm1
include $(APP_SRC_DIR)/sources.mk
C_SRC+=$(addprefix $(APP_SRC_DIR)/, $(src_c_srcs))

# Include the final baremetal-runtime build
include $(ROOT_DIR)/build.mk

# Instantiate CI rules
root_dir:=$(ROOT_DIR)
ci_dir:=$(CI_DIR)
src_dir:=$(APP_SRC_DIR)

ifneq ($(wildcard $(ci_dir)/ci.mk),)

include $(ci_dir)/ci.mk

all_files=$(realpath \
	$(ROOT_DIR)/Makefile \
	$(ROOT_DIR)/build.mk \
	$(ROOT_DIR)/setup.mk \
	$(call list_dir_files_recursive, $(src_dir), *) \
)
all_c_src_files=$(realpath $(call list_dir_files_recursive, $(src_dir), *.c))
all_c_hdr_files=$(realpath $(call list_dir_files_recursive, $(src_dir), *.h))
all_c_files=$(all_c_src_files) $(all_c_hdr_files)

$(call ci, license, "Apache-2.0", $(all_files))
$(call ci, format, $(all_c_files))

.PHONY: ci
ci: license-check format-check

endif
