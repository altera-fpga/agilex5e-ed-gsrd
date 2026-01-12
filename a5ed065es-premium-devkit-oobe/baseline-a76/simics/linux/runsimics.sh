#!/bin/bash

set -eo pipefail

# ============================
# Usage check
# ============================
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <command: sdmmc|qspi|clean> [binaries_path]"
    exit 1
fi

COMMAND="$1"
BINARIES_PATH="${2:-.}"   # Default to current directory if not given

# ============================
# Validate path (for commands that need it)
# ============================
if [[ "$COMMAND" != "clean" && ! -d "$BINARIES_PATH" ]]; then
    echo "[ERROR] Binaries path '$BINARIES_PATH' does not exist or is not a directory"
    exit 1
fi

# Convert BINARIES_PATH to absolute path
if [[ "$BINARIES_PATH" != /* ]]; then
    BINARIES_PATH="$(readlink -f "$BINARIES_PATH")"
fi
echo "[INFO] Binaries path: $BINARIES_PATH"

# ============================
# Clean command
# ============================
if [[ "$COMMAND" == "clean" ]]; then
    echo "[INFO] Cleaning all build and Simics artifacts..."

    # Remove binaries
    (
        cd "$BINARIES_PATH" || { echo "[ERROR] Failed to cd into $BINARIES_PATH"; exit 1; }
        rm -rf \
            simics-u-boot-spl-dtb.hex \
            u-boot-itb.bin \
            agilex5_factory.sof \
            agilex5_factory_hps_auto.sof \
            rootfs.ubifs \
            hps.bin \
            flash_image.jic \
            flash_image_jic.map \
            flash_image_jic.rpd
    )

    # Remove project files
    (
        PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        cd "$PROJECT_ROOT" || { echo "[ERROR] Cannot cd to project root: $PROJECT_ROOT"; exit 1; }
        rm -rf \
            .modcache \
            .project-properties \
            CMakeLists.txt \
            GNUmakefile \
            bin \
            cmake-wrapper.mk \
            compiler.mk \
            config.mk \
            documentation \
            gui-requirements.txt \
            linux64 \
            modules \
            requirements.txt \
            simics \
            simics-riscfree \
            targets
    )
    echo "[INFO] Cleanup complete."
    exit 0
fi

BOOTMODE="$COMMAND"
echo "[INFO] Boot mode: $BOOTMODE"

# ============================
# Set boot directory and scenario
# ============================
if [[ "$BOOTMODE" == "sdmmc" ]]; then
    BOOTDIR="sdmmc_boot"
    SIMICS_SCENARIO="$BOOTDIR/sdmmc_gsrd.simics"

    # Define image file paths
    UBOOT_FILE="$BINARIES_PATH/u-boot-spl-dtb.bin"
    SDMMC_IMAGE_FILE="$BINARIES_PATH/gsrd-console-image-agilex5e.rootfs.wic"

    # Log setup
    echo "[INFO] Simics scenario: $SIMICS_SCENARIO"
    echo "[INFO] U-Boot file: $UBOOT_FILE"
    echo "[INFO] SD image file: $SDMMC_IMAGE_FILE"

    # Verify files and update Simics scenario
    if [[ -f "$UBOOT_FILE" && -f "$SDMMC_IMAGE_FILE" && -f "$SIMICS_SCENARIO" ]]; then
        echo "[INFO] Updating Simics script: $SIMICS_SCENARIO"
        sed -i \
            -e "s|^\$fsbl_image_filename *= *\"[^\"]*\"|\$fsbl_image_filename = \"$UBOOT_FILE\"|" \
            -e "s|^\$sd_image_filename *= *\"[^\"]*\"|\$sd_image_filename = \"$SDMMC_IMAGE_FILE\"|" \
            "$SIMICS_SCENARIO"
        echo "[INFO] Simics script updated successfully."
    else
        echo "[WARN] Missing one or more required files:"
        [[ ! -f "$SIMICS_SCENARIO" ]] && echo "  - Simics scenario: $SIMICS_SCENARIO"
        [[ ! -f "$UBOOT_FILE" ]] && echo "  - U-Boot file: $UBOOT_FILE"
        [[ ! -f "$SDMMC_IMAGE_FILE" ]] && echo "  - SD image file: $SDMMC_IMAGE_FILE"
        exit 1
    fi
elif [[ "$BOOTMODE" == "qspi" ]]; then
    BOOTDIR="qspi_boot"
    SIMICS_SCENARIO="$BOOTDIR/qspi_gsrd.simics"

    # Define image file paths
    UBOOT_FILE="$BINARIES_PATH/u-boot-spl-dtb.bin"
    QSPI_IMAGE_FILE="$BINARIES_PATH/flash_image_jic.rpd"

    # Get absolute path to BOOTDIR
    BOOTDIR_ABS="$(readlink -f "$BOOTDIR")"

    # Create QSPI NOR flash image
    echo "[INFO] Creating QSPI NOR flash image in $BINARIES_PATH ..."
    echo "[DEBUG] Running: sh \"$BINARIES_PATH/qspi_flash_img.sh\" \"$BOOTDIR_ABS\""

    (
        cd "$BINARIES_PATH" || { echo "[ERROR] Failed to cd into $BINARIES_PATH"; exit 1; }
        sh "$BOOTDIR_ABS/qspi_flash_img.sh" "$BOOTDIR_ABS"
    )

    # ============================
    # Verify files and update Simics scenario
    # ============================
    echo "[INFO] Simics scenario: $SIMICS_SCENARIO"
    echo "[INFO] U-Boot file: $UBOOT_FILE"
    echo "[INFO] QSPI image file: $QSPI_IMAGE_FILE"

    if [[ -f "$UBOOT_FILE" && -f "$QSPI_IMAGE_FILE" && -f "$SIMICS_SCENARIO" ]]; then
        echo "[INFO] Updating Simics script: $SIMICS_SCENARIO"
        sed -i \
            -e "s|^\$fsbl_image_filename *= *\"[^\"]*\"|\$fsbl_image_filename = \"$UBOOT_FILE\"|" \
            -e "s|^\$qspi_image_filename *= *\"[^\"]*\"|\$qspi_image_filename = \"$QSPI_IMAGE_FILE\"|" \
            "$SIMICS_SCENARIO"
        echo "[INFO] Simics script updated successfully."
    else
        echo "[WARN] Missing one or more required files:"
        [[ ! -f "$SIMICS_SCENARIO" ]] && echo "  - Simics scenario: $SIMICS_SCENARIO"
        [[ ! -f "$UBOOT_FILE" ]] && echo "  - U-Boot file: $UBOOT_FILE"
        [[ ! -f "$QSPI_IMAGE_FILE" ]] && echo "  - QSPI image file: $QSPI_IMAGE_FILE"
    fi
fi

# ============================
# Deploy & Build Simics project
# ============================
echo "[INFO] Checking for existing Simics project..."
SIMICS_TARGET="targets/agilex5e-universal/agilex5e-universal.simics"
SIMICS_BINARY="./simics"

if find modules -type f \( -name "Makefile" -o -name "*.py" \) | grep -q . && [[ -f "$SIMICS_TARGET" && -f "$SIMICS_BINARY" ]]; then
        echo "[INFO] Existing Simics project and binary detected. Skipping deploy and build."
else
    echo "[INFO] Simics project or binary missing. Deploying and building..."
    simics_intelfpga_cli --deploy agilex5e-universal
    make
fi

# ============================
# Launch simulation
# ============================
echo "[INFO] Starting Simics simulation with scenario $SIMICS_SCENARIO ..."
./simics "$SIMICS_SCENARIO"

