#!/bin/bash
# =============================================================================
# Agilex 5 HPS Ubuntu Linux Example Script
# =============================================================================
#
# Please read the DISCLAIMER below.
#
# PURPOSE:
# This script builds an SD card boot image for Altera Agilex 5 HPS systems to 
# start Ubuntu.
# The SD card image produced from this script will demonstrate the HPS first boot flow
# and no configuration of FPGA core fabric will take place in U-Boot or Linux.
#
# USAGE:
#   ./mk_ubuntu_sd.sh
#
# OUTPUT:
#   sdcard.img - Ready to write to SD card
#
# REQUIREMENTS:
# - Linux host system (Ubuntu 22.04+ recommended)
# - Internet connection for downloading sources
# - ~20GB free disk space
# - Packages:
#   - build-essential
#   - bison
#   - flex
#   - guestfs-tools for SD image creation
#   - u-boot-tools
#   - python3-setuptools
#   - python3-dev
#   - libssl-dev
#   - bc 
#   - qemu-user-static
#   - xz-utils
#   - swig
#   - sudo
#   - wget
#   - git
#
# This script uses guestfs tools to create an SD card image.
# For the tools to work efficiently, it is
# important the kernel image file in /boot be readable by all users
# and that the user running the script be part of the group 'kvm'.
#
# Note that sudo privileges are required to run portions of this script
# to allow adding packages to the Ubuntu base image.
#
# DISCLAIMER:
# 
# Altera provides these materials to our customers solely as an example of
# how a Linux operating system may be configured for use with Altera products.
# Altera does not endorse, certify, or support Ubuntu or any other third-party
# operating system or software. It is the customer’s sole responsibility to
# determine whether Ubuntu, or another Linux instance is appropriate for its
# intended use, and to ensure compliance with all applicable open-source licenses,
# security requirements and technical or regulatory obligations.
# Altera offers these instructions “AS-IS” without any warranty of any kind,
# whether express, implied statutory or otherwise and Altera will not be liable
# to customer under any legal theory related to customer’s choice in using or
# distributing Ubuntu.
#
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# CONFIGURATION
# =============================================================================

# Build configuration
declare -r OUTPUT_DIR="./build_output"
declare -r OUTPUT_DIR_ABS="$(readlink -f ${OUTPUT_DIR})"
declare -r JOBS=$(nproc)

# Component URLs and settings
# Using the musl compiler to make a tight, statically linked Linux environment
declare -r TOOLCHAIN_URL="https://github.com/cross-tools/musl-cross/releases/download/20250929/aarch64-unknown-linux-musl.tar.xz"
declare -r TOOLCHAIN_DIR="aarch64-unknown-linux-musl"

declare -r ATF_REPO="https://github.com/altera-fpga/arm-trusted-firmware"
declare -r ATF_BRANCH="QPDS26.3_REL_BASELINE_PR"
declare -r ATF_DIR="arm-trusted-firmware"

declare -r UBOOT_REPO="https://github.com/altera-fpga/u-boot-socfpga"
declare -r UBOOT_BRANCH="QPDS26.3_REL_BASELINE_PR"
declare -r UBOOT_DIR="u-boot-socfpga"
declare -r UBOOT_ITS_FILE="uboot_script.its"
declare -r UBOOT_ITS_URL="https://raw.githubusercontent.com/altera-fpga/meta-altera-fpga/whinlatter/meta-altera-bsp/recipes-bsp/u-boot/bootscr/${UBOOT_ITS_FILE}"
declare -r UBOOT_SCRIPT_FILE="uboot.txt"
declare -r UBOOT_SCRIPT_URL="https://raw.githubusercontent.com/altera-fpga/meta-altera-fpga/whinlatter/meta-altera-bsp/recipes-bsp/u-boot/bootscr/${UBOOT_SCRIPT_FILE}"

