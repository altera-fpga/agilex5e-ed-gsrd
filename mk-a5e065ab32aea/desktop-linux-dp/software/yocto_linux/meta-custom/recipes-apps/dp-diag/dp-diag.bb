DESCRIPTION = "DisplayPort bring-up sanity checker for the altera-vvp-dp driver"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

SRC_URI = "file://dp_sanity.sh"

S = "${UNPACKDIR}"

# Shell script - nothing to compile.
do_compile[noexec] = "1"

do_install() {
    install -d ${D}/home/root/alteraFPGA
    install -m 0755 ${S}/dp_sanity.sh ${D}/home/root/alteraFPGA/dp_sanity.sh
}

# Runtime dependency: the script probes registers with devmem2.
RDEPENDS:${PN} += "devmem2"

FILES:${PN} = "/home/root/alteraFPGA/dp_sanity.sh"
