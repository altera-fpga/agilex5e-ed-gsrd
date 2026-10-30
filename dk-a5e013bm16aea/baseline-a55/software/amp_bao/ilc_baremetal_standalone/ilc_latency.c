/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/*
 * ilc_latency.c — ILC Interrupt Latency Counter, standalone bare-metal
 *
 * Same logical path as Bao guest VM1 (src/ilc_latency.c + gicv3.c):
 *
 *   vectors.S  →  gic_handle()  →  irq_early_hook(id)  →  ilc_isr(id)
 *                    (gic_handle.c)   (this file)            (below)
 *
 * IRQ early freeze (STP_REG = 1) happens in irq_early_hook — mirrors Bao.
 */

#include "ilc_latency.h"
#include "irq.h"
#include "drivers/gic/socfpga_interrupt.h"
#include "uart.h"

/* ── Strong irq_early_hook — matches Bao guest ilc_latency.c ────────────── */

void irq_early_hook(unsigned id)
{
    if (__builtin_expect(id == ILC_INTID, 1)) {
        mmio_write32(ILC_STP_REG, 1U);
    }
}

/* ── Ring buffer ─────────────────────────────────────────────────────────── */

ilc_ring_t g_ilc_ring;

/* ── Interval Timer helpers ──────────────────────────────────────────────── */

static void itimer_start(void)
{
    mmio_write32(ITIMER_CTRL_REG, ITIMER_CTRL_STOP);
    __asm__ volatile("dsb sy" ::: "memory");

    mmio_write32(ITIMER_STATUS_REG, 0U);
    __asm__ volatile("dsb sy" ::: "memory");

    mmio_write32(ITIMER_CTRL_REG, ITIMER_CTRL_RUN);
    __asm__ volatile("dsb sy" ::: "memory");
}

static inline void itimer_clear_irq(void)
{
    /* Device-nGnRnE: subsequent MMIO stores are strictly ordered with
     * respect to this one, so no explicit DSB is required here. The
     * previous read-back + double-DSB was dead weight inherited from
     * defensive code; the write itself is sufficient to clear the
     * timer's IRQ source line.                                        */
    mmio_write32(ITIMER_STATUS_REG, 0U);
}

/* ── ISR — called from irq_handle() after irq_early_hook() ──────────────── */

void ilc_isr(unsigned id)
{
    (void)id;

    /* 1. Check valid — ILC already frozen in irq_early_hook() */
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

    /* ILC init sequence */
    mmio_write32(ILC_CTRL_REG, 0x0U);
    __asm__ volatile("dsb sy" ::: "memory");
    mmio_write32(ILC_STP_REG, 0U);
    __asm__ volatile("dsb sy" ::: "memory");
    mmio_write32(ILC_CTRL_REG, 0x205U);
    __asm__ volatile("dsb sy" ::: "memory");

    irq_set_handler(ILC_INTID, ilc_isr);

    /* Configure GIC SPI: level-sensitive, targeted to this PE */
    interrupt_spi_enable(ILC_INTID, SPI_INTERRUPT_TYPE_LEVEL, SPI_INTERRUPT_MODE_TARGET, GIC_INTERRUPT_PRIORITY_ILC);

    /* Start interval timer */
    itimer_start();
}

/* ── Drain samples ───────────────────────────────────────────────────────── */

/* Per-sample drain. Output format mirrors the Bao VM1 per-sample line so the
 * two logs are directly diff-able if this function is enabled from main().
 * Main loop currently leaves this off the hot path (matches Bao VM1).       */
void ilc_drain_samples(void)
{
    ilc_ring_t *r = &g_ilc_ring;
    static uint32_t printed = 0U;

    while (r->tail != r->head) {
        uint32_t idx = r->tail;
        r->tail = (r->tail + 1U) & (ILC_RING_SIZE - 1U);
        printed++;
        uart_printf("[BM] ILC sample #%u: latency = %u ns  (%u cycles @ 100 MHz)\n", (unsigned)printed,
                    (unsigned)r->buf[idx].ns, (unsigned)r->buf[idx].cycles);
    }
}

/* ── Print stats ─────────────────────────────────────────────────────────── */
/*
 * Output format matches the Bao VM1 summary line exactly, except the prefix
 * is "[BM]" instead of "[VM1]":
 *
 *   [BM] ILC n=5 | min=1390 max=1630 avg=1600 ns
 *
 * min/max/avg are reported in nanoseconds (cycles * ILC_NS_PER_TICK) to keep
 * the comparison human-readable without further conversion.
 */
void ilc_print_stats(void)
{
    ilc_ring_t *r = &g_ilc_ring;
    uint32_t total = r->total;

    if (total == 0U) {
        uart_printf("[BM] no samples\n");
        return;
    }

    uint32_t avg_ns = (uint32_t)((r->sum_cycles / (uint64_t)total) * ILC_NS_PER_TICK);
    uint32_t min_ns = r->min_cycles * (uint32_t)ILC_NS_PER_TICK;
    uint32_t max_ns = r->max_cycles * (uint32_t)ILC_NS_PER_TICK;

    uart_printf("[BM] ILC n=%u | min=%u max=%u avg=%u ns\n", (unsigned)total, (unsigned)min_ns, (unsigned)max_ns,
                (unsigned)avg_ns);
}
