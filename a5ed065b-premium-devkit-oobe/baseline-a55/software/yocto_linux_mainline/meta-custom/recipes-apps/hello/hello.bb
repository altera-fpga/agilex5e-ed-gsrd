DESCRIPTION = "hello world application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://hello.c"

S = "${UNPACKDIR}"

do_compile() {
    # Compile hello.c into an executable named hello
    ${CC} ${LDFLAGS} ${S}/hello.c -o ${B}/hello
}

do_install() {
    # Create target directory and install hello executable
    install -d ${D}/home/root/alteraFPGA
    install -m 0755 ${B}/hello ${D}/home/root/alteraFPGA/hello
}

FILES:${PN} = "/home/root/alteraFPGA/hello"
