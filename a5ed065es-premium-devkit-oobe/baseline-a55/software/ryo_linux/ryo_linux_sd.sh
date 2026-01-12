#!/bin/bash
# =============================================================================
# Agilex 5 HPS Roll-Your-Own Linux Example Script
# =============================================================================
#
# PURPOSE:
# This script builds an SD card boot image for Altera Agilex 5 HPS systems.
# The SD card image produced from this script will demonstrate the HPS first boot flow
# and no configuration of FPGA core fabric will take place in U-Boot or Linux.
#
# USAGE:
#   ./ryo_linux_sd.sh
#
# OUTPUT:
#   sdcard.img - Ready to write to SD card
#
# REQUIREMENTS:
# - Linux host system (Ubuntu 22.04+ recommended)
# - Internet connection for downloading sources
# - ~20GB free disk space
# - guestfs-tools for SD image creation
#
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# CONFIGURATION
# =============================================================================

echo "======================================================================"
echo "   Agilex 5 HPS SD Card Boot Flow Builder (Simplified)"
echo "======================================================================"

# Build configuration
OUTPUT_DIR="./build_output"
JOBS=$(nproc)

# Component URLs and settings
# Using the musl compiler to make a tight, statically linked Linux environment
TOOLCHAIN_URL="https://landley.net/toybox/downloads/binaries/toolchains/latest/aarch64-linux-musleabi-cross.tar.xz"
TOOLCHAIN_DIR="aarch64-linux-musleabi-cross"

ATF_REPO="https://github.com/altera-fpga/arm-trusted-firmware"
ATF_BRANCH="QPDS25.3.1_REL_GSRD_PR"
ATF_DIR="arm-trusted-firmware"

UBOOT_REPO="https://github.com/altera-fpga/u-boot-socfpga"
UBOOT_BRANCH="QPDS25.3.1_REL_GSRD_PR"
UBOOT_DIR="u-boot-socfpga"

LINUX_REPO="https://github.com/altera-fpga/linux-socfpga"
LINUX_BRANCH="QPDS25.3.1_REL_GSRD_PR"
LINUX_DIR="linux-socfpga"

TOYBOX_REPO="https://github.com/landley/toybox.git"
TOYBOX_DIR="toybox"

# =============================================================================
# BUILD PROCESS
# =============================================================================

echo "[STEP] Setting up build environment..."

# Create and enter build directory
mkdir -p "${OUTPUT_DIR}"
cd "${OUTPUT_DIR}"

# Set environment variables
export ARCH=arm64
export CROSS_COMPILE="${PWD}/${TOOLCHAIN_DIR}/bin/aarch64-linux-musleabi-"

echo "Build directory: ${PWD}"
echo "Architecture: ${ARCH}"
echo "Cross compiler: ${CROSS_COMPILE}"

# =============================================================================
# DOWNLOAD AND SETUP TOOLCHAIN
# =============================================================================

echo "[STEP] Setting up ARM GNU toolchain..."

TOOLCHAIN_ARCHIVE="${TOOLCHAIN_DIR}.tar.xz"

if [[ ! -d "${TOOLCHAIN_DIR}" ]]; then
    if [[ ! -f "${TOOLCHAIN_ARCHIVE}" ]]; then
        echo "Downloading ARM GNU toolchain..."
        if command -v wget >/dev/null 2>&1; then
            wget --no-check-certificate --progress=bar:force:noscroll -O "${TOOLCHAIN_ARCHIVE}" "${TOOLCHAIN_URL}"
        elif command -v curl >/dev/null 2>&1; then
            curl -L --progress-bar -o "${TOOLCHAIN_ARCHIVE}" "${TOOLCHAIN_URL}"
        else
            echo "ERROR: Neither wget nor curl found. Please install one of them."
            exit 1
        fi
    fi

    echo "Extracting ARM GNU toolchain..."
    tar -xf "${TOOLCHAIN_ARCHIVE}"

    # Verify toolchain
    if [[ ! -x "${TOOLCHAIN_DIR}/bin/aarch64-linux-musleabi-gcc" ]]; then
        echo "ERROR: ARM toolchain verification failed"
        exit 1
    fi

    echo "ARM toolchain setup complete"
else
    echo "ARM toolchain already exists, skipping download"
fi

# Add toolchain to the path
export PATH=${PWD}/${TOOLCHAIN_DIR}/bin:$PATH

# =============================================================================
# BUILD ARM TRUSTED FIRMWARE
# =============================================================================

echo "[STEP] Building ARM Trusted Firmware (ATF)..."

