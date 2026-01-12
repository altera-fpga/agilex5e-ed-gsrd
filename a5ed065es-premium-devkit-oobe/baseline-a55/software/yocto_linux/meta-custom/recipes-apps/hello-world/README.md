# Creating a Yocto Recipe by Referring to `hello-world.bb`

This guide explains how to create your own Yocto application recipe by referring to the `hello-world` example recipe. The `hello-world` recipe demonstrates building and installing a simple C program that prints "Hello, World!".

Use `hello-world` as a **template** to bootstrap new applications into your Yocto build.
By referring to the `hello-world` recipe, you can:

* Understand basic Yocto recipe structure
* Learn to fetch and compile sources
* Install applications into Yocto images

## Steps to Create a Recipe Similar to `hello-world`

###  Set Up Metadata

Each recipe should define basic metadata such as description, license, and license checksum:

```
DESCRIPTION = "Hello World application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
```

### **Define the Source (SRC_URI) and Unpack Location (S)**

Use the `SRC_URI` variable to specify where the source code comes from.

#### Local Source File
Use this method when your application's source code (e.g., hello-world.c) is stored locally within the recipe. The source files should be placed inside the files/ directory of your recipe.

Place the source files in the `files/` directory and update SRC_URI, S:
```
meta-custom/recipes-apps/hello-world/files/hello-world.c
```
```
SRC_URI = "file://hello-world.c"
S = "${WORKDIR}/sources"
```

#### Git Repository
Use this method to fetch your application's source code directly from a remote Git repository.

```
SRC_URI = "git://github.com/user/repo.git;branch=main"
SRCREV = "abcdef1234567890abcdef1234567890abcdef12"
S = "${WORKDIR}/git"
```

####  Tarball
This method allows you to fetch your application's source code from a remote compressed archive, such as .tar.gz, .zip,. BitBake will automatically download and unpack the archive during the fetch phase.

```
SRC_URI = "http://example.com/path/to/source.tar.gz"
S = "${WORKDIR}/source"
```

#### Multiple Sources
Yocto allows combining multiple source inputs in a single recipe using the SRC_URI variable. This is useful when your application depends on remote source code (e.g., from Git) as well as local files like patches, configuration files.

```
SRC_URI = "git://github.com/user/repo.git;branch=main \
           file://patches/fix-warning.patch \
           file://config/hello.conf"
SRCREV = "abcdef1234567890abcdef1234567890abcdef12"
S = "${WORKDIR}/git"
```

###  Build the Application (*do_compile*)
For compilation, follow the build flow of the source code and implement the *do_compile()* function.

Refer to `hello-world.bb` for implementation. Typically:

```
do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -o hello-world hello-world.c
}
```

### Install the Application (*do_install*)

Refer to how `hello-world.bb` installs the binary:

```
do_install() {
    install -d ${D}${bindir}
    install -m 0755 hello-world ${D}${bindir}/hello-world
}
```

### Include the Recipe in Your Image

After writing your recipe, you must ensure the application is included in the final image by adding:

```
IMAGE_INSTALL:append = " hello-world"
```

To do this in a structured KAS/Kconfig/YAML-based environment, add the necessary entries to the following configuration files:

**yocto_linux/Kconfig**

Make sure the application's Kconfig i.e, `yocto_linux/kas/apps/Kconfig` is included in the root Kconfig i.e, `yocto_linux/Kconfig`. This allows the application to be selectable via configuration toggles.

**yocto_linux/kas/apps/Kconfig**

Define a configuration option to allow enabling/disabling the application and make sure Kconfig included in root Kconfig i.e, `yocto_linux/Kconfig`.

**yocto_linux/kas/apps/hello-world.yaml**

Appends the application to the image with `IMAGE_INSTALL:append = " hello-world"`.

## Testing the Recipe

After adding the recipe, build the application by using standard bitbake commands:
```
$ bitbake hello-world
$ bitbake -c build console-image-minimal
```

To verify the application included in the image:
```
$ sh runsimics <boot mode> <binaries path>
$ which hello-world
$ hello-world
```
