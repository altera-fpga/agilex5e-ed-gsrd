/* Bao partition config — hps-amp Agilex5 (Linux + FreeRTOS coexistence).
 * ----------------------------------------------------------------------
 * Partition:
 *   pCPU0 = A55 (boot CPU)  -> FreeRTOS VM  vCPU0  (cpu_affinity=0x1)
 *   pCPU1 = A55              -> idle
 *   pCPU2 = A76              -> Linux VM    vCPU0  (cpu_affinity bit2)
 *   pCPU3 = A76              -> Linux VM    vCPU1  (cpu_affinity bit3)
 *
 * FreeRTOS communicates with Linux via OpenAMP rpmsg at IPA 0xC4000000
 * (/dev/rpmsg0). The FreeRTOS image is .incbin'd inside bao.bin via
 * VM_IMAGE; FRTOS_IMG_PATH is injected by the orchestrator Makefile
 * (FREERTOS_BUILD_BACKEND=freertos-socfpga, see configs/linux_freertos/
 * config.mk). Boot loads bao.bin to 0xe0000000 and jumps there (see
 * boot.cmd). Bao is loaded high so the cache-colored Linux VM has a large
 * enough contiguous colored physical region below it — see the region
 * comment in VM 0.
 */

#include <config.h>

#ifndef FRTOS_IMG_PATH
#error "FRTOS_IMG_PATH not defined — orchestrator must pass it via CPPFLAGS"
#endif

#define LINUX_VM_COLORS 0xFFF0 /* colors 4-15 */
#define FRTOS_VM_COLORS 0x000F /* colors 0-3 */
#define HYP_COLORS 0x000F /* colors 0-3: Bao EL2 shares FreeRTOS's L3 slice */

VM_IMAGE(freertos_image, XSTR(FRTOS_IMG_PATH))

