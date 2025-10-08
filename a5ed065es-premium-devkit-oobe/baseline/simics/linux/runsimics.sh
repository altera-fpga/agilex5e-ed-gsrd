#!/bin/bash

set -eo pipefail

# Usage check: expect exactly 2 arguments
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <bootmode: sdmmc|qspi> <binaries_path>"
    exit 1
fi

BOOTMODE="$1"
BINARIES_PATH="$2"

# Validate bootmode argument
if [[ "$BOOTMODE" != "sdmmc" && "$BOOTMODE" != "qspi" ]]; then
    echo "[ERROR] Invalid bootmode '$BOOTMODE'. Allowed values: sdmmc or qspi"
    exit 1
fi

# Validate binaries path
if [[ ! -d "$BINARIES_PATH" ]]; then
    echo "[ERROR] Binaries path '$BINARIES_PATH' does not exist or is not a directory"
    exit 1
fi

# Convert BINARIES_PATH to absolute path if it is relative
if [[ "$BINARIES_PATH" != /* ]]; then
    BINARIES_PATH="$(readlink -f "$BINARIES_PATH")"
fi

echo "[INFO] Boot mode: $BOOTMODE"
echo "[INFO] Binaries path: $BINARIES_PATH"

# Check simics CLI availability
if ! command -v simics_intelfpga_cli >/dev/null 2>&1; then
    echo "[ERROR] SIMICS CLI (simics_intelfpga_cli) not found in PATH. Please set up SIMICS environment."
    exit 1
fi

# Set boot directory and simics scenario file
if [[ "$BOOTMODE" == "sdmmc" ]]; then
    BOOTDIR="sdmmc_boot"
    SIMICS_SCENARIO="sdmmc_gsrd.simics"
    
    # Copy binaries for sdmmc boot
    echo "[INFO] Copying binaries to $BOOTDIR..."
    cp "${BINARIES_PATH}/u-boot-spl-dtb.bin" "$BOOTDIR"/u-boot-spl-dtb.bin
    cp "${BINARIES_PATH}"/console-image-minimal-agilex5e.rootfs-*.wic "$BOOTDIR"/console-image-minimal.rootfs.wic

elif [[ "$BOOTMODE" == "qspi" ]]; then
    BOOTDIR="qspi_boot"
    SIMICS_SCENARIO="qspi_gsrd.simics"
    
    # Create QSPI NOR flash image
    echo "[INFO] Creating QSPI NOR flash image..."
    (
        cd "$BOOTDIR"
        sh qspi_flash_img.sh "$BINARIES_PATH"
    )
fi

# Initialize the project directory and deploy a virtual platform for Agilex5e
echo "[INFO] Deploying Simics project..."
simics_intelfpga_cli --deploy agilex5e-universal

echo "[INFO] Building Simics project..."
make

echo "[INFO] Starting Simics simulation with scenario $SIMICS_SCENARIO ..."
./simics "$BOOTDIR/$SIMICS_SCENARIO"

