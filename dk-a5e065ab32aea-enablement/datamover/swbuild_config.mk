###############################################################################
#                           SW Build Targets
###############################################################################

# FreeRTOS Software Build
###############################################################################
PROJECT_FOLDER = $(realpath .)
FREERTOS_TOP_FOLDER = $(PROJECT_FOLDER)/software/freertos

# Data Mover App
FREERTOS_DATAMOVER_APP := freertos_datamover
ALL_SW_TARGET_STEM_NAMES += software-$(FREERTOS_DATAMOVER_APP)

DATAMOVER_FOLDER = $(FREERTOS_TOP_FOLDER)/datamover-app

# build folders
ST_BUILD_FOLDER = $(DATAMOVER_FOLDER)/single-threaded/build
MT_BUILD_FOLDER = $(DATAMOVER_FOLDER)/multi-threaded/build

# JIC files
ST_JIC = $(ST_BUILD_FOLDER)/fpga_binaries/qspi_image.jic
MT_JIC = $(MT_BUILD_FOLDER)/fpga_binaries/qspi_image.jic

###############################################################################
# Single-Threaded Build Targets
###############################################################################

.PHONY: software-$(FREERTOS_DATAMOVER_APP)-build-st-sw
software-$(FREERTOS_DATAMOVER_APP)-build-st-sw: output_files/datamover.sof
	$(DATAMOVER_FOLDER)/build.sh single-threaded

###############################################################################
# Multi-Threaded Build Targets
###############################################################################

.PHONY: software-$(FREERTOS_DATAMOVER_APP)-build-mt-sw
software-$(FREERTOS_DATAMOVER_APP)-build-mt-sw: output_files/datamover.sof
	$(DATAMOVER_FOLDER)/build.sh multi-threaded

###############################################################################
# General Build Targets
###############################################################################

.PHONY: software-$(FREERTOS_DATAMOVER_APP)-build-sw
software-$(FREERTOS_DATAMOVER_APP)-build-sw: output_files/datamover.sof
	$(DATAMOVER_FOLDER)/build.sh single-threaded
	$(DATAMOVER_FOLDER)/build.sh multi-threaded

.PHONY: software-$(FREERTOS_DATAMOVER_APP)-install-sw
software-$(FREERTOS_DATAMOVER_APP)-install-sw: software-$(FREERTOS_DATAMOVER_APP)-build-sw
	mkdir -p $(INSTALL_ROOT_BINARIES)/freertos/datamover-app/single-threaded/
	mkdir -p $(INSTALL_ROOT_BINARIES)/freertos/datamover-app/multi-threaded/
	cp -f $(ST_JIC) $(INSTALL_ROOT_BINARIES)/freertos/datamover-app/single-threaded/
	cp -f $(MT_JIC) $(INSTALL_ROOT_BINARIES)/freertos/datamover-app/multi-threaded/

.PHONY: software-$(FREERTOS_DATAMOVER_APP)-clean-sw
software-$(FREERTOS_DATAMOVER_APP)-clean-sw:
	rm -rf $(ST_BUILD_FOLDER)
	rm -rf $(MT_BUILD_FOLDER)
	git clean -fdx $(DATAMOVER_FOLDER)
