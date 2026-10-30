# Bao AMP (`amp_bao`)

Asymmetric multi-processing (AMP) software for the Altera **Agilex 5** HPS.
A **Bao** hypervisor partitions the HPS cores across guest VMs (for example
Linux, FreeRTOS, or bare-metal). Guests may use shared memory, Bao IPC, and
RPMsg / OpenAMP for inter-VM communication, depending on the selected system
config.

This directory is a self-contained **build orchestrator**: run all `make`
commands from here. Upstream trees are fetched on demand from `sources.yaml`
into each component's `src/` directory; tracked content is the Makefile,
manifest, patches, configs, and glue. Bare-metal guest sources under
`bao-baremetal-guest/` are vendored in-tree (not fetched).

**Default system config:** `linux_freertos`

Pass `CONFIG=<name>` to select a config under `configs/`. Available configs:

| `CONFIG` | Guests | SD layout |
|----------|--------|-----------|
| `linux_freertos` (default) | Linux + FreeRTOS | FAT + ext4 rootfs |
| `baremetal` | 2× bare-metal VMs | FAT only (guests embedded in `bao.bin`) |

---

## Directory structure

```
amp_bao/
├── Makefile                 # Build orchestrator (run make from here)
├── sources.yaml             # Upstream URLs, refs, and patch dirs (default for builds)
├── sources.lock.yaml        # Optional pinned SHAs (make fetch-lock / make pin only)
├── scripts/                 # fetch, toolchains, SD image + QSPI JIC helpers
├── docs/                    # Solution how-tos (e.g. Linux↔FreeRTOS RPMsg)
├── configs/
│   ├── linux_freertos/      # Linux + FreeRTOS system config
│   └── baremetal/           # 2× bare-metal VM system config
│       ├── config.c         # Bao VM manifest
│       ├── config.mk        # Memory map, flavor knobs (AMP_FLAVOR, …)
│       ├── linux.dts        # Linux guest device tree (linux_freertos only)
│       ├── boot.cmd         # U-Boot boot script source
│       └── sd-layout.mk     # SD card partition layout
├── bao-hypervisor/          # Hypervisor (patches + fetched src/)
├── bao-baremetal-guest/     # Vendored bare-metal guest runtime + VM apps
├── ilc_baremetal_standalone/ # Standalone ILC demo binary (baremetal SD extra)
├── linux/                   # Kernel (patches, configs, lloader, rootfs overlay)
├── freertos/                # FreeRTOS guest (patches, cmake, apps/)
├── atf/                     # Arm Trusted Firmware
├── uboot/                   # U-Boot (+ board / flavor config fragments)
├── buildroot/               # Root filesystem (linux_freertos)
├── openamp/  libmetal/      # Linked into FreeRTOS RPMsg apps (e.g. rpmsg_console)
└── build/<CONFIG>/          # Generated: component trees + out/ images
```

For `linux_freertos`, Linux talks RPMsg through in-kernel remoteproc /
virtio_rpmsg (`bao-rproc` and `/dev/rpmsg0` on the Buildroot rootfs). See
[docs/linux-freertos-rpmsg.md](docs/linux-freertos-rpmsg.md) for attach
steps, shmem layout, and the kick path. The `openamp/` and `libmetal/`
trees are **not** packaged into Buildroot; they are built as libraries for
FreeRTOS apps that implement the remote side.

`configs/<CONFIG>/` is solution-level: it spans every component (Bao manifest,
optional Linux DTS, boot script, SD layout), so it lives at the solution root
rather than inside one component folder.

---

## Prerequisites

- Linux host with network access (to clone upstream trees)
- Python 3
- `mkimage` (`u-boot-tools`) for `boot.scr`
- Disk space for toolchains, sources, and (for `linux_freertos`) Buildroot

---

## Shared setup

Always work from this directory:

```bash
cd software/amp_bao
```

### 1. Toolchains (one-time)

