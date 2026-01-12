SUMMARY = "U-boot boot environment for Altera SoCFPGA devices"
DESCRIPTION = "Sets the boot source for Second stage boot loader"
LICENSE = "MIT"

do_configure() {
    if [ -n "${SSBL_BOOT_SRC}" ]; then
        sed -i -e "s/boot_targets=.*/boot_targets=${SSBL_BOOT_SRC}/" ${WORKDIR}/sources-unpack/u-boot-env.txt
    else
        bbwarn "SSBL_BOOT_SRC is empty!, configure the boot source.."
    fi

    if [ -n "${KERNEL_BOOTARGS}" ]; then
        sed -i -e "s|^custom_bootargs=.*|custom_bootargs=${KERNEL_BOOTARGS}|" ${WORKDIR}/sources-unpack/u-boot-env.txt
    fi
}
