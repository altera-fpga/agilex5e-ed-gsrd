/**
 * Bao configuration — 2× Bare-Metal VMs + Shmem + IPC
 *
 * VM1: UART printer / IPC receiver
 *   - Owns UART0 (0x10c02000); the only VM that prints to the console
 *   - Receives SGI 2 via Bao IPC when VM2 notifies → drains the shmem log
 *     ring and prints, and measures the cross-core VM2 → VM1 IPI latency
 *
 * VM2: ILC latency worker
 *   - Interval timer → F2H IRQ → GICv3 SPI 18 → intid 50
 *   - Owns the LWH2F MMIO (Interval Timer + ILC), GPIO0 LED, Reset Manager
 *   - Measures latency, writes log lines + send timestamp to shmem
 *   - Calls Bao IPC hypercall (HVC) → Bao delivers SGI 2 to VM1
 *
 * Physical memory layout (DRAM 0x80000000-0xFFFFFFFF = 2 GiB, ATF BL31 owns 0x80000000-0x801FFFFF).
 * The agilex5 platform page pool is [0x82000000, 0x100000000). VM RAM is
 * place_phys=false so Bao allocates color-matched pages from the pool (real
 * cache coloring — see below); only the fixed regions are pinned:
 *   0x90200000  Bao        6 MB    hypervisor image + embedded guests + heap
 *                                  (self-relocated into its hyp color slice at boot)
 *   (dynamic)   VM1 RAM    64 MB   place_phys=false, IPA=0x82000000, Bao-allocated colored PA
 *   (dynamic)   VM2 RAM    64 MB   place_phys=false, IPA=0x82000000, Bao-allocated colored PA
 *   0xD0000000  shmem      256 MB  place_phys=true, mapped into guests at IPA 0xc0000000
 *   0x20000000  LWH2F MMIO — Interval Timer + ILC (VM2 only, device region)
 *   0x10c02000  UART0 (VM1 only)
 *
 * Guest IPA layout (same for both VMs):
 *   0x82000000 - 0x85FFFFFF   RAM      (64 MB, stage-2 mapped to each VM's colored PA)
 *   0xc0000000 - 0xCFFFFFFF   shmem    (256 MB, both VMs see it at this IPA)
 *
 * Cache coloring (DSU L3 = 2MB, 16-way, COLOR_NUM=16, 128KB/color)
 *     VM1:   colors = 0x00FF  (colors 0-7  = 1 MB dedicated L3)
 *     VM2:   colors = 0xFF00  (colors 8-15 = 1 MB, shared with Hyp)
 *     Hyp:   colors = 0xFF00  (shares VM2's slice)
 *     Shmem: colors = 0       (NC — shared region, not cache-colored)
 *
 * To disable coloring: remove Hyp/VM1/VM2 .colors field.
 *
 * Build (from software/amp_bao/):
 *   make CONFIG=baremetal bao
 *   # Builds guests → stages build/baremetal/imgs/ → embeds into bao.bin
 *   # (this config.c is pulled in via CONFIG_REPO; edit it here, not via a patch).
 *
 * Manual guest builds (cwd = bao-baremetal-guest/):
 *   make PLATFORM=agilex5 CROSS_COMPILE=aarch64-none-elf- SINGLE_CORE=y \
 *        BUILD_SUFFIX=vm1 NAME=baremetal-vm1 APP_SRC_DIR=$(pwd)/src-vm1 \
 *        SHMEM_BASE=0xc0000000 SHMEM_SIZE=0x10000000 SHMEM_IS=0
 *   make PLATFORM=agilex5 CROSS_COMPILE=aarch64-none-elf- SINGLE_CORE=y \
 *        BUILD_SUFFIX=vm2 NAME=baremetal-vm2 APP_SRC_DIR=$(pwd)/src-vm2 \
 *        SHMEM_BASE=0xc0000000 SHMEM_SIZE=0x10000000 SHMEM_IS=0
 *   cp build/agilex5-vm1/baremetal-vm1.bin $IMGS/baremetal-vm1.bin
 *   cp build/agilex5-vm2/baremetal-vm2.bin $IMGS/baremetal-vm2.bin
 *
 * Manual Bao build (cwd = bao-hypervisor/src/, $IMGS = build/baremetal/imgs):
 *   make PLATFORM=agilex5 CONFIG=baremetal CONFIG_REPO=<amp_bao>/configs \
 *        CROSS_COMPILE=aarch64-none-elf- AGX5_MEM_GB=2 \
 *        CPPFLAGS="-DBAO_DEMOS_WRKDIR_IMGS=$IMGS -DAGX5_MEM_GB=2" \
 *        HOST_CPPFLAGS="-DBAO_DEMOS_WRKDIR_IMGS=$IMGS -DAGX5_MEM_GB=2"
 *
 * Deploy (U-Boot; load addr = BAO_LOAD_ADDR in config.mk):
 *   fatload mmc 0:1 0x90200000 bao.bin
 *   bridge enable; wdt dev watchdog@10d00200; wdt stop; dcache off; go 0x90200000
 */

