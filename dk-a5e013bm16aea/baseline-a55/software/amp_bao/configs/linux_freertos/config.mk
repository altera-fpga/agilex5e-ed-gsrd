# Per-config inputs consumed by ../../Makefile
#
# Current partition:
#   2x Cortex-A76 -> Linux guest (SMP)
#   1x Cortex-A55 -> FreeRTOS VM: rpmsg heartbeat + ILC latency on /dev/rpmsg0
#   1x Cortex-A55 -> idle
#

# Bao
# Bao platform name (must match src/platform/<name>/ inside the Bao tree, as
# created by bao-hypervisor/patches/v2.0.0/0001-Add-agilex5-platform.patch).
BAO_PLATFORM := agilex5
AGX5_MEM_GB := 2

LINUX_DEFCONFIG := defconfig

# FreeRTOS build backend.
# `freertos-socfpga` runs the CMake build under freertos/src and produces a
# single out/freertos.bin that the Bao build .incbin's into bao.bin.
FREERTOS_BUILD_BACKEND := freertos-socfpga

# One FreeRTOS instance (A55 core 0); the second A55 stays idle.
INSTANCES := 0

# --- Instance 0 (A55 core 0) ---
# rpmsg_console: publishes the OpenAMP resource_table at IPA 0xC4000000,
# brings up the rpmsg endpoint ("rpmsg-raw"), emits periodic heartbeats
# and ILC latency summaries on /dev/rpmsg0. UART0 is not mapped (Linux
# owns it).
SAMPLE_INST_0   := rpmsg_console
MEM_BASE_INST_0 := 0x90000000
MEM_SIZE_INST_0 := 0x01000000

# --- Shared inter-VM IPC region (Bao shmem id 0) ---
# Mapped into both VMs at IPA 0xC4000000. Backing PA is allocated
# dynamically by Bao (place_phys=false in config.c shmemlist).
# Linux-side access is via /dev/rpmsg0 (OpenAMP rpmsg channel).
IPC_SHMEM_BASE  := 0xC4000000

# --- Load addresses ---
# Where boot.cmd places each image before jumping to Bao (fatload + go; no FIT).
# Must stay consistent with the Bao partition config (config.c).
# FreeRTOS guests load at MEM_BASE_INST_<i> above.

# Bao entry — keep in sync with configs/<CONFIG>/boot.cmd (fatload/go address).
BAO_LOAD_ADDR    := 0xe0000000
# Linux guest entry — must match VM_IMAGE_LOADED / .entry in config.c.
# The lloader stub's _start sits at this address; the kernel Image is placed
# at LINUX_LOAD_ADDR + 0x80000 (= 0x82080000) by loader_aarch64.ld, which
# satisfies the ARM64 boot protocol (2 MiB-aligned base + TEXT_OFFSET 0x80000).
LINUX_LOAD_ADDR  := 0x82000000
