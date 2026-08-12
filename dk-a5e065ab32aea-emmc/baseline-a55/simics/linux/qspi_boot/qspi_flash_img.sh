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

#--------------------------------------
# Check RPD file exists
#--------------------------------------
RPD_FILE="qspi_boot.rpd"
if [[ ! -f "$RPD_FILE" ]]; then
    echo "[ERROR] qspi_boot.rpd not found. You may generate by following steps mentioned in software/yocto_linux/scripts/README.md"
    exit 1
else
    echo "[INFO] Found qspi_boot.rpd"
fi
