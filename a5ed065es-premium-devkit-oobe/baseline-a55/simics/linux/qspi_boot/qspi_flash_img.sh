#!/bin/bash

#===============================================================================
# Script to prepare QSPI flash image for Agilex5e
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

#--------------------------------------------------------------------
# Create simics-u-boot-spl-dtb.hex if not exists
# Note: Yocto generated u-boot-spl-dtb.hex is not in ihex format, but
#   Simics expectes u-boot-spl-dtb.hex in ihex format. Hence, creating
#   in ihex format.
#---------------------------------------------------------------------
if [[ ! -f "simics-u-boot-spl-dtb.hex" ]]; then
    if [[ -f "u-boot-spl-dtb.bin" ]]; then
        echo "[INFO] Creating simics-u-boot-spl-dtb.hex..."
        aarch64-none-linux-gnu-objcopy -I binary -O ihex --change-addresses 0x00000000 \
            u-boot-spl-dtb.bin simics-u-boot-spl-dtb.hex
        if [[ ! -f "simics-u-boot-spl-dtb.hex" ]]; then
            echo "[ERROR] Failed to generate simics-u-boot-spl-dtb.hex"
            exit 1
        fi
    else
        echo "[ERROR] u-boot-spl-dtb.bin not found"
        exit 1
    fi
else
    echo "[INFO] simics-u-boot-spl-dtb.hex already exists. Skipping."
fi

#--------------------------------------
# Ubinize step if hps.bin does not exist
#--------------------------------------
UBINIZE_CFG="$BOOTDIR_ABS/ubinize.cfg"
if [[ ! -f "hps.bin" ]]; then
    if [[ -f "$UBINIZE_CFG" ]]; then
        echo "[INFO] Creating UBI image using $UBINIZE_CFG..."
        cp console-image-minimal-agilex5e.rootfs_nor.ubifs rootfs.ubifs
        $BOOTDIR_ABS/ubinize -o hps.bin -p 65536 -m 1 -s 1 "$UBINIZE_CFG"
        if [[ ! -f hps.bin ]]; then
            echo "[ERROR] Failed to create hps.bin!"
            exit 1
        fi
        echo "[INFO] UBI image created: hps.bin"
    else
        echo "[ERROR] ubinize.cfg not found at $BOOTDIR_ABS"
        exit 1
    fi
else
    echo "[INFO] hps.bin already exists. Skipping UBI creation."
fi

#--------------------------------------
# Generate final RPD file if not exists
#--------------------------------------
RPD_FILE="flash_image_jic.rpd"
if [[ ! -f "$RPD_FILE" ]]; then
    if [[ -f "$BOOTDIR_ABS/qspi_flash_image_agilex5-final.pfg" ]]; then
        echo "[INFO] Creating RPD using Quartus..."
        cp $BOOTDIR_ABS/agilex5_factory.sof .
        cp u-boot.itb u-boot-itb.bin
        quartus_pfg -c "$BOOTDIR_ABS/qspi_flash_image_agilex5-final.pfg"
        if [[ ! -f "$RPD_FILE" ]]; then
            echo "[ERROR] RPD file flash_image_jic.rpd not found!"
            exit 1
        fi
        echo "[SUCCESS] QSPI flash image created: flash_image_jic.rpd"
    else
        echo "[ERROR] PFG file not found: $BOOTDIR_ABS/qspi_flash_image_agilex5-final.pfg"
        exit 1
    fi
else
    echo "[INFO] flash_image_jic.rpd already exists. Skipping RPD creation."
fi
