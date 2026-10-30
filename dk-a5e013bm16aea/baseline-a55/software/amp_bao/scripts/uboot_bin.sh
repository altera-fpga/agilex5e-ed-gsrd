#!/bin/bash
# Pad u-boot.itb to a 2 MiB u-boot.bin for the QSPI helper JIC partition.
# Run from the amp_bao build/<CONFIG>/out directory (where u-boot.itb lives).
set -euo pipefail

uboot_part_size=$((2 * 1024 * 1024))
uboot_size=$(wc -c < u-boot.itb)
uboot_pad=$((uboot_part_size - uboot_size))
cp u-boot.itb u-boot.bin
truncate -s +"$uboot_pad" u-boot.bin