if [[ ! -d "${ATF_DIR}" ]]; then
    git clone -b "${ATF_BRANCH}" "${ATF_REPO}" "${ATF_DIR}"
fi

cd "${ATF_DIR}"

# Clean and build ATF
make clean
make -j "${JOBS}" PLAT=agilex5 bl31

cd ..

echo "ATF build complete"

# =============================================================================
# BUILD U-BOOT
# =============================================================================

echo "[STEP] Building U-Boot bootloader..."

if [[ ! -d "${UBOOT_DIR}" ]]; then
    git clone -b "${UBOOT_BRANCH}" "${UBOOT_REPO}" "${UBOOT_DIR}"
fi

cd "${UBOOT_DIR}"

# Enable debug info for compatibility
sed -i 's/PLATFORM_CPPFLAGS += -D__ARM__/PLATFORM_CPPFLAGS += -D__ARM__ -gdwarf-4/g' arch/arm/config.mk

# Configure for SD card boot
sed -i 's/u-boot,spl-boot-order.*/u-boot,spl-boot-order = \&mmc;/g' arch/arm/dts/socfpga_agilex5_socdk-u-boot.dtsi

# Disable NAND in device tree
sed -i '/&nand {/!b;n;c\\tstatus = "disabled";' arch/arm/dts/socfpga_agilex5_socdk-u-boot.dtsi

# Link directly to ATF bl31.bin in its build directory
ln -sf "../${ATF_DIR}/build/agilex5/release/bl31.bin" .

# Create SD card specific U-Boot configuration
cat > config-fragment << 'EOF'
# Use Image instead of kernel.itb
CONFIG_BOOTFILE="Image"
# Disable NAND/UBI related settings
CONFIG_NAND_BOOT=n
CONFIG_SPL_NAND_SUPPORT=n
CONFIG_CMD_NAND_TRIMFFS=n
CONFIG_CMD_NAND_LOCK_UNLOCK=n
CONFIG_NAND_DENALI_DT=n
CONFIG_SYS_NAND_U_BOOT_LOCATIONS=n
CONFIG_SPL_NAND_FRAMEWORK=n
CONFIG_CMD_NAND=n
CONFIG_MTD_RAW_NAND=n
CONFIG_CMD_UBI=n
CONFIG_CMD_UBIFS=n
CONFIG_MTD_UBI=n
CONFIG_ENV_IS_IN_UBI=n
CONFIG_UBI_SILENCE_MSG=n
CONFIG_UBIFS_SILENCE_MSG=n
# Disable distroboot and use specific boot command (same as Makefile)
CONFIG_DISTRO_DEFAULTS=n
CONFIG_HUSH_PARSER=y
CONFIG_SYS_PROMPT_HUSH_PS2="> "
CONFIG_USE_BOOTCOMMAND=y
CONFIG_BOOTCOMMAND="printenv bootcmd; fatls mmc 0:1; setenv bootargs console=ttyS0,115200 initrd=0x90000000 root=/dev/ram0 rw init=init ramdisk_size=10000000 earlycon panic=-1 loglevel=8; mmc info; fatload mmc 0:1 0x86000000 Image; fatload mmc 0:1 0x8c000000 socfpga_agilex5_socdk.dtb; fatload mmc 0:1 0x90000000 initramfs.cpio; booti 0x86000000 0x90000000:\${filesize} 0x8c000000"
CONFIG_CMD_FAT=y
CONFIG_CMD_FS_GENERIC=y
CONFIG_DOS_PARTITION=y
CONFIG_SPL_DOS_PARTITION=y
CONFIG_CMD_PART=y
CONFIG_SPL_CRC32=y
CONFIG_LZO=y
CONFIG_CMD_DHCP=y
# Enable more QSPI flash manufacturers
CONFIG_SPI_FLASH_MACRONIX=y
CONFIG_SPI_FLASH_GIGADEVICE=y
CONFIG_SPI_FLASH_WINBOND=y
CONFIG_SPI_FLASH_ISSI=y
EOF

# Build U-Boot
make clean && make mrproper
make socfpga_agilex5_defconfig
./scripts/kconfig/merge_config.sh -O . -m .config config-fragment
make -j "${JOBS}"

cd ..

echo "U-Boot build complete"

# =============================================================================
# BUILD LINUX KERNEL
# =============================================================================

echo "[STEP] Building Linux kernel..."

if [[ ! -d "${LINUX_DIR}" ]]; then
    git clone -b "${LINUX_BRANCH}" "${LINUX_REPO}" "${LINUX_DIR}"
fi

cd "${LINUX_DIR}"

