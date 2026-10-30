# Creating a Yocto Recipe by Referring to `hello.bb`

This guide explains how to create your own Yocto application recipe by referring to the `hello`
example recipe (`hello.bb`). The `hello` recipe demonstrates building a small C program with CMake
and installing it onto the target.

Use `hello` as a **template** to bootstrap new applications into your Yocto build.
By referring to the `hello` recipe, you can:

* Understand basic Yocto recipe structure
* Learn to fetch and compile sources (here, with CMake)
* Install applications into Yocto images

## The `hello` recipe at a glance

`meta-custom/recipes-apps/hello/` contains:

```
hello/
├── hello.bb
└── files/
    ├── hello.c
    └── CMakeLists.txt
```

`hello.bb`:

```
DESCRIPTION = "hello world application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://hello.c \
           file://CMakeLists.txt"

S = "${UNPACKDIR}"

inherit pkgconfig cmake

do_install() {
    # Create target directory and install the CMake-built hello executable
    install -d ${D}/home/root/alteraFPGA
    install -m 0755 ${B}/hello ${D}/home/root/alteraFPGA/hello
}

FILES:${PN} = "/home/root/alteraFPGA/hello"
```

## Steps to Create a Recipe Similar to `hello`

### Set Up Metadata

Each recipe should define basic metadata such as description, license, and license checksum:

```
DESCRIPTION = "Hello World application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
```

### Define the Source (`SRC_URI`) and Unpack Location (`S`)

Use the `SRC_URI` variable to specify where the source code comes from.

#### Local Source File
Use this method when your application's source code (e.g., `hello.c`) is stored locally within the
recipe. Place the source files inside the `files/` directory of your recipe:

```
meta-custom/recipes-apps/hello/files/hello.c
meta-custom/recipes-apps/hello/files/CMakeLists.txt
```
```
SRC_URI = "file://hello.c \
           file://CMakeLists.txt"
S = "${UNPACKDIR}"
```

#### Git Repository
Use this method to fetch your application's source code directly from a remote Git repository.

```
SRC_URI = "git://github.com/user/repo.git;branch=main"
SRCREV = "abcdef1234567890abcdef1234567890abcdef12"
S = "${WORKDIR}/git"
```

#### Tarball
Fetch your application's source from a remote compressed archive (e.g. `.tar.gz`, `.zip`). BitBake
downloads and unpacks it during the fetch phase.

```
SRC_URI = "http://example.com/path/to/source.tar.gz"
S = "${WORKDIR}/source"
```

#### Multiple Sources
Combine multiple source inputs in a single recipe using `SRC_URI` — e.g. remote source plus local
files like patches or configuration:

```
SRC_URI = "git://github.com/user/repo.git;branch=main \
           file://patches/fix-warning.patch \
           file://config/hello.conf"
SRCREV = "abcdef1234567890abcdef1234567890abcdef12"
S = "${WORKDIR}/git"
```

### Build the Application

`hello` builds with CMake, so it simply inherits the `cmake` class (no explicit `do_compile` is
needed — the `files/CMakeLists.txt` drives the build):

```
inherit pkgconfig cmake
```

If instead you compile by hand, implement `do_compile()`:

```
do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -o hello hello.c
}
```

### Install the Application (`do_install`)

Refer to how `hello.bb` installs the CMake-built binary onto the target:

```
do_install() {
    install -d ${D}/home/root/alteraFPGA
    install -m 0755 ${B}/hello ${D}/home/root/alteraFPGA/hello
}

FILES:${PN} = "/home/root/alteraFPGA/hello"
```

### Include the Recipe in Your Image

After writing your recipe, ensure the application is included in the final image.

#### Simple Approach: Direct Installation

Edit `meta-custom/conf/layer.conf` and add:

```
IMAGE_INSTALL:append = " my-app"
```

This will always include your application in the image.

#### Advanced Approach: Menu-Based Configuration (Optional)

To enable/disable your application via a configuration menu, follow the Kconfig integration pattern:

1. Add a Kconfig option under `yocto_linux/kas/apps/Kconfig`
2. Define the environment variable in `yocto_linux/kas.yml`
3. Update `meta-custom/conf/layer.conf` with conditional installation:

```
MY_APP = "${GSRD_APP_MY_APP}"
IMAGE_INSTALL:append = "${@bb.utils.contains('MY_APP', 'true', ' my-app', '', d)}"
```

## Testing the Recipe

After adding the recipe, build the application with standard bitbake commands:

```
$ bitbake hello
$ bitbake console-image-minimal
```

To verify the application is included in the image, boot the target and run:

```
$ /home/root/alteraFPGA/hello
```
