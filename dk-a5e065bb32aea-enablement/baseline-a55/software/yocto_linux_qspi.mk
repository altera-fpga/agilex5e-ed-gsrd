# Yocto Linux QSPI Build
# Required inputs: REVISION, INSTALL_ROOT_BINARIES, INSTALL_ROOT_ARTIFACTS
# Optional inputs: RESTORE_INSTALL
# Entry targets: clean-sw, build-sw, install-sw
# Board vars from sw_build_common.mk: YOCTO_QSPI_IMAGE, KAS_MACHINE, KAS_MACHINE_STRIP

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
$(error ERROR: INSTALL_ROOT_BINARIES was not defined before yocto_linux_qspi.mk was parsed)
endif

ifeq ($(strip $(INSTALL_ROOT_ARTIFACTS)),)
$(error ERROR: INSTALL_ROOT_ARTIFACTS was not defined before yocto_linux_qspi.mk was parsed)
endif

ifeq ($(strip $(REVISION)),)
$(error ERROR: REVISION was not set. Pass REVISION=<revision> on the command line)
endif


include $(THIS_MK_DIR)/sw_build_common.mk

ifdef KAS_CUSTOM_LINUX_DTB
  YOCTO_QSPI_OPTIONAL_DTB := $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/$(KAS_CUSTOM_LINUX_DTB)
else
  YOCTO_QSPI_OPTIONAL_DTB :=
endif


###############################################################################
#                           SW Build Targets
###############################################################################

YOCTO_QSPI_IMAGE_DIR := $(KAS_YOCTO_IMAGE_DIR)
YOCTO_QSPI_UBIFS := $(KAS_YOCTO_IMAGE_DIR)/$(YOCTO_QSPI_IMAGE)-$(KAS_MACHINE).rootfs_nor.ubifs

$(YOCTO_QSPI_UBIFS) \
$(KAS_YOCTO_IMAGE_DIR)/u-boot-spl-dtb.hex: output_files/$(REVISION).core.rbf
	cd software/yocto_linux && ./build.sh $(abspath $<) qspi

# Customer-facing strip-name aliases when MACHINE has a board suffix (noop when strip ==
# machine). Explicit rules so install-sw / -j builds do not rely on recipe side-effects.
ifneq ($(KAS_MACHINE),$(KAS_MACHINE_STRIP))
define yocto_qspi_strip_alias
$(YOCTO_QSPI_IMAGE_DIR)/$(YOCTO_QSPI_IMAGE)-$(KAS_MACHINE_STRIP).$(1): $(YOCTO_QSPI_UBIFS)
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/$(YOCTO_QSPI_IMAGE)-$(KAS_MACHINE).$(1) $$@
endef
$(foreach ext,rootfs_nor.ubifs rootfs.tar.gz rootfs.manifest rootfs.jffs2,\
  $(eval $(call yocto_qspi_strip_alias,$(ext))))
endif

# Yocto Linux FSBL insertion into the SOF
output_files/%_yocto_linux_qspi.sof : output_files/%.sof $(YOCTO_QSPI_UBIFS)
	quartus_pfg -c -o hps_path=$(KAS_YOCTO_IMAGE_DIR)/u-boot-spl-dtb.hex $< $@

# Copy the SOF files to the install directory
$(INSTALL_ROOT_BINARIES)/%_yocto_linux_qspi.sof : output_files/%_yocto_linux_qspi.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@

# Copy the Yocto Linux images to the install directory
$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/%: $(YOCTO_QSPI_IMAGE_DIR)/% | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	cp -f $< $@

# Copy required files to artifacts directory
YOCTO_QSPI_ARTIFACT_FILES := \
	u-boot-spl \
	u-boot-spl.dtb \
	u-boot-spl.map \
	u-boot \
	u-boot.dtb \
	$(KAS_LINUX_DTB) \
	$(YOCTO_QSPI_IMAGE)-$(KAS_MACHINE).rootfs.cpio.gz.u-boot

$(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_qspi/%: $(YOCTO_QSPI_IMAGE_DIR)/% | $(INSTALL_ROOT_ARTIFACTS)
	mkdir -p $(dir $@)
	cp -f $< $@

.PHONY: qspi-postprocess
qspi-postprocess: output_files/$(REVISION)_yocto_linux_qspi.sof output_files/$(REVISION).sof
	cp -f software/yocto_linux/scripts/* $(YOCTO_QSPI_IMAGE_DIR)
	cp -f output_files/$(REVISION)_yocto_linux_qspi.sof $(YOCTO_QSPI_IMAGE_DIR)
	cp -f output_files/$(REVISION).sof $(YOCTO_QSPI_IMAGE_DIR)

	# run uboot script, create UBI images and run quartus_pfg
	cd $(YOCTO_QSPI_IMAGE_DIR) && \
		./uboot_bin.sh && \
		ubinize -o hps.bin -p 65536 -m 1 -s 1 ubinize_nor.cfg && \
		cp $(REVISION)_yocto_linux_qspi.sof ghrd.sof && \
		quartus_pfg -c qspi_boot.pfg && \
		quartus_pfg -o hps=ON -c -o hps_path=u-boot-spl-dtb.hex $(REVISION).sof ghrd.rbf

	mkdir -p $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/hps.bin $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/qspi_boot.pfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/uboot_bin.sh $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/u-boot.bin $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/u-boot-spl $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/ubinize_nor.cfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	echo 'ubinize -o hps.bin -p 65536 -m 1 -s 1 ubinize_nor.cfg' > $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/ubinize.txt
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/qspi_boot.hps.jic $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/qspi_boot.rpd $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/ghrd.core.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/ghrd.hps.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/

# Clean target (clean-sw)
.PHONY: clean-sw
clean-sw:
	cd software/yocto_linux && ./clean_build.sh

# Build target (build-sw)
.PHONY: build-sw
build-sw: $(YOCTO_QSPI_UBIFS)

# Install target (install-sw)
YOCTO_QSPI_INSTALL_FILES := \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/$(YOCTO_QSPI_IMAGE)-$(KAS_MACHINE_STRIP).rootfs_nor.ubifs \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/$(YOCTO_QSPI_IMAGE)-$(KAS_MACHINE_STRIP).rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/$(YOCTO_QSPI_IMAGE)-$(KAS_MACHINE_STRIP).rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/$(YOCTO_QSPI_IMAGE)-$(KAS_MACHINE_STRIP).rootfs.jffs2 \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/Image \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/kernel.itb \
	$(YOCTO_QSPI_OPTIONAL_DTB) \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/u-boot-spl-dtb.bin \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/u-boot-spl-dtb.hex \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/boot.scr.uimg \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/u-boot.itb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/uboot.env \
	$(INSTALL_ROOT_BINARIES)/$(REVISION)_yocto_linux_qspi.sof

.PHONY: install-sw
install-sw : \
	$(YOCTO_QSPI_INSTALL_FILES) \
	qspi-postprocess \
	$(addprefix $(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_qspi/, $(YOCTO_QSPI_ARTIFACT_FILES))
