# hps-amp — top-level orchestrator (Altera Agilex5 HPS, asymmetric multi-processing)
#
# Usage:
#   make CONFIG=linux_freertos <target>
#
# Flow:
#   toolchains -> fetch (manifest-driven clone+patch of every src/<tree>)
#     -> linux -> linux-loader
#     -> freertos -> bao -> sdcard  (linux.bin + bao.bin loaded directly; no FIT)
#
# Source trees live under src/ and are materialised by a single Python driver
# reading the YAML manifest at the repo root:
#
#   sources.yaml          editable, branches/tags/SHAs per component
#   sources.lock.yaml     auto-generated; resolved SHAs for reproducible builds
#   scripts/fetch-sources.py
#                          clone + checkout + apply patches (PyYAML required)
#
# Top-level targets that talk to it:
#
#   make fetch            clone everything per sources.yaml + apply patches
#   make fetch-lock       clone everything per sources.lock.yaml (CI/ship)
#   make <name>-fetch     clone a single component (bao-fetch, linux-fetch, …)
#   make pin              capture current HEAD SHAs into sources.lock.yaml
#   make reset-sources    `git reset --hard && clean -fdx` every src/ tree
#
# To switch kernel trees, prefer editing sources.yaml. For one-shot overrides:
#   make HPS_AMP_LINUX_URL=<url> HPS_AMP_LINUX_REF=<ref> linux-fetch
#
# See README.md for toolchain setup and full prerequisites.

# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------

CONFIG ?= linux_freertos

# This Makefile lives at the ROOT of the Bao AMP solution (software/amp_bao/).
# The solution is self-contained: it owns its Makefile, manifest, scripts, docs
# AND its component checkouts under <c>/src.
#
#   ROOT_DIR      = .../software/amp_bao   this solution's root (= CURDIR)
#   SOLUTION_DIR  = ROOT_DIR               everything this solution owns
ROOT_DIR     := $(abspath $(CURDIR))
SOLUTION_DIR := $(ROOT_DIR)

# One folder per target holds the whole system definition: the Bao VM manifest
# (config.c, config.mk, linux.dts) AND the image/assembly templates (boot.cmd,
# sd-layout.mk, ...).
CONFIG_DIR  := $(SOLUTION_DIR)/configs/$(CONFIG)
BUILD_DIR   := $(ROOT_DIR)/build/$(CONFIG)
OUT_DIR     := $(BUILD_DIR)/out

# Every component is self-contained under <c>/: src/ is the upstream checkout
# (gitignored, fetch-managed); patches/ and configs/ alongside are solution-owned.
BAO_DIR              := $(SOLUTION_DIR)/bao-hypervisor/src
LINUX_DIR            := $(SOLUTION_DIR)/linux/src
ATF_DIR              := $(SOLUTION_DIR)/atf/src
UBOOT_DIR            := $(SOLUTION_DIR)/uboot/src
FREERTOS_SOCFPGA_DIR := $(SOLUTION_DIR)/freertos/src
BUILDROOT_DIR        := $(SOLUTION_DIR)/buildroot/src
OPENAMP_DIR          := $(SOLUTION_DIR)/openamp/src
LIBMETAL_DIR         := $(SOLUTION_DIR)/libmetal/src

SCRIPTS_DIR    := $(ROOT_DIR)/scripts

# ── Source manifest + fetcher ─────────────────────────────────────────────────
# Single source of truth for every src/<tree>. Bumping a ref means editing
# sources.yaml; one-shot overrides go through HPS_AMP_<NAME>_REF/_URL env vars
# consumed by scripts/fetch-sources.py (e.g. make HPS_AMP_LINUX_REF=v6.12 ...).
SOURCES_MANIFEST ?= $(ROOT_DIR)/sources.yaml
SOURCES_LOCK     ?= $(ROOT_DIR)/sources.lock.yaml
FETCH_SOURCES    := $(SCRIPTS_DIR)/fetch-sources.py

# Resolve a component's pinned `ref` straight out of sources.yaml so the
# informational build logs below cannot drift from the manifest (the single
# source of truth). Strips inline "# ..." comments and surrounding quotes.
#   Usage: $(call manifest_ref,<component-name>)
manifest_ref = $(shell awk -v want="$(1)" '/^[[:space:]]*-[[:space:]]*name:/{n=$$0; sub(/.*name:[[:space:]]*/,"",n); sub(/[[:space:]]*\#.*/,"",n)} /^[[:space:]]*ref:/ && n==want {r=$$0; sub(/.*ref:[[:space:]]*/,"",r); sub(/[[:space:]]*\#.*/,"",r); gsub(/"/,"",r); print r; exit}' $(SOURCES_MANIFEST))

# Pinned versions — derived from sources.yaml (DO NOT hardcode; bump the
# manifest instead). Used only in build-log echoes, never to select a ref.
BAO_TAG   := $(call manifest_ref,bao)
# LINUX_REPO / LINUX_BRANCH are per-CONFIG overrides — set them in
# configs/<CONFIG>/config.mk to point linux-fetch at a different tree. When
# unset the manifest defaults from sources.yaml are used.
LINUX_REPO   ?=
LINUX_BRANCH ?=
# Export the per-CONFIG Linux override as the manifest fetcher's
# HPS_AMP_LINUX_URL / HPS_AMP_LINUX_REF override so EVERY fetch invocation
# (top-level `fetch`, `apply-patches`, and the bespoke `linux-fetch` wrapper)
# resolves to the same URL+branch. Deferred (=, not :=) so config.mk's
# override (loaded later) is picked up. Empty values are treated as "unset"
# by fetch-sources.py and fall through to the manifest defaults.
export HPS_AMP_LINUX_URL = $(LINUX_REPO)
export HPS_AMP_LINUX_REF = $(LINUX_BRANCH)
ATF_TAG   := $(call manifest_ref,atf)
UBOOT_TAG := $(call manifest_ref,u-boot)
BUILDROOT_VERSION ?= $(call manifest_ref,buildroot)
BUILDROOT_DEFCFG  := $(SOLUTION_DIR)/buildroot/configs/aarch64.config
ROOTFS_EXT4       := $(OUT_DIR)/rootfs.ext4

# Buildroot rootfs overlay -- static files under linux/rootfs-overlay/ are
# rsync'd into the per-config staging overlay before Buildroot assembles the
# rootfs (BR2_ROOTFS_OVERLAY=$(ROOTFS_OVERLAY_DIR), passed on Make command
# line — Buildroot's Kconfig does not expand $(VAR) in defconfig strings).
ROOTFS_OVERLAY_DIR := $(BUILD_DIR)/rootfs-overlay

FREERTOS_APPS_DIR   := $(SOLUTION_DIR)/freertos/apps

# Patch overlays are solution-owned and live under bao/<c>/patches/. They are
# applied by scripts/fetch-sources.py straight from the `patches:` field in
# sources.yaml, so there are no per-component patch-dir Make variables here.

# ---------------------------------------------------------------------------
# Per-config overrides (instance map, memory map, sample selection)
# ---------------------------------------------------------------------------

