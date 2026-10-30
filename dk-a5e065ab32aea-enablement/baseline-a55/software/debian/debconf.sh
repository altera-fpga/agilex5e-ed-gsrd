# all variables required
ATF_REPO="github:altera-fpga/arm-trusted-firmware"
ATF_REF="QPDS26.3_REL_BASELINE_PR"
UBOOT_REPO="github:altera-fpga/u-boot-socfpga"
UBOOT_REF="QPDS26.3_REL_BASELINE_PR"
LINUX_REPO="github:altera-fpga/linux-socfpga"
LINUX_REF="QPDS26.3_REL_BASELINE_PR"

# optional
UBOOT_ITS_FILE="uboot_script.its"
UBOOT_ITS_URL="https://raw.githubusercontent.com/altera-fpga/meta-altera-fpga/wrynose/meta-altera-bsp/recipes-bsp/u-boot/bootscr/${UBOOT_ITS_FILE}"
UBOOT_SCRIPT_FILE="uboot.txt"
UBOOT_SCRIPT_URL="https://raw.githubusercontent.com/altera-fpga/meta-altera-fpga/wrynose/meta-altera-bsp/recipes-bsp/u-boot/bootscr/${UBOOT_SCRIPT_FILE}"

FABRIC_RBF_FILE=
FABRIC_RBF_URL=
