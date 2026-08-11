# Linux Kernel device-tree customization and build

## Custom Linux device tree
### Full custom device tree (CUSTOM_LINUX_DTS_FILE = "<custom_linux_device_tree>.dts")
**CUSTOM LINUX DEVICE TREE**
- Refer to the official base device tree source https://github.com/altera-fpga/linux-socfpga.git - arch/arm64/boot/dts/intel/socfpga_agilex5_socdk.dts and create custom device tree with the different name. The dts file name must be different (e.g. baseline_a55.dts) for the custom device tree (dts). 
- Reference custom device tree source file (dts) is available at recipe-kernel/linux/devicetree folder that include FPGA design specific changes.
- The custom dts can include Linux kernel board specific base dt include file e.g. "agilex5_socdk.dtsi" OR completely new dtsi file based on Linux kernel board specific dt include file.  

## Build Linux kernel with device tree changes
```
$ bitbake -c clean linux-socfpga-lts
$ bitbake linux-socfpga-lts
```
**DTB files**

During the build, the DTB files are installed to:
```build/tmp/deploy/images/<Machine Id>/``` 

FIT image - kernel.itb will use the custom device tree is CUSTOM_LINUX_DTS_FILE if defined in kas/bsp.yml, else it will use Linux Kernel in-tree device tree defined using LINUX_DTS_FILE in kas/bsp.yml.

```
E.g. 
build/tmp/deploy/images/<Machine Id>/socfpga_agilex5_socdk.dtb 
build/tmp/deploy/images/<Machine Id>/baseline_a55.dtb
```