declare -r LINUX_REPO="https://github.com/altera-fpga/linux-socfpga"
declare -r LINUX_BRANCH="QPDS26.3_REL_BASELINE_PR"
declare -r LINUX_DIR="linux-socfpga"

declare -r UBUNTU_VERSION="24.04.4"
declare -r UBUNTU_PACKAGES="apt-utils dialog language-pack-en-base sudo ssh net-tools \
ethtool iputils-ping rsyslog bash-completion vim-tiny kmod isc-dhcp-client network-manager \
systemd-timesyncd"
# the credentials below are of no security issue
declare -r UBUNTU_USER="user"
declare -r UBUNTU_PASS="fpga1983"
# use this variable to set a different timezone than the system
# e.g. America/Chicago
declare -r UBUNTU_TIMEZONE=""

# work on the base image
declare -r UBUNTU_WORKDIR="work_ubuntu"

declare -r SZ_KB=1024
declare -r SZ_MB=$((${SZ_KB}*${SZ_KB}))
declare -r SZ_GB=$((${SZ_MB}*${SZ_KB}))

# sizes in bytes
declare -r SDIMG=sdcard.img
declare -r SDCARD_IMG_SIZE=$((10*SZ_GB))
declare -r RFS_PART_SIZE=$((7*${SZ_GB}))
declare -r BOOT_PART_SIZE=$((50*${SZ_MB}))

# =============================================================================
# HELPERS AND FUNCTIONS
# =============================================================================

declare -r BOOT_PART_SECTOR_START=2048
declare -r BOOT_PART_SECTOR_END=$(( (${BOOT_PART_SIZE} / 512 ) + ${BOOT_PART_SECTOR_START})) 
declare -r RFS_PART_SECTOR_START=$((${BOOT_PART_SECTOR_END} + 1))
declare -r RFS_PART_SECTOR_END=$(( (${RFS_PART_SIZE} / 512 ) + ${RFS_PART_SECTOR_START})) 

# disclaimer
function print_disclaimer() {

    cat <<EOD
Altera provides these materials to our customers solely as an example of
how a Linux operating system may be configured for use with Altera products.
Altera does not endorse, certify, or support Ubuntu or any other third-party
operating system or software. It is the customer’s sole responsibility to
determine whether Ubuntu, or another Linux instance is appropriate for its
intended use, and to ensure compliance with all applicable open-source licenses,
security requirements and technical or regulatory obligations.
Altera offers these instructions “AS-IS” without any warranty of any kind,
whether express, implied statutory or otherwise and Altera will not be liable
to customer under any legal theory related to customer’s choice in using or
distributing Ubuntu.
EOD

    return 0
}

# usage
declare -r SELF="$(basename $0)"

function usage() {

    cat <<EOH
Builds an SD card image with an unmodified Ubuntu run time.

Usage: ${SELF} [-y] [-h]
    -y: assumes user has read the disclaimer
    -h: prints this message
EOH

    echo
    
    print_disclaimer
    
    return 0
}

# download <url> <local file name>
function download() {

    local archive="${2}"
    local url="${1}"
    local err=0

    if command -v wget >/dev/null 2>&1; then
        wget --no-check-certificate --progress=bar:force:noscroll -O "${archive}" "${url}"
	err=$?
    elif command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "${archive}" "${url}"
	err=$?
    else
        echo "ERROR: Neither wget nor curl found. Please install one of them."
        return 1
    fi  

    return ${err}
}

# =============================================================================
# CLI 
# =============================================================================
_ASSUME_YES="no"
case "${1}" in
    -y)
	    _ASSUME_YES="yes"
	    ;;
    -h)
	    usage
	    exit 0
	    ;;
esac

print_disclaimer
if [ "${_ASSUME_YES}" == "no" ] ; then
	echo
	read -r -n 1 -s -p "Press any key to acknowledge you've read the disclaimer above... " _
fi

echo "======================================================================"
echo "   Agilex 5 HPS SD Card Boot Flow Builder 			    "
echo "======================================================================"

