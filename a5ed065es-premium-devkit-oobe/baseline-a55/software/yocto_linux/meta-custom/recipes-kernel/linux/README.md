# Linux Kernel - linux-socfpga-lts

## Device tree
Refer and follow the steps mentioned at ```meta-custom/recipes-bsp/device-tree/README.md```

## Configuration fragments
Follow the below steps to create and add configuration fragments for Linux Kernel.

### Set bitbake build environment
```
$ kas shell kas.yml
```

### Create Linux Kernel configuration fragment.
- Launch Linux configuration menu and edit configurations and Save & Exit.
```$ bitbake -c menuconfig linux-socfpga-lts```
- Generate kernel configuration fragment file.
```
$ bitbake -c diffconfig linux-socfpga-lts
Note - This command generates the fragment.cfg file.
```

### Add configuration fragment for linux-socfpga-lts Kernel
- Copy ```fragment.cfg``` file at ```../meta-custom/recipes-kernel/linux/linux-socfpga-lts/configs/```
- Create ```fragment.scc``` at the same location with ```kconf non-hardware fragment.cfg``` line added.
```Note: kconf option depends on the configuration variables in the fragment.cfg file, for more information refer Yocto documentation.```
- Add following line to ```SRC_URI:append``` in ```../meta-custom/recipes-kernel/linux/linux-socfpga-lts_%.bbappend``` file.
```
file://fragment.scc
```

### Build Linux kernel
```
$ bitbake -c clean linux-socfpga-lts
$ bitbake -c build linux-socfpga-lts
```

## Linux Kernel patching
Follow below steps to create the patch & build Linux Kernel.

### Clone Linux Kernel repo
```
$ git clone https://github.com/altera-fpga/linux-socfpga.git
$ cd linux-socfpga
$ git checkout <branch>
```

Do your source code changes.

### Generate the source patch
```
$ git add <changed files>
$ git commit -m "Add my custom feature"  (Note: Make sure to add Upstream-Status: in commit message, refer Yocto docs)
$ git format-patch -1 HEAD (Note: -1 is number of patches)
  This generates one patch file like 0001-Add-my-custom-feature.patch.
```

### Add source patch for linux-socfpga-lts Kernel
- Copy above generated patch at ```meta-custom/recipes-kernel/linux/linux-socfpga-lts/patches/```
- Add following line to ```SRC_URI:append``` in ```meta-custom/recipes-kernel/linux/linux-socfpga-lts_%.bbappend```
```
file://0001-Add-my-custom-feature.patch
```

### Build Linux kernel
```
$ kas shell kas.yml
$ bitbake -c clean linux-socfpga-lts
$ bitbake -c build linux-socfpga-lts
```

## List of Linux binaries
```
build/tmp/deploy/images/<Machine Id>/Image
build/tmp/deploy/images/<Machine Id>/kernel.itb
build/tmp/deploy/images/<Machine Id>/devicetree/socfpga_agilex5_socdk.dtb
build/tmp/deploy/images/<Machine Id>/devicetree/socfpga_agilex5_vanilla.dtb

build/tmp/work/<Machine Id>-poky-linux/linux-socfpga-lts/<Linux version>/deploy-linux-socfpga-lts/Image
build/tmp/work/<Machine Id>-poky-linux/linux-socfpga-lts/<Linux version>/deploy-linux-socfpga-lts/kernel.itb
build/tmp/work/<Machine Id>-poky-linux/device-tree/1.0/image/boot/devicetree/socfpga_agilex5_socdk.dtb
build/tmp/work/<Machine Id>-poky-linux/device-tree/1.0/image/boot/devicetree/socfpga_agilex5_vanilla.dtb
```
