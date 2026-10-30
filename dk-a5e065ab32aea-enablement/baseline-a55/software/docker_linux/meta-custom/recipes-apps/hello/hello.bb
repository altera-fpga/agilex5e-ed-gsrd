DESCRIPTION = "hello world application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://hello.c \
           file://CMakeLists.txt"

S = "${UNPACKDIR}"

inherit pkgconfig cmake

do_install() {
    # Create target directory and install the CMake-built hello executable
    install -d ${D}/home/root/alteraFPGA
    install -m 0755 ${B}/hello ${D}/home/root/alteraFPGA/hello
}

FILES:${PN} = "/home/root/alteraFPGA/hello"
