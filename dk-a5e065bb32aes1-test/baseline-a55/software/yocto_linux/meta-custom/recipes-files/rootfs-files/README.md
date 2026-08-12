# rootfs-files Recipe

This recipe provides a simple, extensible mechanism to deploy generic files (documents, scripts, configs, static binaries, static libraries, etc.) into the target root filesystem.

## Purpose

The `rootfs-files` recipe allows you to bundle static content into your Yocto images without writing complex recipes or modifying existing packages. It's ideal for:

- Platform README files and documentation with getting-started instructions
- System configuration files
- Custom scripts or utilities
- Precompiled static binaries
- Static libraries
- Any static content needed on the target

## Current Behavior

By default, the recipe installs:
- **Source**: `files/README.md`
- **Target**: `/home/root/README.md` on the rootfs

## Configuration Variables

You can customize the installation path and filename via BitBake variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `FILE_DIR` | `/home/root` | Target directory where the file will be installed |
| `FILE_NAME` | `README.md` | Name of the source file (must match a file in `files/`) and target filename |

### Example: Installing to `/etc`

To deploy a config file instead:

1. Add your file to `files/`, e.g., `files/custom.conf`
2. Override variables in your `local.conf` or layer config:
   ```bitbake
   FILE_DIR = "${sysconfdir}"
   FILE_NAME = "custom.conf"
   ```
3. Update `SRC_URI` in the recipe to match:
   ```bitbake
   SRC_URI = "file://custom.conf"
   ```

## Adding Multiple Files

To install multiple files, extend the recipe:

```bitbake
SRC_URI = "file://README.md \
           file://install.sh \
          "

do_install() {
    install -d ${D}${FILE_DIR}
    install -m 0644 ${UNPACKDIR}/README.md ${D}${FILE_DIR}/README.md
    
    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/install.sh ${D}${bindir}/install.sh
}

FILES:${PN} += "${FILE_DIR}/README.md ${bindir}/install.sh"
```

## Testing

Build and verify the recipe standalone:

```bash
bitbake rootfs-files
oe-pkgdata-util list-pkg-files rootfs-files
```

Expected output:
```
/home/root/README.md
```

To test in a full image, add the package to `IMAGE_INSTALL:append = " rootfs-files"` and build your target image:
```bash
bitbake console-image-minimal [or] bitbake gsrd-console-image
```

After booting, verify:
```bash
cat /home/root/README.md
```
