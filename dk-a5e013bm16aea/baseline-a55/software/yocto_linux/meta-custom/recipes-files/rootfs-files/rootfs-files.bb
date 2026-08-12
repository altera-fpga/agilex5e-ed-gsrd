SUMMARY = "Add custom files to the Linux rootfs"
DESCRIPTION = "Recipe to install generic files (like README, documentation, scripts) into the target rootfs"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit allarch

FILE_DIR ?= "/home/root"
FILE_NAME ?= "README.md"
SRC_URI = "file://${FILE_NAME}"

S = "${UNPACKDIR}"

do_install() {
    install -d ${D}${FILE_DIR}
    install -m 0644 ${S}/${FILE_NAME} ${D}${FILE_DIR}/${FILE_NAME}
}

FILES:${PN} += "${FILE_DIR}/${FILE_NAME}"
