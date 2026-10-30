# Per-config inputs for ../../Makefile (CONFIG=baremetal)
#
# Partition: A76 cpuid 2 → VM1 (UART/IPC receiver), A76 cpuid 3 → VM2 (ILC worker).
# Pure Bao + bare-metal; no Linux/FreeRTOS/rootfs.

AMP_FLAVOR := baremetal
AGX5_MEM_GB := 2

# Must match src/platform/<name>/ in the Bao tree. Reuses agilex5 (DRAM pool + SMMUv3 bypass);
# keep all place_phys regions in config.c inside that pool.
BAO_PLATFORM := agilex5

# configs/<name>/ folder (config.c pulled in via CONFIG_REPO).
BAO_CONFIG   := baremetal

# Guests built from bao-baremetal-guest/ and staged into build/baremetal/imgs/.
# NC shmem IPA — must match shmemlist in config.c.
SHMEM_BASE := 0xc0000000
SHMEM_SIZE := 0x10000000
SHMEM_IS   := 0

# U-Boot `go` address; keep in sync with uboot/configs/uboot.baremetal.cfg.frag.
BAO_LOAD_ADDR := 0x90200000
