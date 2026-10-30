SUMMARY = "Deploy the Agilex5 U-Boot test suite to the boot partition"
DESCRIPTION = "Deploys the uboot-test-suite-agilex5 archive (prebuilt U-Boot script images \
               and their .cmd sources) into DEPLOY_DIR_IMAGE so the tree is copied onto the \
               FAT boot partition via IMAGE_BOOT_FILES. At the U-Boot prompt the scripts are \
               loaded and executed, e.g.: \
                 load mmc 0:1 \${scriptaddr} uboot-test-suite/config/uboot.scr; source \${scriptaddr} \
                 load mmc 0:1 \${scriptaddr} uboot-test-suite/uboot/ethernet/ping.scr; source \${scriptaddr} \
               Replace meta-custom/recipes-files/uboot-test-suite-agilex5/files/uboot-test-suite-agilex5.tar.gz \
               with the latest archive from the validation team and rebuild to pick up updates."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Deploy-only recipe: it stages a machine-agnostic archive into the
# machine-specific DEPLOY_DIR_IMAGE, so it is NOT allarch.
inherit deploy

SRC_URI = "file://uboot-test-suite-agilex5.tar.gz"

S = "${UNPACKDIR}"

# This recipe only stages artifacts for the boot partition; nothing is built
# or installed into the target rootfs.
do_configure[noexec] = "1"
do_compile[noexec] = "1"
do_install[noexec] = "1"
deltask do_populate_sysroot

PACKAGES = ""

# BitBake unpacks the tar.gz during do_unpack. The archive has a top-level
# "uboot-test-suite/" directory, so the tree is available at ${S}/uboot-test-suite/.
# Deploy it verbatim so IMAGE_BOOT_FILES can copy it onto the FAT boot partition.
do_deploy() {
    install -d ${DEPLOYDIR}
    cp -r ${S}/uboot-test-suite ${DEPLOYDIR}/uboot-test-suite
}
addtask deploy before do_build after do_install
