# Overview of yocto_linux
The Yocto Linux framework enables users to customize the Board Support Package (BSP)
to match the specific hardware design and evaluate the system on either a virtual
platform (Simics) or real hardware.

The base layer for yocto_linux is meta-altera-fpga/meta-altera-bsp. Yocto can be configurable/build
using kas menu and bitbake commands.

Following is the top level view of the yocto_linux framework.

```
.
├── kas
│   ├── apps
│   │   ├── hello-world.yaml
│   │   └── Kconfig
│   ├── gsrd
│   │   └── Kconfig
│   └── image
│       ├── all-image-targets.yaml
│       ├── console-image-minimal.yaml
│       ├── core-image-minimal.yaml
│       ├── gsrd-console-image.yaml
│       └── Kconfig
├── kas.yml
├── Kconfig
├── meta-custom
│   ├── conf
│   │   ├── layer.conf
│   │   └── machine
│   ├── LICENSE
│   ├── README.md
│   ├── recipes-apps
│   │   └── hello-world
│   ├── recipes-bsp
│   │   ├── device-tree
│   │   └── u-boot
│   ├── recipes-fpga
│   │   └── fpga-bitstream
│   └── recipes-kernel
│       └── linux
└── README.md
```

## KAS
- **Kconfig**  
Contains configuration definitions for KAS menu options to configure the Yocto.
- **kas.yml**  
kas.yaml is the configuration file used by KAS and contains the info of repos to be cloned, machine and other Yocto related configurations.

- **kas/image**  
The image directory contains yaml configurations for core-image-minimal, console-image-minimal and gsrd-console-image targets.

    - **core-image-minimal**  
        In the Yocto core-image-minimal is the most basic reference image recipes provided by the Poky
        distribution. It’s essentially a minimal root filesystem which is just enough to boot the system and
        provide a command-line interface.
    - **console-image-minimal**  
        In addition to core-image-base, console-image-minimal enables following packages,
        - Common essentials
        - Network essentials
        - Openssh
        - NFS
        - lighttpd
        - udev
        - systemd
        - mtd-utils
    - **gsrd-console-image**  
        In addition to core-image-base, gsrd-console-image enables following packages,
        - Common essentials
        - dev-tools essentials
        - Network essentials
        - web-server essentials
        - nfs-utils-client
        - Openssh
        - FIO
        - perl
        - NFS
        - lighttpd
        - udev
        - systemd
        - mtd-utils

## meta-custom layer
- **conf**  
Conf describes the layer and machine definitions.
- **recipes-bsp**  
    Contains _device-tree_ recipe for Linux kernel and _u-boot_ recipe for boot loader.
    - _device-tree_ recipe allows integration of custom Linux device tree source and device tree fragment to enable the hardware-specific modifications.
    - _u-boot_ recipe allows integration of custom device tree source to enable the hardware-specific modifications. Also, allows integration of custom U-Boot environment variables.
- **recipes-fpga**  
Contains the _fpga-bitstream_ recipe to include RBF file.
- **recipes-kernel**  
Contains _linux_ recipe to create Kernel Image with custom configurations.

Refer following links to understand more on BSP customization (Top level ```meta-custom/README.md``` provides introduction to each section).

- U-Boot
	```meta-custom/recipes-bsp/u-boot/README.md```
- Linux Kernel
	```meta-custom/recipes-kernel/linux/README.md```
- Linux Device Tree
	```meta-custom/recipes-bsp/device-tree/README.md```
- FPGA Bitstream
	```meta-custom/recipes-fpga/fpga-bitstream/README.md```

# Yocto Build

## Build environment
Install the following host packages and tools required for yocto build.

**Host packages**
```
$ apt install build-essential chrpath cpio debianutils diffstat file gawk gcc git iputils-ping libacl1 liblz4-tool locales python3 python3-git python3-jinja2 python3-pexpect python3-pip python3-subunit socat texinfo unzip wget xz-utils zstd
```
Reference, https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html#build-host-packages

**KAS tool**
```
$ python3 -m venv venv --system-site-packages (Note on --system-site-packages: Host system package(python3-newt) dependency for KAS and not possible to install in venv)
$ source venv/bin/activate
$ pip install --upgrade pip
$ pip install kas
$ pip install kconfiglib
```
Reference, https://kas.readthedocs.io/en/latest/userguide/getting-started.html#dependencies-installation

