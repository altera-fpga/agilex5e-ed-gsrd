# meta-custom

This bitbake layer contains Altera SoCFPGA core's metadata of design/device tree/configurations for u-boot and Linux kernel.
Refer the following README.md files for more details.

# U-Boot
For detailed instructions and customization guidance, refer to: `meta-custom/recipes-bsp/u-boot/README.md`

- Device Tree - Describes how to use in-tree or custom U-Boot device trees.
- Configuration fragments - Steps to generate, apply, and include custom U-Boot configuration changes using fragments.
- Source patching - How to create & apply patches to the U-Boot source within the Yocto build system.

# Linux Kernel
For detailed instructions and customization guidance, refer to: `meta-custom/recipes-kernel/linux/README.md`

- Device Tree - Describes how to use in-tree or custom device trees.
- Configuration fragments - Steps to generate, apply, and include custom Linux Kernel configuration changes using fragments.
- Source patching - How to create & apply patches to the Linux Kernel source within the Yocto build system.

# FPGA Bitstream
For details on FPGA bitstream handling, refer to: `meta-custom/recipes-fpga/fpga-bitstream/README.md`

- Core RBF FPGA configuration - Instructions for integrating the core.rbf file into the Yocto build system, enabling automatic deployment as part of the image build.
