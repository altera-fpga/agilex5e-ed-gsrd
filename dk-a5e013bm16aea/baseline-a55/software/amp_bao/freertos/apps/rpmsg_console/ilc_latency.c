/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * ilc_latency.c -- ILC Interrupt Latency Counter, FreeRTOS-on-Bao port.
 *
 * Measurement pipeline:
 *
 *   FPGA Interval Timer (period fixed by the FPGA bitstream)
 *      |
 *      +-> F2H IRQ1 -> GICv3 SPI 18 -> intid 50
 *               |
 *               +-> Bao injects vIRQ 50 into this FreeRTOS VM
 *                       |
 *                       +-> GIC shim -> ilc_isr() below
 *                               |
 *                               +-> [first instruction] STP_REG = 1  (freeze)
 *                                   read VLD / CNT
 *                                   clear ITIMER STATUS
 *                                   re-arm ILC (STP_REG = 0)
 *                                   push sample to SPSC ring
 *                       |
 *                       +-> prvIlcDrainTask polls the ring every 1 s,
 *                           accumulates window stats, emits one
 *                           '[FRT] ilc n=10 ...' line per 10 samples
 *                           via rpmsg_trysendto() on the same channel
 *                           the heartbeat uses.
 *
 * Notes:
 *   - Samples are surfaced over the rpmsg-raw channel, so a single
 *     `cat /dev/rpmsg0` on Linux sees both heartbeats and ILC summary
 *     lines interleaved.
 *   - No direct UART output: Linux owns UART0 exclusively
 *     (configs/linux_freertos/config.c). The drain task formats lines
 *     and pushes them through rpmsg.
 *
 * Memory ordering / SPSC discipline:
 *   - All MMIO targets in the LWH2F bridge map at 0x20000000 are
 *     Device-nGnRnE (Stage-2 attr default for vm_dev_region in Bao).
 *     ARMv8 strictly orders Device-nGnRnE accesses against each other,
 *     so explicit DSBs between MMIO ops are unnecessary in the ISR.
 *   - The ring is single-producer (ISR) / single-consumer (drain task)
 *     on the same vCPU, so the producer-side `dmb ishst` before the
 *     head update and the consumer-side `dmb ishld` after observing
 *     the head are the only barriers needed for the Normal-memory
 *     ring buffer payload visibility ordering.
 */

#include "ilc_latency.h"

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "FreeRTOS.h"
#include "task.h"

#include <openamp/rpmsg.h>

#include "socfpga_interrupt.h"

#include "drivers/gpio/gpio_led.h"

/* Linux's rpmsg_chrdev default ept on /dev/rpmsg0 is the first id from
 * RPMSG_RESERVED_ADDRESSES (= 0x400). Mirror the heartbeat target in
 * main_rpmsg_console.c so summary lines land in whichever reader
 * currently holds /dev/rpmsg0 open. See the long comment block above
 * BAO_LINUX_DEFAULT_EPT_ADDR in main_rpmsg_console.c for the empirical
 * justification of the fixed-dst pattern. */
#define ILC_LINUX_DEFAULT_EPT_ADDR RPMSG_RESERVED_ADDRESSES

/* One summary line per 10 samples. The '[FRT] ilc ...' line rate is
 * determined by the bitstream-fixed ITIMER period. */
#define ILC_SAMPLES_PER_LINE 10U

#define ILC_DRAIN_POLL_MS 1000U
#define ILC_DRAIN_POLL_TICKS pdMS_TO_TICKS(ILC_DRAIN_POLL_MS)

#define ILC_DRAIN_TASK_PRIORITY (tskIDLE_PRIORITY + 1)
#define ILC_DRAIN_STACK_WORDS 1024U

/* Stack-resident format buffer; sized for the longest line we can emit
 * (well under 160 bytes). */
#define ILC_LINE_BUF_SIZE 192

/* MMIO accessors. Match the existing FreeRTOS sample style (volatile
 * cast) -- there is no project-wide mmio_read32/write32 helper in the
 * freertos-socfpga tree. Wrap as inlines so call sites stay readable
 * and the compiler still inlines the load/store. */
static inline uint32_t ilc_read32(uintptr_t addr)
{
    return *(volatile uint32_t *)addr;
}

static inline void ilc_write32(uintptr_t addr, uint32_t value)
{
    *(volatile uint32_t *)addr = value;
}

/* Single global ring -- exported via the header for debug/stats. The
 * volatile fields are described in detail in ilc_latency.h. */
ilc_ring_t g_ilc_ring;

/* rpmsg endpoint captured by ilc_start(). The drain task uses it for
 * rpmsg_trysendto(); the ISR never touches it. The pointer is stable
 * for the lifetime of the guest because it points at a file-static
 * struct in main_rpmsg_console.c (see prvProducerTask). */
