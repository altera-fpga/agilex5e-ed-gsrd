###############################################################################
#                           Generic Targets
###############################################################################
# Create the core RBF files from the SOF files
output_files/%.core.rbf : output_files/%.sof
	quartus_pfg -c $< output_files/$*.rbf -o hps=ON

###############################################################################
#                           SW Build Targets
###############################################################################

# HPS Debug Software Build
###############################################################################
SW_HPS_DEBUG_TARGET := software-hps_debug
RBF_NAME := ghrd
# Do not add HPS to the SW build target. Instead make it a part of the SOF install
# target. This is because other SW builds require this SOF
# ALL_SW_TARGET_STEM_NAMES += $(SW_HPS_DEBUG_TARGET)
define create_hps_debug_targets_on_revisions
$(strip $(1))-install-sof : $(INSTALL_ROOT_BINARIES)/$(strip $(1))_hps_debug.sof $(strip $(1))-install-core-rbf

.PHONY: $(strip $(1))-install-core-rbf
$(strip $(1))-install-core-rbf : output_files/$(strip $(1))_hps_debug.core.rbf | $(INSTALL_ROOT_BINARIES)
	cp -f output_files/$(strip $(1))_hps_debug.core.rbf $(INSTALL_ROOT_BINARIES)/$(RBF_NAME).core.rbf
endef
$(foreach revision,$(REVISION_NAMES),$(eval $(call create_hps_debug_targets_on_revisions,$(revision))))
clean-sw: $(SW_HPS_DEBUG_TARGET)-clean-sw

# Build the SW
software/hps_debug/hps_wipe.ihex:
	cd software/hps_debug && ./build.sh

# HPS Debug FSBL insertion into the SOF
# Create the debug SOF specific SOFs using the hps_debug SW
ifneq ($(RESTORE_INSTALL),1)
output_files/%_hps_debug.sof : output_files/%.sof software/hps_debug/hps_wipe.ihex
	quartus_pfg -c -o hps_path=software/hps_debug/hps_wipe.ihex $< $@

$(INSTALL_ROOT_BINARIES)/%_hps_debug.sof : output_files/%_hps_debug.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@
endif

.PHONY: $(SW_HPS_DEBUG_TARGET)-clean-sw
$(SW_HPS_DEBUG_TARGET)-clean-sw:
	cd software/hps_debug && ./clean_build.sh

.PHONY: $(SW_HPS_DEBUG_TARGET)-build-sw
$(SW_HPS_DEBUG_TARGET)-build-sw : software/hps_debug/hps_wipe.ihex

.PHONY: $(SW_HPS_DEBUG_TARGET)-install-sw
$(SW_HPS_DEBUG_TARGET)-install-sw : $(INSTALL_ROOT_BINARIES)/%_hps_debug.sof


# Yocto Linux Software Build for SD
###############################################################################
SW_YOCTO_LINUX_SD_TARGET := software-yocto_linux_sd
ALL_SW_TARGET_STEM_NAMES += $(SW_YOCTO_LINUX_SD_TARGET)

YOCTO_SD_IMAGE_DIR := software/yocto_linux/build/tmp/deploy/images/agilex5e
YOCTO_SD_WIC       := $(YOCTO_SD_IMAGE_DIR)/gsrd-console-image-agilex5e.rootfs.wic
YOCTO_SD_SPL_HEX   := $(YOCTO_SD_IMAGE_DIR)/u-boot-spl-dtb.hex

#Build the Yocto image (depends on baseline RBF)
$(YOCTO_SD_WIC): output_files/baseline_hps_debug.core.rbf
	cd software/yocto_linux && ./build.sh $(abspath $<) sd

#FSBL insertion into SOF
output_files/%_yocto_linux_sd.sof : output_files/%.sof $(YOCTO_SD_WIC)
	quartus_pfg -c -o hps_path=$(YOCTO_SD_SPL_HEX) $< $@

#Copy SOF files to install dir
$(INSTALL_ROOT_BINARIES)/%_yocto_linux_sd.sof : output_files/%_yocto_linux_sd.sof | $(INSTALL_ROOT_BINARIES)
	cp -f $< $@

#Create sdimage.tar.gz from the WIC
$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/sdimage.tar.gz: $(YOCTO_SD_WIC) | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	tar -chzf $@ -C $(dir $<) $(notdir $<)

