## SPDX-License-Identifier: Apache-2.0
## Copyright (c) Bao Project and Contributors. All rights reserved.

gen_ld_file:=$(BUILD_DIR)/linker.ld

inner_c_srcs:=$(filter $(ROOT_DIR)/%.c, $(C_SRC))
inner_asm_srcs:=$(filter $(ROOT_DIR)/%.S, $(ASM_SRC))
outer_c_srcs:=$(filter-out $(inner_c_srcs), $(C_SRC))
outer_asm_srcs:=$(filter-out $(inner_asm_srcs), $(ASM_SRC))

external_build_dir:=$(BUILD_DIR)/external

objs:=$(inner_c_srcs:$(ROOT_DIR)/%.c=$(BUILD_DIR)/%.o) \
	$(inner_asm_srcs:$(ROOT_DIR)/%.S=$(BUILD_DIR)/%.o) \
	$(outer_c_srcs:%.c=$(external_build_dir)/%.o) \
	$(outer_asm_srcs:%.S=$(external_build_dir)/%.o)

deps:=$(objs:%=%.d) $(gen_ld_file).d
dirs:=$(sort $(dir $(objs) $(deps)))

cc=$(CROSS_COMPILE)gcc
objcopy=$(CROSS_COMPILE)objcopy
objdump=$(CROSS_COMPILE)objdump

OPT_LEVEL = 2
DEBUG_LEVEL = 3

debug_flags:= -g$(DEBUG_LEVEL) $(arch_debug_flags) $(platform_debug_flags)
GENERIC_FLAGS = $(ARCH_GENERIC_FLAGS) -O$(OPT_LEVEL) $(debug_flags) -static
CPPFLAGS += $(ARCH_CPPFLAGS) $(addprefix -I, $(INC_DIRS)) -MD -MF $@.d
ifneq ($(STD_ADDR_SPACE),)
CPPFLAGS+=-DSTD_ADDR_SPACE
endif
ifneq ($(MPU),)
CPPFLAGS+=-DMPU
endif
ifneq ($(MEM_BASE),)
CPPFLAGS+=-DMEM_BASE=$(MEM_BASE)
endif
ifneq ($(MEM_SIZE),)
CPPFLAGS+=-DMEM_SIZE=$(MEM_SIZE)
endif
ifneq ($(SHMEM_BASE),)
CPPFLAGS+=-DSHMEM_BASE=$(SHMEM_BASE)
endif
ifneq ($(SHMEM_SIZE),)
CPPFLAGS+=-DSHMEM_SIZE=$(SHMEM_SIZE)
endif
ifneq ($(SINGLE_CORE),)
CPPFLAGS+=-DSINGLE_CORE=y
endif
ifneq ($(NO_FIRMWARE),)
CPPFLAGS+=-DNO_FIRMWARE=y
endif
ifneq ($(RO_MEM_BASE),)
CPPFLAGS+=-DRO_MEM_BASE=$(RO_MEM_BASE)
endif
ifneq ($(RO_MEM_SIZE),)
CPPFLAGS+=-DRO_MEM_SIZE=$(RO_MEM_SIZE)
endif
ifneq ($(RW_MEM_BASE),)
CPPFLAGS+=-DRW_MEM_BASE=$(RW_MEM_BASE)
endif
ifneq ($(RW_MEM_SIZE),)
CPPFLAGS+=-DRW_MEM_SIZE=$(RW_MEM_SIZE)
endif
ifneq ($(STACKHEAP_SIZE),)
CPPFLAGS+=-DSTACKHEAP_SIZE=$(STACKHEAP_SIZE)
endif
ifneq ($(SHMEM_IS),)
CPPFLAGS+=-DSHMEM_IS=$(SHMEM_IS)
endif
ifeq ($(MEM_MODEL),NON_UNIFIED)
CPPFLAGS+=-DMEM_NON_UNIFIED
endif

ASFLAGS += $(GENERIC_FLAGS) $(CPPFLAGS) $(ARCH_ASFLAGS)
CFLAGS += $(GENERIC_FLAGS) $(CPPFLAGS) $(ARCH_CFLAGS)
LDFLAGS += $(GENERIC_FLAGS) $(ARCH_LDFLAGS) -nostartfiles

target:=$(BUILD_DIR)/$(NAME)
all: $(target).bin

ifneq ($(MAKECMDGOALS), clean)
-include $(deps)
endif

$(target).bin: $(target).elf
	$(objcopy) -O binary $< $@

$(target).elf: $(objs) $(gen_ld_file)
	$(cc) $(LDFLAGS) -T$(gen_ld_file) $(objs) -o $@
	$(objdump) -S $@ > $(target).asm
	$(objdump) -x -d --wide $@ > $(target).lst

$(BUILD_DIR):
	mkdir -p $@

$(objs): | $(BUILD_DIR)

$(BUILD_DIR)/%.o: $(ROOT_DIR)/%.c
	@echo $@
	$(cc) $(CFLAGS) -c $< -o $@

$(external_build_dir)/%.o: %.c
	@echo $@
	$(cc) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(ROOT_DIR)/%.S
	@echo $@
	@$(cc) $(ASFLAGS) -c $< -o $@

$(external_build_dir)/%.o: %.S
	@echo $@
	@$(cc) $(ASFLAGS) -c $< -o $@

$(gen_ld_file): $(LD_FILE)
	@$(cc) $(CPPFLAGS) -E -x assembler-with-cpp $< | grep "^[^#;]" > $@

.SECONDEXPANSION:

$(objs) $(deps): | $$(@D)/

$(dirs):
	mkdir -p $@

clean:
	@rm -rf $(BUILD_DIR)

.PHONY: all clean
