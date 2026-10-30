# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Altera Corporation. All rights reserved.

# Makefile — ILC bare-metal demo v2, Agilex5
# Single unified binary — no CPU variant selection needed.
# Usage:  make           → ilc_demo.bin

#CROSS       ?= aarch64-none-elf-
CROSS       ?= aarch64-none-linux-gnu-
CC          := $(CROSS)gcc
LD          := $(CROSS)gcc
OBJCOPY     := $(CROSS)objcopy
OBJDUMP     := $(CROSS)objdump
SIZE        := $(CROSS)size

TARGET      := ilc_demo
CFLAGS_CPU  :=

SRCS_C := \
    main.c \
    uart.c \
    irq.c \
    gic_handle.c \
    ilc_latency.c \
    drivers/gic/socfpga_gic.c \
    drivers/gic/socfpga_gic_reg.c \
    drivers/gic/socfpga_interrupt.c

SRCS_S := \
    vectors.S

OBJS := $(SRCS_S:.S=.o) $(SRCS_C:.c=.o)

ARCH_FLAGS := -march=armv8.2-a -mabi=lp64

CFLAGS := \
    $(ARCH_FLAGS) \
    $(CFLAGS_CPU) \
    -O2 \
    -ffreestanding \
    -fno-builtin \
    -fno-stack-protector \
    -mgeneral-regs-only \
    -fno-asynchronous-unwind-tables \
    -fno-unwind-tables \
    -Wall \
    -Wextra \
    -Werror \
    -std=c11 \
    -I.

ASFLAGS := \
    $(ARCH_FLAGS) \
    -ffreestanding \
    -I.

LDFLAGS := \
    $(ARCH_FLAGS) \
    -ffreestanding \
    -nostdlib \
    -T agilex5_amp.ld \
    -Wl,-Map=$(TARGET).map \
    -Wl,--build-id=none

LIBS := -lgcc

.PHONY: all clean dis size

all: $(TARGET).elf $(TARGET).bin
	@echo ""
	@$(SIZE) $(TARGET).elf
	@echo ""
	@echo "Built: $(TARGET).elf  $(TARGET).bin"
	@echo "Entry point : $$($(OBJDUMP) -f $(TARGET).elf | grep 'start address' | awk '{print $$3}')"

%.o: %.c
	@mkdir -p $$(dirname $@)
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(ASFLAGS) -c $< -o $@

$(TARGET).elf: $(OBJS) agilex5_amp.ld
	$(LD) $(LDFLAGS) $(OBJS) $(LIBS) -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

# Verify ilc_isr: first instruction after entry should be STR to ILC_STP_REG
dis: $(TARGET).elf
	$(OBJDUMP) -d -S $< | grep -A 25 "<ilc_isr>"

size: $(TARGET).elf
	$(SIZE) $<

clean:
	find . -name '*.o' -delete
	rm -f ilc_demo.elf ilc_demo.bin ilc_demo.map
