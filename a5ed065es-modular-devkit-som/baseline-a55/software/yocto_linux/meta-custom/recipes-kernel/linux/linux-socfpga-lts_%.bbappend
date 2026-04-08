# Append GSRD specific kernel config fragments and Patches.
FILESEXTRAPATHS:prepend := "${THISDIR}/device-tree:${THISDIR}/linux-socfpga-lts/configs:${THISDIR}/linux-socfpga-lts/patches:"

python () {
    import os

    enable = d.getVar("FPGA_CORE_PGM_ENABLE") or "0"

    #
    # Handle CUSTOM_LINUX_DTS_FILE only if FPGA_CORE_PGM_ENABLE == "1"
    #
    custom_dts = d.getVar("CUSTOM_LINUX_DTS_FILE")

    if enable == "1":
        if not custom_dts:
            bb.fatal("CUSTOM_LINUX_DTS_FILE must be set when FPGA_CORE_PGM_ENABLE = 1")
        # Compute DTB
        dtb = os.path.basename(custom_dts).replace(".dts", ".dtb")
        d.setVar("FPGA_LINUX_DTB_FILE", dtb)
    else:
        # Optional → do NOT fatal, but set DTB_FILE empty so no invalid append happens
        d.setVar("FPGA_LINUX_DTB_FILE", "")

    #
    # LINUX_DTS_FILE is ALWAYS required
    #
    linux_dts = d.getVar("LINUX_DTS_FILE")
    if not linux_dts:
        bb.fatal("LINUX_DTS_FILE must be set (base Linux DTS missing)")

    linux_dtb = os.path.basename(linux_dts).replace(".dts", ".dtb")
    d.setVar("LINUX_DTB_FILE", linux_dtb)
}


#KERNEL_DEVICETREE:append = " intel/${FPGA_LINUX_DTB_FILE}"
KERNEL_DEVICETREE:append = "${@(' intel/%s' % d.getVar('FPGA_LINUX_DTB_FILE')) if d.getVar('FPGA_LINUX_DTB_FILE') else ''}"


#IMAGE_BOOT_FILES:append = " ${FPGA_LINUX_DTB_FILE}"
IMAGE_BOOT_FILES:append = "${@(' %s' % d.getVar('FPGA_LINUX_DTB_FILE')) if d.getVar('FPGA_LINUX_DTB_FILE') else ''}"


SRC_URI:append = " file://agilex5.scc \
		   file://edac.scc \
		   file://initrd.scc \
		   file://jffs2.scc \
		   file://sensors.scc \
		   file://ubifs.scc \
           file://usbedac.scc \
"

# Auto-add all DTS / DTSI into SRC_URI at PARSE TIME
python __anonymous () {
    import os

    layerdir = d.getVar("LAYERDIR_meta_custom")
    tree = os.path.join(layerdir, "recipes-kernel/linux/device-tree")

    if not os.path.isdir(tree):
        bb.fatal("Device-tree folder not found: %s" % tree)

    for fname in os.listdir(tree):
        if fname.endswith(".dts") or fname.endswith(".dtsi"):
            #bb.note("Adding to SRC_URI at parse time: %s" % fname)
            d.appendVar("SRC_URI", " file://%s" % fname)
}

do_patch:append() {

    DTS_SRC_DIR="${WORKDIR}"
    DTS_DST_DIR="${S}/arch/arm64/boot/dts/intel"
    MAKEFILE="${DTS_DST_DIR}/Makefile"

    enable="${FPGA_CORE_PGM_ENABLE}"

    #
    # If FPGA_CORE_PGM_ENABLE = 1 → must install CUSTOM_LINUX_DTS_FILE
    #
    if [ "${enable}" = "1" ]; then
        if [ ! -f "${DTS_SRC_DIR}/${CUSTOM_LINUX_DTS_FILE}" ]; then
            bbfatal "CUSTOM_LINUX_DTS_FILE ${CUSTOM_LINUX_DTS_FILE} not found in ${DTS_SRC_DIR}"
        fi

        install -m 0644 "${DTS_SRC_DIR}/${CUSTOM_LINUX_DTS_FILE}" "${DTS_DST_DIR}"
    fi

    #
    # Copy all DTSI files into kernel source
    #
    find "${DTS_SRC_DIR}" -type f -name "*.dtsi" | while read DTSI; do
        BASENAME=$(basename "${DTSI}")
        install -m 0644 "${DTSI}" "${DTS_DST_DIR}/${BASENAME}"
    done

    #
    # Add DTB entry to kernel Makefile only when custom DTS is enabled
    #
    if [ "${enable}" = "1" ] && [ -n "${FPGA_LINUX_DTB_FILE}" ]; then
        if ! grep -Fq "${FPGA_LINUX_DTB_FILE}" "${MAKEFILE}"; then
            echo "dtb-\$(CONFIG_ARCH_INTEL_SOCFPGA) += ${FPGA_LINUX_DTB_FILE}" >> "${MAKEFILE}"
        fi
    fi
}


addtask do_patch after do_unpack before do_configure