#include <config.h>

/* Path tokens must stay glued; clang-format would insert spaces around / and -. */
/* clang-format off */
VM_IMAGE(vm1_image, XSTR(BAO_DEMOS_WRKDIR_IMGS/baremetal-vm1.bin))
VM_IMAGE(vm2_image, XSTR(BAO_DEMOS_WRKDIR_IMGS/baremetal-vm2.bin))
/* clang-format on */

struct config config = {
    CONFIG_HEADER

    /* Hypervisor shares VM2's color slice (colors 8-15). Bao self-relocates its
     * image + runtime memory into these colors at boot; its EL2 IRQ-injection is
     * part of VM2's measured ILC path, so co-locating keeps that hot path warm
     * in one partition (Bao's few-KB footprint is negligible vs VM2's 1 MB).
     * Requires patches 0008/0009. */
    .hyp = { .colors = 0xFF00 },

    /**
     * 256 MB shared memory for ILC data passing (VM2 → VM1).
     * place_phys = true: pinned PA; colors = 0: NC (not cache-colored).
     */
    .shmemlist_size = 1,
    .shmemlist = (struct shmem[]) {
        [0] = {
            .size       = 0x10000000,   /* 256 MB */
            .colors     = 0,            /* NC — not in cache coloring */
            .place_phys = true,
            /* PA must be inside real DRAM [0x80000000, 0xF0000000) on this 1792 MiB board.
             * 0xF0000000 is outside physical DRAM (platform pool still advertises to 4G) and hangs.
             * 0xD0000000: in real DRAM, above low pool VM RAM, clear of top-of-DRAM carveouts. */
            .phys       = 0xD0000000,
        }
    },

