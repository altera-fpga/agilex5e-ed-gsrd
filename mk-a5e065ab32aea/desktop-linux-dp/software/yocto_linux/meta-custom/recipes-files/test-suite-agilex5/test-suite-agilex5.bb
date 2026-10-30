SUMMARY = "Install Agilex5 test suite into the root filesystem"
DESCRIPTION = "Deploys the test-suite-agilex5 archive to /home/root/test-suite on the target rootfs. \
               Replace meta-custom/recipes-files/test-suite-agilex5/files/test-suite-agilex5.tar.gz \
               with the latest archive from the validation team and rebuild to pick up updates."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit allarch

SRC_URI = "file://test-suite-agilex5.tar.gz"

S = "${UNPACKDIR}"

INSTALL_DIR = "/home/root"

# BitBake automatically unpacks the tar.gz during do_unpack.
# The archive contains a top-level "test-suite/" directory, so after unpacking
# the contents are available at ${S}/test-suite/.
do_install() {
    install -d ${D}${INSTALL_DIR}
    cp -r ${S}/test-suite ${D}${INSTALL_DIR}/test-suite
}

FILES:${PN} += "${INSTALL_DIR}/test-suite"