static struct rpmsg_endpoint *s_ept;

/* Cached final return code from ilc_start(), surfaced via the one-shot
 * '[FRT] ilc-init ...' line emitted just before the drain task is
 * spawned. Useful when rpmsg comes up but no '[FRT] ilc ...' samples
 * follow -- inspect rc to localise the failure (negative -> ilc_start
 * itself bailed; 0 -> init OK, look further down the pipeline). */
static int s_ilc_start_rc = -99;

#define ILC_VGIC_GICD_BASE 0x1D000000UL
#define ILC_VGIC_GICD_IROUTER ((volatile uint32_t *)(uintptr_t)(ILC_VGIC_GICD_BASE + 0x6000UL))

static void ilc_fix_gic_route_for_intid_50(void)
{
    /* IROUTER is 64-bit per intid, base 0x6000. For intid 50 the
     * 64-bit word lives at GICD + 0x6000 + 50*8 = +0x6190. Two
     * 32-bit stores: low half = aff0..aff2 (all zero -> boot A55 =
     * the only vCPU of this VM); high half = aff3 + irm bit (also
     * zero -> "route to specific affinity"). */
    volatile uint32_t *r = &ILC_VGIC_GICD_IROUTER[(ILC_INTID * 2U)];
    r[0] = 0U;
    r[1] = 0U;
    __asm__ volatile("dsb ish; isb" ::: "memory");
}

/*
 * ISR -- registered on intid 50 (FPGA2HPS_INTERRUPT1) by ilc_start().
 *
 * Runs in IRQ context. Must be:
 *   - leaf (no FreeRTOS API calls -- the drain task does the talking)
 *   - branchless on the hot path beyond the validity check
 *   - free of library calls and printf
 *
 * Sequence (the early-hook freeze is inlined as the first MMIO write):
 *
 *   1. STP_REG = 1                 -- freeze (measurement capture point)
 *   2. read VLD; if not valid, just clear timer + re-arm and exit
 *   3. read CNT, compute ns = cycles * 10
 *   4. STATUS_REG = 0              -- clear timer IRQ source
 *   5. STP_REG  = 0                -- re-arm ILC for next pulse
 *   6. push (cycles, ns) to ring; update min/max/sum/total
 *
 * The order between (4) and (5) doesn't matter for correctness -- the
 * timer IRQ source clear stops the SPI line from re-asserting and the
 * STP_REG=0 re-enables ILC counting; both are idempotent w.r.t. each
 * other thanks to Device-nGnRnE strict ordering.
 */
void ilc_isr(void *user_data)
{
    (void)user_data;

    /* (1) Freeze. Closest software-visible point to IAR ack we can
     * reach without patching the GIC shim. */
    ilc_write32(ILC_STP_REG, 1U);

    /* (2) Validity gate. If the ILC pulse arrived before VLD latched
     * (shouldn't happen on a healthy IP but defend anyway), still
     * clear the timer + re-arm so we don't wedge on a stale STATUS. */
    uint32_t vld = ilc_read32(ILC_VLD_REG);
    if (!(vld & 0x1U)) {
        ilc_write32(ITIMER_STATUS_REG, 0U);
        ilc_write32(ILC_STP_REG, 0U);
        return;
    }

    /* (3) Latch counter. */
    uint32_t cycles = ilc_read32(ILC_CNT_REG);
    uint32_t ns = cycles * (uint32_t)ILC_NS_PER_TICK;

    /* (4) Clear timer IRQ source. */
    ilc_write32(ITIMER_STATUS_REG, 0U);

    /* (5) Re-arm ILC. */
    ilc_write32(ILC_STP_REG, 0U);

    /* (6) Push to ring + cumulative stats. */
    ilc_ring_t *r = &g_ilc_ring;
    uint32_t next = (r->head + 1U) & (ILC_RING_SIZE - 1U);
    if (next != r->tail) {
        r->buf[r->head].cycles = cycles;
        r->buf[r->head].ns = ns;
        /* Producer-side barrier: payload writes must be visible to
         * the consumer (drain task) BEFORE the head update authorises
         * them. Same-vCPU consumer is post-context-switch synchronised
         * by exception-return, but explicit for architectural
         * correctness on ARMv8. */
        __asm__ volatile("dmb ishst" ::: "memory");
        r->head = next;
    } else {
        r->overruns++;
    }

    r->total++;
    if (cycles < r->min_cycles) {
        r->min_cycles = cycles;
    }
    if (cycles > r->max_cycles) {
        r->max_cycles = cycles;
    }
    r->sum_cycles += (uint64_t)cycles;
}