-include $(CONFIG_DIR)/config.mk

# ── Build flavor ──────────────────────────────────────────────────────────────
# Selects the overall build flow. Set to `baremetal` in configs/<CONFIG>/config.mk
# for the Bao + 2x bare-metal guest flow; defaults to the Linux+FreeRTOS flow.
AMP_FLAVOR ?= linux_freertos

# Baremetal-flavor sources (vendored in-tree, NOT fetched) + guest staging dir.
GUEST_DIR   := $(SOLUTION_DIR)/bao-baremetal-guest
ILC_DIR     := $(SOLUTION_DIR)/ilc_baremetal_standalone
IMGS_DIR    := $(BUILD_DIR)/imgs

# Baremetal shmem map (consumed by the vm1/vm2 guest builds). Overridden in
# configs/baremetal/config.mk.
SHMEM_BASE ?= 0xc0000000
SHMEM_SIZE ?= 0x10000000
SHMEM_IS   ?= 0

# Bao config folder name (configs/<BAO_CONFIG>/config.c). Defaults to CONFIG so
# both flavors resolve configs/$(CONFIG)/config.c via Bao's CONFIG_REPO.
BAO_CONFIG ?= $(CONFIG)

# Host C compiler for Bao's native config-gen tool. The baremetal flow forwards
# this to the Bao sub-make (some hosts' PATH gcc lacks a usable sysroot).
HOST_CC    ?= /usr/bin/gcc

# Defaults if config.mk is missing or doesn't set these
INSTANCES        ?= 0 1

SAMPLE_INST_0    ?= ilc_latency
MEM_BASE_INST_0  ?= 0x90000000
MEM_SIZE_INST_0  ?= 0x01000000

SAMPLE_INST_1    ?= ilc_latency
MEM_BASE_INST_1  ?= 0x91000000
MEM_SIZE_INST_1  ?= 0x01000000

IPC_SHMEM_BASE   ?= 0x92000000

# Bao build inputs
# BAO_PLATFORM must match src/platform/<name>/ inside the Bao tree. The
# default `agilex5` is added by
# bao-hypervisor/patches/v2.0.0/0001-Add-agilex5-platform.patch. Both the
# linux_freertos and baremetal flavors use `agilex5`.
BAO_PLATFORM    ?= agilex5
# Platform name for the in-tree bare-metal guest build (bao-baremetal-guest/
# src/platform/<name>/). This is the guest's own runtime platform (UART, memory
# model) and is kept as a separate knob from BAO_PLATFORM in case the Bao
# hypervisor platform ever diverges from the guest platform.
GUEST_PLATFORM  ?= agilex5
# Pass the configs/ parent so Bao's fallback logic finds <CONFIG>/config.c.
BAO_CONFIG_REPO ?= $(SOLUTION_DIR)/configs

# Board DDR capacity in GiB. Forwarded to the Bao platform sub-make, where
# src/platform/agilex5/platform.mk turns it into -DAGX5_MEM_GB=<n> so the
# common agilex5_desc.c builds the right mem_region table. Supported: 1, 2,
# 4, 8. Override per board in configs/<CONFIG>/config.mk (AGX5_MEM_GB := 8)
# or on the command line (make AGX5_MEM_GB=8 bao).
AGX5_MEM_GB     ?= 2

# ATF / U-Boot build inputs
ATF_PLAT        ?= agilex5
UBOOT_DEFCONFIG ?= socfpga_agilex5_defconfig
# U-Boot Kconfig fragment is a Bao-solution config. The two flavors boot
# differently: linux_freertos sources a boot.scr; baremetal embeds the full
# BOOTCOMMAND (fatload bao.bin -> go) and forces the SPL boot order to mmc.
ifeq ($(AMP_FLAVOR),baremetal)
UBOOT_FRAGMENT  ?= $(SOLUTION_DIR)/uboot/configs/uboot.baremetal.cfg.frag
UBOOT_PREP_CMD  := sed -i 's/u-boot,spl-boot-order.*/u-boot,spl-boot-order = \&mmc;/g' $(UBOOT_DIR)/arch/arm/dts/socfpga_agilex5_socdk-u-boot.dtsi 2>/dev/null || true
else
UBOOT_FRAGMENT  ?= $(SOLUTION_DIR)/uboot/configs/uboot.cfg.frag
UBOOT_PREP_CMD  := true
endif

# Toolchains
#   LINUX_CROSS    used for Linux kernel, ATF, U-Boot
#   BM_CROSS       used for Bao (EL2) and FreeRTOS guests (bare-metal, EL1)
LINUX_CROSS    ?= aarch64-none-linux-gnu-
BM_CROSS       ?= aarch64-none-elf-

# ── Local toolchain PATH injection ────────────────────────────────────────────
# `make toolchains` downloads ARM GNU 14.3.rel1 bundles and builds genimage
# into .toolchain/.  We prepend all bin dirs to PATH so component builds and
# scripts find the right tools even when nothing is installed system-wide.
# Non-existent PATH entries are harmless (shell ignores them).
TOOLCHAIN_DIR   := $(ROOT_DIR)/.toolchain
TC_LINUX_VER    := arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-linux-gnu
TC_ELF_VER      := arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-elf
export PATH     := $(TOOLCHAIN_DIR)/hostdeps/bin:$(TOOLCHAIN_DIR)/$(TC_LINUX_VER)/bin:$(TOOLCHAIN_DIR)/$(TC_ELF_VER)/bin:$(PATH)

# Linux build inputs
LINUX_DEFCONFIG ?= defconfig
LINUX_ARCH      ?= arm64

# Linux guest: Kconfig fragment + lloader entry stub + guest DTB.
# bao-amp.config is the single fragment merged on top of the kernel defconfig.
# It carries the rproc/rpmsg/virtio symbols required by the bao-rproc driver.
LLOADER_DIR     := $(SOLUTION_DIR)/linux/lloader
LINUX_CFG_DIR   := $(SOLUTION_DIR)/linux/configs
LINUX_CFG_FRAGS := $(wildcard $(LINUX_CFG_DIR)/bao-amp.config)
LINUX_DTS       := $(CONFIG_DIR)/linux.dts
LINUX_DTB       := $(OUT_DIR)/linux.dtb
LINUX_BIN       := $(OUT_DIR)/linux.bin

# SD image layout template lives alongside the target config
SD_LAYOUT       ?= $(CONFIG_DIR)/sd-layout.mk

# ── FPGA bitstream ─────────────────────────────────────────────────────────────
# FPGA_RBF (optional) — path to the GHRD core.rbf to embed in the SD FAT32
# partition as fpga.rbf.  If not supplied the SD image is built without it
# and a loud warning is printed at the end of the build.  Supply it whenever the
# design needs the FPGA fabric (e.g. the FreeRTOS ILC soft-IP at 0x20000000).
#
#   make CONFIG=linux_freertos sdcard                          # no RBF, warns
#   make CONFIG=linux_freertos FPGA_RBF=/path/core.rbf sdcard  # with RBF
FPGA_RBF ?=