# =============================================================================
# BUILD PROCESS
# =============================================================================

echo "[STEP] Setting up build environment..."

# Create and enter build directory
mkdir -p "${OUTPUT_DIR}"
cd "${OUTPUT_DIR}"

# Set environment variables, read-only and exported
declare -rx ARCH=arm64
declare -rx CROSS_COMPILE="${PWD}/${TOOLCHAIN_DIR}/bin/aarch64-unknown-linux-musl-"

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
        if ! download "${TOOLCHAIN_URL}" "${TOOLCHAIN_ARCHIVE}" ; then
	    echo "error: failed to download the ARM GNU toolchain (${TOOLCHAIN_ARCHIVE})"
	    exit 1
	fi
    fi

    echo "Extracting ARM GNU toolchain..."
    tar -xf "${TOOLCHAIN_ARCHIVE}"

    # Verify toolchain
    if [[ ! -x "${TOOLCHAIN_DIR}/bin/aarch64-unknown-linux-musl-gcc" ]]; then
        echo "ERROR: ARM toolchain verification failed"
        exit 1
    fi

    echo "ARM toolchain setup complete"
else
    echo "ARM toolchain already downloaded"
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
make -j "${JOBS}" PLAT=agilex5 bl31 ENABLE_LTO=0

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

# Build U-Boot
make clean && make mrproper
make socfpga_agilex5_defconfig
make -j "${JOBS}"

# spl hex file is needed when JIC file is created. Copy it at a known location
cp spl/u-boot-spl-dtb.hex ${OUTPUT_DIR_ABS} 

cd ..

echo "U-Boot build complete"

# =============================================================================
# GET UBOOT SCRIPT
# =============================================================================
echo "[STEP] Getting uboot script ..."

# get the updated uboot_script.its everytime
rm -f "${UBOOT_ITS_FILE}"
if ! download "${UBOOT_ITS_URL}" "${UBOOT_ITS_FILE}" ; then
	echo "error: failed to dowbload ${UBOOT_ITS_FILE}"
	exit 3
fi

# get the updated uboot.txt everytime
rm -f "${UBOOT_SCRIPT_FILE}"
if ! download "${UBOOT_SCRIPT_URL}" "${UBOOT_SCRIPT_FILE}" ; then
	echo "error: failed to dowbload ${UBOOT_SCRIPT_FILE}"
	exit 3
fi

mkimage -f "${UBOOT_ITS_FILE}" boot.scr.uimg

echo "Created boot.scr.uimg"

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
# CREATE KERNEL.ITS
# =============================================================================
xz --threads=${JOBS} --format=lzma -f -k ${LINUX_DIR}/arch/arm64/boot/Image

echo "[STEP] Creating kernel.its & kernel.itb"

#create a minimal kernel.its file
cat > kernel_test.its <<EOF

/dts-v1/;

/ {

    description = "FIT image with custom kernel and DTB";

    #address-cells = <1>;

    images {

        kernel {

            description = "Linux Kernel";

            data = /incbin/("${LINUX_DIR}/arch/arm64/boot/Image.lzma");

            type = "kernel";

            arch = "arm64";

            os = "linux";

            compression = "lzma";

            load = <0x86000000>;

            entry = <0x86000000>;

            hash-1 { algo = "crc32"; };

        };

        fdt-0 {

            description = "socfpga_agilex5_socdk";

            data = /incbin/("${LINUX_DIR}/arch/arm64/boot/dts/intel/socfpga_agilex5_socdk.dtb");

            type = "flat_dt";

            arch = "arm64";

            compression = "none";

            hash-1 { algo = "crc32"; };

        };

    };

    configurations {

        default = "board-0";

        board-0 {

            description = "board_0";

            kernel = "kernel";

            fdt = "fdt-0";

            hash-1 { algo = "crc32"; };

        };

    };

};
EOF

#create kernel.itb
mkimage -f kernel_test.its kernel.itb

