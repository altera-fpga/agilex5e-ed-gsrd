# SD card layout for hps-amp Altera Agilex5 (two-partition: FAT32 + ext4).
#
# Consumed by scripts/mksdcard.sh.
#
# Layout:
#   Partition 1 (FAT32): u-boot.itb + bao.bin + linux.bin + boot.scr + optional fpga.rbf.
#   Partition 2 (ext4):  Linux root filesystem built by Buildroot (make rootfs).
#
# U-Boot SPL lives in HPS QSPI (programmed once via quartus_pfg), NOT on SD.

SD_SIZE_MB      := 512           # 512 MB total — fits on any 1 GB SD card, flashes fast
SD_LABEL        := AGILEX5BAO
SD_PARTITIONS   := fat32 ext4

SD_FAT_SIZE_MB  := 64            # p1 FAT32 — boot files (~44 MB used; 64 MB gives headroom)
SD_EXT4_SIZE_MB := 320           # p2 ext4  — rootfs (Buildroot image is 256 MB; 320 MB
                                 #   partition leaves room to grow on-board with resize2fs)

# Files (relative to build/<CONFIG>/out/) to copy into the FAT32 partition root.
# linux.bin + bao.bin loaded individually by boot.scr (no FIT/bootm needed).
# boot.scr  : compiled by `make boot-scr` from configs/<CONFIG>/boot.cmd
# fpga.rbf  : added separately via FPGA_RBF env var (optional, warn-and-continue)
SD_FAT_FILES    := u-boot.itb linux.bin bao.bin boot.scr

# ext4 image file (relative to build/<CONFIG>/out/) produced by `make rootfs`.
SD_EXT4_IMG     := rootfs.ext4