# Create MD5 checksum
$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/sdimage.tar.gz.md5sum: \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/sdimage.tar.gz
	cd $(dir $@) && md5sum $(notdir $(basename $@)) > $(notdir $@)

#Copy Yocto artifacts to install dir
$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/%: $(YOCTO_SD_IMAGE_DIR)/% | $(INSTALL_ROOT_BINARIES)
	mkdir -p $(dir $@)
	cp -f $< $@

# Copy required files to artifacts directory
YOCTO_SD_ARTIFACT_FILES := \
	u-boot-spl \
	u-boot-spl.dtb \
	u-boot-spl.map \
	u-boot \
	devicetree/socfpga_agilex5_vanilla.dtb \
	console-image-minimal-agilex5e.rootfs.cpio.gz.u-boot \
	gsrd-console-image-agilex5e.rootfs.cpio.gz.u-boot

$(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_sd/%: $(YOCTO_SD_IMAGE_DIR)/% | $(INSTALL_ROOT_ARTIFACTS)
	mkdir -p $(dir $@)
	cp -f $< $@

.PHONY: sd-postprocess
sd-postprocess: output_files/baseline_hps_debug.sof
	cp -f software/yocto_linux/scripts/* $(YOCTO_SD_IMAGE_DIR)
	cp -f output_files/baseline_yocto_linux_sd.sof $(YOCTO_SD_IMAGE_DIR)
	cp -f output_files/baseline_hps_debug.sof $(YOCTO_SD_IMAGE_DIR)

	# run uboot script and quartus_pfg to generate uboot only JIC
	cd $(YOCTO_SD_IMAGE_DIR) && \
		./uboot_bin.sh && \
		cp baseline_yocto_linux_sd.sof ghrd.sof && \
		quartus_pfg -c uboot_only.pfg && \
		quartus_pfg -o hps=ON -c -o hps_path=u-boot-spl-dtb.hex baseline_hps_debug.sof ghrd.rbf

	mkdir -p $(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd
	cp -f $(YOCTO_SD_IMAGE_DIR)/uboot_only.pfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/
	cp -f $(YOCTO_SD_IMAGE_DIR)/uboot_bin.sh $(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/
	cp -f $(YOCTO_SD_IMAGE_DIR)/u-boot.bin $(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/
	cp -f $(YOCTO_SD_IMAGE_DIR)/uboot.jic $(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/
	cp -f $(YOCTO_SD_IMAGE_DIR)/ghrd.core.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/
	cp -f $(YOCTO_SD_IMAGE_DIR)/ghrd.hps.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/

# Clean target
.PHONY: $(SW_YOCTO_LINUX_SD_TARGET)-clean-sw
$(SW_YOCTO_LINUX_SD_TARGET)-clean-sw:
	cd software/yocto_linux && ./clean_build.sh

# Build target
.PHONY: $(SW_YOCTO_LINUX_SD_TARGET)-build-sw
$(SW_YOCTO_LINUX_SD_TARGET)-build-sw: $(YOCTO_SD_WIC)

# Install target
.PHONY: $(SW_YOCTO_LINUX_SD_TARGET)-install-sw
$(SW_YOCTO_LINUX_SD_TARGET)-install-sw : \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/sdimage.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/sdimage.tar.gz.md5sum \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/console-image-minimal-agilex5e.rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/console-image-minimal-agilex5e.rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/gsrd-console-image-agilex5e.rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/gsrd-console-image-agilex5e.rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/Image \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/kernel.itb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/socfpga_agilex5_socdk.dtb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/u-boot-spl-dtb.bin \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/u-boot-spl-dtb.hex \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/boot.scr.uimg \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/u-boot.itb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_sd/uboot.env \
	$(INSTALL_ROOT_BINARIES)/baseline_yocto_linux_sd.sof \
	sd-postprocess \
	$(addprefix $(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_sd/, $(YOCTO_SD_ARTIFACT_FILES))

# Yocto Linux Software Build for QSPI
###############################################################################
SW_YOCTO_LINUX_QSPI_TARGET := software-yocto_linux_qspi
ALL_SW_TARGET_STEM_NAMES += $(SW_YOCTO_LINUX_QSPI_TARGET)

YOCTO_QSPI_IMAGE_DIR := software/yocto_linux/build/tmp/deploy/images/agilex5e

software/yocto_linux/build/tmp/deploy/images/agilex5e/console-image-minimal-agilex5e.rootfs_nor.ubifs \
software/yocto_linux/build/tmp/deploy/images/agilex5e/u-boot-spl-dtb.hex: output_files/baseline_hps_debug.core.rbf
	cd software/yocto_linux && ./build.sh $(abspath $<) qspi

# Yocto Linux FSBL insertion into the SOF
output_files/%_yocto_linux_qspi.sof : output_files/%.sof software/yocto_linux/build/tmp/deploy/images/agilex5e/console-image-minimal-agilex5e.rootfs_nor.ubifs
	quartus_pfg -c -o hps_path=software/yocto_linux/build/tmp/deploy/images/agilex5e/u-boot-spl-dtb.hex $< $@

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
	devicetree/socfpga_agilex5_vanilla.dtb \
	console-image-minimal-agilex5e.rootfs.cpio.gz.u-boot

$(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_qspi/%: $(YOCTO_QSPI_IMAGE_DIR)/% | $(INSTALL_ROOT_ARTIFACTS)
	mkdir -p $(dir $@)
	cp -f $< $@

.PHONY: qspi-postprocess
qspi-postprocess: output_files/baseline_hps_debug.sof
	cp -f software/yocto_linux/scripts/* $(YOCTO_QSPI_IMAGE_DIR)
	cp -f output_files/baseline_yocto_linux_qspi.sof $(YOCTO_QSPI_IMAGE_DIR)
	cp -f output_files/baseline_hps_debug.sof $(YOCTO_QSPI_IMAGE_DIR)

	# run uboot script, create UBI images and run quartus_pfg
	cd $(YOCTO_QSPI_IMAGE_DIR) && \
		./uboot_bin.sh && \
		ubinize -o root.ubi -p 65536 -m 1 -s 1 ubinize_nor.cfg && \
		ubinize -o hps.bin -p 65536 -m 1 -s 1 ubinize_nor.cfg && \
		cp baseline_yocto_linux_qspi.sof ghrd.sof && \
		quartus_pfg -c flash_image_hps.pfg && \
		quartus_pfg -c flash_image.pfg && \
		quartus_pfg -o hps=ON -c -o hps_path=u-boot-spl-dtb.hex baseline_hps_debug.sof ghrd.rbf

	mkdir -p $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/root.ubi $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/hps.bin $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/flash_image_hps.pfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/flash_image.pfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/uboot_bin.sh $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/u-boot.bin $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/ubinize_nor.cfg $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/qspi_flash_image.hps.jic $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/qspi_flash_image.jic $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/ghrd.core.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/
	cp -f $(YOCTO_QSPI_IMAGE_DIR)/ghrd.hps.rbf $(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/

.PHONY: $(SW_YOCTO_LINUX_QSPI_TARGET)-clean-sw
$(SW_YOCTO_LINUX_QSPI_TARGET)-clean-sw:
	cd software/yocto_linux && ./clean_build.sh

.PHONY: $(SW_YOCTO_LINUX_QSPI_TARGET)-build-sw
$(SW_YOCTO_LINUX_QSPI_TARGET)-build-sw: software/yocto_linux/build/tmp/deploy/images/agilex5e/console-image-minimal-agilex5e.rootfs_nor.ubifs

.PHONY: $(SW_YOCTO_LINUX_QSPI_TARGET)-install-sw
$(SW_YOCTO_LINUX_QSPI_TARGET)-install-sw : \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/console-image-minimal-agilex5e.rootfs_nor.ubifs \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/console-image-minimal-agilex5e.rootfs.tar.gz \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/console-image-minimal-agilex5e.rootfs.manifest \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/Image \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/kernel.itb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/socfpga_agilex5_socdk.dtb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/u-boot-spl-dtb.bin \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/u-boot-spl-dtb.hex \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/boot.scr.uimg \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/u-boot.itb \
	$(INSTALL_ROOT_BINARIES)/software/yocto_linux_qspi/uboot.env \
	$(INSTALL_ROOT_BINARIES)/baseline_yocto_linux_qspi.sof \
	qspi-postprocess \
	$(addprefix $(INSTALL_ROOT_ARTIFACTS)/software/yocto_linux_qspi/, $(YOCTO_QSPI_ARTIFACT_FILES))
