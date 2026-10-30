#!/usr/bin/env bash
# hps-amp/scripts/mksdcard.sh
#
# Assemble the SD card image for a given CONFIG using genimage.
#
# Reads $LAYOUT_FILE (a Makefile-style key=value file) to learn the partition
# table and the per-partition file lists. Outputs $OUT_IMG.
#
# Required environment:
#   CONFIG        e.g. linux_freertos
#   OUT_DIR       directory containing the staged binaries (build/<CONFIG>/out)
#   OUT_IMG       full path to the sdimage.img to create
#   LAYOUT_FILE   full path to bao/configs/<CONFIG>/sd-layout.mk
# Optional:
#   FPGA_RBF      path to the FPGA bitstream (.rbf), copied into FAT32 if present
#   VERBOSE=1     show command output
#
# The layout file must define:
#   SD_LABEL        FAT32 volume label (default AGILEX5BAO)
#   SD_PARTITIONS   must be "fat32 ext4"
#   SD_FAT_SIZE_MB  FAT32 partition size in MB (default 128)
#   SD_EXT4_SIZE_MB ext4 partition size in MB (default 1900)
#   SD_FAT_FILES    files (relative to $OUT_DIR) to copy into FAT32 root
#   SD_EXT4_IMG     ext4 image filename (relative to $OUT_DIR)
#
# Partition layout (MBR / dos):
#   p1: FAT32, starts at 1 MiB, size = SD_FAT_SIZE_MB
#       Contains: u-boot.itb, linux.bin, bao.bin, boot.scr, [fpga.rbf]
#   p2: ext4,  starts immediately after p1
#       Contains: Buildroot rootfs image
#
# No root privilege required: genimage uses fakeroot internally.
# genimage is provisioned by `make toolchains` into .toolchain/hostdeps/bin/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

: "${CONFIG:?CONFIG not set}"
: "${OUT_DIR:?OUT_DIR not set}"
: "${OUT_IMG:?OUT_IMG not set}"
: "${LAYOUT_FILE:?LAYOUT_FILE not set}"

[[ -d "$OUT_DIR"     ]] || die "OUT_DIR does not exist: $OUT_DIR"
[[ -f "$LAYOUT_FILE" ]] || die "layout file not found: $LAYOUT_FILE"

# Parse layout (Make-style assignments). Only accepts SD_* keys.
SD_LABEL="AGILEX5BAO"
SD_PARTITIONS="fat32 ext4"
SD_FAT_SIZE_MB="128"
SD_EXT4_SIZE_MB="1900"
SD_FAT_FILES=""
SD_EXT4_IMG="rootfs.ext4"

while IFS= read -r line; do
    line="${line%%\#*}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z "$line" ]] && continue
    case "$line" in
        SD_LABEL*:=*|SD_LABEL*=*)
            SD_LABEL="$(printf '%s' "$line" | sed -E 's/^[^:=]*[:=]+[[:space:]]*//')" ;;
        SD_PARTITIONS*:=*|SD_PARTITIONS*=*)
            SD_PARTITIONS="$(printf '%s' "$line" | sed -E 's/^[^:=]*[:=]+[[:space:]]*//')" ;;
        SD_FAT_SIZE_MB*:=*|SD_FAT_SIZE_MB*=*)
            SD_FAT_SIZE_MB="$(printf '%s' "$line" | sed -E 's/^[^:=]*[:=]+[[:space:]]*//')" ;;
        SD_EXT4_SIZE_MB*:=*|SD_EXT4_SIZE_MB*=*)
            SD_EXT4_SIZE_MB="$(printf '%s' "$line" | sed -E 's/^[^:=]*[:=]+[[:space:]]*//')" ;;
        SD_FAT_FILES*:=*|SD_FAT_FILES*=*)
            SD_FAT_FILES="$(printf '%s' "$line" | sed -E 's/^[^:=]*[:=]+[[:space:]]*//')" ;;
        SD_EXT4_IMG*:=*|SD_EXT4_IMG*=*)
            SD_EXT4_IMG="$(printf '%s' "$line" | sed -E 's/^[^:=]*[:=]+[[:space:]]*//')" ;;
    esac
