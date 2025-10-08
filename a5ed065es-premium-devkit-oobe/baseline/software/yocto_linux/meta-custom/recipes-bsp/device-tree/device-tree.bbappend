SUMMARY = "Linux Kernel custom Device Tree"
DESCRIPTION = "This receipe provides configurations for custom device tree and device tree fragments"

# Prepare the path of the device tree file location
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
KERNEL_DEVICE_TREE_SRC_PATH := "${THISDIR}/files"