# Cosmetic name written into the boot.scr header (mkimage -n). Not used by any
# boot logic — the boot flow is board-agnostic.
BOOT_LABEL := Agilex5 Bao AMP

BOOT_SCR := $(OUT_DIR)/boot.scr

JOBS ?= $(shell nproc 2>/dev/null || echo 4)

# ---------------------------------------------------------------------------
# Top-level targets
# ---------------------------------------------------------------------------

.PHONY: all help check-config fetch fetch-lock pin reset-sources \
        bao-fetch linux-fetch atf-fetch uboot-fetch buildroot-fetch \
        freertos-fetch freertos-kernel-fetch freertos-socfpga-fetch \
        openamp-fetch libmetal-fetch \
        libmetal-prepare openamp-prepare \
        apply-patches toolchains \
        atf atf-clean uboot uboot-clean linux linux-loader freertos freertos-clean freertos-compile \
        vm1 vm2 guests ilc ilc-clean \
        \
        bao bao-compile rootfs sdcard \
        clean distclean

all: sdcard

help:
	@echo "hps-amp orchestrator"
	@echo
	@echo "Usage:  make CONFIG=<system> <target>"
	@echo "Active: CONFIG=$(CONFIG)"
	@echo
	@echo "Targets:"
	@echo "  toolchains       Download ARM GNU 14.3.rel1 toolchains to .toolchain/"
	@echo "  fetch            Clone every src/<tree> per sources.yaml + apply patches"
	@echo "  fetch-lock       Same, but pin each ref to sources.lock.yaml (CI/ship)"
	@echo "  pin              Re-capture every src/<tree> HEAD into sources.lock.yaml"
	@echo "  <name>-fetch     Clone a single component (bao-fetch, linux-fetch, ...)"
	@echo "  reset-sources    git reset --hard && clean -fdx every src/ tree"
	@echo "  apply-patches    Reset + re-apply patches/* on top of every src/<tree>"
	@echo "  atf              Build ATF bl31 (PLAT=$(ATF_PLAT))"
	@echo "  uboot            Build U-Boot SPL + .itb (depends on atf)"
	@echo "  linux            Fetch + build Linux kernel (merges linux/configs/bao-amp.config)"
	@echo "  linux-loader     Wrap Image + guest dtb via lloader -> linux.bin"
	@echo "  freertos         Build FreeRTOS guest(s). Backend selected by"
	@echo "                   FREERTOS_BUILD_BACKEND (set in configs/<C>/config.mk):"
	@echo "                     freertos-socfpga -> CMake build of selected FreeRTOS app"
	@echo "                                   (freertos/apps first, then freertos/src in-tree samples)"
	@echo "  freertos-clean   Drop the CMake build dir + out/freertos.{bin,elf}"
	@echo "                   [only when FREERTOS_BUILD_BACKEND=freertos-socfpga]"
	@echo "  freertos-compile Recompile FreeRTOS without re-applying patches or cmake reconfigure"
	@echo "                   (requires a prior 'make freertos' to initialise the build dir)"
	@echo "  bao              Build Bao hypervisor with $(CONFIG) (re-applies patches)"
	@echo "  bao-compile      Compile Bao without re-applying patches (patches already applied)"
	@echo "  rootfs           Build Buildroot ext4 rootfs -> rootfs.ext4"
	@echo "  boot-scr         Compile configs/<CONFIG>/boot.cmd -> boot.scr"
	@echo "  sdcard           Build complete SD image (default target)"
	@echo "                     FPGA_RBF=<path>  embed an FPGA bitstream as fpga.rbf (optional)"
	@echo "  clean            Remove $(BUILD_DIR)"
	@echo "  distclean        clean + reset-sources"
	@echo
	@echo "Instance map:"
	@$(foreach i,$(INSTANCES), \
	  echo "  inst $(i): sample=$(SAMPLE_INST_$(i)) mem=$(MEM_BASE_INST_$(i))..+$(MEM_SIZE_INST_$(i))";)
	@echo "  ipc shmem base: $(IPC_SHMEM_BASE)"
	@echo "  bao load addr:  $(BAO_LOAD_ADDR)"
	@echo "  linux load:     $(LINUX_LOAD_ADDR)  (dtb embedded in linux.bin via lloader)"
	@echo
	@echo "Linux kernel source:"
	@echo "  repo:    $(if $(strip $(LINUX_REPO)),$(LINUX_REPO) (config.mk override),from sources.yaml)"
	@echo "  branch:  $(LINUX_BRANCH)"
	@echo "  dir:     $(LINUX_DIR)"
	@echo "  defconfig: $(LINUX_DEFCONFIG)"
	@echo
	@echo "Source manifest:"
	@echo "  manifest: $(SOURCES_MANIFEST)"
	@echo "  lock:     $(SOURCES_LOCK)"
	@echo
	@echo "Linux Kconfig fragments to be merged:"
	@for f in $(LINUX_CFG_FRAGS); do echo "  $$f"; done
	@if [ -z "$(strip $(LINUX_CFG_FRAGS))" ]; then echo "  (none)"; fi

check-config: toolchains
	@if [ ! -d "$(CONFIG_DIR)" ]; then \
	  echo "ERROR: config '$(CONFIG)' not found at $(CONFIG_DIR)"; exit 1; \
	fi

# ---------------------------------------------------------------------------
# Source fetch + patch management (manifest-driven)
# ---------------------------------------------------------------------------
#
# Implementation lives in scripts/fetch-sources.py. The Makefile only knows
# how to call it; per-component URLs/refs/patch-dirs live in sources.yaml.

# Resolve the python interpreter once (override with `make PYTHON=python3.11 …`).
PYTHON ?= python3

# Common args every fetch invocation passes (manifest + lock paths).
# --root is this solution dir: dest: paths in sources.yaml are solution-relative
# (<c>/src for every component checkout, <c>/patches for the Bao overlays).
FETCH_ARGS := --manifest $(SOURCES_MANIFEST) --lock $(SOURCES_LOCK) --root $(SOLUTION_DIR)

# Component selection per flavor. The baremetal flow uses only bao/atf/u-boot
# from the shared manifest (its guests are vendored in-tree); the Linux+FreeRTOS
# flow fetches/patches the full component set.
ifeq ($(AMP_FLAVOR),baremetal)
FETCH_ONLY         := --only bao --only atf --only u-boot
APPLY_PATCHES_ONLY := --only bao
else
FETCH_ONLY         :=
APPLY_PATCHES_ONLY := --only bao --only linux --only atf --only u-boot --only freertos-socfpga
endif

# Clone + patch every component declared in sources.yaml. Idempotent;
# re-running drops local edits in each src/<tree> and reapplies patches.
fetch:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) $(FETCH_ONLY)

# Same flow, but each ref is overridden by sources.lock.yaml. This is the
# shipping default: SHAs only, no branch drift.
fetch-lock:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --use-lock

# Capture every src/<tree>'s current HEAD into sources.lock.yaml. Run after
# a deliberate `make fetch` whose refs you've verified on hardware.
pin:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --no-patches --update-lock

