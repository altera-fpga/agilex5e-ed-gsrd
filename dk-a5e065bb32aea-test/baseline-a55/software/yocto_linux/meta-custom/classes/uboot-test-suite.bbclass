# Agilex5 U-Boot test suite -> boot (FAT) partition
#
# The uboot-test-suite-agilex5 recipe deploys the whole archive tree
# (uboot-test-suite/config/... and uboot-test-suite/uboot/<category>/...) into
# DEPLOY_DIR_IMAGE. IMAGE_BOOT_FILES globbing is NOT recursive and cannot copy
# directories, so EVERY file in the archive is enumerated individually as an
# exact "path;path" entry. This copies every file at any nesting depth with its
# full path preserved, so whatever the test-suite maintainers put in the tarball
# ends up on the boot partition verbatim - no assumptions about the folder
# layout and nothing is silently dropped.
#
# This logic lives in a class (not layer.conf) because BitBake only allows
# python "def" blocks in BBHandler-parsed files, not in ConfHandler-parsed
# .conf files. It is inherited by image recipes via IMAGE_CLASSES.
#
# At the U-Boot prompt the scripts are loaded and executed, e.g.:
#   load mmc 0:1 ${scriptaddr} uboot-test-suite/config/uboot.scr; source ${scriptaddr}
#   load mmc 0:1 ${scriptaddr} uboot-test-suite/uboot/ethernet/ping.scr; source ${scriptaddr}

def uboot_test_suite_boot_files(archive):
    import os
    import tarfile
    if not archive or not os.path.isfile(archive):
        return ""
    files = []
    try:
        with tarfile.open(archive) as tar:
            for member in tar.getmembers():
                if member.isfile():
                    name = member.name.lstrip("./")
                    if name:
                        files.append(name)
    except (OSError, tarfile.TarError):
        return ""
    return " ".join("%s;%s" % (name, name) for name in sorted(files))

IMAGE_BOOT_FILES:append = " ${@uboot_test_suite_boot_files(d.getVar('UBOOT_TEST_SUITE_ARCHIVE'))}"

# Ensure the archive is staged in DEPLOY_DIR_IMAGE before the SD/eMMC image is built.
do_image_wic[depends] += "uboot-test-suite-agilex5:do_deploy"
