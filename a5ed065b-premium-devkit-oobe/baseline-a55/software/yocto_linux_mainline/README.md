# Overview of yocto_linux_mainline

## What is yocto_linux_mainline?

This directory contains the **mainline Yocto Linux** build configuration, which uses the latest Yocto Project release (Whinlatter version). 

**Key Differences:**
- **yocto_linux_mainline**: Uses the latest Yocto Project release (Whinlatter) for users who want cutting-edge features and the most recent upstream packages
- **yocto_linux**: Uses the stable Yocto Project LTS release (Scarthgap) for users who prioritize stability and long-term support

Choose yocto_linux_mainline if you want to leverage the latest Yocto features and packages. Choose yocto_linux for production deployments requiring long-term stability.

**Note:** This yocto_linux_mainline implementation is provided as an **example for this specific design only**. If you want to use mainline Yocto for other designs in this repository, you will need to create your own yocto_linux_mainline directory by referring to this folder as a template and adapting it to your target design's requirements (e.g., yml configurations and meta-custom layer changes).

## Framework Overview

The Yocto Linux framework enables users to customize the Board Support Package (BSP)
to match the specific hardware design and evaluate the system on either a virtual
platform (Simics) or real hardware.

The base layer for yocto_linux_mainline is meta-altera-fpga/meta-altera-bsp. Yocto can be configurable/build
using kas menu and bitbake commands.

Following is the top level view of the yocto_linux_mainline framework.

```
.
├── kas
│   ├── apps
│   │   └── Kconfig
│   ├── bsp.yml
│   ├── gsrd
│   │   ├── console-image.yaml
│   │   └── Kconfig
│   ├── image
│   │   ├── all-image-targets.yaml
│   │   ├── console-image-minimal.yaml
│   │   ├── core-image-minimal.yaml
│   │   ├── gsrd-console-image.yaml
│   │   └── Kconfig
│   └── machine.yml
├── kas.yml
├── Kconfig
├── meta-custom
│   ├── conf
│   │   ├── layer.conf
│   │   └── machine
│   ├── LICENSE
│   ├── README.md
│   ├── recipes-apps
│   │   └── hello
│   ├── recipes-bsp
│   │   └── u-boot
│   ├── recipes-files
│   │   └── rootfs-files
│   ├── recipes-fpga
│   │   └── fpga-bitstream
│   └── recipes-kernel
│       ├── linux
│       │   ├── device-tree
│       │   ├── linux-socfpga-lts
│       │   └── pio-interrupt
│       └── perf
├── qspi_boot_src.yml
├── scripts
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
        distribution. It's essentially a minimal root filesystem which is just enough to boot the system and
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
Contains layer configuration.
- **recipes-apps**  
Contains custom application recipes such as the hello example.
- **recipes-bsp**  
Contains _u-boot_ recipe for boot loader.
    - _u-boot_ recipe allows integration of custom device tree source to enable the hardware-specific modifications. Also, allows integration of custom U-Boot environment variables.
- **recipes-files**  
Contains recipes for adding custom files to the root filesystem.
- **recipes-fpga**  
Contains the _fpga-bitstream_ recipe to include RBF file.
- **recipes-kernel**  
Contains _linux_ recipe to create Kernel Image with custom configurations.
    - _device-tree_ recipe allows integration of custom Linux device tree source and device tree fragment to enable the hardware-specific modifications.
    - _linux-socfpga-lts_ contains kernel configuration fragments and patches.
    - _pio-interrupt_ contains PIO interrupt driver example.
    - _perf_ recipe for performance analysis tools.

Refer following links to understand more on BSP customization (Top level ```meta-custom/README.md``` provides introduction to each section).

- U-Boot
	```meta-custom/recipes-bsp/u-boot/README.md```
- Linux Kernel
	```meta-custom/recipes-kernel/linux/README.md```
- Linux Device Tree
	```meta-custom/recipes-kernel/linux/device-tree/README.md```
- FPGA Bitstream
	```meta-custom/recipes-fpga/fpga-bitstream/README.md```

## scripts
Contains helper scripts and configuration files for generating QSPI JIC images from Yocto build outputs.
Refer to ```scripts/README.md``` for detailed instructions on creating bootable images for QSPI flash.

# Yocto Build

## Prepare FPGA Bitstream (RBF)

Before building Yocto, copy the FPGA bitstream generated by the GHRD build into the Yocto build tree:

```bash
# Example: Copy RBF from GHRD output to Yocto
cp ../../output_files/ghrd.rbf meta-custom/recipes-fpga/fpga-bitstream/files/baseline_a55_hps_debug.core.rbf
```

**Note:** The RBF filename must match the `FPGA_RBF_FILE` variable in `kas.yml`. Adjust the source and destination paths based on your design name and directory structure.

## Build environment

**Prerequisites**
- Ubuntu 22.04 LTS or later is recommended for Yocto builds
- The system shell must use bash instead of dash. On Ubuntu 22.04, run:
  ```bash
  sudo ln -sf /bin/bash /bin/sh
  ```

Install the following host packages and tools required for yocto build.

**Host packages**
```bash
# apt install build-essential chrpath cpio debianutils diffstat file gawk gcc git iputils-ping libacl1 liblz4-tool locales python3 python3-git python3-jinja2 python3-pexpect python3-pip python3-subunit python3-newt socat texinfo unzip wget xz-utils zstd
```
Reference, https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html#build-host-packages

**KAS tool**
```bash
$ python3 -m venv venv --system-site-packages
$ source venv/bin/activate
$ pip install --upgrade pip
$ pip install kas
$ pip install kconfiglib
```
Reference, https://kas.readthedocs.io/en/latest/userguide/getting-started.html#dependencies-installation

## How to build

### Default build
- **Using Yocto GUI**
```bash
# Run kas menu command and Build
$ kas menu
```

(or)

- **From command line**
```bash
# Set bitbake build environment
$ kas shell kas.yml

