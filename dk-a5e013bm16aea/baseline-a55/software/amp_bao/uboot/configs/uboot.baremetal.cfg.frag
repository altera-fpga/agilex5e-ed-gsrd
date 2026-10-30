# Bao hypervisor U-Boot config fragment — Agilex5 SD card (bare-metal AMP).
#
# Merged on top of socfpga_agilex5_defconfig by `make uboot`
# (scripts/kconfig/merge_config.sh).
#
# Boot flow (amp_bao disables CONFIG_BOOTSCR_FIT_SIGNATURE — see below):
#   1. fatload boot.scr from FAT partition 1
#   2. source ${loadaddr}
#        boot.scr from configs/baremetal/boot.cmd via `make boot-scr`
#        performs: fpga.rbf (optional) -> bao.bin -> bridge enable -> wdt stop
#        -> dcache off -> go 0x90200000.
#
# ${loadaddr} is a U-Boot runtime env var (NOT a Make var). The FPGA bitstream
# is always named fpga.rbf on p1; `make sdcard FPGA_RBF=<path>` stages it there.
CONFIG_USE_BOOTCOMMAND=y
CONFIG_BOOTCOMMAND="fatload mmc 0:1 ${loadaddr} boot.scr && source ${loadaddr}"
CONFIG_HUSH_PARSER=y
CONFIG_SYS_PROMPT="hps-amp # "

# amp_bao does not use FIT signature verification (override Agilex5 defconfig).
CONFIG_BOOTSCR_FIT_SIGNATURE=n
CONFIG_SPL_FIT_SIGNATURE=n

# Disable NAND / UBI (not needed for SD boot)
CONFIG_NAND_BOOT=n
CONFIG_SPL_NAND_SUPPORT=n
CONFIG_CMD_NAND=n
CONFIG_MTD_RAW_NAND=n
CONFIG_NAND_DENALI_DT=n
CONFIG_SYS_NAND_U_BOOT_LOCATIONS=n
CONFIG_CMD_UBI=n
CONFIG_CMD_UBIFS=n
CONFIG_MTD_UBI=n
CONFIG_ENV_IS_IN_UBI=n
CONFIG_UBI_SILENCE_MSG=n
CONFIG_UBIFS_SILENCE_MSG=n

# FAT / partition support
CONFIG_CMD_FAT=y
CONFIG_CMD_FS_GENERIC=y
CONFIG_DOS_PARTITION=y
CONFIG_SPL_DOS_PARTITION=y
CONFIG_CMD_PART=y
CONFIG_SPL_CRC32=y
CONFIG_LZO=y

# Network (for optional TFTP fallback)
CONFIG_CMD_DHCP=y
CONFIG_CMD_NET=y

# SPI flash manufacturers
CONFIG_SPI_FLASH_MACRONIX=y
CONFIG_SPI_FLASH_GIGADEVICE=y
CONFIG_SPI_FLASH_WINBOND=y
CONFIG_SPI_FLASH_ISSI=y
