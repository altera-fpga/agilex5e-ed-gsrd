# U-Boot

## Device tree source

### In-Tree device tree
- By default, U-Boot uses the In-Tree device tree provided within its source.
- No additional Yocto configuration is required, by default `CUSTOM_UBOOT_DEVICE_TREE` variable is disabled in `kas.yml`.

### Custom device tree
- Create the custom device tree by referring to https://github.com/altera-fpga/u-boot-socfpga.git - arch/arm/dts/socfpga_agilex5_socdk.dts.
- Ensure required .dtsi file (e.g., socfpga_agilex5.dtsi) included in your custom .dts, similar to how it's done in the reference .dts.
- Copy the complete custom .dts file in `meta-custom/recipes-bsp/u-boot/files/dts/`
- Enable the `CUSTOM_UBOOT_DEVICE_TREE` variable in `kas.yml` to instruct the Yocto build system to build your custom .dts instead of the default in-tree one.

### Build u-boot
```
$ kas shell kas.yml
$ bitbake -c clean u-boot-socfpga
$ bitbake -c build u-boot-socfpga
```

## Configuration fragments
Follow below steps to generate the configuration fragments, apply & build. 

### Set bitbake build environment
```
$ kas shell kas.yml
``` 

### Create U-Boot configuration fragment.
- Launch the U-Boot configuration menu, edit U-Boot configurations and Save & Exit.
```  
$ bitbake -c menuconfig u-boot-socfpga
```

- Generate U-Boot configuration fragment file.
```
$ bitbake -c diffconfig u-boot-socfpga
Note - This command generates the fragment.cfg file.
```  

### Add configuration fragment for U-Boot
- Copy ```fragment.cfg``` file at ```../meta-custom/recipes-bsp/u-boot/files/configs/```
- Add following line to ```SRC_URI:append``` in ```../meta-custom/recipes-bsp/u-boot/u-boot-socfpga_%.bbappend``` file.
```
file://fragment.cfg
```

### Build u-boot
```
$ bitbake -c clean u-boot-socfpga
$ bitbake -c build u-boot-socfpga
```

## Source patches
Follow below steps to create the patch, apply & build the U-Boot.

### Clone U-Boot source repo
```
$ git clone https://github.com/altera-fpga/u-boot-socfpga.git
$ cd u-boot-socfpga
$ git checkout <branch>
```
Do your source code changes.

### Generate the source patch
```
$ git add <changed files>
$ git commit -m "Add my custom feature"  (Note: Make sure to add Upstream-Status: in commit message, refer Yocto docs)
$ git format-patch -1 HEAD (Note: -1 is number of patches)
  This generates a patch file like 0001-Add-my-custom-feature.patch.
```
### Add source patch for u-boot
- Copy above generated patch at ```/meta-custom/recipes-bsp/u-boot/files/patches/```
- Add following line to _SRC_URI:append in ```meta-custom/recipes-bsp/u-boot/u-boot-socfpga_%.bbappend```
```
file://0001-Add-my-custom-feature.patch
```

### Build u-boot
```
$ kas shell kas.yml
$ bitbake -c clean u-boot-socfpga
$ bitbake -c build u-boot-socfpga
```

### Build u-boot environment variables and boot script
```
$ kas shell kas.yml
$ bitbake -c clean u-boot-socfpga-env-var
$ bitbake -c build u-boot-socfpga-env-var

$ bitbake -c clean u-boot-socfpga-scr
$ bitbake -c build u-boot-socfpga-scr
```

### List of u-boot binaries
```
build/tmp/deploy/images/<Machine Id>/u-boot
build/tmp/deploy/images/<Machine Id>/u-boot.elf
build/tmp/deploy/images/<Machine Id>/u-boot.itb
build/tmp/deploy/images/<Machine Id>/u-boot-spl
build/tmp/deploy/images/<Machine Id>/u-boot-spl-dtb.bin
build/tmp/deploy/images/<Machine Id>/u-boot-spl-dtb.hex
build/tmp/deploy/images/<Machine Id>/u-boot-spl.dtb
build/tmp/deploy/images/<Machine Id>/u-boot-spl.map
build/tmp/deploy/images/<Machine Id>/u-boot.txt
build/tmp/deploy/images/<Machine Id>/uboot.env
build/tmp/deploy/images/<Machine Id>/boot.scr.uimg
build/tmp/work/<Machine Id>-poky-linux/u-boot-socfpga/<u-boot version>/build/socfpga_agilex5_defconfig/arch/arm/dts/socfpga_agilex5_socdk.dtb
```
