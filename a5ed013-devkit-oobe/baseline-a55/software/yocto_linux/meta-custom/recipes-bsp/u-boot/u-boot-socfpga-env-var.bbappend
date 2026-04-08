SUMMARY = "U-boot boot environment for Altera SoCFPGA devices"
DESCRIPTION = "Sets the boot source for Second stage boot loader"
LICENSE = "MIT"

do_configure() {
    if [ -n "${SSBL_BOOT_SRC}" ]; then
        sed -i -e "s/boot_targets=.*/boot_targets=${SSBL_BOOT_SRC}/" ${S}/u-boot-env.txt
    else
        bbwarn "SSBL_BOOT_SRC is empty!, configure the boot source.."
    fi

    if [ -n "${KERNEL_BOOTARGS}" ]; then
        sed -i -e "s|^custom_bootargs=.*|custom_bootargs=${KERNEL_BOOTARGS}|" ${S}/u-boot-env.txt
    fi

    # Override MTD partition sizes for 512Mb (64MB) QSPI flash
    # Change from default 66m(u-boot),190m(root) to 12m(u-boot),52m(root)
    sed -i -e "s/66m(u-boot),190m(root)/12m(u-boot),52m(root)/" ${S}/u-boot-env.txt
    sed -i -e "s/66m(qspi_uboot),190m(qspi_root)/12m(qspi_uboot),52m(qspi_root)/" ${S}/u-boot-env.txt
}