echo "Created kernel.itb" 

# =============================================================================
# DOWNLOAD UBUNTU
# =============================================================================

echo "[STEP] Download root filesystem..."

UBUNTU_ARCHIVE="ubuntu-base-${UBUNTU_VERSION}-base-${ARCH}.tar.gz"
UBUNTU_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_VERSION}/release/${UBUNTU_ARCHIVE}"

if [[ ! -f "${UBUNTU_ARCHIVE}" ]]; then
    echo "Download Ubuntu archive"
    if ! download "${UBUNTU_URL}" "${UBUNTU_ARCHIVE}" ; then
        echo "error: failed to download the Ubuntu archive (${UBUNTU_ARCHIVE})"
        exit 2
    fi
else
    echo "Ubuntu archive previously downloaded"
fi

echo "Ubuntu download complete"

# =============================================================================
# AUGMENT UBUNTU BASE IMAGE
# =============================================================================

echo "[STEP] Augment Ubuntu Base Image..."
echo "Please enter your password (sudo):"
# empty buffer
# while read -t 0.01 -N 255; do :; done

sudo -sE <<EOT

# again, exit in case of error
set -e

trap umount_vfs EXIT

# a few helpers
function mount_vfs() {

    mount -t proc  none     "${UBUNTU_WORKDIR}/proc"
    mount -t sysfs none     "${UBUNTU_WORKDIR}/sys"
    mount -o bind  /dev     "${UBUNTU_WORKDIR}/dev"
    mount -o bind  /dev/pts "${UBUNTU_WORKDIR}/dev/pts"

}

function umount_vfs() {

    umount "${UBUNTU_WORKDIR}/dev/pts" || true
    umount "${UBUNTU_WORKDIR}/dev"     || true
    umount "${UBUNTU_WORKDIR}/sys"     || true
    umount "${UBUNTU_WORKDIR}/proc"    || true

}

# setting the time zone is important so
# date and time can be set by timesyncd
# apt may encounter issues otherwise
# this function sets the time zone on Agilex 5
# to the TZ of the host running this script
function set_timezone() {

    if [ ! -z ${UBUNTU_TIMEZONE} ] ; then
        echo "${FUNCNAME}: use UBUNTU_TIMEZONE (${UBUNTU_TIMEZONE})..."
        echo "${UBUNTU_TIMEZONE}" > ${UBUNTU_WORKDIR}/etc/timezone
        return 0
    fi
        
    if [ -f /etc/timezone ] ; then
        echo "${FUNCNAME}: used /etc/timezone..."
        cp /etc/timezone ${UBUNTU_WORKDIR}/etc
        return 0
    fi

    echo "${FUNCNAME}: WARNING: could not set timezone. This may cause issues"
    return 0

}

# housekeeping
# in case the previous run failed, we can unmount
umount_vfs

# FS work starts here
rm -rf "${UBUNTU_WORKDIR}" && mkdir "${UBUNTU_WORKDIR}"
tar xf "${UBUNTU_ARCHIVE}" -C "${UBUNTU_WORKDIR}"

# we'll use some resources of the host
grep -vE '^search' /etc/resolv.conf >"${UBUNTU_WORKDIR}/etc/resolv.conf"
set_timezone

# we'll need to run ARM64 applications
cp /usr/bin/qemu-aarch64-static "${UBUNTU_WORKDIR}/usr/bin"

# nount "virtual" fs'es
mount_vfs

# now, enter the ARM64 realm. 
exit_after_cleanup="no"
chroot "${UBUNTU_WORKDIR}" /bin/bash <<EOS

# different shell, same setting
set -e

echo "[arm64] augmenting file system..."
export LANG=C.UTF-8
unset LC_NUMERIC
unset LC_TIME
unset LC_MEASUREMENT
unset LC_TELEPHONE
unset LC_IDENTIFICATION
unset LC_PAPER
unset LC_MONETARY
unset LC_NAME
unset LC_ADDRESS

