# SPDX-License-Identifier: MIT
#
# dp-kms.bb - Yocto recipe for the Intel Agilex 5 DP DRM/KMS kernel module.
#
# Builds altera-vvp-dp.ko out-of-tree against the socfpga kernel.
# The module replaces the userspace dp_demo.sh / uio_pdrv_genirq approach.
#
# To add this recipe to your image, add to local.conf or your image recipe:
#   IMAGE_INSTALL:append = " dp-kms"
#
# The recipe also installs the updated device-tree source; the DTS must be
# built by the linux-socfpga recipe (add it to the kernel's SRC_URI or
# reference it from the bbappend).

SUMMARY = "Altera Agilex VVP DisplayPort DRM/KMS kernel module"
PR = "r8"
DESCRIPTION = "Out-of-tree DRM/KMS driver for the Agilex 5 GHRD DP subsystem. \
Implements the same 6-step bring-up sequence as dp_demo.sh (clock PIO, \
AXI2CV mode-bank, VFR frame-reader, DP TX link training) as proper \
DRM plane/CRTC/encoder/connector objects."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=12f884d2ae1ff87c09e5b7ccc2c4ca7e"

inherit module

# Source: local files in the recipe's files/ directory.
# In a real integration, replace with a git SRC_URI.
SRC_URI = " \
    file://COPYING \
    file://Makefile \
    file://altera_vvp_dp.c \
    file://altera_vvp_dp.h \
    file://altera_vvp_dp_link.c \
    file://altera_vvp_dp_regs.h \
    "

S = "${UNPACKDIR}"

# The 'module' class sets KERNEL_SRC and calls make with KDIR automatically.
EXTRA_OEMAKE = "KDIR=${KBUILD_OUTPUT}"

# Autoload the module on boot.
KERNEL_MODULE_AUTOLOAD += "altera-vvp-dp"
