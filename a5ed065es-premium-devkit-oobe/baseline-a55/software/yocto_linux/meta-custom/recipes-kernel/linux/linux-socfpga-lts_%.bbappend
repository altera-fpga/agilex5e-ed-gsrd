# Append GSRD specific kernel config fragments and Patches.

FILESEXTRAPATHS:prepend := "${THISDIR}/linux-socfpga-lts/configs:${THISDIR}/linux-socfpga-lts/patches"

SRC_URI:append = " file://agilex5.scc \
		   file://edac.scc \
		   file://initrd.scc \
		   file://sensors.scc \
		   file://ubifs.scc \
"