# Reset every src/<tree> to pristine HEAD (drops local edits + untracked
# files). Does not re-apply patches — use `make apply-patches` or `make fetch`
# for that. Implemented via the fetcher so it stays manifest-driven.
reset-sources:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --no-patches --reset

# Per-component fetch wrappers (preserve the old `linux-fetch` / `atf-fetch`
# names so external scripts / habits keep working). Each is a 1-line shim.
bao-fetch:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --only bao --no-patches

freertos-socfpga-fetch:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --only freertos-socfpga --no-patches

freertos-kernel-fetch:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --only freertos-kernel --no-patches

# linux-fetch honours per-CONFIG overrides set in configs/<CONFIG>/config.mk
# (LINUX_REPO / LINUX_BRANCH) via the HPS_AMP_LINUX_URL / HPS_AMP_LINUX_REF
# env vars exported at the top of this Makefile.
linux-fetch:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --only linux --no-patches

atf-fetch:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --only atf --no-patches

uboot-fetch:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --only u-boot --no-patches

openamp-fetch:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --only openamp --no-patches

libmetal-fetch:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --only libmetal --no-patches

buildroot-fetch:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --only buildroot --no-patches

# The freertos-socfpga backend needs both the SoC-FPGA port tree and the
# upstream FreeRTOS kernel it builds against.
freertos-fetch: freertos-socfpga-fetch freertos-kernel-fetch

# Reset + reapply patches for the four trees that have patch dirs today.
# Bao / linux / atf / u-boot / freertos-socfpga are all driven by sources.yaml.
# libmetal + openamp stay deferred (see *-prepare below) so non-rpmsg builds
# don't pay their fetch+patch cost.
apply-patches:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) $(APPLY_PATCHES_ONLY)

# libmetal + openamp prepare hooks (kept identical in semantics: deferred
# fetch+reset+patch, only triggered by samples that actually need them).
libmetal-prepare:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --only libmetal

openamp-prepare:
	$(PYTHON) $(FETCH_SOURCES) $(FETCH_ARGS) --only openamp

# ---------------------------------------------------------------------------
# Component builds
# ---------------------------------------------------------------------------

linux: check-config linux-fetch
	@echo ">>> Building Linux  branch=$(LINUX_BRANCH)  defconfig=$(LINUX_DEFCONFIG)  (src=$(LINUX_DIR))"
	mkdir -p $(BUILD_DIR)/linux
	$(MAKE) -C $(LINUX_DIR) O=$(BUILD_DIR)/linux \
	    ARCH=$(LINUX_ARCH) CROSS_COMPILE=$(LINUX_CROSS) $(LINUX_DEFCONFIG)
ifneq ($(strip $(LINUX_CFG_FRAGS)),)
	@echo ">>> merging Linux Kconfig fragments:"
	@for f in $(LINUX_CFG_FRAGS); do echo "    $$f"; done
	cd $(LINUX_DIR) && ARCH=$(LINUX_ARCH) CROSS_COMPILE=$(LINUX_CROSS) \
	    ./scripts/kconfig/merge_config.sh -O $(BUILD_DIR)/linux -m \
	    $(BUILD_DIR)/linux/.config $(LINUX_CFG_FRAGS)
	$(MAKE) -C $(LINUX_DIR) O=$(BUILD_DIR)/linux \
	    ARCH=$(LINUX_ARCH) CROSS_COMPILE=$(LINUX_CROSS) olddefconfig
endif
	$(MAKE) -C $(LINUX_DIR) O=$(BUILD_DIR)/linux \
	    ARCH=$(LINUX_ARCH) CROSS_COMPILE=$(LINUX_CROSS) -j$(JOBS) Image dtbs
	mkdir -p $(OUT_DIR)
	cp $(BUILD_DIR)/linux/arch/$(LINUX_ARCH)/boot/Image $(OUT_DIR)/Image

# Wrap kernel Image + guest DTB into a single linux.bin via the lloader stub.
# This is what Bao actually starts (it does not perform AArch64 Linux boot-
# protocol register setup itself — the stub sets x0 = phys(FDT) and branches
# to the kernel).
linux-loader: linux
	@[ -f $(LINUX_DTS) ] || { \
	  echo "ERROR: missing $(LINUX_DTS)"; \
	  echo "       Drop in a guest Linux DTS at this path (see"; \
	  echo "       $(CONFIG_DIR)/linux.dts.placeholder for guidance)."; \
	  exit 1; }
	@command -v dtc >/dev/null 2>&1 \
	  || { echo "ERROR: dtc not found (install device-tree-compiler)"; exit 1; }
	mkdir -p $(OUT_DIR)
	@echo ">>> dtc $(LINUX_DTS) -> $(LINUX_DTB)"
	dtc -I dts -O dtb -o $(LINUX_DTB) $(LINUX_DTS)
	@echo ">>> lloader: $(OUT_DIR)/Image + $(LINUX_DTB) -> $(LINUX_BIN)"
	$(MAKE) -C $(LLOADER_DIR) \
	    ARCH=aarch64 \
	    CROSS_COMPILE=$(BM_CROSS) \
	    IMAGE=$(OUT_DIR)/Image \
	    DTB=$(LINUX_DTB) \
	    TARGET=$(OUT_DIR)/linux

# Bao build.
#
# Configs that use VM_IMAGE (embedded image via .incbin) need:
#   1. The guest binary to exist BEFORE bao compiles config.c — Bao's
#      Makefile parses .incbin paths out of the preprocessed config.c
#      and adds them as object-file deps (src/bao/Makefile:370). If the
#      file is missing the dep generator silently emits a broken rule
#      and we get a cryptic "no rule to make target" later.
#   2. The absolute path of the binary forwarded as a -D macro so the
#      VM_IMAGE(XSTR(FRTOS_IMG_PATH)) expansion in configs/<C>/config.c
#      stringifies to a valid .incbin path at assembly time.
#
# We trigger both by depending on `freertos` when the active config sets
# FREERTOS_BUILD_BACKEND=freertos-socfpga (in configs/<CONFIG>/config.mk,
# pulled in by check-config).
BAO_EXTRA_DEPS :=
BAO_CPPFLAGS   :=
# Extra flags forwarded to the Bao sub-make (flavor-specific).
BAO_MAKE_EXTRA :=
# AGX5_MEM_GB must reach BOTH the target compile (agilex5_desc.c / config.c) AND
# the HOST-side platform_defs_gen tool, because that tool sizes PLAT_BITMAP_POOL_SIZE
# from platform.regions (one page-pool bitmap per region). The Bao Makefile only
# appends platform-cppflags to HOST_CPPFLAGS via a non-override '+=', which a
# command-line HOST_CPPFLAGS=... (set below) silently wins over — so the generator
# would otherwise see the default AGX5_MEM_GB=2 and under-size the bitmap pool for
# an 8 GB (two-region) target, faulting pre-console in mem_init(). Carrying it in
# BAO_CPPFLAGS (passed as both CPPFLAGS and HOST_CPPFLAGS) fixes both paths.
BAO_CPPFLAGS   += -DAGX5_MEM_GB=$(AGX5_MEM_GB)
ifeq ($(AMP_FLAVOR),baremetal)
  # Baremetal: Bao embeds the two guest .bin via .incbin (BAO_DEMOS_WRKDIR_IMGS);
  # the guests must be built and staged into IMGS_DIR before Bao compiles.
  BAO_EXTRA_DEPS += guests
  BAO_CPPFLAGS   += -DBAO_DEMOS_WRKDIR_IMGS=$(IMGS_DIR)
  BAO_MAKE_EXTRA += HOST_CC=$(HOST_CC)
