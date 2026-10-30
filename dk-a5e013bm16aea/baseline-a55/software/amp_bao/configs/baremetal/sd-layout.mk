# SD card layout for amp_bao (baremetal) — single FAT32 partition, no rootfs.
#
# Consumed by scripts/mksdcard.sh.
#
# Layout:
#   Partition 1 (FAT32): U-Boot itb + bao.bin + ilc_demo.bin + boot.scr + optional FPGA bitstream.
#   (No ext4/rootfs partition — the bare-metal VMs are embedded inside bao.bin.)
#
# Boot is driven by BOOTCOMMAND in uboot/configs/uboot.baremetal.cfg.frag, which
# fatloads + sources boot.scr (compiled from configs/baremetal/boot.cmd); the
# script fatloads fpga.rbf + bao.bin and `go`es to Bao.

SD_SIZE_MB      := 128           # informational — total image size target
SD_LABEL        := AGILEX5BAO
SD_PARTITIONS   := fat32         # single FAT32 partition (boot-only)

SD_FAT_SIZE_MB  := 120           # p1 FAT32 — boot files (~128 MB total image)

SD_FAT_FILES    := u-boot.itb bao.bin ilc_demo.bin boot.scr
