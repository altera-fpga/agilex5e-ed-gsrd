# software/amp_bao/linux/lloader/Makefile
#
# Wraps a Linux kernel Image + DTB into a single guest binary that satisfies
# the AArch64 Linux boot protocol when entered cold by a hypervisor that does
# not itself set up x0 = phys(FDT) — which is Bao's behaviour.
#
# Layout produced (from loader_<arch>.ld):
#   offset 0x00000   .nloader   small stub (_start)
#   offset 0x00???   .dtb       8-byte aligned, incbin'd at build time
#   offset 0x80000   .linux     kernel Image, incbin'd at build time
#
# Required inputs:
#   ARCH           e.g. aarch64
#   IMAGE          path to the kernel Image (binary, not Image.gz)
#   DTB            path to the compiled guest device tree blob
#   TARGET         output path WITHOUT extension (Makefile emits TARGET.elf + TARGET.bin)
#
# Optional:
#   CROSS_COMPILE  default per ARCH (see below)

ifeq ($(MAKECMDGOALS),clean)
# clean target has no required inputs
else
ifeq ($(and $(IMAGE),$(DTB),$(TARGET),$(ARCH)),)
$(error IMAGE, DTB, TARGET, and ARCH must all be set \
        (got IMAGE='$(IMAGE)' DTB='$(DTB)' TARGET='$(TARGET)' ARCH='$(ARCH)'))
endif
endif

ARCH ?= aarch64

ifeq ($(ARCH),aarch64)
  CROSS_COMPILE ?= aarch64-none-elf-
  OPTIONS       := -mcmodel=large
else ifeq ($(ARCH),aarch32)
  CROSS_COMPILE ?= arm-none-eabi-
  OPTIONS       := -march=armv7-a
else ifeq ($(ARCH),riscv64)
  CROSS_COMPILE ?= riscv64-unknown-elf-
  OPTIONS       := -mcmodel=medany
else
  $(error unsupported ARCH '$(ARCH)' — extend this Makefile)
endif

CC      := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy

LLOADER_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
STUB_SRC    := $(LLOADER_DIR)/$(ARCH).S
LINKER_LD   := $(LLOADER_DIR)/loader_$(ARCH).ld

.PHONY: all clean

all: $(TARGET).bin

# Pre-flight: refuse to build if the stub or linker script is missing.
_check-sources:
	@if [ ! -f "$(STUB_SRC)" ]; then \
	  echo "ERROR: missing $(STUB_SRC)"; \
	  echo "       Drop in the entry stub (e.g. copy $(ARCH).S.todo -> $(ARCH).S)"; \
	  echo "       or copy from bao-demos/guests/linux/lloader/$(ARCH).S (Apache 2.0)."; \
	  exit 1; \
	fi
	@if [ ! -f "$(LINKER_LD)" ]; then \
	  echo "ERROR: missing $(LINKER_LD)"; \
	  echo "       Drop in the linker script (e.g. copy loader_$(ARCH).ld.todo -> loader_$(ARCH).ld)"; \
	  echo "       or copy from bao-demos/guests/linux/lloader/loader_$(ARCH).ld."; \
	  exit 1; \
	fi

$(TARGET).elf: _check-sources $(STUB_SRC) $(LINKER_LD) $(IMAGE) $(DTB)
	$(CC) -Wl,-build-id=none -nostdlib -T $(LINKER_LD) \
	      -o $@ $(OPTIONS) $(STUB_SRC) \
	      -I$(LLOADER_DIR) \
	      -DIMAGE=\"$(abspath $(IMAGE))\" -DDTB=\"$(abspath $(DTB))\"

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -S -O binary $< $@

clean:
	@if [ -n "$(TARGET)" ]; then rm -f "$(TARGET).elf" "$(TARGET).bin"; fi