done < "$LAYOUT_FILE"

# Prepend the hostdeps bin dir and standard sbin dirs so genimage, mkdosfs,
# mcopy, and fakeroot are found even when the caller has not run
# `eval "$(toolchains.sh --print-env)"`.
_HOSTDEPS_DIR="${TOOLCHAIN_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)/.toolchain}/hostdeps"
export PATH="$_HOSTDEPS_DIR/bin:/usr/sbin:/sbin:$PATH"
# genimage is dynamically linked against a locally-built libconfuse under
# .toolchain/hostdeps/.  Export LD_LIBRARY_PATH so the dynamic linker finds
# the bundled libconfuse.so at runtime.
export LD_LIBRARY_PATH="${_HOSTDEPS_DIR}/lib:${_HOSTDEPS_DIR}/lib64:${LD_LIBRARY_PATH:-}"

# Validate prerequisites — genimage is provisioned by make toolchains;
# mkfs.fat (dosfstools) and mcopy (mtools) are called by genimage internally.
for cmd in genimage fakeroot mkfs.fat mcopy; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        if [[ "$cmd" == "fakeroot" ]]; then
            die "missing tool: fakeroot  (install fakeroot package on host)"
        fi
        die "missing tool: $cmd  (run: make toolchains)"
    fi
done

case "$SD_PARTITIONS" in
    "fat32 ext4") HAS_EXT4=1 ;;
    "fat32")      HAS_EXT4=0 ;;
    *) die "SD_PARTITIONS='$SD_PARTITIONS' not supported (expected 'fat32' or 'fat32 ext4')" ;;
esac

# Verify FAT files exist before touching the image.
missing=()
for f in $SD_FAT_FILES; do
    [[ -f "$OUT_DIR/$f" ]] || missing+=("$f")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    die "missing FAT artefact(s) under $OUT_DIR: ${missing[*]}"
fi

# Verify ext4 image (only when the layout includes a rootfs partition)
EXT4_IMG_PATH="$OUT_DIR/$SD_EXT4_IMG"
if [[ "$HAS_EXT4" -eq 1 ]]; then
    [[ -f "$EXT4_IMG_PATH" ]] \
        || die "ext4 rootfs image not found: $EXT4_IMG_PATH (run: make rootfs)"
fi

step "Creating SD image  CONFIG=$CONFIG  label=$SD_LABEL"
step "  p1: FAT32  ${SD_FAT_SIZE_MB}MB  (boot files)"
[[ "$HAS_EXT4" -eq 1 ]] && step "  p2: ext4   ${SD_EXT4_SIZE_MB}MB (rootfs)"

mkdir -p "$(dirname "$OUT_IMG")"

# ── Work directory ────────────────────────────────────────────────────────────
# genimage needs a clean tmp dir, an inputpath with all source files, and an
# outputpath to write the finished image. We use a subdir of OUT_IMG's parent.
WORK_DIR="$(dirname "$OUT_IMG")/genimage-work"
INPUT_DIR="$WORK_DIR/input"
TMP_DIR="$WORK_DIR/tmp"
ROOT_DIR_GI="$WORK_DIR/root"
OUTPUT_DIR="$WORK_DIR/output"

rm -rf "$WORK_DIR"
mkdir -p "$INPUT_DIR" "$TMP_DIR" "$ROOT_DIR_GI" "$OUTPUT_DIR"

# Stage FAT files (symlinks — avoids copying large rootfs)
for f in $SD_FAT_FILES; do
    ln -sf "$OUT_DIR/$f" "$INPUT_DIR/$f"
done

