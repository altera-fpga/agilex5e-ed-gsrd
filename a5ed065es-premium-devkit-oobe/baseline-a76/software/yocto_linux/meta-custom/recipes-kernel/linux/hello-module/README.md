# Creating a Yocto Kernel Module Recipe by Referring to `hello-module.bb`

This guide walks through the creation of a Yocto recipe for building and installing an out-of-tree Linux kernel module, using `hello-module` as a reference.
The provided `hello-module.bb` file can serve as a starting point for integrating your own external kernel modules into a Yocto-based embedded Linux system.
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

## hello-module recipe contents

- hello_module.c - The kernel module source code.
- Makefile - Makefile to compile the module against kernel headers.
- COPYING - License file (e.g., GPLv2).
- hello-module.bb - Yocto recipe to build the module.

### Directory Layout
```
meta-custom/
    |--recipes-kernel/
        |--linux/
            |--hello-module/  <---- Root directory of hello-module recipe.
                |--files/
                |    |--hello_module.c
                |    |--Makefile
                |    |--COPYING
                |--hello-module.bb
```

## Steps to Create a Recipe Similar to hello-module

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

Use this method when your module's source code (e.g., hello_module.c, Makefile..etc) is stored locally within the recipe.

```
SRC_URI = "file://hello_module.c \
           file://Makefile \
           file://COPYING"

S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"
```

**Git Repository**

Use this method to fetch your module's source code directly from a remote Git repository.
```
SRC_URI = "git://github.com/user/hello_module.git;branch=main"
SRCREV = "abcdef1234567890abcdef1234567890abcdef12"
S = "${WORKDIR}/git"
```

**Tarball**

This method allows you to fetch your module's source code from a remote compressed archive, such as .tar.gz, .zip,. BitBake will automatically download and unpack the archive during the fetch phase.

```
SRC_URI = "http://example.com/path/to/hello_module.tar.gz"
S = "${WORKDIR}/hello_module"
```

**Multiple Sources**

Yocto allows combining multiple source inputs in a single recipe using the SRC_URI variable. This is useful when your module depends on remote source code (e.g., from Git) as well as local files like patches, configuration files.

```
SRC_URI = "git://github.com/user/hello_module.git;branch=main \
           file://linux-socfpga-lts/patches/fix-warning.patch \
           file://linux-socfpga-lts/configs/hello_world.conf"
SRCREV = "abcdef1234567890abcdef1234567890abcdef12"
S = "${WORKDIR}/git"
```

#### Inherit module class and add runtime provides

```
inherit module

RPROVIDES:${PN} += "kernel-module-hello_module"
```

#### Add Makefile for out-of-tree kernel module
Create Makefile as shown below if source is placed in recipe itself.
Makefile expected to be part of repo/tar if SRC_URI is git repo or tar file, if not create it.

```
obj-m := hello_module.o

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

Add following line in `meta-custom/conf/layer.conf`

```
IMAGE_INSTALL:append = " hello-module"
```

#### Testing the Module

**Build the Module**
```
bitbake hello-module
bitbake console-image-minimal [or] bitbake gsrd-console-image
```

**Run on Target**
```
$ modprobe hello_module
$ dmesg | tail
```
You should see,

```
hello_module: loading out-of-tree module taints kernel.
hello_module: Kernel module loaded successfully.
```

**Verify list of modules**
```
$ lsmod | grep hello_module
hello_module           12288  0
```

To remove,
```
$ rmmod hello_module
$ dmesg | tail
```

You should see,

```hello_module: Kernel module unloaded. Goodbye!```