else ifeq ($(FREERTOS_BUILD_BACKEND),freertos-socfpga)
  BAO_EXTRA_DEPS += freertos
  BAO_CPPFLAGS   += -DFRTOS_IMG_PATH=$(OUT_DIR)/freertos.bin
endif

bao: check-config apply-patches $(BAO_EXTRA_DEPS)
	@echo ">>> Building Bao ($(BAO_TAG)) platform=$(BAO_PLATFORM) config=$(CONFIG) mem=$(AGX5_MEM_GB)GB"
	mkdir -p $(BUILD_DIR)/bao
	$(MAKE) -C $(BAO_DIR) \
	    PLATFORM=$(BAO_PLATFORM) \
	    CONFIG_REPO=$(BAO_CONFIG_REPO) \
	    CONFIG=$(BAO_CONFIG) \
	    AGX5_MEM_GB=$(AGX5_MEM_GB) \
	    CROSS_COMPILE=$(BM_CROSS) \
	    $(BAO_MAKE_EXTRA) \
	    CPPFLAGS="$(BAO_CPPFLAGS)" \
	    HOST_CPPFLAGS="$(BAO_CPPFLAGS)" \
	    -j$(JOBS)
	mkdir -p $(OUT_DIR)
	@if [ -f $(BAO_DIR)/bin/$(BAO_PLATFORM)/$(BAO_CONFIG)/bao.bin ]; then \
	  cp $(BAO_DIR)/bin/$(BAO_PLATFORM)/$(BAO_CONFIG)/bao.bin $(OUT_DIR)/bao.bin; \
	fi

# Like `bao` but skips apply-patches — use when patches are already applied
# and you only want to recompile (e.g. after editing config.c or a patch source).
bao-compile: check-config $(BAO_EXTRA_DEPS)
	@echo ">>> Building Bao ($(BAO_TAG)) platform=$(BAO_PLATFORM) config=$(CONFIG) mem=$(AGX5_MEM_GB)GB [no patch]"
	mkdir -p $(BUILD_DIR)/bao
	$(MAKE) -C $(BAO_DIR) \
	    PLATFORM=$(BAO_PLATFORM) \
	    CONFIG_REPO=$(BAO_CONFIG_REPO) \
	    CONFIG=$(BAO_CONFIG) \
	    AGX5_MEM_GB=$(AGX5_MEM_GB) \
	    CROSS_COMPILE=$(BM_CROSS) \
	    $(BAO_MAKE_EXTRA) \
	    CPPFLAGS="$(BAO_CPPFLAGS)" \
	    HOST_CPPFLAGS="$(BAO_CPPFLAGS)" \
	    -j$(JOBS)
	mkdir -p $(OUT_DIR)
	@if [ -f $(BAO_DIR)/bin/$(BAO_PLATFORM)/$(BAO_CONFIG)/bao.bin ]; then \
	  cp $(BAO_DIR)/bin/$(BAO_PLATFORM)/$(BAO_CONFIG)/bao.bin $(OUT_DIR)/bao.bin; \
	fi

# ---------------------------------------------------------------------------
# Bare-metal guests + ILC standalone (baremetal flavor, vendored in-tree)
# ---------------------------------------------------------------------------
# VM1: UART printer (src-vm1/). VM2: ILC latency worker (src-vm2/). Both build
# against the shared runtime in bao-baremetal-guest/src/ and are staged into
# IMGS_DIR, where the baremetal config.c .incbin's them into bao.bin.

vm1: check-config
	@echo ">>> Building VM1 (baremetal-vm1.bin)"
	mkdir -p $(IMGS_DIR)
	$(MAKE) -C $(GUEST_DIR) PLATFORM=$(GUEST_PLATFORM) CROSS_COMPILE=$(BM_CROSS) \
	    SINGLE_CORE=y BUILD_SUFFIX=vm1 NAME=baremetal-vm1 \
	    APP_SRC_DIR=$(GUEST_DIR)/src-vm1 \
	    SHMEM_BASE=$(SHMEM_BASE) SHMEM_SIZE=$(SHMEM_SIZE) SHMEM_IS=$(SHMEM_IS)
	@[ -f $(GUEST_DIR)/build/$(GUEST_PLATFORM)-vm1/baremetal-vm1.bin ] \
	  || { echo "ERROR: VM1 build produced no baremetal-vm1.bin"; exit 1; }
	cp $(GUEST_DIR)/build/$(GUEST_PLATFORM)-vm1/baremetal-vm1.bin $(IMGS_DIR)/baremetal-vm1.bin
	mkdir -p $(OUT_DIR)
	cp $(IMGS_DIR)/baremetal-vm1.bin $(OUT_DIR)/baremetal-vm1.bin
	@echo ">>> $(IMGS_DIR)/baremetal-vm1.bin  ($$(stat -c%s $(IMGS_DIR)/baremetal-vm1.bin) bytes)"

vm2: check-config
	@echo ">>> Building VM2 (baremetal-vm2.bin)"
	mkdir -p $(IMGS_DIR)
	$(MAKE) -C $(GUEST_DIR) PLATFORM=$(GUEST_PLATFORM) CROSS_COMPILE=$(BM_CROSS) \
	    SINGLE_CORE=y BUILD_SUFFIX=vm2 NAME=baremetal-vm2 \
	    APP_SRC_DIR=$(GUEST_DIR)/src-vm2 \
	    SHMEM_BASE=$(SHMEM_BASE) SHMEM_SIZE=$(SHMEM_SIZE) SHMEM_IS=$(SHMEM_IS)
	@[ -f $(GUEST_DIR)/build/$(GUEST_PLATFORM)-vm2/baremetal-vm2.bin ] \
	  || { echo "ERROR: VM2 build produced no baremetal-vm2.bin"; exit 1; }
	cp $(GUEST_DIR)/build/$(GUEST_PLATFORM)-vm2/baremetal-vm2.bin $(IMGS_DIR)/baremetal-vm2.bin
	mkdir -p $(OUT_DIR)
	cp $(IMGS_DIR)/baremetal-vm2.bin $(OUT_DIR)/baremetal-vm2.bin
	@echo ">>> $(IMGS_DIR)/baremetal-vm2.bin  ($$(stat -c%s $(IMGS_DIR)/baremetal-vm2.bin) bytes)"

guests: vm1 vm2

