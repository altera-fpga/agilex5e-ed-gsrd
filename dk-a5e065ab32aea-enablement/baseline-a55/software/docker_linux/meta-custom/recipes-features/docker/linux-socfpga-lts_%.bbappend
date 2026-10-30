SUMMARY = "Image Feature: Docker recipe. Configuration, Patches and files."
DESCRIPTION = "Docker-specific changes and additions."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Add path to our Config files, Patches and additional files.
FILESEXTRAPATHS:prepend := "${THISDIR}/configs:${THISDIR}/patches:${THISDIR}/files:"

# This include kicks off the kconf for Docker required kernel configs
SRC_URI:append = " ${@bb.utils.contains('DOCKER_BUILD', '1', ' file://docker.scc', '', d)}"
