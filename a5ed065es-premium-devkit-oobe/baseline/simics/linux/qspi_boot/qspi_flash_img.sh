#!/bin/bash

# Exit immediately if a command fails or an unset variable is used
set -euo pipefail

# Check and get binaries path
binaries_path="${1:-}"

if [[ -z "$binaries_path" ]]; then
    echo "[ERROR] Binaries path not provided. Exiting..."
    exit 1
fi

echo "[INFO] Using binaries path: $binaries_path"

# Define required input/output files
declare -A files=(
    ["$binaries_path/u-boot-spl-dtb.bin"]="u-boot-spl-dtb.bin"
    ["$binaries_path/u-boot.itb"]="u-boot-itb.bin"
    ["$binaries_path/console-image-minimal-*.rootfs_nor.ubifs"]="rootfs.ubifs"
    ["$binaries_path/kernel.itb"]="kernel.itb"
    ["$binaries_path/boot.scr.uimg"]="boot.scr.uimg"
    ["$binaries_path/uboot.env"]="uboot.env"
)

# Copy each file with check
for src in "${!files[@]}"; do
    dest="${files[$src]}"
    match=($src)  # word-splitting allows glob to expand
    if [[ ${#match[@]} -eq 0 ]]; then
        echo "[WARNING] No match for: $src"
        continue
    fi
    cp "${match[0]}" "$dest"
    echo "[INFO] Copied ${match[0]} -> $dest"
done

# Create u-boot-spl-dtb.hex
echo "[INFO] Creating u-boot-spl-dtb.hex..."
aarch64-none-linux-gnu-objcopy -I binary -O ihex --change-addresses 0xffe00000 u-boot-spl-dtb.bin u-boot-spl-dtb.hex
if [[ ! -f u-boot-spl-dtb.hex ]]; then
    echo "[ERROR] Failed to generate u-boot-spl-dtb.hex"
    exit 1
fi

# Ubinize step
echo "[INFO] Creating UBI image..."
ubinize -o root.ubi -p 65536 -m 1 -s 1 ubinize.cfg
if [[ ! -f root.ubi ]]; then
    echo "[ERROR] Failed to create root.ubi!"
    exit 1
fi

cp root.ubi hps.bin
echo "[INFO] UBI image created: root.ubi -> hps.bin"

# Generate final RPD file
echo "[INFO] Creating RPD using Quartus..."
quartus_pfg -c qspi_flash_image_agilex5-final.pfg
if [[ ! -f flash_image_jic.rpd ]]; then
    echo "[ERROR] RPD file flash_image_jic.rpd not found!"
    exit 1
fi

echo "[SUCCESS] qspi flash image(flash_image_jic.rpd) created."