```bash
make toolchains
eval "$(./scripts/toolchains.sh --print-env)"
```

Downloads the ARM GNU Toolchain into `.toolchain/` and prints the `PATH` /
cross-compile environment. Re-run `eval` in each new shell before building.

### 2. Fetch sources and apply patches

```bash
make fetch
```

Clones trees listed in `sources.yaml` into the matching `<component>/src/`
and applies that component's patch overlay (see [Patches](#patches)).

Which components are fetched depends on the active config (`AMP_FLAVOR` in
`configs/<CONFIG>/config.mk`):

| Config | `make fetch` pulls |
|--------|--------------------|
| `linux_freertos` | Full set (Bao, ATF, U-Boot, Linux, FreeRTOS, Buildroot, OpenAMP, libmetal, …) |
| `baremetal` | Bao, ATF, and U-Boot only (guests are vendored under `bao-baremetal-guest/`) |

#### Branch tip vs pinned SHA

Edit **`sources.yaml`** to choose what a normal build fetches. A normal build
(`make fetch`, component builds such as `make linux` / `make atf` / `make uboot`,
and the design-level software install targets) uses that file only — it does
**not** read or update `sources.lock.yaml`.

| Goal | How |
|------|-----|
| Track the latest commit on a branch each fetch | In `sources.yaml`, set `ref` to the branch name and `ref_kind: branch` (Linux, ATF, and U-Boot use this today). Each fetch re-pulls the branch tip, checks it out, then re-applies patches. |
| Pin one component to a fixed commit | In `sources.yaml`, set `ref` to the full SHA and `ref_kind: sha`. |
| Bit-identical checkout of every component | `make fetch-lock` — uses SHAs from `sources.lock.yaml` and ignores the moving `ref` values in `sources.yaml`. |
| Refresh the lock after you have verified a good tip | `make pin` (rewrites `sources.lock.yaml` from the current `src/` HEADs). Do not edit the lock by hand. |

`sources.lock.yaml` is optional tooling for reproducible / ship builds. Day-to-day
development should keep using `make fetch` so branch-tracked components (Linux,
ATF, U-Boot) pick up the latest code on those branches.

List all targets and the active instance / load map:

```bash
make help
```

---

## Patches

Solution-owned changes live under `<component>/patches/<ref>/` as numbered
`*.patch` files. `sources.yaml` selects which overlay applies:

```yaml
- name: bao
  dest: bao-hypervisor/src
  patches: bao-hypervisor/patches/v2.0.0
```

| Component | Patch dir (current) | Purpose (summary) |
|-----------|---------------------|-------------------|
| Bao | `bao-hypervisor/patches/v2.0.0/` | Agilex 5 platform, PSCI / vGICv3, IPC, SMMUv3, … |
| Linux | `linux/patches/6.18/` | `bao-rproc` remoteproc driver |
| FreeRTOS | `freertos/patches/v26.1-SMP/` | `BAO_GUEST` guards, load address, CMake option |
| libmetal | `libmetal/patches/v2025.04.0/` | Bao guest port |
| ATF, U-Boot, OpenAMP, Buildroot | _(none)_ | `patches: ""` in the manifest |

**How they are applied**

1. `make fetch` (or `make <name>-fetch`) clones pristine sources into `src/`.
2. Patches are applied in lexicographic order from the directory named in
   `sources.yaml`.
3. `make apply-patches` resets each `src/` tree and re-applies overlays
   (useful after local edits or a failed apply).
4. `<ref>` is version-keyed so you can keep `patches/v2.0.0/` and
   `patches/v2.1.1/` side by side; point `sources.yaml` at the one you want.

**Also layered (not patches):** Linux merges `linux/configs/bao-amp.config`
onto the kernel defconfig (rproc / rpmsg / virtio options that pair with the
`bao-rproc` driver). The bare-metal VM apps and Bao `config.c` for
`CONFIG=baremetal` are solution-owned source, not patches.

