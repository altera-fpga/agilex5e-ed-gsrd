# Creating a Yocto Kernel Module Recipe by Referring to `pio-interrupt.bb`

This guide walks through the creation of a Yocto recipe for building and installing an out-of-tree Linux kernel module, using `pio-interrupt` as a reference.
The provided `pio-interrupt.bb` file can serve as a starting point for integrating your own external kernel modules into a Yocto-based embedded Linux system.
- This README assumes the reader has prior knowledge of Linux kernel/Device Driver programming.
- The URLs for repositories, tarballs, and commit hashes shown are for illustrative purposes only.

By referring to this recipe/README, you will:
- Understand basic structure of a kernel module recipe in Yocto.
- Learn how to build external (out-of-tree) kernel modules.
- Explore common methods to include OOT Linux kernel modules in Yocto:
    - Local Source Files - Using Files Included Directly in the Recipe.
    - Tarball - Fetching Source Code from Compressed Archives.
    - Git Repository - Cloning Source Code Directly from Git.
    - Multiple Sources - Combining Remote Repositories and Local Files.
- Package and install kernel modules into target images.

## pio-interrupt recipe contents

- gpio_interrupt.c - The kernel module source code.
- Makefile - Makefile to compile the module against kernel headers.
- COPYING - License file (e.g., GPLv2).
- pio-interrupt.bb - Yocto recipe to build the module.

### Directory Layout
```
meta-custom/
    |--recipes-kernel/
        |--linux/
            |--pio-interrupt/  <---- Root directory of pio-interrupt recipe.
                |--files/
                |    |--gpio_interrupt.c
                |    |--Makefile
                |    |--COPYING
                |--pio-interrupt.bb
```

## Steps to Create a Recipe Similar to pio-interrupt

#### Setup Metadata

Each recipe should define basic metadata such as description, license, and license checksum.

```
SUMMARY = "Simple external Linux kernel module example"
DESCRIPTION = "A minimal example demonstrating how to build and package an out-of-tree Linux kernel module using the Yocto Project."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=12f884d2ae1ff87c09e5b7ccc2c4ca7e"
```

#### Define the Source (SRC_URI) and Unpack Location (S)

**Local Source Files**

Use this method when your module's source code (e.g., gpio_interrupt.c, Makefile..etc) is stored locally within the recipe.

```
SRC_URI = "file://gpio_interrupt.c \
           file://Makefile \
           file://COPYING"

S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"
```

**Git Repository**

Use this method to fetch your module's source code directly from a remote Git repository.
```
SRC_URI = "git://github.com/user/gpio_interrupt.git;branch=main"
SRCREV = "abcdef1234567890abcdef1234567890abcdef12"
S = "${WORKDIR}/git"
```

**Tarball**

This method allows you to fetch your module's source code from a remote compressed archive, such as .tar.gz, .zip,. BitBake will automatically download and unpack the archive during the fetch phase.

```
SRC_URI = "http://example.com/path/to/gpio_interrupt.tar.gz"
SRC_URI[sha256sum] = "checksum-here"
S = "${WORKDIR}/gpio_interrupt"
```

**Note:** Remote files (http/https/ftp) require SHA256 checksums for security and build reproducibility. Calculate the checksum using:
```
sha256sum gpio_interrupt.tar.gz
```

**Multiple Sources**

Yocto allows combining multiple source inputs in a single recipe using the SRC_URI variable. This is useful when your module depends on remote source code (e.g., from Git) as well as local files like patches, configuration files.

```
SRC_URI = "git://github.com/user/gpio_interrupt.git;branch=main \
           file://linux-socfpga-lts/patches/fix-warning.patch \
           file://linux-socfpga-lts/configs/hello_world.conf"
SRCREV = "abcdef1234567890abcdef1234567890abcdef12"
S = "${WORKDIR}/git"
```

#### Inherit module class and add runtime provides

```
inherit module

RPROVIDES:${PN} += "kernel-module-gpio_interrupt"
```

#### Add Makefile for out-of-tree kernel module
Create Makefile as shown below if source is placed in recipe itself.
Makefile expected to be part of repo/tar if SRC_URI is git repo or tar file, if not create it.

```
obj-m := gpio_interrupt.o

SRC := $(shell pwd)

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC)

modules_install:
	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules_install

clean:
	rm -f *.o *~ core .depend .*.cmd *.ko *.mod.c
	rm -f Module.markers Module.symvers modules.order
	rm -rf .tmp_versions Modules.symvers
```

#### Include the Module in Your Image

After writing your recipe, you must ensure the kernel module is included in the final image.

**Simple Approach: Direct Installation**

Edit `meta-custom/conf/layer.conf` and add:

```
IMAGE_INSTALL:append = " my-module"
```

This will always include your kernel module in the image.

**Advanced Approach: Menu-Based Configuration (Optional)**

If you want to enable/disable your module via a configuration menu, follow the Kconfig integration pattern used by `pio-interrupt`:

1. Add Kconfig option in `yocto_linux/kas/gsrd/Kconfig`
2. Define environment variable in `yocto_linux/kas.yml`
3. Update `meta-custom/conf/layer.conf` with conditional installation:

```
MY_MODULE = "${GSRD_APP_MY_MODULE}"
IMAGE_INSTALL:append = "${@bb.utils.contains('MY_MODULE', 'true', ' my-module', '', d)}"
```

#### Testing the Module

**Build the Module**
```
bitbake pio-interrupt
bitbake console-image-minimal [or] bitbake gsrd-console-image
```

**Run on Target**
```
$ modprobe gpio_interrupt gpio_number=592 intr_type=2
$ dmesg | tail
```
You should see,

```
gpio_interrupt: loading out-of-tree module taints kernel.
gpio_interrupt: Kernel module loaded successfully.
```

**Verify list of modules**
```
$ lsmod | grep gpio_interrupt
gpio_interrupt           12288  0
```

To remove,
```
$ rmmod gpio_interrupt
$ dmesg | tail
```

You should see,

```gpio_interrupt: Kernel module unloaded. Goodbye!```
