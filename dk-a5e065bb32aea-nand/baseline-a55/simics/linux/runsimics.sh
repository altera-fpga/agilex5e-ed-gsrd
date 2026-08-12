#!/bin/bash

set -eo pipefail

# ============================
# Usage check
# ============================
COMMAND="${1:-}"

if [[ -z "$COMMAND" ]]; then
    echo "Usage: $0 clean"
    echo "       $0 <nand|qspi> <binaries_path>"
    exit 1
fi

BINARIES_PATH="$2"

# ============================
# Validate path (for commands that need it)
# ============================
if [[ "$COMMAND" != "clean" ]]; then
    if [[ -z "$BINARIES_PATH" ]]; then
        echo "[ERROR] Binaries path is required for '$COMMAND' command"
        echo "Usage: $0 $COMMAND <binaries_path>"
        exit 1
    fi
    if [[ ! -d "$BINARIES_PATH" ]]; then
        echo "[ERROR] Binaries path '$BINARIES_PATH' does not exist or is not a directory"
        exit 1
    fi

    # Convert BINARIES_PATH to absolute path
    if [[ "$BINARIES_PATH" != /* ]]; then
        BINARIES_PATH="$(readlink -f "$BINARIES_PATH")"
    fi
    echo "[INFO] Binaries path: $BINARIES_PATH"
fi

# ============================
# Clean command
# ============================
if [[ "$COMMAND" == "clean" ]]; then
    echo "[INFO] Cleaning Simics project files..."

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
if [[ "$BOOTMODE" == "nand" ]]; then
    BOOTDIR="nand_boot"
    SIMICS_SCENARIO="$BOOTDIR/nand_gsrd.simics"

    # Define image file paths
    UBOOT_FILE="$BINARIES_PATH/u-boot-spl-dtb.bin"
    UBOOT_ITB_FILE="$BINARIES_PATH/u-boot.itb"
    ROOT_UBI_FILE="$BINARIES_PATH/root.ubi"
    NAND_IMAGE_FILE="$BINARIES_PATH/nand.img"

    # Get absolute path to BOOTDIR
    BOOTDIR_ABS="$(readlink -f "$BOOTDIR")"

    # Log setup
    echo "[INFO] Simics scenario: $SIMICS_SCENARIO"
    echo "[INFO] U-Boot file: $UBOOT_FILE"
    echo "[INFO] U-Boot ITB file: $UBOOT_ITB_FILE"
    echo "[INFO] Root UBI file: $ROOT_UBI_FILE"
    echo "[INFO] NAND image file: $NAND_IMAGE_FILE"

    # Verify required files for NAND image creation
    if [[ ! -f "$UBOOT_FILE" ]]; then
        echo "[ERROR] u-boot-spl-dtb.bin not found at: $UBOOT_FILE"
        exit 1
    fi
    if [[ ! -f "$UBOOT_ITB_FILE" ]]; then
        echo "[ERROR] u-boot.itb not found at: $UBOOT_ITB_FILE"
        exit 1
    fi
    if [[ ! -f "$ROOT_UBI_FILE" ]]; then
        echo "[ERROR] root.ubi not found at: $ROOT_UBI_FILE"
        exit 1
    fi

    # Create NAND image
    if [[ -f "$NAND_IMAGE_FILE" ]]; then
        echo "[INFO] NAND image already exists: $NAND_IMAGE_FILE"
        echo "[INFO] Skipping regeneration. Use 'clean' command to remove and regenerate."
    else
        echo "[INFO] Creating NAND image in $BINARIES_PATH ..."
        echo "[DEBUG] Running: sh \"$BOOTDIR_ABS/nand_img.sh\" \"$BOOTDIR_ABS\""

        (
            cd "$BINARIES_PATH" || { echo "[ERROR] Failed to cd into $BINARIES_PATH"; exit 1; }
            sh "$BOOTDIR_ABS/nand_img.sh" "$BOOTDIR_ABS"
        )

        # Verify NAND image was created
        if [[ ! -f "$NAND_IMAGE_FILE" ]]; then
            echo "[ERROR] NAND image creation failed"
            exit 1
        fi
    fi

    # Update Simics scenario
    if [[ -f "$SIMICS_SCENARIO" ]]; then
        echo "[INFO] Updating Simics script: $SIMICS_SCENARIO"
        sed -i \
            -e "s|^\$fsbl_image_filename *= *\"[^\"]*\"|\$fsbl_image_filename = \"$UBOOT_FILE\"|" \
            -e "s|^\$nand_data_image_filename *= *\"[^\"]*\"|\$nand_data_image_filename = \"$NAND_IMAGE_FILE\"|" \
            "$SIMICS_SCENARIO"
        echo "[INFO] Simics script updated successfully."
    else
        echo "[ERROR] Simics scenario not found: $SIMICS_SCENARIO"
        exit 1
    fi

elif [[ "$BOOTMODE" == "qspi" ]]; then
    BOOTDIR="qspi_boot"
    SIMICS_SCENARIO="$BOOTDIR/qspi_gsrd.simics"

    # Define image file paths
    UBOOT_FILE="$BINARIES_PATH/u-boot-spl-dtb.bin"
    QSPI_IMAGE_FILE="$BINARIES_PATH/qspi_boot.rpd"

    # Get absolute path to BOOTDIR
    BOOTDIR_ABS="$(readlink -f "$BOOTDIR")"

    # Create QSPI NOR flash image
    echo "[INFO] Creating QSPI NOR flash image in $BINARIES_PATH ..."
    echo "[DEBUG] Running: sh \"$BOOTDIR_ABS/qspi_flash_img.sh\" \"$BOOTDIR_ABS\""

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
# Patch Simics scenario for NAND boot: connect eth0 instead of eth2
# ============================
if [[ "$BOOTMODE" == "nand" ]]; then
    SIMICS_UNIVERSAL="targets/agilex5e-universal/agilex5e-universal.simics"
    if [[ -f "$SIMICS_UNIVERSAL" ]]; then
        echo "[INFO] Patching $SIMICS_UNIVERSAL to connect eth0 instead of eth2..."
        sed -i \
            -e '/^\s*# Connect HPS eth2 to Ethernet Switch$/ {N; s/^\s*# Connect HPS eth2 to Ethernet Switch\n\s*connect (\$eth_switch.get-free-connector) \$system.board.eth2/\# Connect HPS eth0 to Ethernet Switch\n    connect (\$eth_switch.get-free-connector) \$system.board.eth0/; }' \
            "$SIMICS_UNIVERSAL"
        echo "[INFO] Patch applied."
    else
        echo "[WARN] $SIMICS_UNIVERSAL not found, skipping eth patch."
    fi
fi

# ============================
# Launch simulation
# ============================
echo "[INFO] Starting Simics simulation with scenario $SIMICS_SCENARIO ..."
./simics "$SIMICS_SCENARIO"