# Standalone ILC bare-metal demo — an extra SD binary (not auto-booted).
ilc: check-config
	@echo ">>> Building ILC standalone (ilc_demo.bin)"
	$(MAKE) -C $(ILC_DIR) CROSS=$(BM_CROSS)
	@[ -f $(ILC_DIR)/ilc_demo.bin ] || { echo "ERROR: missing $(ILC_DIR)/ilc_demo.bin"; exit 1; }
	mkdir -p $(OUT_DIR)
	cp $(ILC_DIR)/ilc_demo.bin $(OUT_DIR)/ilc_demo.bin
	@echo ">>> $(OUT_DIR)/ilc_demo.bin  ($$(stat -c%s $(OUT_DIR)/ilc_demo.bin) bytes)"

ilc-clean:
	$(MAKE) -C $(ILC_DIR) CROSS=$(BM_CROSS) clean 2>/dev/null || true
	rm -f $(OUT_DIR)/ilc_demo.bin

# FreeRTOS build backend selection.
#   freertos-socfpga -> CMake build of the selected app against freertos/src
#                       with -DBAO_GUEST=ON; produces a single raw freertos.bin
#                       linked at MEM_BASE_INST_0. Both shipped configs set it.
FREERTOS_BUILD_BACKEND ?=

# ----- Backend: freertos-socfpga --------------------------------------------
ifeq ($(FREERTOS_BUILD_BACKEND),freertos-socfpga)

# Sample dir resolution. First-party apps live under freertos/apps/.
# Fall back to the freertos-socfpga in-tree samples for older baselines.
FRTOS_SAMPLE_DIR := $(firstword \
  $(wildcard $(FREERTOS_APPS_DIR)/$(SAMPLE_INST_0)) \
  $(wildcard $(FREERTOS_SOCFPGA_DIR)/FreeRTOS/Demo/SOCFPGA/apps/samples/$(SAMPLE_INST_0)) \
  $(wildcard $(FREERTOS_SOCFPGA_DIR)/FreeRTOS/Demo/SOCFPGA/apps/$(SAMPLE_INST_0)))

# CMake produces these names; the prefix `freertos_` comes from the per-sample
# `project(freertos_<name> ...)` declaration in the sample's CMakeLists.txt.
FRTOS_ELF := $(BUILD_DIR)/freertos/freertos_$(SAMPLE_INST_0).elf
FRTOS_BIN := $(BUILD_DIR)/freertos/freertos_$(SAMPLE_INST_0).bin

.PHONY: freertos freertos-clean freertos-compile

# freertos-fetch is declared globally above and pulls in both the
# freertos-socfpga port tree and the upstream FreeRTOS-Kernel via the manifest.

# Per-sample CMake-time deps and extra -D flags.
# rpmsg_console needs OpenAMP + libmetal vendored under <c>/src. Other samples
# (e.g. main_blinky) leave both lists empty and build without them.
FRTOS_SAMPLE_DEPS    :=
FRTOS_SAMPLE_CMAKE   :=
ifeq ($(SAMPLE_INST_0),rpmsg_console)
  FRTOS_SAMPLE_DEPS  += libmetal-prepare openamp-prepare
  FRTOS_SAMPLE_CMAKE += -DOPENAMP_SRC_DIR=$(OPENAMP_DIR) \
                       -DLIBMETAL_SRC_DIR=$(LIBMETAL_DIR)
endif

freertos: check-config freertos-fetch $(FRTOS_SAMPLE_DEPS) apply-patches
	@command -v cmake >/dev/null 2>&1 \
	  || { echo "ERROR: cmake not found (install cmake >= 3.15)"; exit 1; }
	@[ -n "$(FRTOS_SAMPLE_DIR)" ] \
	  || { echo "ERROR: SAMPLE_INST_0='$(SAMPLE_INST_0)' not found under $(FREERTOS_APPS_DIR), $(FREERTOS_SOCFPGA_DIR)/FreeRTOS/Demo/SOCFPGA/apps/{samples/,}"; exit 1; }
	@echo ">>> Building freertos-socfpga FreeRTOS-on-Bao"
	@echo "    sample = $(SAMPLE_INST_0)  ($(FRTOS_SAMPLE_DIR))"
	@echo "    load   = $(MEM_BASE_INST_0)  size = $(MEM_SIZE_INST_0)"
	rm -rf $(BUILD_DIR)/freertos
	mkdir -p $(BUILD_DIR)/freertos $(OUT_DIR)
	cd $(BUILD_DIR)/freertos && cmake \
	    -DBAO_GUEST=ON \
	    -DBAO_LOAD_ADDR=$(MEM_BASE_INST_0) \
	    -DBAO_MEM_SIZE=$(MEM_SIZE_INST_0) \
	    -DFREERTOS_SOCFPGA_DIR=$(FREERTOS_SOCFPGA_DIR) \
	    -DSOC=AGILEX5 -DCORE=A55 -DSMP=OFF \
	    -DCMAKE_BUILD_TYPE=Release \
	    $(FRTOS_SAMPLE_CMAKE) \
	    $(FRTOS_SAMPLE_DIR)
	$(MAKE) -C $(BUILD_DIR)/freertos -j$(JOBS)
	@[ -f $(FRTOS_BIN) ] || { echo "ERROR: missing $(FRTOS_BIN) — check the sample project() name"; exit 1; }
	cp $(FRTOS_ELF) $(OUT_DIR)/freertos.elf
	cp $(FRTOS_BIN) $(OUT_DIR)/freertos.bin
	@echo ">>> $(OUT_DIR)/freertos.bin  ($$(stat -c%s $(OUT_DIR)/freertos.bin) bytes)"

freertos-clean:
	rm -rf $(BUILD_DIR)/freertos $(OUT_DIR)/freertos.bin $(OUT_DIR)/freertos.elf

# Like `freertos` but skips apply-patches and cmake reconfigure — use when
# patches are already applied and you only changed C source files.
freertos-compile: check-config
	@command -v cmake >/dev/null 2>&1 \
	  || { echo "ERROR: cmake not found (install cmake >= 3.15)"; exit 1; }
	@[ -f "$(BUILD_DIR)/freertos/Makefile" ] \
	  || { echo "ERROR: no cmake build dir found — run 'make freertos' first"; exit 1; }
	@echo ">>> Recompiling FreeRTOS (no patch/cmake reconfigure)"
	$(MAKE) -C $(BUILD_DIR)/freertos -j$(JOBS)
	@[ -f $(FRTOS_BIN) ] || { echo "ERROR: missing $(FRTOS_BIN) — check the sample project() name"; exit 1; }
	mkdir -p $(OUT_DIR)
	cp $(FRTOS_ELF) $(OUT_DIR)/freertos.elf
	cp $(FRTOS_BIN) $(OUT_DIR)/freertos.bin
	@echo ">>> $(OUT_DIR)/freertos.bin  ($$(stat -c%s $(OUT_DIR)/freertos.bin) bytes)"

# ----- Backend: unset -------------------------------------------------------
# No fallback. Fail fast with a useful pointer instead of silently doing nothing.
else
.PHONY: freertos
freertos:
	@echo "ERROR: FREERTOS_BUILD_BACKEND is unset for CONFIG=$(CONFIG)." >&2
	@echo "       Set it to 'freertos-socfpga' in configs/$(CONFIG)/config.mk." >&2
	@exit 1
