SUMMARY = "Altera SoCFPGA Bitstream"
DESCRIPTION = "Custom FPGA bitstream for SOC Development Kit"
SECTION = "bsp"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

python () {
    if not d.getVar('FPGA_ENABLE_CORE_PGM'):
        raise bb.parse.SkipRecipe("FPGA Enable Core Programming option is not set!")
}