    .vmlist_size = 2,
    .vmlist = (struct vm_config[]) {

        /* ── VM1: UART printer / IPC receiver ────────────── */
        {
            .image = {
                .base_addr = 0x82000000,
                .load_addr = VM_IMAGE_OFFSET(vm1_image),
                .size      = VM_IMAGE_SIZE(vm1_image),
            },

            .entry        = 0x82000000,
            //.cpu_affinity = 0x4,        /* bit 2 = cpuid 2 = A76 core 0 */
            .cpu_affinity = 0x1,        /* bit 0 = cpuid 0 = A55 core 0 */
            .colors       = 0x00FF,     /* COLORING ON — colors 0-7 = 1 MB DSU L3 */

            .platform = {
                .cpu_num = 1,
                .mmu     = false,

                .region_num = 1,
                .regions = (struct vm_mem_region[]) {
                    {
                        /*
                         * VM1 RAM — 64 MB (matches guest PLAT_MEM_SIZE).
                         * place_phys=false: Bao allocates color-matched pages
                         * (.colors=0x00FF) from the pool and recolors the
                         * embedded guest image into them. Guest sees IPA
                         * 0x82000000; PA is Bao-chosen and != IPA.
                         */
                        .base       = 0x82000000,
                        .size       = 0x04000000,   /* 64 MB */
                        .place_phys = false,
                    },
                },

                /* IPC: VM1 receives SGI 2 when VM2 calls the IPC hypercall */
                .ipc_num = 1,
                .ipcs = (struct ipc[]) {
                    [0] = {
                        .base          = 0xc0000000,  /* shmem IPA in VM1 — above 64 MB RAM window */
                        .size          = 0x10000000,  /* 256 MB */
                        .shmem_id      = 0,
                        .interrupt_num = 1,
                        .interrupts    = (irqid_t[]){ 2 },  /* SGI 2 delivered to VM1 */
                    },
                },

                .dev_num = 1,
                .devs = (struct vm_dev_region[]) {
                    {
                        /*
                         * UART0 — VM1 owns this device. IRQ 140 (THRE ISR)
                         * passed through so the TX ring ISR can drain.
                         */
                        .pa            = 0x10c02000,
                        .va            = 0x10c02000,
                        .size          = 0x00001000,
                        .interrupt_num = 1,
                        .interrupts    = (irqid_t[]){ 140 },
                    },
                },

                .arch = {
                    .gic = {
                        .gicd_addr     = 0x1d000000,
                        .gicr_addr     = 0x1d060000,
                        .interrupt_num = 160,  /* covers INTID 140 (UART THRE) */
                    },
                },
            },
        },

        /* ── VM2: ILC latency worker ─────────────────────── */
        {
            .image = {
                .base_addr = 0x82000000,    /* same IPA as VM1 — each VM's own space */
                .load_addr = VM_IMAGE_OFFSET(vm2_image),
                .size      = VM_IMAGE_SIZE(vm2_image),
            },

            .entry        = 0x82000000,
            //.cpu_affinity = 0x8,        /* bit 3 = cpuid 3 = A76 core 1 */
            .cpu_affinity = 0x2,        /* bit 1 = cpuid 1 = A55 core 1 */
            .colors       = 0xFF00,     /* COLORING ON — colors 8-15 = 1 MB DSU L3 (shared with Hyp) */

            .platform = {
                .cpu_num = 1,
                .mmu     = false,

                /*
                 * Only VM2 RAM is a mem region. The LWH2F MMIO at 0x20000000
                 * is passthrough hardware and is mapped as a device region
                 * (devs[0]) with Device attributes — NOT as a place_phys mem
                 * region. The baseline Bao's mem_init runs mem_check_reserved()
                 * which hard-fails (silently, before console_init) if any
                 * place_phys region cannot be reserved from a DRAM page pool.
                 * An MMIO address can never live in a DRAM pool, so declaring
                 * it place_phys here caused a pre-banner hang.
                 */
                .region_num = 1,
                .regions = (struct vm_mem_region[]) {
                    {
                        /*
                         * VM2 RAM — 64 MB (matches guest PLAT_MEM_SIZE).
                         * place_phys=false: Bao allocates color-matched pages
                         * (.colors=0xFF00) from the pool and recolors the
                         * embedded guest image into them. Guest sees IPA
                         * 0x82000000; PA is Bao-chosen and != IPA.
                         */
                        .base       = 0x82000000,
                        .size       = 0x04000000,   /* 64 MB */
                        .place_phys = false,
                    },
                },

                /* IPC: VM2 sends notify to VM1; no interrupt needed on VM2's side */
                .ipc_num = 1,
                .ipcs = (struct ipc[]) {
                    [0] = {
                        .base          = 0xc0000000,  /* shmem IPA in VM2 — above 64 MB RAM window */
                        .size          = 0x10000000,  /* 256 MB */
                        .shmem_id      = 0,
                        .interrupt_num = 0,           /* VM2 only sends, no SGI needed here */
                    },
                },

                .dev_num = 3,
                .devs = (struct vm_dev_region[]) {
                    {
                        /* LWH2F MMIO — Interval Timer + ILC interrupt (intid 50) */
                        .pa            = 0x20000000,
                        .va            = 0x20000000,
                        .size          = 0x00001000,
                        .interrupt_num = 1,
                        .interrupts    = (irqid_t[]){ 50 },
                    },
                    {
                        /*
                         * GPIO0 page — porta (0x10C03200): hps_led0=pin0, hps_led1=pin11
                         * E-Series 013B DevKit.
                         */
                        .pa            = 0x10c03000,
                        .va            = 0x10c03000,
                        .size          = 0x00001000,
                        .interrupt_num = 0,
                    },
                    {
                        /*
                         * Reset Manager — VM2 deasserts GPIO0/GPIO1 reset at boot.
                         * RSTMGR_SOC64_PER1MODRST=0x28, GPIO0=bit24, GPIO1=bit25.
                         * Active-low: clear bits to deassert (release from reset).
                         */
                        .pa            = 0x10d11000,
                        .va            = 0x10d11000,
                        .size          = 0x00001000,
                        .interrupt_num = 0,
                    },
                },

                .arch = {
                    .gic = {
                        .gicd_addr     = 0x1d000000,
                        .gicr_addr     = 0x1d060000,
                        .interrupt_num = 64,  /* covers INTID 50 (ILC SPI) */
                    },
                },
            },
        },

    }, /* vmlist */
};