When bumping an upstream `ref` in `sources.yaml`, re-fetch and confirm every
patch still applies:

```bash
make reset-sources
make fetch
```

---

## System configs

### 1. Linux + FreeRTOS (`CONFIG=linux_freertos`)

| Guest | CPUs | Role |
|-------|------|------|
| Linux | 2× Cortex-A76 | SMP guest; owns UART0 |
| FreeRTOS (inst 0) | 1× Cortex-A55 | `rpmsg_console` sample (RPMsg heartbeats / ILC) |
| (idle) | 1× Cortex-A55 | Not used in this config |

After boot, attach `bao-rproc` and use `/dev/rpmsg0` as described in
[docs/linux-freertos-rpmsg.md](docs/linux-freertos-rpmsg.md).

#### Build the SD image

The demo needs an FPGA bitstream on the SD card (U-Boot loads it and enables
the HPS–FPGA bridge). Pass the design's core RBF via `FPGA_RBF`:

```bash
make CONFIG=linux_freertos FPGA_RBF=/path/to/core.rbf sdcard
```

`sdcard` is the default target (`make` alone is equivalent when `CONFIG`
defaults to `linux_freertos`), but always supply `FPGA_RBF` for a working
demo.

Dependency order:

```
fetch
  ├─ atf ──► uboot ─────────────────────┐
  ├─ linux ──► linux-loader ────────────┤
  ├─ freertos ──────────────────────────┤──► sdcard
  ├─ bao ───────────────────────────────┤
  └─ buildroot ──► rootfs ──► boot-scr ─┘
```

To build **without** a bitstream (not recommended for this example):

```bash
make CONFIG=linux_freertos sdcard
```

The FAT partition then has no `fpga.rbf`. U-Boot `fpga load` / `bridge enable`
fail, and FPGA-dependent features (for example FreeRTOS ILC) will not work.

#### Outputs

| Artifact | Location |
|----------|----------|
| SD card image | `build/linux_freertos/out/sdimage.img` |
| Binaries | `build/linux_freertos/out/` (`bao.bin`, `linux.bin`, `freertos.bin`, …) |
| Component build trees | `build/linux_freertos/` (linux, freertos, bao, …) |

Flash `sdimage.img` to an SD card with your usual imaging tool, then boot the
board from that card.

#### Build components separately

Use these when iterating on one piece without rebuilding everything.
Pass `CONFIG=linux_freertos` (or rely on the default).

| Target | What it builds |
|--------|----------------|
| `make atf` | Arm Trusted Firmware `bl31` |
| `make uboot` | U-Boot SPL + FIT image (depends on `atf`) |
| `make linux` | Linux kernel (fetches if needed; merges Kconfig fragments) |
| `make linux-loader` | Wraps `Image` + guest DTB → `linux.bin` via `lloader` |
| `make freertos` | FreeRTOS guest binary (`freertos/apps/...` via CMake) |
| `make bao` | Bao hypervisor (re-applies patches, then builds) |
| `make rootfs` | Buildroot ext4 root filesystem |
| `make boot-scr` | Legacy `mkimage -T script` from `configs/<CONFIG>/boot.cmd` (FIT signature off in `uboot/configs/*.frag`) |
| `make sdcard` | Assembles the full SD image from the pieces above |

**Fetch a single component**

```bash
make bao-fetch
make linux-fetch
make freertos-fetch    # freertos-socfpga + FreeRTOS-Kernel
make atf-fetch
make uboot-fetch
make openamp-fetch
make libmetal-fetch
make buildroot-fetch
```

**Faster rebuilds after sources are already patched**

| Target | When to use |
|--------|-------------|
| `make bao-compile` | Rebuild Bao without re-applying patches |
| `make freertos-compile` | Rebuild FreeRTOS without re-patch / CMake reconfigure (needs a prior `make freertos`) |

