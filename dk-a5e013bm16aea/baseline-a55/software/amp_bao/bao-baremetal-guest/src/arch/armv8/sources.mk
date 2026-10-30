## SPDX-License-Identifier: Apache-2.0
## Copyright (c) Bao Project and Contributors. All rights reserved.

arch_c_srcs:= init.c psci.c irq.c timer.c

ifeq ($(GIC_VERSION),GICV3)
	arch_c_srcs+=gicv3.c
else
	arch_c_srcs+=gicv2.c
endif
