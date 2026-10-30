/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 *
 * ilc_latency.h — ILC Interrupt Latency Counter for Bao baremetal guest
 *
 * Hardware (Agilex5 LWH2F bridge):
 *   Interval Timer : ITIMER_BASE (from plat.h)
 *   ILC soft IP    : ILC_BASE    (from plat.h)
 *   Clock          : ILC_FREQ_HZ (from plat.h, 100 MHz)
 *
 * F2H IRQ path:
 *   F2H IRQ0[1] → GICv3 SPI 18 → intid 50 (ILC_INTID from plat.h)
 */

#ifndef ILC_LATENCY_H
#define ILC_LATENCY_H

#include <stdint.h>
#include <plat.h>

/* ── Interval Timer registers ────────────────────────────────────────────── */

#define ITIMER_STATUS_REG (ITIMER_BASE + 0x00UL)
#define ITIMER_CTRL_REG (ITIMER_BASE + 0x04UL)
#define ITIMER_PERIOD_LO (ITIMER_BASE + 0x08UL)
#define ITIMER_PERIOD_HI (ITIMER_BASE + 0x0CUL)

#define ITIMER_CTRL_ITO (1U << 0)
#define ITIMER_CTRL_CONT (1U << 1)
#define ITIMER_CTRL_START (1U << 2)
#define ITIMER_CTRL_STOP (1U << 3)
#define ITIMER_CTRL_RUN (ITIMER_CTRL_ITO | ITIMER_CTRL_CONT | ITIMER_CTRL_START)

/* ── ILC registers (from Linux altera_ilc.c) ─────────────────────────────── */

#define ILC_CNT_REG (ILC_BASE + 0x00UL)
#define ILC_CTRL_REG (ILC_BASE + 0x80UL)
#define ILC_FREQ_REG (ILC_BASE + 0x84UL)
#define ILC_STP_REG (ILC_BASE + 0x88UL)
#define ILC_VLD_REG (ILC_BASE + 0x8CUL)

#define ILC_NS_PER_TICK (1000000000UL / ILC_FREQ_HZ) /* 10 ns at 100MHz */

/* ── MMIO accessors (shared with other drivers via mmio.h) ──────────────── */
#include <mmio.h>

/* ── Ring buffer ─────────────────────────────────────────────────────────── */

#define ILC_RING_SIZE 64U

typedef struct {
    uint32_t cycles;
    uint32_t ns;
} ilc_sample_t;

typedef struct {
    ilc_sample_t buf[ILC_RING_SIZE]; /* written by ISR, read by drain — same core, post-WFI */
    volatile uint32_t head; /* ISR writes, drain reads */
    volatile uint32_t tail; /* drain reads/writes, ISR reads */
    volatile uint32_t total; /* ISR writes, main loop polls */
    uint32_t overruns; /* ISR only */
    uint32_t min_cycles; /* ISR only */
    uint32_t max_cycles; /* ISR only */
    uint64_t sum_cycles; /* ISR only */
} ilc_ring_t;

/* ── Public API ──────────────────────────────────────────────────────────── */

void ilc_init(void);
void ilc_drain_samples(void);
void ilc_print_stats(void);
void ilc_isr(unsigned id);

extern ilc_ring_t g_ilc_ring;

#endif /* ILC_LATENCY_H */
