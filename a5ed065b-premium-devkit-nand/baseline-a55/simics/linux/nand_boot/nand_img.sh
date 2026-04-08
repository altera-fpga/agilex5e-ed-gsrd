#!/bin/bash

#===============================================================================
# Script to prepare NAND image for Agilex5e
#===============================================================================

set -euo pipefail

#--------------------------------------
# Get BOOTDIR_ABS path
#--------------------------------------
BOOTDIR_ABS="${1:-}"

if [[ -z "$BOOTDIR_ABS" ]]; then
    echo "[ERROR] Boot directory path not provided. Exiting..."
    exit 1
fi
echo "[INFO] Using boot directory: $BOOTDIR_ABS"

#--------------------------------------
# Check required files exist
#--------------------------------------
FSBL_BIN="u-boot-spl-dtb.bin"
UBOOT_ITB="u-boot.itb"
ROOT_UBI="root.ubi"

if [[ ! -f "$FSBL_BIN" ]]; then
    echo "[ERROR] u-boot-spl-dtb.bin not found. You may generate by following steps mentioned in software/yocto_linux/README.md"
    exit 1
fi

if [[ ! -f "$UBOOT_ITB" ]]; then
    echo "[ERROR] u-boot.itb not found. You may generate by following steps mentioned in software/yocto_linux/README.md"
    exit 1
fi

if [[ ! -f "$ROOT_UBI" ]]; then
    echo "[ERROR] root.ubi not found. You may generate by following steps mentioned in software/yocto_linux/README.md"
    exit 1
fi

echo "[INFO] Found u-boot-spl-dtb.bin"
echo "[INFO] Found u-boot.itb"
echo "[INFO] Found root.ubi"

#--------------------------------------
# Create NAND image
#--------------------------------------
NAND_IMG="nand.img"

echo "[INFO] Creating 1GB NAND image filled with 0xFF..."
dd if=/dev/zero count=1 bs=1024M 2>/dev/null | tr '\0' $'\xFF' > "$NAND_IMG" || {
    echo "[ERROR] Failed to create NAND image"
    exit 1
}

echo "[INFO] Writing u-boot.itb at offset 0x00000000..."
dd conv=notrunc bs=1 if="$UBOOT_ITB" of="$NAND_IMG" seek=$((0x00000000)) 2>/dev/null || {
    echo "[ERROR] Failed to write u-boot.itb"
    exit 1
}

echo "[INFO] Writing root.ubi at offset 0x00200000..."
dd conv=notrunc bs=1 if="$ROOT_UBI" of="$NAND_IMG" seek=$((0x00200000)) 2>/dev/null || {
    echo "[ERROR] Failed to write root.ubi"
    exit 1
}

echo "[INFO] NAND image created successfully at: $NAND_IMG"
echo "[INFO] NAND image size: $(du -h "$NAND_IMG" | cut -f1)"
