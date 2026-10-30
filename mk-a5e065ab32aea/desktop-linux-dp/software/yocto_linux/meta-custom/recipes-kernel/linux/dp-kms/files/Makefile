# SPDX-License-Identifier: GPL-2.0-only
#
# Kbuild / Makefile for the Altera Agilex VVP DP DRM/KMS out-of-tree kernel module.
#
# Out-of-tree build (from this directory):
#   make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KDIR=/path/to/linux-socfpga
#
# Yocto: the dp-kms recipe sets KDIR automatically via inherit module.

obj-m := altera-vvp-dp.o

# Core DRM/KMS driver + native DisplayPort AUX and CR/EQ link training
# (drm_dp_helper path).  No third-party code is compiled in.
altera-vvp-dp-objs := \
	altera_vvp_dp.o \
	altera_vvp_dp_link.o

# Kernel source tree (override from environment or command line)
KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

modules_install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