## How to build

### Default build
- **Using Yocto GUI**
```
# Run kas menu command and Build
$ kas menu
```

(or)

- **From command line**
```
# Set bitbake build environment
$ kas shell kas.yml

# Build console-image-minimal
$ bitbake -c build console-image-minimal
```

### Custom build
- **Using Yocto GUI**
```
# Run kas menu command and do custom configurations using menu & Build
$ kas menu
```

(or)

- **From command line**
```
# Generate .config.yaml using KAS GUI
#  Run kas menu, do configurations and Save & Exit
#  This command generates .config.yaml after Save & Exit
$ kas menu

# Set bitbake build environment
$ kas shell .config.yaml

# Build console-image-minimal
$ bitbake -c build console-image-minimal
```
### Binaries
After the build, the generated binaries can be found in ```build/tmp/deploy/images/<machine>/.```

**List of Binaries**
|Binaries								        |Description                                                            |
|-----------------------------------------------|-----------------------------------------------------------------------|
|uboot.env										|U-Boot environment file.                                               |
|boot.scr.uimg  								|Boot script.                                                           |
|u-boot-spl-dtb.bin								|U-Boot FSBL image in binary format.                                    |
|u-boot-spl-dtb.hex								|U-Boot FSBL image in hex format.                                       |
|u-boot.itb										|U-Boot proper + device tree blob.                                      |
|bl31.bin                                       |Arm Trusted Firmware                                                   |
|Image											|Linux Kernel image.                                                    |
|kernel.itb										|Linux kernel Image (Image + DTB + RBF, if RBF programming is enabled). |
|socfpga_agilex5_vanilla.dtb					|Basic/Minimal device tree blob for Linux Kernel.                 	    |
|socfpga_agilex5_socdk.dtb						|Dev kit specific and full featured Device tree blob for Linux Kernel.  |
|console-image-minimal-agilex5e.rootfs.tar.gz	|console-image-minimal rootfs.					                        |
|console-image-minimal-agilex5_nor.ubifs        |QSPI boot mode specific console-image-minimal rootfs.                  |
|console-image-minimal-agilex5.cpio.gz.u-boot	|console-image-minimal for RAMDISK boot.                                |
|gsrd-console-image-agilex5.cpio.gz.u-boot      |gsrd-console-image for RAMDISK boot.                                   |
|console-image-minimal-agilex5.wic              |SD/MMC bootable disk image.                                            |
|gsrd-console-image-agilex5.wic                 |SD/MMC bootable disk image.                                            |

### How to simulate binaries on Simics

Navigate to the directory ``/<workspace>/applications.fpga.soc.agilex5e-ed-ghrd/<devkit>/<design>/simics/linux/``

Run the simulation with the command ``$ ./runsimics.sh <Boot Mode> <Path of Binaries>``

**Boot mode options**
- SD/MMC boot source - sdmmc
    - The runsimics script uses the WIC image generated by Yocto to simulate SD/MMC boot in Simics.
- QSPI boot source - qspi
    - The runsimics script uses existing binaries to generate a QSPI JIC image and simulates QSPI boot in Simics.

**Example Usage**

$ ``./runsimics.sh sdmmc /<workspace>/applications.fpga.soc.agilex5e-ed-ghrd/<devkit>/<design>/software/yocto_linux/build/tmp/deploy/images/<agilex5e>/``
$ ``./runsimics.sh sdmmc ../../software/yocto_linux/build/tmp/deploy/images/agilex5e/``

### Steps to create QSPI bootable image (JIC)
Follow steps mentioned in ```yocto_linux/scripts/README.md``` file.

### Notes
Bitbake commands for building key targets,
- **Core Image**
``` 
$ bitbake -c build core-image-minimal
```
- **GSRD Image**
```
$ bitbake -c build gsrd-console-image
```
- **U-Boot**
```
$ bitbake -c build u-boot-socfpga (or) bitbake -c build virtual/bootloader
```
- **Linux**
```
$ bitbake -c build linux-socfpga-lts  (or) bitbake -c build virtual/kernel
```
- **ATF**
```
$ bitbake -c build arm-trusted-firmware
```
- **Device Tree**
```
$ bitbake -c build device-tree
```

### Documentation
- [KAS] https://kas.readthedocs.io/en/latest/
- [YOCTO] https://docs.yoctoproject.org/
