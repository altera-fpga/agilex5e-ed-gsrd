SUMMARY = "Simple external Linux kernel module example"
DESCRIPTION = "A minimal example demonstrating how to build and package an out-of-tree Linux kernel module using the Yocto Project."

LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=12f884d2ae1ff87c09e5b7ccc2c4ca7e"

inherit module

SRC_URI = "file://Makefile \
           file://hello_module.c \
           file://COPYING \
          "

S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"

# The inherit of module.bbclass will automatically name module packages with
# "kernel-module-" prefix as required by the oe-core build environment.

RPROVIDES:${PN} += "kernel-module-hello_module"