**Clean**

```bash
make freertos-clean    # FreeRTOS CMake build + freertos outputs
make atf-clean
make uboot-clean
make clean             # Remove build/<CONFIG>/
make distclean         # clean + reset all fetched sources
```

---

### 2. Bare-metal (`CONFIG=baremetal`)

Two bare-metal VMs under Bao, communicating over shared memory and Bao IPC.
There is no Linux, FreeRTOS, or rootfs. Guest binaries are built from
[`bao-baremetal-guest/`](bao-baremetal-guest/README.md) and embedded into
`bao.bin`. An optional standalone ILC binary is also placed on the FAT
partition — see [`ilc_baremetal_standalone/`](ilc_baremetal_standalone/README.md).

| Guest | CPUs (active affinity) | Role |
|-------|------------------------|------|
| VM1 (`src-vm1/`) | 1× Cortex-A55 (core 0) | Owns UART0; drains VM2 shmem log; measures VM2→VM1 IPC latency |
| VM2 (`src-vm2/`) | 1× Cortex-A55 (core 1) | ILC / interval-timer worker; writes shmem log; notifies VM1 via Bao IPC |

A76 affinities are present as comments in `configs/baremetal/config.c` if you
want to retarget the VMs.

#### Build the SD image

```bash
make CONFIG=baremetal FPGA_RBF=/path/to/core.rbf sdcard
```

`FPGA_RBF` is recommended: VM2's ILC path uses fabric IP behind the HPS–FPGA
bridge. Without a bitstream, U-Boot skips `fpga load` when `fpga.rbf` is
absent, and ILC-dependent behavior will not work.

Dependency order:

```
fetch
  ├─ atf ──► uboot ─────────────────────┐
  ├─ guests (vm1 + vm2) ──► bao ────────┤──► sdcard
  ├─ ilc ───────────────────────────────┤
  └─ boot-scr ──────────────────────────┘
```

`make bao` builds the guests first and stages them under
`build/baremetal/imgs/`; `configs/baremetal/config.c` `.incbin`s those images
into `bao.bin`.

Boot is driven by `boot.scr` (compiled from `configs/baremetal/boot.cmd`).
U-Boot's flavor fragment (`uboot/configs/uboot.baremetal.cfg.frag`) only
`fatload`s and `source`s that script, which then loads optional `fpga.rbf`,
loads `bao.bin` at `0x90200000`, enables the bridge, and `go`s to Bao.

#### Outputs

| Artifact | Location |
|----------|----------|
| SD card image | `build/baremetal/out/sdimage.img` |
| Hypervisor (+ embedded guests) | `build/baremetal/out/bao.bin` |
| Guest binaries | `build/baremetal/out/baremetal-vm{1,2}.bin` |
| Standalone ILC | `build/baremetal/out/ilc_demo.bin` |
| Boot script | `build/baremetal/out/boot.scr` |

FAT partition contents (no ext4): `u-boot.itb`, `bao.bin`, `ilc_demo.bin`,
`boot.scr`, and optional `fpga.rbf`.

#### Build components separately

| Target | What it builds |
|--------|----------------|
| `make CONFIG=baremetal atf` | Arm Trusted Firmware `bl31` |
| `make CONFIG=baremetal uboot` | U-Boot SPL + FIT (uses `uboot.baremetal.cfg.frag`) |
| `make CONFIG=baremetal vm1` / `vm2` | One guest binary → `build/baremetal/imgs/` |
| `make CONFIG=baremetal guests` | Both VM1 and VM2 |
| `make CONFIG=baremetal bao` | Guests (if needed) + Bao with embedded images |
| `make CONFIG=baremetal bao-compile` | Rebuild Bao without re-applying patches |
| `make CONFIG=baremetal ilc` | Standalone ILC demo → `ilc_demo.bin` |
| `make CONFIG=baremetal boot-scr` | Legacy `mkimage -T script` from `configs/baremetal/boot.cmd` |
| `make CONFIG=baremetal sdcard` | Full FAT-only SD image |