endif

# ---------------------------------------------------------------------------
# Toolchains
# ---------------------------------------------------------------------------

toolchains:
	@$(SCRIPTS_DIR)/toolchains.sh

# ---------------------------------------------------------------------------
# Buildroot / rootfs
# ---------------------------------------------------------------------------

# buildroot-fetch is declared globally above (manifest entry `buildroot`).

# Build the ext4 rootfs (userspace only — kernel built separately by make linux).
# Output: $(ROOTFS_EXT4)  (copy of buildroot/output/images/rootfs.ext4)
#
# To customise the package set:
#   make -C buildroot/src menuconfig
#   make -C buildroot/src savedefconfig BR2_DEFCONFIG=$(PWD)/buildroot/configs/aarch64.config
# Static rootfs overlay: files committed under linux/rootfs-overlay/ are copied
# into the per-config staging overlay before Buildroot assembles the rootfs.
# Add a file with `git add linux/rootfs-overlay/<path>`.
ROOTFS_OVERLAY_SRC := $(SOLUTION_DIR)/linux/rootfs-overlay

.PHONY: rootfs-overlay-static
rootfs-overlay-static:
	@if [ -d "$(ROOTFS_OVERLAY_SRC)" ]; then \
	  echo ">>> Staging static rootfs overlay  $(ROOTFS_OVERLAY_SRC) -> $(ROOTFS_OVERLAY_DIR)"; \
	  mkdir -p $(ROOTFS_OVERLAY_DIR); \
	  cp -a $(ROOTFS_OVERLAY_SRC)/. $(ROOTFS_OVERLAY_DIR)/; \
	  find $(ROOTFS_OVERLAY_DIR) -name '*.sh' -exec chmod 0755 {} \; ; \
	fi

rootfs: check-config buildroot-fetch rootfs-overlay-static
	@echo ">>> Building Buildroot rootfs  version=$(BUILDROOT_VERSION)  defconfig=$(BUILDROOT_DEFCFG)"
	@echo ">>> Buildroot rootfs overlay   $(ROOTFS_OVERLAY_DIR)"
	@[ -f "$(BUILDROOT_DEFCFG)" ] \
	  || { echo "ERROR: missing $(BUILDROOT_DEFCFG)"; exit 1; }
	$(MAKE) -C $(BUILDROOT_DIR) CONFIG=support/kconfig \
	    defconfig BR2_DEFCONFIG=$(BUILDROOT_DEFCFG)
	$(MAKE) -C $(BUILDROOT_DIR) CONFIG=support/kconfig -j$(JOBS) host-patchelf 2>/dev/null || true
	@PATCHELF="$(BUILDROOT_DIR)/output/host/bin/patchelf"; \
	if [ -f "$$PATCHELF" ] && ! "$$PATCHELF" --version >/dev/null 2>&1; then \
	  echo ">>> patchelf can't run (libstdc++ mismatch) — rebuilding with compatible g++"; \
	  SRC_CC=$$(ls $(BUILDROOT_DIR)/output/build/host-patchelf-*/src/patchelf.cc 2>/dev/null | head -1); \
	  VER=$$(basename $$(dirname $$(dirname $$SRC_CC)) | sed 's/host-patchelf-//'); \
	  GPP=$$(for v in g++-9 g++-10 g++-11 g++-12 g++-13 g++; do \
	           BIN=$$(command -v $$v 2>/dev/null) && \
	           $$BIN -std=c++17 -O2 -DPACKAGE_STRING="\"patchelf $$VER\"" \
	             -o "$$PATCHELF" "$$SRC_CC" >/dev/null 2>&1 && \
	           "$$PATCHELF" --version >/dev/null 2>&1 && echo $$v && break; \
	         done); \
	  if [ -n "$$GPP" ]; then \
	    echo "    OK: rebuilt patchelf $$VER with $$GPP"; \
	  else \
	    echo "ERROR: no compatible g++ found — run: sudo apt-get install -y patchelf"; exit 1; \
	  fi; \
	fi
	$(MAKE) -C $(BUILDROOT_DIR) CONFIG=support/kconfig -j$(JOBS) \
	    BR2_ROOTFS_OVERLAY='$(ROOTFS_OVERLAY_DIR)'
	mkdir -p $(OUT_DIR)
	@[ -f "$(BUILDROOT_DIR)/output/images/rootfs.ext4" ] \
	  || { echo "ERROR: Buildroot did not produce rootfs.ext4"; exit 1; }
	cp $(BUILDROOT_DIR)/output/images/rootfs.ext4 $(ROOTFS_EXT4)
	@echo ">>> rootfs: $(ROOTFS_EXT4)  ($$(du -sh $(ROOTFS_EXT4) | cut -f1))"

# ---------------------------------------------------------------------------
# ATF (bl31 only)
# ---------------------------------------------------------------------------

ATF_BL31 := $(ATF_DIR)/build/$(ATF_PLAT)/release/bl31.bin

atf: check-config atf-fetch apply-patches
	@if [ -f "$(OUT_DIR)/bl31.bin" ]; then \
	  echo ">>> ATF already built: $(OUT_DIR)/bl31.bin  (use 'make atf-clean' to force rebuild)"; \
	else \
	  echo ">>> Building ATF ($(ATF_TAG)) PLAT=$(ATF_PLAT) -> bl31"; \
	  $(MAKE) -C $(ATF_DIR) \
	    PLAT=$(ATF_PLAT) \
	    CROSS_COMPILE=$(LINUX_CROSS) \
	    -j$(JOBS) bl31; \
	  [ -f $(ATF_BL31) ] || { echo "ERROR: missing $(ATF_BL31)"; exit 1; }; \
	  mkdir -p $(OUT_DIR); \
	  cp $(ATF_BL31) $(OUT_DIR)/bl31.bin; \
	fi

# ---------------------------------------------------------------------------
# U-Boot (SPL + .itb)
# ---------------------------------------------------------------------------