# ensure no dialog shows up
export DEBIAN_FRONTEND=noninteractive

apt update
apt install --yes ${UBUNTU_PACKAGES}
apt clean

echo "[arm64] setting up network..."
cat <<EOM >/etc/NetworkManager/conf.d/allow-ethernet.conf
[keyfile]
unmanaged-devices=*,except:type:wifi,except:type:gsm,except:type:cdma,except:type:ethernet
EOM

echo "127.0.0.1    localhost" >> /etc/hosts

# No security issue here
echo "[arm64] adding user ${UBUNTU_USER} with password ${UBUNTU_PASS}..."
useradd ${UBUNTU_USER} -m -s /bin/bash -G sudo
echo ${UBUNTU_USER}:${UBUNTU_PASS} | chpasswd

echo "[arm64] done..."

EOS

[ $? -ne 0 ] && exit_after_cleanup="yes"

# clean up
umount_vfs
rm ${UBUNTU_WORKDIR}/usr/bin/qemu-aarch64-static

if [ "${exit_after_cleanup}" == "yes" ] ; then
    echo "exiting after error setting up ARM64 file system" >&2
    exit 1
fi

# This will be useful to simplify SD card image creation
cd "${UBUNTU_WORKDIR}"
tar cfz ../"AUGM_${UBUNTU_ARCHIVE}" *

EOT

echo "Base Image augmented, tar ball created"
# =============================================================================
# CREATE SD CARD IMAGE
# =============================================================================

echo "[STEP] Creating SD card image..."

# Running guestfish requires access to /boot/vmlinuz-* (chmod a+r)
# Being part of the kvm group may help with speed execution
guestfish <<EOF
sparse ${SDIMG} ${SDCARD_IMG_SIZE}
run
part-init /dev/sda mbr
part-add /dev/sda p ${BOOT_PART_SECTOR_START} ${BOOT_PART_SECTOR_END}
part-add /dev/sda p ${RFS_PART_SECTOR_START}  ${RFS_PART_SECTOR_END}
mkfs fat /dev/sda1
mount /dev/sda1 /
copy-in ${PWD}/${UBOOT_DIR}/u-boot.itb /
copy-in ${PWD}/kernel.itb /
copy-in ${PWD}/boot.scr.uimg /
unmount /
mkfs ext4 /dev/sda2
mount /dev/sda2 /
tar-in ${PWD}/AUGM_${UBUNTU_ARCHIVE} / compress:gzip xattrs:true
unmount /
EOF

if [[ $? -eq 0 ]]; then
    echo "SUCCESS: SD card image created: ${SDIMG}"
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
    echo "  ${UBUNTU_ARCHIVE}            - Ubuntu root filesystem (downloaded)"
    echo ""
    echo "To write SD card image (:"
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
    echo "          -o hps_path=${OUTPUT_DIR_ABS}/u-boot-spl-dtb.hex \\"
    echo "          -o mode=ASX4 \\"
    echo "          -o hps=1"
    echo "  4. Program the JIC and power cycle the board"
    echo "     e.g. quartus_pgm -c 1 -m jtag -o \"pvi;output_file.jic\""
    echo ""
    echo "EDUCATIONAL: Boot process:"
    echo "  1. U-Boot loads Image and DTB"
    echo "  2. Linux kernel initializes system and kicks off user space"
    echo "  3. System runs SD/MMC"
    echo ""
    echo "IMPORTANT:"
    echo " Once you have logged on to Ubuntu on Agilex5, please check the date"
    echo " are set correctly by NTP"
    echo "    timedatectl show"
    echo " If NTPSynchronized=no appears, NTP is not functional, which may be"
    echo " due to a firewall issue"
    echo " You may have to set the date manually, such as:"
    echo "    sudo date -s '2026-06-22 12:00:00'"
    echo ""
else
    echo "ERROR: Failed to create SD card image"
    exit 1
fi
