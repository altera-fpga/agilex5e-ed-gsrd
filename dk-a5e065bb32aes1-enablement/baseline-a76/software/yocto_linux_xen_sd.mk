# Yocto Linux XEN SD Build
# Required inputs: REVISION, INSTALL_ROOT_BINARIES, INSTALL_ROOT_ARTIFACTS
# Optional inputs: RESTORE_INSTALL
# Entry targets: clean-sw, build-sw, install-sw
# Board vars from sw_build_common.mk: FLASH_LOADER, KAS_MACHINE, KAS_MACHINE_STRIP

THIS_MK_ABSPATH := $(abspath $(lastword $(MAKEFILE_LIST)))
THIS_MK_DIR := $(dir $(THIS_MK_ABSPATH))

# Enable pipefail for all commands
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

# Enable second expansion
.SECONDEXPANSION:

# Clear all built in suffixes
.SUFFIXES:

ifeq ($(strip $(INSTALL_ROOT_BINARIES)),)
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before yocto_linux_xen_sd.mk was parsed)
endif

ifeq ($(strip $(INSTALL_ROOT_ARTIFACTS)),)
$(error ERROR: INSTALL_ROOT_ARTIFACTS was not defined before yocto_linux_xen_sd.mk was parsed)
endif

ifeq ($(strip $(REVISION)),)
$(error ERROR: REVISION was not set. Pass REVISION=<revision> on the command line)
endif


include $(THIS_MK_DIR)/sw_build_common.mk