**Incremental rebuild tips**

| What changed | Command |
|--------------|---------|
| Guest C sources under `bao-baremetal-guest/` | `make CONFIG=baremetal bao-compile` (or `guests` then `bao-compile`) |
| Bao patches / `config.c` | `make CONFIG=baremetal bao` then `sdcard` |
| Standalone ILC only | `make CONFIG=baremetal ilc` |
| Everything | `make CONFIG=baremetal FPGA_RBF=/path/to/core.rbf sdcard` |

**Clean**

```bash
make CONFIG=baremetal clean      # Remove build/baremetal/
make CONFIG=baremetal distclean  # clean + reset fetched sources
```

---

## Design install (FSBL SOF + QSPI JIC)

From the design directory (`baseline-a55/`), `software-amp_bao_<config>-install-sw`
builds the SD image, inserts that config's U-Boot SPL into a FSBL SOF, and
generates QSPI JIC images (same flow as Yocto). Helpers live in
`scripts/qspi_helper.pfg` and `scripts/uboot_bin.sh` (copied into
`build/<CONFIG>/out/` during install).

```bash
# From baseline-a55/ (after a hardware build that produces output_files/<REVISION>.sof)
make software-amp_bao_linux_freertos-install-sw
make software-amp_bao_baremetal-install-sw
```

| Output | Location |
|--------|----------|
| FSBL SOF | `install/binaries/<REVISION>_amp_bao_<config>.sof` |
| QSPI JICs + helpers | `install/binaries/software/amp_bao/<config>/` (`qspi_helper.hps.jic`, `ghrd.hps.jic`, `qspi_helper.pfg`, `uboot_bin.sh`, …) |
| SD image tarball | `install/binaries/software/amp_bao/<config>/sdimage.img.tar.gz` |

Requires Quartus (`quartus_pfg`) on `PATH`. Flash `*.hps.jic` to QSPI with
Quartus Programmer as for the Yocto SD flow.

---

## Customize the system config

Edit files under `configs/<CONFIG>/` (or add a new folder and pass
`CONFIG=<name>`):

| File | Change this to… | `linux_freertos` | `baremetal` |
|------|-----------------|------------------|-------------|
| `config.c` | VM layout, CPU affinity, memory regions, IPC / shmem | yes | yes |
| `config.mk` | Flavor knobs, memory bases, guest / app selection | yes | yes |
| `linux.dts` | Linux guest device tree | yes | — |
| `boot.cmd` | U-Boot boot sequence (FPGA load, load addresses, …) | yes | yes |
| `sd-layout.mk` | SD partition sizes and which files land on FAT / rootfs | yes | yes (FAT only) |

Keep `config.c` and `config.mk` consistent (guest IPA / load addresses, shmem
base/size). For `linux_freertos`, also keep `linux.dts` and FreeRTOS load
addresses aligned with the Bao manifest.

---

## Troubleshooting tips

| Symptom | What to try |
|---------|-------------|
| `mkimage: command not found` | Install `u-boot-tools` |
| Patch apply fails after a ref bump | Fix or refresh patches; or roll back `sources.yaml` `ref` |
| Stale / dirty `src/` trees | `make apply-patches` or `make reset-sources && make fetch` |
| Cross compiler not found | Re-run `eval "$(./scripts/toolchains.sh --print-env)"` |
| FPGA / bridge errors at boot | Rebuild with `FPGA_RBF=` set to your core RBF |
| Bare-metal ILC silent / no LED | Confirm `fpga.rbf` is on the FAT partition and bridge enable runs |
| Guest rebuild not picked up in `bao.bin` | Rebuild with `make CONFIG=baremetal bao` (not only `guests`) |
| Need a reminder of addresses / targets | `make help` |
