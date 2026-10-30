# U-Boot Kconfig fragment for hps-amp (Altera Agilex5).
# Merged on top of socfpga_agilex5_defconfig at build time via
#   scripts/kconfig/merge_config.sh
#
# Boot flow embedded in CONFIG_BOOTCOMMAND:
#   1. fatload boot.scr from FAT partition 1
#   2. source ${loadaddr}
#
# socfpga_v2026.07 Agilex5 defconfig enables CONFIG_BOOTSCR_FIT_SIGNATURE=y
# (ES-14537). amp_bao overrides that below and builds a legacy
# `mkimage -T script` boot.scr — no FIT signature and no pubkey embed.
#
# ${loadaddr}, ${filesize} are U-Boot runtime env vars (NOT Make vars).
# 0x88000000 is FIT_LOAD_ADDR; keep in sync with configs/<CONFIG>/config.mk.

# Boot command: load boot.scr from FAT32 partition 1 and execute it.
# boot.scr is built by `make boot-scr`.
CONFIG_USE_BOOTCOMMAND=y
CONFIG_BOOTCOMMAND="fatload mmc 0:1 ${loadaddr} boot.scr && source ${loadaddr}"

CONFIG_HUSH_PARSER=y
CONFIG_SYS_PROMPT="hps-amp # "

# FIT image support. Do not inherit Agilex5 FIT *signature* (amp_bao unsigned).
CONFIG_FIT=y
CONFIG_SPL_FIT=y
CONFIG_CMD_BOOTM=y
CONFIG_BOOTM_LINUX=y
CONFIG_BOOTSCR_FIT_SIGNATURE=n
CONFIG_SPL_FIT_SIGNATURE=n

# Disable NAND / UBI — SD boot only
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

# FAT / MMC / partitions
CONFIG_CMD_FAT=y
CONFIG_CMD_FS_GENERIC=y
CONFIG_DOS_PARTITION=y
CONFIG_SPL_DOS_PARTITION=y
CONFIG_CMD_PART=y
CONFIG_SPL_CRC32=y
CONFIG_LZO=y

# Network (TFTP fallback during bring-up)
CONFIG_CMD_DHCP=y
CONFIG_CMD_NET=y

# SPI flash chips commonly fitted on Agilex5 SoC dev boards
CONFIG_SPI_FLASH_MACRONIX=y
CONFIG_SPI_FLASH_GIGADEVICE=y
CONFIG_SPI_FLASH_WINBOND=y
CONFIG_SPI_FLASH_ISSI=y
