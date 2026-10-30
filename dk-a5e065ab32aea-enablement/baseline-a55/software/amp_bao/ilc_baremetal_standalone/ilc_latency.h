/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/*
 * ilc_latency.h — ILC Interrupt Latency Counter, Agilex5 A55
 *
 * Shared register definitions and ring buffer for both:
 *   - Standalone bare-metal (EL2, physical GIC)
 *   - Bao hypervisor guest  (EL1, vGIC)
 *
 * Hardware (LWH2F bridge):
 *   Interval Timer : 0x20000000
 *   ILC soft IP    : 0x20000100
 *   Clock          : 100 MHz → 10 ns/tick
 *
 * F2H IRQ path:
 *   F2H IRQ0[1] → GICv3 SPI 18 → intid 50
 *
 * ILC register map (from Linux altera_ilc.c):
 *   CNT_REG  0x00  — up-counter (RO), latency in cycles
 *   CTRL_REG 0x80  — control: write 0x0 then 0x205 to init
 *   FREQ_REG 0x84  — IP clock frequency in Hz (100MHz)
 *   STP_REG  0x88  — 1=freeze counter, 0=re-arm
 *   VLD_REG  0x8C  — bit0=1: valid measurement captured
 */

#ifndef ILC_LATENCY_H
#define ILC_LATENCY_H

#include <stdint.h>

/* ── Interval Timer registers ────────────────────────────────────────────── */

#define ITIMER_BASE 0x20000000UL
#define ITIMER_STATUS_REG (ITIMER_BASE + 0x00UL)
#define ITIMER_CTRL_REG (ITIMER_BASE + 0x04UL)
#define ITIMER_PERIOD_LO (ITIMER_BASE + 0x08UL)
#define ITIMER_PERIOD_HI (ITIMER_BASE + 0x0CUL)

#define ITIMER_CTRL_ITO (1U << 0)
#define ITIMER_CTRL_CONT (1U << 1)
#define ITIMER_CTRL_START (1U << 2)
#define ITIMER_CTRL_STOP (1U << 3)
#define ITIMER_CTRL_RUN (ITIMER_CTRL_ITO | ITIMER_CTRL_CONT | ITIMER_CTRL_START)

/* ~4 s at 100 MHz: 400000000 - 1 = 0x17D783FF */
#define ITIMER_PERIOD_VAL 0x17D783FFUL

/* ── ILC registers ───────────────────────────────────────────────────────── */

#define ILC_BASE 0x20000100UL
#define ILC_CNT_REG (ILC_BASE + 0x00UL)
#define ILC_CTRL_REG (ILC_BASE + 0x80UL)
#define ILC_FREQ_REG (ILC_BASE + 0x84UL)
#define ILC_STP_REG (ILC_BASE + 0x88UL)
#define ILC_VLD_REG (ILC_BASE + 0x8CUL)

#define ILC_CTRL_RESET 0x000U
#define ILC_CTRL_ENABLE 0x205U

#define ILC_FREQ_HZ 100000000UL
#define ILC_NS_PER_TICK 10UL

/* ── GIC interrupt ID ────────────────────────────────────────────────────── */

#define ILC_INTID 50U /* FPGA2HPS_INTERRUPT1 = SPI 18 = intid 50 */

/* ── MMIO accessors ──────────────────────────────────────────────────────── */

static inline uint32_t mmio_read32(uintptr_t addr)
{
    return *((volatile uint32_t *)addr);
}
static inline void mmio_write32(uintptr_t addr, uint32_t val)
{
    *((volatile uint32_t *)addr) = val;
}

/* ── Ring buffer ─────────────────────────────────────────────────────────── */

#define ILC_RING_SIZE 64U

typedef struct {
    uint32_t cycles;
    uint32_t ns;
} ilc_sample_t;

typedef struct {
    volatile ilc_sample_t buf[ILC_RING_SIZE];
    volatile uint32_t head;
    volatile uint32_t tail;
    volatile uint32_t total;
    volatile uint32_t overruns;
    volatile uint32_t min_cycles;
    volatile uint32_t max_cycles;
    volatile uint64_t sum_cycles;
} ilc_ring_t;

/* ── Public API ──────────────────────────────────────────────────────────── */

void ilc_init(void);
void ilc_drain_samples(void);
void ilc_print_stats(void);

/* ISR — Bao-matched signature: (unsigned id) from irq_handle() */
void ilc_isr(unsigned id);

extern ilc_ring_t g_ilc_ring;

#endif /* ILC_LATENCY_H */
