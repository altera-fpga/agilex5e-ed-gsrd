## SPDX-License-Identifier: Apache-2.0
## Copyright (c) Bao Project and Contributors. All rights reserved.

ARCH_SUB?=aarch64
arch_sub_dir:=$(cur_dir)/$(ARCH_SUB)
include $(arch_sub_dir)/arch_sub.mk
SRC_DIRS+=$(arch_sub_dir)
INC_DIRS+=$(arch_sub_dir)/inc
include $(arch_sub_dir)/sources.mk

ARM_PROFILE?=armv8-a
ARCH_GENERIC_FLAGS +=-DGIC_VERSION=$(GIC_VERSION) -march=$(ARM_PROFILE) \
	$(ARCH_SUB_GENERIC_FLAGS)
ARCH_ASFLAGS =
ARCH_CFLAGS = -mgeneral-regs-only
ARCH_CPPFLAGS =
ARCH_LDFLAGS =