struct config config = {
    CONFIG_HEADER
    /* Cache-coloring
     *
     * Agilex5 L3: 16-way, 2048 sets, 64B line → 2 MiB total.
     * FLC (L1I) way size = 128 × 64 = 8 KiB = 2 pages.
     * COLOR_SIZE = 2, COLOR_NUM = 16 → 128 KiB of L3 per color.
     *
     * FreeRTOS VM gets colors 0–3 (bits 0x000F) = 512 KiB of dedicated L3.
     * Its ISR code, stack, ring-buffer and ILC measurement variables sit in
     * a distinct physical color zone from Linux data.
     *
     * Linux VM gets colors 4–15 (bits 0xFFF0) = 1.5 MiB of dedicated L3, the
     * exact complement of FreeRTOS's slice — the two guests now share no L3
     * color, so neither can evict the other's lines.  This is possible because
     * the SMMUv3 driver (0007-add-smmuv3.patch) gives the Linux VM a stage-2
     * IOMMU: with coloring, IPA != PA, but Bao walks the same stage-2 page
     * table for the VM-bound DMA masters (SDMMC ADMA stream 5, gmac2 stream 3),
     * so passthrough DMA still resolves the guest's IPA to its colored PA.
     * The Linux region is therefore place_phys=false (Bao allocates colored
     * physical pages and copies/recolors the loaded kernel image into them).
     *
     * Bao hypervisor gets the same color slice (0x000F) so the IRQ-dispatch
     * hot-path (EL2 entry/exit + GIC emulation) stays warm in the same
     * 512 KiB L3 partition as FreeRTOS. Hyp coloring depends on the hyp
     * self-relocation fixes in patches 0008/0009. */
    .hyp = { .colors = HYP_COLORS },
    .shmemlist_size = 1,
    .shmemlist = (struct shmem[]) {
        [0] = {
            /* 64 KiB inter-VM region at IPA 0xC4000000. Hosts the
             * OpenAMP resource_table, two vrings, and the shared rpmsg
             * buffer pool. See resource_table.h for the full layout. */
            .size = 0x00010000,
            /* place_phys=false -> Bao picks a PA outside both VMs'
             * place_phys regions (Linux owns 0x82000000..0xc2000000,
             * Bao itself sits at 0xe0000000). */
            .place_phys = false,
        }
    },
    .vmlist_size = 2,
    .vmlist = (struct vm_config[]) {
        {
            .image = VM_IMAGE_LOADED(0x82000000, 0x82000000, 0x3100000),
            .entry = 0x82000000,
            /* Bao pCPU layout on Agilex5 HPS:
             *   pCPU0 = A55 (boot CPU; ATF lands here)
             *   pCPU1 = A55
             *   pCPU2 = A76
             *   pCPU3 = A76
             *
             * Linux SMP on both A76 cores (pCPU2 + pCPU3).
             *
             * Bao maps vCPU_i to the i-th set bit of cpu_affinity (LSB
             * first), so:
             *   cpu_affinity = 0xc -> bit2 = pCPU2 = vCPU0,
             *                         bit3 = pCPU3 = vCPU1.
             * cpu_affinity is a bitmask of pCPUs (LSB = pCPU0). */
            .cpu_affinity = 0xc,
            /* colors 4–15 (0xFFF0): the complement of FreeRTOS's 0x000F, giving
             * Linux a dedicated 1.5 MiB L3 partition with zero color overlap.
             * Safe now that the SMMUv3 stage-2 binding below translates the
             * passthrough DMA masters' IPAs to their colored PAs. */
            .colors = LINUX_VM_COLORS,
            .platform = {
                .cpu_num = 2,
                .mmu = true,
                .region_num = 1,
                .regions = (struct vm_mem_region[]) {
                    {
                        // Colored 1 GiB at guest IPA 0x82000000 – 0xC2000000.
                        // place_phys=false: with .colors=0xFFF0 set above, Bao
                        // allocates colored physical pages for the whole region
                        // and copies/recolors the loaded kernel image (the
                        // VM_IMAGE_LOADED at PA 0x82000000) into them. IPA != PA
                        // now, so every passthrough DMA master that touches this
                        // memory MUST be bound to the VM's SMMU stage-2 (see the
                        // .arch.smmu groups below); the SMMU walks this same
                        // stage-2 table to translate the device's IPA to the
                        // colored PA. Bao itself is loaded at 0xE0000000 (high,
                        // so the contiguous colored region below it is big
                        // enough for this 1 GiB VM) and the shmem IPC lives at
                        // IPA 0xC4000000, both outside the guest IPA window.
                        .base = 0x82000000,
                        .size = 0x40000000,
                    },
                },
                .ipc_num = 1,
                .ipcs = (struct ipc[]) {{
                    /* IPA 0xC4000000: above Linux 1 GiB (ends 0xC2000000).
                     * Backing PA is Bao-allocated dynamically
                     * (shmem.place_phys = false). */
                    .base = 0xC4000000,
                    .size = 0x00010000,
                    .shmem_id = 0,
                    /* Two events both wired to the same SPI 52 so
                     * bao_kick(vqid={0,1}) from either peer always fires.
                     * OpenAMP backend / virtio_rpmsg_bus issue one kick
                     * per vring (vqid mirrors vring index); ipc.c gates
                     * with `event_id < interrupt_num` so a single entry
                     * would silently swallow vqid=1 kicks. Both vrings
                     * deliver on the same vIRQ — the receiver-side ISR
                     * fans out to rproc_virtio_notified() / rproc_vq_
                     * interrupt() for both vqids. */
                    .interrupt_num = 2,
                    .interrupts = (irqid_t[]) { 52, 52 },
                }},
                .dev_num = 10,
                .devs = (struct vm_dev_region[]) {
                    {
                        /* UART0 — GIC SPI 108 → irqid 140 (32 + 108).
                         * Interrupt passthrough is required; without it the
                         * dw-apb-uart driver cannot register IRQ 140 and
                         * /dev/ttyS0 is not available to serial-getty. */
                        .pa   = 0x10c02000,
                        .va   = 0x10c02000,
                        .size = 0x1000,
                        .interrupt_num = 1,
                        .interrupts = (irqid_t[]) { 140 },
                    },
                    {
                        // QSPI controller
                        .pa = 0x108d2000,
                        .va = 0x108d2000,
                        .size = 0x1000,
                        .interrupt_num = 1,
                        .interrupts = (irqid_t[]) { 35 },
                    },
                    {
                        // QSPI flash window
                        .pa = 0x10900000,
                        .va = 0x10900000,
                        .size = 0x100000,
                    },
                    {
                        // Virtual timer PPI
                        .interrupt_num = 1,
                        .interrupts = (irqid_t[]) { 27 },
                    },
                    {
                        // System manager (required by Ethernet driver)
                        .pa = 0x10d12000,
                        .va = 0x10d12000,
                        .size = 0x1000,
                    },
                    {
                        // Reset manager (required by Ethernet and MMC drivers)
                        .pa = 0x10d11000,
                        .va = 0x10d11000,
                        .size = 0x1000,
                    },
                    {
                        // gmac2 Ethernet — SPI 224-240 → irqid 256-272
                        .pa = 0x10830000,
                        .va = 0x10830000,
                        .size = 0x4000,
                        .interrupt_num = 17,
                        .interrupts = (irqid_t[]) {
                            256, 257, 258, 259, 260, 261, 262, 263,
                            264, 265, 266, 267, 268, 269, 270, 271, 272,
                        },
                    },
                    {
                        // SDMMC — SPI 96 → irqid 128
                        .pa = 0x10808000,
                        .va = 0x10808000,
                        .size = 0x1000,
                        .interrupt_num = 1,
                        .interrupts = (irqid_t[]) { 128 },
                    },
                    {
                        // GPIO1 (portb) — page-aligned to 0x10c03000; actual regs at +0x300
                        .pa = 0x10c03000,
                        .va = 0x10c03000,
                        .size = 0x1000,
                    },
                    {
                        /* USB3.1 DWC3 wrapper — GIC SPI 94 → irqid 126.
                         * Memory window covers both the DWC3 glue regs and the
                         * internal xHCI / DWC3 core registers (0x11000000+0x100000). */
                        .pa = 0x11000000,
                        .va = 0x11000000,
                        .size = 0x100000,
                        .interrupt_num = 1,
                        .interrupts = (irqid_t[]) { 126 },
                    },
                },
                .arch = {
                    .gic = {
                        .gicd_addr = 0x1d000000,
                        .gicr_addr = 0x1d060000,
                        .interrupt_num = 288,   /* covers SPI 0-255; gmac2 uses SPI 240 = irqid 272 */
                    },
                    /* SMMUv3 stream-ID bindings.
                     *
                     * IMPORTANT: this VM is cache-colored (.colors=0xFFF0), so
                     * its guest IPA no longer equals PA. Bao's SMMU driver
                     * leaves every unbound stream in BYPASS (incoming attrs
                     * preserved), which means an unbound master's DMA reaches
                     * the bus with address == guest IPA and lands at the WRONG
                     * physical page (the identity PA, no longer owned by this
                     * VM). Therefore, under coloring, EVERY DMA master the guest
                     * actually drives into its RAM must be bound here so its
                     * IPA is translated through the VM's stage-2 to the colored
                     * PA. (Pure-MMIO masters with no bus-mastering DMA need no
                     * entry.)
                     *
                     * Stream IDs (Agilex5 system-manager SID assignment):
                     *   - SDMMC (mmc0) -> stream id 5   (rootfs ADMA)
                     *   - gmac2 (TSN2) -> stream id 3   (ethernet RX/TX DMA)
                     *   - USB3 -> stream id 7   (USB3 DMA)
                     *
                     * Both bus-mastering devices the guest drives into RAM are
                     * bound. (In the old identity-mapped config gmac2 was left
                     * in BYPASS on purpose — IPA==PA made that safe and binding
                     * it merely exposed a TX bug. Under coloring BYPASS is no
                     * longer an option: gmac2's DMA descriptors hold guest IPAs
                     * that only resolve via stage-2, so it MUST be bound.)
                     *
                     * NOTE: if USB (usb31, stream id of usb2/usb3) is left
                     * enabled it bus-masters at xHCI probe; under coloring that
                     * BYPASS DMA hits the wrong PA. If you see xHCI/dwc3 errors,
                     * either bind USB's stream id here too or set usb31
                     * status="disabled" in linux.dts. */
                    .smmu = {
                        .group_num = 3,
                        .groups = (struct smmu_group[]) {
                            { .mask = 0, .id = 5 },   /* SDMMC */
                            { .mask = 0, .id = 3 },   /* gmac2 (TSN2) */
                            { .mask = 0, .id = 7 },   /* USB3 */
                        },
                    },
                },
            },
        },

        /* ---------------------------------------------------------------
         * VM 1 — FreeRTOS on A55 core 0 (rpmsg_console guest).
         *
         * Image: embedded via VM_IMAGE. Bao allocates the backing PA
         * dynamically (no place_phys), so the 16 MiB sits outside
         * Linux's 0x82000000..0xC2000000 and Bao's image at 0xe0000000.
         *
         * UART policy: UART0 is not mapped here — Linux owns it
         * exclusively. All FreeRTOS output goes over rpmsg at IPA
         * 0xC4000000 (/dev/rpmsg0).
         * --------------------------------------------------------------- */
        {
            .image = {
                .base_addr = 0x90000000,
                .load_addr = VM_IMAGE_OFFSET(freertos_image),
                .size      = VM_IMAGE_SIZE(freertos_image),
            },
            .entry = 0x90000000,
            .cpu_affinity = 0x1,
            /* colors 0–3 → 512 KiB of dedicated L3 for the FreeRTOS real-time
             * partition.  Region is place_phys=false (Bao allocates the backing
             * PA dynamically), so vm_config.colors drives the allocation. */
            .colors = FRTOS_VM_COLORS,
            .platform = {
                .cpu_num = 1,
                .mmu = true,

                .region_num = 1,
                .regions = (struct vm_mem_region[]) {
                    {
                        .base = 0x90000000,
                        .size = 0x01000000,
                    },
                },

                .ipc_num = 1,
                .ipcs = (struct ipc[]) {{
                    .base = 0xC4000000,   /* matches Linux VM IPC IPA above */
                    .size = 0x00010000,
                    .shmem_id = 0,
                    /* Two events / one IRQ — see Linux VM ipc comment above. */
                    .interrupt_num = 2,
                    .interrupts = (irqid_t[]) { 52, 52 },
                }},

                /* UART0 dev region intentionally NOT exposed to this VM:
                 * the longer-term policy locked in 2B/2C is "Linux owns
                 * UART0 exclusively". The FreeRTOS guest is silent on
                 * UART0 and surfaces all liveness via the rpmsg
                 * heartbeat over /dev/rpmsg0 (see
                 * freertos/apps/rpmsg_console/main_rpmsg_console.c). The
                 * only IRQ this VM needs is the EL1 virtual timer PPI. */
                .dev_num = 4,
                .devs = (struct vm_dev_region[]) {
                    {
                        /* EL1 virtual timer PPI (per-CPU intid 27) --
                         * required for the FreeRTOS scheduler tick. */
                        .interrupt_num = 1,
                        .interrupts = (irqid_t[]) { 27 },
                    },
                    {
                        /* LWH2F bridge: Interval Timer + ILC soft-IP for
                         * interrupt-latency measurement.
                         *
                         * Map one page (0x1000) starting at PA 0x20000000
                         * identity-mapped into the FreeRTOS guest IPA so
                         * freertos/apps/rpmsg_console/ilc_latency.c can
                         * touch the Interval Timer (offset 0x000-0x00F)
                         * and the ILC (offset 0x100-0x18F) without any
                         * IPA->PA translation gymnastics. Stage-2 attrs
                         * default to Device-nGnRnE for vm_dev_region
                         * (see Bao's mem.c / vmm.c) which is exactly
                         * what we want for these MMIO registers.
                         *
                         * IRQ: F2H IRQ1 -> GICv3 SPI 18 -> intid 50.
                         * The ISR is registered through the
                         * freertos-socfpga interrupt API
                         * (interrupt_register_isr +
                         * interrupt_spi_enable) at GIC priority 0
                         * (highest) so timer captures preempt the
                         * rpmsg-kick SPI 52 -- preserving measurement
                         * fidelity at the cost of a negligible
                         * head-of-line bump on the kick path.
                         *
                         * NOTE: U-Boot must run `bridge enable` BEFORE
                         * `go 0xe0000000` so the LWH2F bridge fronting
                         * 0x20000000 is powered up; without it any
                         * access here external-aborts (see boot.cmd). */
                        .pa            = 0x20000000,
                        .va            = 0x20000000,
                        .size          = 0x1000,
                        .interrupt_num = 1,
                        .interrupts    = (irqid_t[]) { 50 },
                    },
                    {
                        /* GPIO0 + GPIO1 dw-apb-gpio page -- 4 KiB at PA
                         * 0x10c03000 covers porta (0x10c03200, hps_led0
                         * pin 0 + hps_led1 pin 11) and portb
                         * (0x10c03300).  Mapped passthrough into
                         * FreeRTOS so ilc_isr() can toggle the LEDs on
                         * every Interval Timer fire (see
                         * freertos/apps/rpmsg_console/drivers/gpio/
                         * gpio_led.{c,h}).  No IRQ -- this driver only
                         * does direct MMIO writes.
                         *
                         * Coexistence: the Linux VM also has this same
                         * 4 KiB page mapped (see VM 0 above) for its
                         * dw-apb-gpio driver bound to GPIO1 / portb.
                         * Bao maps each vm_dev_region independently in
                         * Stage 2, so both VMs see the same PA at the
                         * same IPA.  Software discipline keeps the
                         * register banks disjoint: Linux only touches
                         * GPIO1 (porta of the second IP block, +0x300)
                         * and FreeRTOS only touches GPIO0 (porta of the
                         * first IP block, +0x200). */
                        .pa            = 0x10c03000,
                        .va            = 0x10c03000,
                        .size          = 0x1000,
                    },
                    {
                        /* Reset Manager -- required by the freertos-socfpga
                         * gpio_open() HAL call: rstmgr_toggle_reset()
                         * reads/writes RSTMGR_SOC64_PER1MODRST
                         * (RSTMGR_BASE + 0x28) to deassert the GPIO
                         * peripheral reset before first use.
                         *
                         * Coexistence: Linux also maps this page for
                         * reset-socfpga.c.  Our one-shot deassert runs
                         * at sub-millisecond FreeRTOS init time; Linux
                         * init takes seconds and touches different bits
                         * for its own peripherals. */
                        .pa            = 0x10d11000,
                        .va            = 0x10d11000,
                        .size          = 0x1000,
                    },
                },

                .arch = {
                    .gic = {
                        .gicd_addr     = 0x1d000000,
                        .gicr_addr     = 0x1d060000,
                        /* 288 matches the Linux VM so Bao's vGIC
                         * tables stay consistent across VMs. */
                        .interrupt_num = 288,
                    },
                },
            },
        },
    },
};