uboot: check-config uboot-fetch apply-patches atf
	@if [ -f "$(OUT_DIR)/u-boot.itb" ]; then \
	  echo ">>> U-Boot already built: $(OUT_DIR)/u-boot.itb  (use 'make uboot-clean' to force rebuild)"; \
	else \
	  echo ">>> Building U-Boot ($(UBOOT_TAG)) defconfig=$(UBOOT_DEFCONFIG)"; \
	  [ -f $(UBOOT_FRAGMENT) ] || { echo "ERROR: missing $(UBOOT_FRAGMENT)"; exit 1; }; \
	  [ -f $(OUT_DIR)/bl31.bin ] || { echo "ERROR: missing $(OUT_DIR)/bl31.bin (build atf first)"; exit 1; }; \
	  ln -sf $(abspath $(OUT_DIR)/bl31.bin) $(UBOOT_DIR)/bl31.bin; \
	  $(UBOOT_PREP_CMD); \
	  $(MAKE) -C $(UBOOT_DIR) ARCH=arm CROSS_COMPILE=$(LINUX_CROSS) $(UBOOT_DEFCONFIG) || exit 1; \
	  cd $(UBOOT_DIR) && ./scripts/kconfig/merge_config.sh -O . -m .config $(UBOOT_FRAGMENT) || exit 1; \
	  $(MAKE) -C $(UBOOT_DIR) ARCH=arm CROSS_COMPILE=$(LINUX_CROSS) -j$(JOBS) || exit 1; \
	  for f in u-boot.itb u-boot spl/u-boot-spl-dtb.hex spl/u-boot-spl-dtb.bin \
	           spl/u-boot-spl spl/u-boot-spl.dtb spl/u-boot-spl.map; do \
	    [ -f $(UBOOT_DIR)/$$f ] || { echo "ERROR: missing $(UBOOT_DIR)/$$f"; exit 1; }; \
	  done; \
	  mkdir -p $(OUT_DIR); \
	  cp $(UBOOT_DIR)/u-boot.itb              $(OUT_DIR)/u-boot.itb; \
	  cp $(UBOOT_DIR)/u-boot                  $(OUT_DIR)/u-boot; \
	  cp $(UBOOT_DIR)/spl/u-boot-spl-dtb.hex  $(OUT_DIR)/u-boot-spl-dtb.hex; \
	  cp $(UBOOT_DIR)/spl/u-boot-spl-dtb.bin  $(OUT_DIR)/u-boot-spl-dtb.bin; \
	  cp $(UBOOT_DIR)/spl/u-boot-spl          $(OUT_DIR)/u-boot-spl; \
	  cp $(UBOOT_DIR)/spl/u-boot-spl.dtb      $(OUT_DIR)/u-boot-spl.dtb; \
	  cp $(UBOOT_DIR)/spl/u-boot-spl.map      $(OUT_DIR)/u-boot-spl.map; \
	fi

# ---------------------------------------------------------------------------
# SD card image
# ---------------------------------------------------------------------------

SDIMAGE_IMG := $(OUT_DIR)/sdimage.img

# ── boot.scr compilation ──────────────────────────────────────────────────────
# Compiles configs/<CONFIG>/boot.cmd -> OUT_DIR/boot.scr via mkimage.
# The source boot.cmd loads linux.bin and bao.bin directly (fatload + go),
# no FIT/bootm involved.  Rebuild when the source script changes.
BOOT_CMD_SRC := $(CONFIG_DIR)/boot.cmd

.PHONY: boot-scr
boot-scr: $(BOOT_SCR)

$(BOOT_SCR): $(BOOT_CMD_SRC) | $(OUT_DIR)
	@command -v mkimage >/dev/null 2>&1 \
	  || { echo "ERROR: mkimage not found (install u-boot-tools)"; exit 1; }
	@echo ">>> Compiling boot.scr  ($(BOOT_LABEL))"
	@mkdir -p $(OUT_DIR)
	mkimage -A arm64 -O linux -T script -C none \
	    -n "$(BOOT_LABEL) Boot" \
	    -d $< $@
	@echo ">>> boot.scr: $@"

$(OUT_DIR):
	@mkdir -p $@

# SD image dependencies per flavor: baremetal = boot files only (bao embeds the
# guests, ILC is an extra binary); linux_freertos = full stack + rootfs + boot.scr.
# Both flavors source boot.scr (compiled from configs/<CONFIG>/boot.cmd).
ifeq ($(AMP_FLAVOR),baremetal)
SDCARD_DEPS := uboot bao ilc boot-scr
else
SDCARD_DEPS := uboot bao linux-loader freertos rootfs boot-scr
endif

sdcard: check-config $(SDCARD_DEPS)
	@[ -f $(SD_LAYOUT) ] || { echo "ERROR: missing $(SD_LAYOUT)"; exit 1; }
	@echo ">>> Building SD image"
	CONFIG=$(CONFIG) \
	OUT_DIR=$(OUT_DIR) \
	OUT_IMG=$(SDIMAGE_IMG) \
	LAYOUT_FILE=$(SD_LAYOUT) \
	FPGA_RBF=$(FPGA_RBF) \
	ROOTFS_EXT4=$(ROOTFS_EXT4) \
	  $(SCRIPTS_DIR)/mksdcard.sh
	@# FPGA bitstream is optional, but its absence is easy to miss and silently
	@# breaks any FPGA-dependent guest (e.g. FreeRTOS ILC at 0x20000000 aborts
	@# when the HPS-FPGA bridge is left unconfigured). Make the warning the very
	@# last, loud thing printed so it cannot be scrolled past unnoticed.
	@if [ -z "$(FPGA_RBF)" ]; then \
	  echo ""; \
	  echo "  ############################################################################"; \
	  echo "  ##                                                                        ##"; \
	  echo "  ##   WARNING: SD image built WITHOUT an FPGA bitstream (fpga.rbf)         ##"; \
	  echo "  ##                                                                        ##"; \
	  echo "  ##   FPGA_RBF was not set, so the FAT partition has no fpga.rbf. At boot  ##"; \
	  echo "  ##   'fpga load' + 'bridge enable' will FAIL and the HPS-FPGA bridge      ##"; \
	  echo "  ##   stays down.                                                          ##"; \
	  echo "  ##                                                                        ##"; \
	  echo "  ##   Rebuild with the bitstream if you need the FPGA:                     ##"; \
	  echo "  ##     make CONFIG=$(CONFIG) FPGA_RBF=<path/to/core.rbf> sdcard            ##"; \
	  echo "  ##                                                                        ##"; \
	  echo "  ############################################################################"; \
	  echo ""; \
	else \
	  echo ">>> FPGA bitstream included: $(FPGA_RBF)"; \
	fi


# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------

atf-clean:
	rm -f $(OUT_DIR)/bl31.bin
	$(MAKE) -C $(ATF_DIR) PLAT=$(ATF_PLAT) clean 2>/dev/null || true

uboot-clean:
	rm -f $(OUT_DIR)/u-boot.itb $(OUT_DIR)/u-boot-spl-dtb.hex \
	      $(OUT_DIR)/u-boot-spl-dtb.bin $(OUT_DIR)/u-boot-spl
	$(MAKE) -C $(UBOOT_DIR) ARCH=arm CROSS_COMPILE=$(LINUX_CROSS) mrproper 2>/dev/null || true

clean:
	rm -rf $(BUILD_DIR)
	@if [ -d $(GUEST_DIR) ]; then \
	  $(MAKE) -C $(GUEST_DIR) PLATFORM=$(GUEST_PLATFORM) BUILD_SUFFIX=vm1 NAME=baremetal-vm1 clean 2>/dev/null || true; \
	  $(MAKE) -C $(GUEST_DIR) PLATFORM=$(GUEST_PLATFORM) BUILD_SUFFIX=vm2 NAME=baremetal-vm2 clean 2>/dev/null || true; \
	fi
	@if [ -d $(ILC_DIR) ]; then \
	  $(MAKE) -C $(ILC_DIR) CROSS=$(BM_CROSS) clean 2>/dev/null || true; \
	fi

distclean: clean reset-sources
