###############################################################################
#                          Nios V Utility Targets
###############################################################################

NIOSV_FW_TARGET := niosv_fw

.PHONY: $(NIOSV_FW_TARGET)-build
$(NIOSV_FW_TARGET)-build: nios_mem.hex

$(NIOSV_FW_TARGET)-install: sim/nios_mem.hex
sim/nios_mem.hex: nios_mem.hex
	cp $< $@

.PHONY: $(NIOSV_FW_TARGET)-clean
$(NIOSV_FW_TARGET)-clean:
	git clean -dfx -- niosv_fw
	-rm -f nios_mem.hex sim/nios_mem.hex

NIOSV_GCC_ON_PATH := $(shell command -v riscv32-unknown-elf-gcc 2>/dev/null)

ifneq ($(NIOSV_GCC_ON_PATH),)
niosv_fw/bsp/settings.bsp: niosv_fw/settings.bsp.orig
	mkdir -p $(@D)
	cp $^ $@

niosv_fw/bsp/CMakeLists.txt: niosv_fw/bsp/settings.bsp
	niosv-bsp -b=$(@D) -g $(<D)/settings.bsp

niosv_fw/app/build/Makefile: niosv_fw/bsp/CMakeLists.txt
	echo 'cmake -B niosv_fw/app/build niosv_fw/app' | niosv-shell

niosv_fw/app/build/u_niosv_onchip_memory.hex: niosv_fw/app/build/Makefile
	echo 'cmake --build niosv_fw/app/build' | niosv-shell

nios_mem.hex: niosv_fw/app/build/u_niosv_onchip_memory.hex
	cp $^ $@
else
nios_mem.hex:
	@echo "Warning: riscv32-unknown-elf-gcc not found on PATH; creating empty $@"
	: > $@
endif
