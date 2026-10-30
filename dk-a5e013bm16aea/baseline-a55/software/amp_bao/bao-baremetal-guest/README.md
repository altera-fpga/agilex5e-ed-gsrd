# bao-baremetal-guest

A trimmed derivative of the upstream
[bao-project/bao-baremetal-guest](https://github.com/bao-project/bao-baremetal-guest)
framework, extended for the Agilex 5 bare-metal AMP config
(`CONFIG=baremetal` in the parent `amp_bao` orchestrator).

## Layout

| Path | Role |
|------|------|
| `src/` | Shared bare-metal runtime (core / arch / platform / drivers) |
| `src/platform/agilex5/` | Agilex 5 SoCFPGA platform (memory map, GIC, UART, timer) |
| `src-vm1/` | VM1 app — UART0 printer / IPC latency receiver |
| `src-vm2/` | VM2 app — ILC interrupt latency worker |

Unused upstream platforms and demos are omitted to keep the tree small.

### VM roles

- **VM1** owns UART0. It drains the VM2→VM1 shared-memory log ring, prints
  to the console, and measures cross-core IPC latency when Bao delivers SGI 2.
- **VM2** owns the interval timer, ILC, and GPIO LED (via LWH2F MMIO). It
  writes log lines and send timestamps into shmem, then notifies VM1 with a
  Bao IPC hypercall.

Shmem IPA / size / inner-shareable flag come from
`configs/baremetal/config.mk` (`SHMEM_BASE`, `SHMEM_SIZE`, `SHMEM_IS`).
CPU affinity is set in `configs/baremetal/config.c`.

## Build (recommended)

Build from the parent orchestrator (`software/amp_bao/`), not from this
directory alone:

```bash
cd ..   # software/amp_bao/

make CONFIG=baremetal guests          # VM1 + VM2 → build/baremetal/imgs/
make CONFIG=baremetal bao             # embeds guests into bao.bin
make CONFIG=baremetal FPGA_RBF=/path/to/core.rbf sdcard
```

`make CONFIG=baremetal bao` builds the guests first when needed. See the
parent [amp_bao README](../README.md) for the full bare-metal flow.

## Manual build

If you need to compile a guest outside the orchestrator:

```bash
export CROSS_COMPILE=aarch64-none-elf-

# VM1 — UART printer / IPC latency receiver
make PLATFORM=agilex5 SINGLE_CORE=y \
     BUILD_SUFFIX=vm1 NAME=baremetal-vm1 \
     APP_SRC_DIR=$(pwd)/src-vm1 \
     SHMEM_BASE=0xc0000000 SHMEM_SIZE=0x10000000 SHMEM_IS=0

# VM2 — ILC latency worker
make PLATFORM=agilex5 SINGLE_CORE=y \
     BUILD_SUFFIX=vm2 NAME=baremetal-vm2 \
     APP_SRC_DIR=$(pwd)/src-vm2 \
     SHMEM_BASE=0xc0000000 SHMEM_SIZE=0x10000000 SHMEM_IS=0
```

Outputs: `build/agilex5-vm1/baremetal-vm1.bin` and
`build/agilex5-vm2/baremetal-vm2.bin`.

These binaries must be staged where `configs/baremetal/config.c` expects them
(`build/baremetal/imgs/`) before building Bao; the orchestrator `vm1` / `vm2`
/ `guests` targets do that copy for you.

## Upstream reference

| Property | Value |
|----------|-------|
| Upstream repository | https://github.com/bao-project/bao-baremetal-guest |
| License | Apache-2.0 (unchanged from upstream) |