# Create custom config fragment for networking
cat > config-fragment-agilex5 << 'EOF'
# Enable Ethernet connectivity
CONFIG_MARVELL_PHY=y
EOF

# Configure and build kernel
make defconfig
./scripts/kconfig/merge_config.sh -O ./ ./.config ./config-fragment-agilex5
make oldconfig
make -j "${JOBS}" Image && make intel/socfpga_agilex5_socdk.dtb

cd ..

echo "Linux kernel build complete"

# =============================================================================
# BUILD TOYBOX ROOTFS
# =============================================================================

echo "[STEP] Building toybox root filesystem..."

if [[ ! -d "${TOYBOX_DIR}" ]]; then
    git clone "${TOYBOX_REPO}" "${TOYBOX_DIR}"
fi

cd "${TOYBOX_DIR}"

# Clean any previous builds first
make clean 2>/dev/null || true

# Use defconfig and build with cross-compilation
export CC=gcc

# Use standard defconfig - musl toolchain should handle this cleanly
make defconfig
mkroot/mkroot.sh || { echo "ERROR: make root failed"; exit 1; }

# Extract the initramfs.cpio from toybox's output (same as Makefile approach)
if [[ -f "root/aarch64/initramfs.cpio.gz" ]]; then
    echo "Creating initramfs.cpio from toybox output..."
    gzip -dc root/aarch64/initramfs.cpio.gz > ../initramfs.cpio

    echo "Toybox initramfs.cpio created successfully"
else
    echo "ERROR: Failed to find toybox initramfs.cpio.gz output"
    exit 1
fi

cd ..

echo "Toybox rootfs build complete"

# =============================================================================
# CREATE SD CARD IMAGE
# =============================================================================

echo "[STEP] Creating SD card image..."

# Write an empty SD card image
dd if=/dev/zero of=sdcard.img bs=1M count=64

echo "Creating SD card image with files: u-boot.itb, Image, socfpga_agilex5_socdk.dtb, initramfs.cpio"

# Format the SD card image with FAT32 partition
mformat -i sdcard.img :: -F

# Copy U-Boot, Kernel Image, DTB and Toybox Root CPIO to the SD card image
mcopy -i sdcard.img ${UBOOT_DIR}/u-boot.itb ::
mcopy -i sdcard.img ${LINUX_DIR}/arch/arm64/boot/Image ::
mcopy -i sdcard.img ${LINUX_DIR}/arch/arm64/boot/dts/intel/socfpga_agilex5_socdk.dtb ::
mcopy -i sdcard.img initramfs.cpio ::

if [[ $? -eq 0 ]]; then
    echo "SUCCESS: SD card image created: sdcard.img"
    echo ""
    echo "======================================================================"
    echo "                           BUILD COMPLETE"
    echo "======================================================================"
    echo ""
    echo "Output files created in: ${PWD}"
    echo ""
    echo "Key files:"
    echo "  sdcard.img                   - SD card image (write to SD card)"
    echo "  u-boot.itb                   - U-Boot bootloader"
    echo "  Image                        - Linux kernel"
    echo "  socfpga_agilex5_socdk.dtb    - Device tree"
    echo "  initramfs.cpio               - Root filesystem (initramfs)"
    echo ""
    echo "To write SD card image:"
    echo "  sudo dd if=${PWD}/sdcard.img of=/dev/sdX bs=1M"
    echo "  (Replace /dev/sdX with your SD card device)"
    echo ""
    echo "To boot from SD card:"
    echo "  1. Write image to SD card"
    echo "  2. Insert SD card into Agilex 5 board"
    echo "  3. Use quartus_pfg to generate a JIC using GHRD sof + u-boot-spl-dtb.hex"
    echo "     e.g. quartus_pfg \\"
    echo "          -c sof_filename.sof output_file.jic \\"
    echo "          -o device=MT25QU128 \\"
    echo "          -o flash_loader=A5ED065BB32AE6SR0 \\"
    echo "          -o hps_path=${UBOOT_DIR}/spl/u-boot-spl-dtb.hex \\"
    echo "          -o mode=ASX4 \\"
    echo "          -o hps=1"
    echo "  4. Program the JIC and power cycle the board"
    echo "     e.g. quartus_pgm -c 1 -m jtag -o \"pvi;output_file.jic\""
    echo ""
    echo "EDUCATIONAL: Boot process:"
    echo "  1. U-Boot loads Image, DTB, and initramfs.cpio from FAT32"
    echo "  2. Linux kernel unpacks initramfs.cpio into RAM"
    echo "  3. System runs entirely from RAM (no ext3 partition needed)"
    echo ""
else
    echo "ERROR: Failed to create SD card image"
    exit 1
fi
