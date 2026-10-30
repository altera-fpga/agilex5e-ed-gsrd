# U-Boot boot script — Agilex5 Bao AMP (board-agnostic)
#
# Compiled to boot.scr by `make boot-scr` (or `make sdcard`):
#   mkimage -A arm64 -O linux -T script -C none \
#           -n "Agilex5 Bao AMP Boot" -d boot.cmd boot.scr
#
# Loaded by U-Boot's CONFIG_BOOTCOMMAND:
#   fatload mmc 0:1 ${loadaddr} boot.scr && source ${loadaddr}
#
# Partition layout (produced by `make sdcard`):
#   p1 FAT32  : u-boot.itb, linux.bin, bao.bin, boot.scr[, fpga.rbf]
#   p2 ext4   : Linux root filesystem (Buildroot)
#
# The FPGA bitstream is optional: `make sdcard FPGA_RBF=<path/to/core.rbf>`
# copies it onto the FAT32 partition as fpga.rbf.  If FPGA_RBF is omitted
# the image has no fpga.rbf and the FPGA programming step is skipped.
#
# Load addresses (matching the proven demo image and harness):
#   linux.bin -> 0x82000000
#   bao.bin   -> 0xe0000000
#
# bao.bin load address note: it was 0xd0000000 before cache-coloring. With the
# Linux VM colored (config.c .colors=0xFFF0, place_phys=false), Bao must
# allocate ~1 GiB of *contiguous* Linux-colored physical pages. Bao's own image
# (Bao + the embedded 16 MiB FreeRTOS) splits that pool, so it is placed high at
# 0xe0000000 to leave a large enough contiguous colored region below it. Keep
# this in sync with the `go` address below and any test-harness serial command.

echo "=== Agilex5 Bao AMP Boot ==="

# 1. Program FPGA fabric from FAT32 (optional — image may omit fpga.rbf)
# Reuse linux.bin load address — safe because fpga load consumes the
# bitstream before linux.bin is loaded to the same address.
echo "Loading FPGA bitstream (fpga.rbf, if present)..."
mmc dev 0
if fatload mmc 0:1 0x82000000 fpga.rbf; then
    fpga load 0 0x82000000 ${filesize}
fi

# 2. Enable HPS-FPGA bridges
bridge enable

# 3. Load Bao hypervisor + Linux VM
echo "Loading Linux+FreeRTOS binaries..."
fatload mmc 0:1 0x82000000 linux.bin
fatload mmc 0:1 0xe0000000 bao.bin

# 4. Stop watchdog and jump to Bao
wdt dev watchdog@10d00200
wdt stop
dcache off

echo "Booting Bao hypervisor..."
go 0xe0000000