/*
 * Drain task -- consumes the SPSC ring, maintains a 10-sample sliding
 * window (min/max/sum + last), and emits one summary line every
 * ILC_SAMPLES_PER_LINE samples via rpmsg_trysendto.
 *
 * Lives at tskIDLE_PRIORITY + 1 (same as the heartbeat producer) so
 * it cannot preempt the priority-2 RX dispatch task. We use trysendto
 * (not sendto) so a wedged Linux reader never stalls the producer --
 * the ILC ring keeps absorbing samples and the next successful send
 * resumes the line stream.
 */
static void prvIlcDrainTask(void *pvParameters)
{
    (void)pvParameters;

    char szLine[ILC_LINE_BUF_SIZE];
    uint32_t win_count = 0U;
    uint32_t win_min = 0xFFFFFFFFUL;
    uint32_t win_max = 0U;
    uint64_t win_sum = 0ULL;
    uint32_t total_seen = 0U;

    /* Alert-only overrun watch: silent under normal operation; emits a
     * '[FRT] ilc-WARN ...' line immediately on the next drain wake after
     * the ISR records a new overrun (ring tail caught up to head --
     * samples were lost). If this line appears in a log, the drain task
     * is not keeping up with the ISR cadence. */
    uint32_t last_overruns = 0U;

    for (;;) {
        vTaskDelay(ILC_DRAIN_POLL_TICKS);

        ilc_ring_t *r = &g_ilc_ring;

        if (r->overruns != last_overruns) {
            last_overruns = r->overruns;
            int n = snprintf(szLine, sizeof(szLine), "[FRT] ilc-WARN overruns=%lu total=%lu\r\n",
                             (unsigned long)r->overruns, (unsigned long)r->total);
            if (n > 0 && (size_t)n < sizeof(szLine) && s_ept != NULL) {
                (void)rpmsg_trysendto(s_ept, szLine, n, (uint32_t)ILC_LINUX_DEFAULT_EPT_ADDR);
            }
        }
        while (r->tail != r->head) {
            /* Consumer-side barrier: pair with the ISR's `dmb ishst`.
             * Once we have observed `head`, the buf[idx] payload that
             * went in BEFORE that head update must be visible. */
            __asm__ volatile("dmb ishld" ::: "memory");
            uint32_t idx = r->tail;
            uint32_t cycles = r->buf[idx].cycles;
            r->tail = (r->tail + 1U) & (ILC_RING_SIZE - 1U);

            win_count++;
            total_seen++;
            if (cycles < win_min) {
                win_min = cycles;
            }
            if (cycles > win_max) {
                win_max = cycles;
            }
            win_sum += (uint64_t)cycles;

            /* Visual heartbeat: flip hps_led0 (and hps_led1 on the 2-LED
             * board variant) once per sample consumed.  Because the
             * ISR's only job per fire is to push exactly one sample
             * onto the SPSC ring, this loop runs once-per-ISR-fire by
             * construction, so the LED cadence on the bench matches
             * the Interval Timer period exactly without any of the
             * MMIO cost landing in the ISR's latency measurement.
             *
             * Backpressure is the drain task's responsibility (see the
             * overruns counter handled at the top of this loop); if
             * the drain ever falls behind, the LED simply lags the
             * true ISR cadence by one drain wake-up (~1 s), and the
             * '[FRT] ilc-WARN overruns=...' line on /dev/rpmsg0
             * surfaces the condition explicitly. */
            gpio_led_toggle();

            if (win_count >= ILC_SAMPLES_PER_LINE) {
                uint32_t avg_ns = (uint32_t)((win_sum * (uint64_t)ILC_NS_PER_TICK) / (uint64_t)win_count);
                int n = snprintf(szLine, sizeof(szLine),
                                 "[FRT] ilc n=%lu min=%lu max=%lu avg=%lu ns "
                                 "total=%lu\r\n",
                                 (unsigned long)win_count, (unsigned long)(win_min * ILC_NS_PER_TICK),
                                 (unsigned long)(win_max * ILC_NS_PER_TICK), (unsigned long)avg_ns,
                                 (unsigned long)total_seen);
                if (n > 0 && (size_t)n < sizeof(szLine) && s_ept != NULL) {
                    /* Best-effort send; drop on RPMSG_ERR_NO_BUFF.
                     * Mirror the heartbeat-side policy of fixed dst
                     * 0x400 -- see ILC_LINUX_DEFAULT_EPT_ADDR. */
                    (void)rpmsg_trysendto(s_ept, szLine, n, (uint32_t)ILC_LINUX_DEFAULT_EPT_ADDR);
                }
                win_count = 0U;
                win_min = 0xFFFFFFFFUL;
                win_max = 0U;
                win_sum = 0ULL;
            }
        }
    }
}

/*
 * Bring the ILC pipeline online. See ilc_latency.h for the full
 * ordering contract w.r.t. interrupt_init_gic / the rpmsg endpoint.
 *
 * Returns 0 on success, negative errno-ish value on failure.
 */
