/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 *
 * ilc_latency.c — ILC Interrupt Latency Counter for Bao baremetal guest
 *
 * Owned by VM2. Latency stats are published into the VM2 -> VM1 shmem log ring
 * (vm2_log.h) and printed by VM1; the per-sample shmem_msg_t + IPC notify wakes
 * VM1 and carries the send timestamp for its cross-core IPI latency.
 *
 * Split ISR to keep the measured path short:
 *   irq_early_hook() (gic_handle, right after IAR ack): STP_REG=1 to freeze the
 *     ILC counter at the earliest software point — this is the capture.
 *   ilc_isr() (via handler table): read VLD/CNT, clear timer IRQ, re-arm ILC,
 *     push to ring + publish shmem + notify VM1. All post-capture.
 * The freeze lives in irq_early_hook so the handler-table lookup/dispatch is
 * out of the measured number. The arch dispatcher only calls a weak-default
 * hook (customers can reuse the same slot for their own fast-path IRQs).
 */

#include "ilc_latency.h"
#include <shmem_msg.h>
#include "vm2_log.h"
#include <irq.h>

/* ── Ring buffer ─────────────────────────────────────────────────────────── */

ilc_ring_t g_ilc_ring;

/* ── Interval Timer helpers ──────────────────────────────────────────────── */

static void itimer_start(void)
{
    mmio_write32(ITIMER_CTRL_REG, ITIMER_CTRL_STOP);
    __asm__ volatile("dsb sy" ::: "memory");

    /* ITIMER_PERIOD_{LO,HI} are set by the FPGA soft-IP at reset (fixes the
     * ~4 s tick cadence) and must NOT be rewritten here. */

    mmio_write32(ITIMER_STATUS_REG, 0U);
    __asm__ volatile("dsb sy" ::: "memory");

    mmio_write32(ITIMER_CTRL_REG, ITIMER_CTRL_RUN);
    __asm__ volatile("dsb sy" ::: "memory");
}

static inline void itimer_clear_irq(void)
{
    /* Device-nGnRnE MMIO is strictly ordered, so no explicit DSB is needed. */
    mmio_write32(ITIMER_STATUS_REG, 0U);
}

/* Early-IRQ fast path (strong override of the weak default). Called from
 * gic_handle() right after IAR ack, before handler dispatch: latch the ILC
 * counter (STP_REG=1) at the earliest software instant. Kept leaf/branchless
 * and library-free — it is in the measured path. */
void irq_early_hook(unsigned id)
{
    if (__builtin_expect(id == ILC_INTID, 1)) {
        mmio_write32(ILC_STP_REG, 1U);
    }
}

/* ISR (post-capture). The ILC counter is already frozen by irq_early_hook() —
 * do NOT re-freeze. All MMIO here is Device-nGnRnE (strictly ordered, no DSBs
 * needed); the only barrier is the producer-side dmb ishst before the ring
 * head update (orders Normal-memory payload vs head). */
void ilc_isr(unsigned id)
{
    (void)id;

    /* 1. Check valid — ILC is already frozen by gic_handle(). */
    uint32_t vld = mmio_read32(ILC_VLD_REG);

    uint32_t cycles = 0U;
    uint32_t ns = 0U;
    if (vld & 0x1U) {
        cycles = mmio_read32(ILC_CNT_REG);
        ns = cycles * (uint32_t)ILC_NS_PER_TICK;
    }

    /* 2. Clear timer IRQ source */
    itimer_clear_irq();

    /* 3. Re-arm ILC for next pulse */
    mmio_write32(ILC_STP_REG, 0U);

    /* 4. Store sample */
    if (vld & 0x1U) {
        ilc_ring_t *r = &g_ilc_ring;
        uint32_t next = (r->head + 1U) & (ILC_RING_SIZE - 1U);
        if (next != r->tail) {
            r->buf[r->head].cycles = cycles;
            r->buf[r->head].ns = ns;
            /* SPSC producer barrier: buf[] writes visible before head update
             * (so the drain never sees a bumped head with stale data). */
            __asm__ volatile("dmb ishst" ::: "memory");
            r->head = next;
        } else {
            r->overruns++;
        }
        r->total++;
        if (cycles < r->min_cycles)
            r->min_cycles = cycles;
        if (cycles > r->max_cycles)
            r->max_cycles = cycles;
        r->sum_cycles += (uint64_t)cycles;

        /* 5. Publish shmem + notify VM1. The fresh ipi_send_ticks lets VM1 time
         *    the VM2 -> VM1 HVC-to-SGI latency in its IPC ISR. */
#if SHMEM_SIZE > 0
        shmem_msg_t *msg = SHMEM_MSG;
        msg->seq++;
        msg->ipi_send_ticks = read_cntvct(); /* stamp before commit */
        msg->ready = 1U; /* commit — must be last write */
        __dsb_sy(); /* single barrier before notify */
        ipi_notify();
#endif
    }
}