# Build console-image-minimal
$ bitbake -c build console-image-minimal
```

### Custom build
- **Using Yocto GUI**
```bash
# Run kas menu command and do custom configurations using menu & Build
$ kas menu
```

(or)

- **From command line**
```bash
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
|console-image-minimal-agilex5.cpio.gz.u-boot	|console-image-minimal for RAMDISK boot.                                |
|console-image-minimal-agilex5.wic              |SD/MMC bootable disk image.                                            |
|gsrd-console-image-agilex5.cpio.gz.u-boot      |gsrd-console-image for RAMDISK boot.                                   |
|gsrd-console-image-agilex5.wic                 |SD/MMC bootable disk image.                                            |

### How to simulate binaries on Simics

Navigate to the directory ``/<workspace>/applications.fpga.soc.agilex5e-ed-ghrd/<devkit>/<design>/simics/linux/``

Run the simulation with the command
``
$ ./runsimics.sh <Boot Mode> <Path of Binaries>
$ run
``

**Boot mode options**
- SD/MMC boot source - sdmmc
    - The runsimics script uses the WIC image generated by Yocto to simulate SD/MMC boot in Simics.
- QSPI boot source - qspi
    - The runsimics script uses existing binaries to generate a QSPI JIC image and simulates QSPI boot in Simics.

**Example Usage**
```bash
$ ./runsimics.sh sdmmc /<workspace>/applications.fpga.soc.agilex5e-ed-ghrd/<devkit>/<design>/software/yocto_linux_mainline/build/tmp/deploy/images/<agilex5e>/
$ run
```

[or]

```bash
$ ./runsimics.sh sdmmc ../../software/yocto_linux_mainline/build/tmp/deploy/images/agilex5e/
$ run
```

### Steps to create QSPI bootable image (JIC)
Follow steps mentioned in ```scripts/README.md``` file.

### Notes

#### KAS Configuration - Include and Append/Override configurations

KAS supports modularizing build configurations by allowing multiple YAML files to be included and merged.
When multiple files are specified, KAS processes and merges them **in order**, with settings in later files overriding those from earlier ones.
This mechanism enables maintaining a stable base configuration while applying targeted overrides or additions as needed.

**Usage Example**

Before building, verify final configuration after merge:
```bash
kas dump kas.yml:bsp.yml
```

To build the project:
```bash
kas build kas.yml:bsp.yml
```

* `kas.yml` is the base configuration file.
* `bsp.yml` contains override or additional settings that modify the base.
* `device-tree.yml` contains device tree specific settings that extend or override the base configuration.

This layered approach promotes a clean and maintainable configuration strategy, allowing you to customize specific settings without altering the main configuration directly.

**Example `kas.yml` with Includes**

```yaml
header:
  version: 11
  includes:
    - bsp.yml
    - device-tree.yml
```

* Here, `bsp.yml`, and `device-tree.yml` are included and merged in that order.
* Later files can override or add settings to earlier ones.

**References**

* [Including In-Tree Configuration Files](https://kas.readthedocs.io/en/latest/userguide/project-configuration.html#including-in-tree-configuration-files)
* [Including Configuration Files from Other Repos](https://kas.readthedocs.io/en/latest/userguide/project-configuration.html#including-configuration-files-from-other-repos)
* [Including Configuration Files via the Command Line](https://kas.readthedocs.io/en/latest/userguide/project-configuration.html#including-configuration-files-via-the-command-line)

#### Bitbake commands for building key targets
- **Core Image**
```bash
$ bitbake -c build core-image-minimal
```
- **GSRD Image**
```bash
$ bitbake -c build gsrd-console-image
```
- **GSRD Console Image**
```bash
$ bitbake -c build gsrd-console-image
```
- **U-Boot**
```bash
$ bitbake -c build u-boot-socfpga (or) bitbake -c build virtual/bootloader
```
- **Linux**
```bash
$ bitbake -c build linux-socfpga-lts  (or) bitbake -c build virtual/kernel
```
- **ATF**
```bash
$ bitbake -c build arm-trusted-firmware
```
- **Device Tree**
```bash
$ bitbake -c build device-tree
```

### eSDK build

The extensible SDK (eSDK) provides a cross-development toolchain and libraries tailored to the contents of a specific image.

**Prerequisites**

Before building the eSDK, modify `kas.yml` to add the following configuration under `local_conf_header`:

```yaml
  yocto-config: |
    CONF_VERSION = "2"
```

**Build eSDK**

After modifying `kas.yml`, build the extensible SDK:

```bash
# Set bitbake build environment
$ kas shell kas.yml

# Build eSDK for console-image-minimal and gsrd-console-image
$ bitbake console-image-minimal gsrd-console-image -c populate_sdk_ext
```

The generated eSDK installer will be located in `build/tmp/deploy/sdk/`.

### Documentation
- [KAS] https://kas.readthedocs.io/en/latest/
- [YOCTO] https://docs.yoctoproject.org/

