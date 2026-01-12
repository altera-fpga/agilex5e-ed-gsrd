SUMMARY = "U-boot"
DESCRIPTION = "This receipe enables u-boot customizations(device tree, configs and patches)"

# Prepare the path of the device tree file location
UBOOT_DEVICE_TREE_SRC_PATH := "${THISDIR}/files/dts"

# Set path for configs and source patches
FILESEXTRAPATHS:prepend := "${THISDIR}/files/configs:${THISDIR}/files/patches:"

# FSBL - based on boot source (SSBL_BOOT_SRC) configuration, update
# the u-boot,spl-boot-order property in device tree source file
do_configure:append() {
   UBOOT_DTSI_FILE="${S}/arch/arm/dts/socfpga_agilex5_socdk-u-boot.dtsi"

    if [ "${SSBL_BOOT_SRC}" = "mmc0" ]; then
        # Replace the value of the u-boot,spl-boot-order property with '&mmc,"/memory"'
        sed -i 's/^\(\s*u-boot,spl-boot-order\s*=\s*\).*$/\1\&mmc,"\/memory";/' "${UBOOT_DTSI_FILE}"

    elif [ "${SSBL_BOOT_SRC}" = "qspi" ]; then
        # Replace the value of the u-boot,spl-boot-order property with '&flash0,"/memory"'
        sed -i 's/^\(\s*u-boot,spl-boot-order\s*=\s*\).*$/\1\&flash0,"\/memory";/' "${UBOOT_DTSI_FILE}"
    else
        :
    fi
}