int ilc_start(struct rpmsg_endpoint *endpoint)
{
    if (endpoint == NULL) {
        return -1;
    }
    s_ept = endpoint;

    /* Initialise the ring + cumulative stats. */
    ilc_ring_t *r = &g_ilc_ring;
    for (uint32_t i = 0U; i < ILC_RING_SIZE; i++) {
        r->buf[i].cycles = 0U;
        r->buf[i].ns = 0U;
    }
    r->head = 0U;
    r->tail = 0U;
    r->total = 0U;
    r->overruns = 0U;
    r->min_cycles = 0xFFFFFFFFUL;
    r->max_cycles = 0U;
    r->sum_cycles = 0ULL;

    /* ILC init sequence:
     *   CTRL = 0   -- quiesce
     *   STP  = 0   -- ensure not frozen
     *   CTRL = 0x205 -- enable + arm */
    ilc_write32(ILC_CTRL_REG, 0x0U);
    ilc_write32(ILC_STP_REG, 0U);
    ilc_write32(ILC_CTRL_REG, 0x205U);

    /* Register + enable the SPI 50 ISR. Priority 0 = highest GIC
     * priority (lower numerical = higher priority on ARMv8 GICv3),
     * so an ILC IRQ preempts the rpmsg-kick SPI 52. The
     * ITIMER is level-triggered (the IRQ line stays asserted until
     * STATUS_REG is cleared), so SPI_INTERRUPT_TYPE_LEVEL is correct.
     * SPI_INTERRUPT_MODE_ANY routes to whichever vCPU is online --
     * we only have one vCPU in this guest.
     *
     * Order: register the handler BEFORE enabling the SPI so the
     * very first IRQ (which can fire as soon as we start the ITIMER
     * below) lands on a defined ilc_isr, not the GIC default. */
    if (interrupt_register_isr((socfpga_hpu_interrupt_t)ILC_INTID, ilc_isr, NULL) != ERR_OK) {
        return -2;
    }
    if (interrupt_spi_enable((socfpga_hpu_interrupt_t)ILC_INTID, SPI_INTERRUPT_TYPE_LEVEL, SPI_INTERRUPT_MODE_ANY,
                             0U /* highest GIC priority */) != ERR_OK) {
        return -3;
    }

    /* Patch the missing IROUTER write that gic_set_int_route() skipped
     * for our intid 50 (see the long comment block above
     * ilc_fix_gic_route_for_intid_50). Without this, Bao's vGIC has no
     * target vCPU and the ILC IRQ is lost. */
    ilc_fix_gic_route_for_intid_50();

    /* Start the Interval Timer. STOP first to defensively quiesce in
     * case U-Boot or a prior boot left it running, then clear any
     * pending STATUS (= clear pending IRQ source), then arm with
     * RUN = ITO|CONT|START.
     *
     * NOTE: PERIOD_LO/HI are programmed by the FPGA Soft-IP at power-
     * on reset and are read-only at runtime -- the ~4 s tick is a
     * property of the bitstream. Do NOT write them here. */
    ilc_write32(ITIMER_CTRL_REG, ITIMER_CTRL_STOP);
    ilc_write32(ITIMER_STATUS_REG, 0U);
    ilc_write32(ITIMER_CTRL_REG, ITIMER_CTRL_RUN);

    /* Spawn the drain task. Created last so the ring + ISR are fully
     * live before we start consuming -- but a missed early sample is
     * harmless either way (the ring just absorbs it). */
    BaseType_t rc = xTaskCreate(prvIlcDrainTask, "ilcDRAIN", (configSTACK_DEPTH_TYPE)ILC_DRAIN_STACK_WORDS, NULL,
                                (UBaseType_t)ILC_DRAIN_TASK_PRIORITY, NULL);
    if (rc != pdPASS) {
        s_ilc_start_rc = -4;
        return -4;
    }
    s_ilc_start_rc = 0;

    /* One-shot init beacon. Surfaces ilc_start's outcome on the same
     * rpmsg-raw channel as the heartbeat so a `cat /dev/rpmsg0` on
     * Linux reports whether the pipeline armed cleanly. trysendto
     * (not sendto) so a wedged Linux reader can't stall here. */
    {
        char init_line[96];
        int n = snprintf(init_line, sizeof(init_line), "[FRT] ilc-init rc=%d intid=%lu prio=%u\r\n", s_ilc_start_rc,
                         (unsigned long)ILC_INTID, 0U);
        if (n > 0 && (size_t)n < sizeof(init_line)) {
            (void)rpmsg_trysendto(s_ept, init_line, n, (uint32_t)ILC_LINUX_DEFAULT_EPT_ADDR);
        }
    }
    return 0;
}
