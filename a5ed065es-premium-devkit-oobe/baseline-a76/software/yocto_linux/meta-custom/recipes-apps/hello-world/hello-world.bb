DESCRIPTION = "hello world application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://hello-world.c"

S = "${WORKDIR}/sources-unpack"

do_compile() {
    # Compile hello-world.c into an executable named hello-world
    ${CC} ${LDFLAGS} ${S}/hello-world.c -o ${B}/hello-world
}

do_install() {
    # Create target binary directory and install hello-world executable
    install -d ${D}${bindir}
    install -m 0755 ${B}/hello-world ${D}${bindir}/hello-world
}