/* ── Init ────────────────────────────────────────────────────────────────── */

void ilc_init(void)
{
    /* Zero ring buffer */
    for (uint32_t i = 0U; i < ILC_RING_SIZE; i++) {
        g_ilc_ring.buf[i].cycles = 0U;
        g_ilc_ring.buf[i].ns = 0U;
    }
    g_ilc_ring.head = 0U;
    g_ilc_ring.tail = 0U;
    g_ilc_ring.total = 0U;
    g_ilc_ring.overruns = 0U;
    g_ilc_ring.min_cycles = 0xFFFFFFFFUL;
    g_ilc_ring.max_cycles = 0U;
    g_ilc_ring.sum_cycles = 0ULL;

#if SHMEM_SIZE > 0
    /* DRAM may be stale across soft reboot; start these defined. */
    shmem_msg_t *msg = SHMEM_MSG;
    msg->seq = 0U;
    msg->latency_cycles = 0U;
    msg->latency_ns = 0U;
    msg->ipi_send_ticks = 0ULL;
    msg->ready = 0U;
    __dsb_sy();
#endif

    /* ILC init sequence */
    mmio_write32(ILC_CTRL_REG, 0x0U);
    __asm__ volatile("dsb sy" ::: "memory");
    mmio_write32(ILC_STP_REG, 0U);
    __asm__ volatile("dsb sy" ::: "memory");
    mmio_write32(ILC_CTRL_REG, 0x205U);
    __asm__ volatile("dsb sy" ::: "memory");

    /* Register ISR with bao-baremetal IRQ framework */
    irq_set_handler(ILC_INTID, ilc_isr);
    irq_enable(ILC_INTID);
    irq_set_prio(ILC_INTID, 0);

    /* Start interval timer */
    itimer_start();
}

/* Drain per-sample lines into the shmem ring (VM1 prints them; each embeds its
 * own [VM2] prefix). Called only when ILC_PER_SAMPLE_LOG is defined. */
void ilc_drain_samples(void)
{
    ilc_ring_t *r = &g_ilc_ring;
    static uint32_t printed = 0U; /* wraps at 2^32; harmless at 4 s/sample */

    while (r->tail != r->head) {
        /* SPSC consumer barrier: pairs with dmb ishst in ilc_isr. */
        __asm__ volatile("dmb ishld" ::: "memory");
        uint32_t idx = r->tail;
        r->tail = (r->tail + 1U) & (ILC_RING_SIZE - 1U);
        printed++;
        char b[VM2_LOG_SLOT_SZ];
        int p = 0;
        vm2_log_append_str(b, &p, "[VM2] ILC sample #");
        vm2_log_append_uint(b, &p, printed);
        vm2_log_append_str(b, &p, ": latency = ");
        vm2_log_append_uint(b, &p, r->buf[idx].ns);
        vm2_log_append_str(b, &p, " ns  (");
        vm2_log_append_uint(b, &p, r->buf[idx].cycles);
        vm2_log_append_str(b, &p, " cycles @ 100 MHz)\n");
        b[p] = '\0';
        vm2_log_emit(b);
    }
}

/* ── Print stats ─────────────────────────────────────────────────────────── */

void ilc_print_stats(void)
{
    ilc_ring_t *r = &g_ilc_ring;
    uint32_t total = r->total;

    if (total == 0U) {
        vm2_log_emit("[VM2] no samples\n");
        return;
    }

    uint32_t avg_ns = (uint32_t)((r->sum_cycles * ILC_NS_PER_TICK) / (uint64_t)total);
    char b[VM2_LOG_SLOT_SZ];
    int p = 0;
    vm2_log_append_str(b, &p, "[VM2] ILC n=");
    vm2_log_append_uint(b, &p, total);
    vm2_log_append_str(b, &p, " | min=");
    vm2_log_append_uint(b, &p, r->min_cycles * ILC_NS_PER_TICK);
    vm2_log_append_str(b, &p, " max=");
    vm2_log_append_uint(b, &p, r->max_cycles * ILC_NS_PER_TICK);
    vm2_log_append_str(b, &p, " avg=");
    vm2_log_append_uint(b, &p, avg_ns);
    vm2_log_append_str(b, &p, " ns\n");
    b[p] = '\0';
    vm2_log_emit(b);
}
