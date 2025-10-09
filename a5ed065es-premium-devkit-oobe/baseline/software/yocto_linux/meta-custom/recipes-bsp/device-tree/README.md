# Linux Kernel device-tree customization and build

## FPGA design specific custom Linux device tree
### a. Full custom device tree (When FPGA_ENABLE_CORE_PGM=1, CUSTOM_LINUX_DEVICE_TREE=1)
**CUSTOM LINUX DEVICE TREE**
- Refer to the official base device tree source https://github.com/altera-innersource/applications.fpga.soc.linux-socfpga-dev/blob/socfpga-6.12.19-lts/arch/arm64/boot/dts/intel/socfpga_agilex5_socdk.dts and create custom device tree with same name or different name.

- Ensure your custom .dts includes `socfpga_agilex5.dtsi` similar to how it's done in the reference .dts.

**FPGA DESIGN SPECIFIC DEVICE TREE**
- A sample `socfpga_agilex5_ghrd.dtsi` is placed in the `meta-custom/recipes-bsp/device-tree/files/` directory as a reference. You can modify this to reflect your FPGA design. This dtsi will be included in custom .dts by `device-tree` recipe during yocto build.

- Copy your custom .dts file at `meta-custom/recipes-bsp/device-tree/files/`

- `device-tree` recipe replaces the In-Tree Linux .dts with custom Linux .dts during Yocto build.

### b. FPGA specific customization only (When FPGA_ENABLE_CORE_PGM=1, CUSTOM_LINUX_DEVICE_TREE=0)
**FPGA DESIGN SPECIFIC DEVICE TREE**
- A sample `socfpga_agilex5_ghrd.dtsi` is placed in the `meta-custom/recipes-bsp/device-tree/files/` directory as a reference. You can modify this to reflect your FPGA design. This dtsi will be included in In-Tree .dts by `device-tree` recipe during yocto build.

## In-Tree Linux device tree (When FPGA_ENABLE_CORE_PGM=0, CUSTOM_LINUX_DEVICE_TREE=0)
- The `device-tree` recipe builds only the In-Tree Linux device tree during yocto build.

## Build device tree for Linux kernel
```
$ bitbake -c clean device-tree
$ bitbake -c build device-tree
```

**DTB files**

During the build, the DTB files are installed to:
```build/tmp/deploy/images/<Machine Id>/devicetree/``` 
Meanwhile, the kernel recipe picks up the DTB files as needed and generates the combined kernel image kernel.itb.

```
build/tmp/deploy/images/<Machine Id>/devicetree/socfpga_agilex5_socdk.dtb
build/tmp/deploy/images/<Machine Id>/devicetree/socfpga_agilex5_vanilla.dtb
build/tmp/work/<Machine Id>-poky-linux/device-tree/1.0/image/boot/devicetree/socfpga_agilex5_socdk.dtb
build/tmp/work/<Machine Id>-poky-linux/device-tree/1.0/image/boot/devicetree/socfpga_agilex5_vanilla.dtb
```