ifdef KAS_CUSTOM_LINUX_DTB
  YOCTO_XEN_SD_OPTIONAL_DTB := $(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/$(KAS_CUSTOM_LINUX_DTB)
else
  YOCTO_XEN_SD_OPTIONAL_DTB :=
endif


###############################################################################
#                           SW Build Targets
###############################################################################

YOCTO_XEN_SD_IMAGE_DIR := $(KAS_YOCTO_IMAGE_DIR)
YOCTO_XEN_SD_WIC       := $(YOCTO_XEN_SD_IMAGE_DIR)/xen-image-minimal-$(KAS_MACHINE).rootfs.wic
YOCTO_XEN_SD_SPL_HEX   := $(YOCTO_XEN_SD_IMAGE_DIR)/u-boot-spl-dtb.hex

# Build the Yocto XEN image (depends on $(REVISION) RBF)
$(YOCTO_XEN_SD_WIC): output_files/$(REVISION).core.rbf
	cd software/yocto_linux && XEN_BUILD=1 ./build.sh $(abspath $<) sd

# Customer-facing strip-name aliases when MACHINE has a board suffix (noop when strip ==
# machine). Explicit rules so install-sw / -j builds do not rely on recipe side-effects.
ifneq ($(KAS_MACHINE),$(KAS_MACHINE_STRIP))
define yocto_xen_sd_strip_alias
$(YOCTO_XEN_SD_IMAGE_DIR)/$(1)-$(KAS_MACHINE_STRIP).$(2): $(YOCTO_XEN_SD_WIC)
	cp -f $(YOCTO_XEN_SD_IMAGE_DIR)/$(1)-$(KAS_MACHINE).$(2) $$@
endef
$(foreach base,xen-image-minimal gsrd-console-image console-image-minimal,\
  $(foreach ext,rootfs.tar.gz rootfs.manifest rootfs.cpio.gz,\
    $(eval $(call yocto_xen_sd_strip_alias,$(base),$(ext)))))
endif

# FSBL insertion into SOF
output_files/%_yocto_linux_xen_sd.sof : output_files/%.sof $(YOCTO_XEN_SD_WIC)
	quartus_pfg -c -o hps_path=$(YOCTO_XEN_SD_SPL_HEX) $< $@

# Copy SOF files to install dir
$(INSTALL_ROOT_BINARIES)/%_yocto_linux_xen_sd.sof : output_files/%_yocto_linux_xen_sd.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@

# Create sdimage.tar.gz packaging the gsrd-console-image WIC (also produced by the XEN build).
# NOTE: The dependency is intentionally on YOCTO_XEN_SD_WIC (xen-image-minimal-*.wic) rather than
# gsrd-console-image-*.wic, because both the SD and XEN builds produce gsrd-console-image-*.wic in
# the same directory. Using a shared file as a Make target would cause a duplicate-rule conflict and
# Make would silently pick one recipe over the other. xen-image-minimal-*.wic is unique to the XEN
# build and serves as the safe, unambiguous trigger here.
# TODO: Consider outputting the XEN gsrd-console-image WIC to a separate directory so this rule can
# depend on it directly without conflicting with the non-XEN SD build rule.
$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/sdimage.tar.gz: $(YOCTO_XEN_SD_WIC) | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	tar -chzf $@ -C $(YOCTO_XEN_SD_IMAGE_DIR) gsrd-console-image-$(KAS_MACHINE).rootfs.wic

# Create MD5 checksum
$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/sdimage.tar.gz.md5sum: \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/sdimage.tar.gz
	cd $(dir $@) && md5sum $(notdir $(basename $@)) > $(notdir $@)

# Copy Yocto XEN artifacts to install dir
$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/%: $(YOCTO_XEN_SD_IMAGE_DIR)/% | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	cp -f $< $@

# Copy required files to artifacts directory
YOCTO_XEN_SD_ARTIFACT_FILES := \
	u-boot-spl \
	u-boot-spl.dtb \
	u-boot-spl.map \
	u-boot \
	u-boot.dtb \
	$(KAS_LINUX_DTB) \
	xen-image-minimal-$(KAS_MACHINE).rootfs.cpio.gz.u-boot \
	console-image-minimal-$(KAS_MACHINE).rootfs.cpio.gz.u-boot \
	gsrd-console-image-$(KAS_MACHINE).rootfs.cpio.gz.u-boot

$(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_xen_sd/%: $(YOCTO_XEN_SD_IMAGE_DIR)/% | $(INSTALL_ROOT_ARTIFACTS)
	mkdir -p $(dir $@)
	cp -f $< $@

.PHONY: xen-sd-postprocess
xen-sd-postprocess: output_files/$(REVISION)_yocto_linux_xen_sd.sof output_files/$(REVISION).sof
	cp -f software/yocto_linux/scripts/* $(YOCTO_XEN_SD_IMAGE_DIR)
	cp -f output_files/$(REVISION)_yocto_linux_xen_sd.sof $(YOCTO_XEN_SD_IMAGE_DIR)
	cp -f output_files/$(REVISION).sof $(YOCTO_XEN_SD_IMAGE_DIR)

	# run uboot script and quartus_pfg to generate uboot only JIC
	cd $(YOCTO_XEN_SD_IMAGE_DIR) && \
		./uboot_bin.sh && \
		cp $(REVISION)_yocto_linux_xen_sd.sof ghrd.sof && \
		quartus_pfg -c qspi_helper.pfg && \
		quartus_pfg -c ghrd.sof ghrd.jic -o device=MT25QU128 -o flash_loader=$(FLASH_LOADER) -o hps_path=u-boot-spl-dtb.hex -o mode=ASX4 -o hps=1 && \
		quartus_pfg -o hps=ON -c -o hps_path=u-boot-spl-dtb.hex $(REVISION).sof ghrd.rbf

	mkdir -p $(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd
	cp -f $(YOCTO_XEN_SD_IMAGE_DIR)/qspi_helper.pfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/
	cp -f $(YOCTO_XEN_SD_IMAGE_DIR)/uboot_bin.sh $(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/
	cp -f $(YOCTO_XEN_SD_IMAGE_DIR)/u-boot.bin $(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/
	cp -f $(YOCTO_XEN_SD_IMAGE_DIR)/u-boot-spl $(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/
	cp -f $(YOCTO_XEN_SD_IMAGE_DIR)/qspi_helper.hps.jic $(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/
	cp -f $(YOCTO_XEN_SD_IMAGE_DIR)/ghrd.hps.jic $(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/
	cp -f $(YOCTO_XEN_SD_IMAGE_DIR)/ghrd.core.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/
	cp -f $(YOCTO_XEN_SD_IMAGE_DIR)/ghrd.hps.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/

# Clean target (clean-sw)
.PHONY: clean-sw
clean-sw:
	cd software/yocto_linux && ./clean_build.sh

# Build target (build-sw)
.PHONY: build-sw
build-sw: $(YOCTO_XEN_SD_WIC)

# Install target (install-sw)
YOCTO_XEN_SD_INSTALL_FILES := \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/sdimage.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/sdimage.tar.gz.md5sum \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/xen-image-minimal-$(KAS_MACHINE_STRIP).rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/xen-image-minimal-$(KAS_MACHINE_STRIP).rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/xen-image-minimal-$(KAS_MACHINE_STRIP).rootfs.cpio.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/console-image-minimal-$(KAS_MACHINE_STRIP).rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/console-image-minimal-$(KAS_MACHINE_STRIP).rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/gsrd-console-image-$(KAS_MACHINE_STRIP).rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/gsrd-console-image-$(KAS_MACHINE_STRIP).rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/Image \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/kernel.itb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/xen \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/boot.scr.xen.uimg \
	$(YOCTO_XEN_SD_OPTIONAL_DTB) \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/u-boot-spl-dtb.bin \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/u-boot-spl-dtb.hex \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/boot.scr.uimg \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/u-boot.itb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_xen_sd/uboot.env \
	$(INSTALL_ROOT_BINARIES)/$(REVISION)_yocto_linux_xen_sd.sof

.PHONY: install-sw
install-sw : \
	$(YOCTO_XEN_SD_INSTALL_FILES) \
	xen-sd-postprocess \
	$(addprefix $(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_xen_sd/, $(YOCTO_XEN_SD_ARTIFACT_FILES))
