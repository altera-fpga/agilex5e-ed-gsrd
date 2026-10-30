# linux_freertos

Bao partition config for Altera Agilex5:

| Guest      | CPUs          | Notes                                   |
|------------|---------------|-----------------------------------------|
| Linux      | 2x Cortex-A76 | one VM                                  |
| FreeRTOS 0 | 1x Cortex-A55 | inst 0 — `SAMPLE_INST_0` from config.mk |

Second A55 (inst 1) is idle.

## Files

- `config.mk` — instance map (SAMPLE, MEM_BASE, MEM_SIZE per VM), memory map, IPC base.
- `config.c` — Bao VM manifest (tracked; edit to change the partition layout).
- `linux.dts` — Linux guest device tree.
- `boot.cmd` — U-Boot script loaded from FAT partition.
