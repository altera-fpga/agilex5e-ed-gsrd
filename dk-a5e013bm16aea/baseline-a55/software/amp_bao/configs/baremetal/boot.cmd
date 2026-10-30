# U-Boot boot script — Agilex5 Bao AMP, bare-metal flavor (board-agnostic)
#
# Compiled to boot.scr by `make boot-scr` (or `make sdcard`):
#   mkimage -A arm64 -O linux -T script -C none \
#           -n "Agilex5 Bao AMP (baremetal) Boot" -d boot.cmd boot.scr
#
# Loaded by U-Boot's CONFIG_BOOTCOMMAND (uboot/configs/uboot.baremetal.cfg.frag):
#   fatload mmc 0:1 ${loadaddr} boot.scr && source ${loadaddr}
#
# Partition layout (produced by `make sdcard`):
#   p1 FAT32 : u-boot.itb, bao.bin, ilc_demo.bin, boot.scr[, fpga.rbf]
#   (no ext4/rootfs — both bare-metal VMs are embedded inside bao.bin)
#
# The FPGA bitstream is optional: `make sdcard FPGA_RBF=<path/to/core.rbf>`
# copies it onto the FAT32 partition as fpga.rbf.  If FPGA_RBF is omitted the
# image has no fpga.rbf and the FPGA programming step is skipped.
#
# Load addresses (keep bao.bin in sync with BAO_LOAD_ADDR in configs/baremetal/config.mk):
#   fpga.rbf -> 0x88000000  (scratch; MUST differ from ${loadaddr}, see note)
#   bao.bin  -> 0x90200000
#
# NOTE: BOOTCOMMAND loads THIS script to ${loadaddr} and `source`s it in place,
# so the script must not fatload anything back to ${loadaddr} — that would
# overwrite the running script mid-execution. fpga.rbf therefore uses a dedicated
# scratch address (0x88000000, clear of both ${loadaddr} and bao.bin).

echo "=== Agilex5 Bao AMP Boot (baremetal) ==="

# 1. Program FPGA fabric from FAT32 (optional — image may omit fpga.rbf).
echo "Loading FPGA bitstream (fpga.rbf, if present)..."
mmc dev 0
if fatload mmc 0:1 0x88000000 fpga.rbf; then
    fpga load 0 0x88000000 ${filesize}
fi

# 2. Load Bao hypervisor (both bare-metal VMs are embedded inside bao.bin).
echo "Loading Bao hypervisor (bao.bin)..."
fatload mmc 0:1 0x90200000 bao.bin

# 3. Enable HPS-FPGA bridges (LWH2F: interval timer + ILC live in the fabric).
bridge enable

# 4. Disable caches (flushes to DRAM) + MMU, then jump to Bao.
# Bao must be entered with the MMU off and DRAM coherent; dcache off does both.
wdt dev watchdog@10d00200
wdt stop
dcache off

echo "Booting Bao hypervisor..."
go 0x90200000