# Optional FPGA bitstream
if [[ -n "${FPGA_RBF:-}" && -f "$FPGA_RBF" ]]; then
    # Resolve to absolute path so the symlink target is valid from inside INPUT_DIR.
    FPGA_RBF="$(realpath "$FPGA_RBF")"
    ln -sf "$FPGA_RBF" "$INPUT_DIR/fpga.rbf"
    ok "  FAT p1: will include fpga.rbf  ($(bytes_human "$(stat -c%s "$FPGA_RBF")"))"
elif [[ -n "${FPGA_RBF:-}" ]]; then
    warn "FPGA_RBF=$FPGA_RBF not found — image created without it"
fi

# Stage ext4 rootfs (symlink) — only when the layout has a rootfs partition
if [[ "$HAS_EXT4" -eq 1 ]]; then
    ln -sf "$EXT4_IMG_PATH" "$INPUT_DIR/$SD_EXT4_IMG"
fi

# ── Build genimage.cfg ────────────────────────────────────────────────────────
CFG="$WORK_DIR/genimage.cfg"

# Build the FAT files list for genimage config (commas between entries, no trailing comma)
fat_files_array=()
for f in $SD_FAT_FILES; do
    fat_files_array+=("$f")
done
# Add fpga.rbf if staged
if [[ -L "$INPUT_DIR/fpga.rbf" ]]; then
    fat_files_array+=("fpga.rbf")
fi

fat_files_cfg=""
for i in "${!fat_files_array[@]}"; do
    if [[ $i -lt $((${#fat_files_array[@]} - 1)) ]]; then
        fat_files_cfg+="            \"${fat_files_array[$i]}\","$'\n'
    else
        fat_files_cfg+="            \"${fat_files_array[$i]}\""$'\n'
    fi
done

# The rootfs partition is only emitted for the two-partition (fat32 ext4) layout.
rootfs_part_cfg=""
if [[ "$HAS_EXT4" -eq 1 ]]; then
    rootfs_part_cfg="    partition rootfs {
        partition-type = 0x83
        image = \"${SD_EXT4_IMG}\"
        size = ${SD_EXT4_SIZE_MB}M
    }
"
fi

cat > "$CFG" <<EOF
image boot.vfat {
    vfat {
        label = "${SD_LABEL}"
        files = {
${fat_files_cfg}        }
    }
    size = ${SD_FAT_SIZE_MB}M
}

image sdimage.img {
    hdimage {}
    partition boot {
        partition-type = 0xC
        bootable = true
        image = "boot.vfat"
    }
${rootfs_part_cfg}}
EOF

# ── Run genimage ──────────────────────────────────────────────────────────────
run fakeroot genimage \
    --config "$CFG" \
    --tmppath "$TMP_DIR" \
    --inputpath "$INPUT_DIR" \
    --outputpath "$OUTPUT_DIR" \
    --rootpath "$ROOT_DIR_GI"

[[ -f "$OUTPUT_DIR/sdimage.img" ]] || die "genimage did not produce sdimage.img"

# Move final image into place and clean up work dir
mv "$OUTPUT_DIR/sdimage.img" "$OUT_IMG"
rm -rf "$WORK_DIR"

ok "SD image: $OUT_IMG  ($(bytes_human "$(stat -c%s "$OUT_IMG")"))"
echo ""
echo "  Partition map:"
echo "    p1  FAT32   ${SD_FAT_SIZE_MB}MiB  -> boot files${FPGA_RBF:+, fpga.rbf}"
if [[ "$HAS_EXT4" -eq 1 ]]; then
    echo "    p2  ext4    ${SD_EXT4_SIZE_MB}MiB  -> Linux rootfs (auto-login as root)"
fi
echo ""
echo "  To flash:"
echo "    sudo dd if=\"$OUT_IMG\" of=/dev/sdX bs=4M status=progress conv=fsync"
echo "    (replace /dev/sdX with your SD card device; verify with lsblk)"
if [[ "$HAS_EXT4" -eq 1 ]]; then
    echo ""
    echo "  To grow the rootfs partition to fill the SD card on-board:"
    echo "    resize2fs /dev/mmcblk0p2"
fi
echo ""
