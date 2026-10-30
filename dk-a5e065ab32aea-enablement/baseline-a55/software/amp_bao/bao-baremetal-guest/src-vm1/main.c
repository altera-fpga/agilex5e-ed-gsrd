/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */
/**
 * main.c — VM1: UART printer + cross-core IPI-latency receiver (Agilex5)
 *
 * VM1 owns UART0 and is the only VM that prints to the console.
 * UART0 directly (mapped as a Stage-2 Device region in config.c) and is the
 * only VM that prints to the console.
 *
 * The latency-measurement work (ILC + interval timer + GPIO LED) lives in
 * VM2. VM2 has no UART: it writes log strings into a vm2_log_ring_t in shmem
 * (shmem_msg.h) and, on every ILC sample, fires the Bao IPC hypercall. Bao
 * injects virtual SGI 2 into VM1. VM1:
 *   - wakes from WFI on that SGI,
 *   - drains the log ring and prints each entry verbatim to UART0,
 *   - in the SGI ISR, measures the cross-core VM2 → VM1 hypercall latency
 *     using the ipi_send_ticks VM2 stamped just before the notify.
 *
 * SHMEM IPA: 0xC0000000 (256 MB, Bao IPC shmem_id=0).
 *
 * Boot order matters on the autoboot path: VM2 can already be producing ILC
 * samples by the time VM1 reaches main(). Any multi-line drain done in
 * polling uart_puts() (before uart_irq_init) stalls for seconds on the
 * DW-APB UART after U-Boot/FPGA bring-up, overflows the log ring, and
 * misses IPC SGIs → log drops + inflated IPI latency. So IRQ TX + IPC are
 * armed before the first banner / drain.
 */

#include <core.h>
#include <cpu.h>
#include <plat.h>
#include <irq.h>
#include <arch/timer.h>

#include <shmem_msg.h>
#include "drivers/uart/uart.h"
#include "drivers/uart/uart_tx_ring.h"

/* ── SGI used for IPC notification from VM2 ────────────────────────────── */
#define IPC_SGI_ID 2U /* must match VM1 ipc.interrupts[0] in Bao config */

/* ── VM2 log ring: consumer side (VM1 owns tail) ────────────────────────── */

static void vm1_log_ring_init(void)
{
    VM2_LOG->tail = 0U;
}

/* Report any new VM2 log-ring drops since the last check. VM2 publishes a
 * dropped counter in shmem; VM1 prints one warning line per new drop batch
 * so sustained ring overflow is visible but doesn't spam the console. */
static void vm1_check_vm2_log_drops(void)
{
    static uint32_t last_reported = 0U;
#if SHMEM_IS
    __asm__ volatile("dmb ishld" ::: "memory");
#endif
    uint32_t cur = VM2_LOG->dropped;
    if (cur != last_reported) {
        uart_puts("[VM1] WARN: VM2 log drops=");
        uart_put_uint(cur);
        uart_puts("\n");
        last_reported = cur;
    }
}

/* Drain pending VM2 log entries to UART0. Cross-core SPSC (VM2 producer, VM1
 * consumer): VM2 writes data[] then len; VM1 reads len, dmb, data[], clears
 * len, dmb, advances tail.
 *
 * Capped at one ring pass so a garbage/full ring cannot livelock boot, and
 * len is validated + NUL-clamped so a bad entry cannot overrun uart_puts(). */
static void vm1_drain_vm2_log(void)
{
    vm2_log_ring_t *ring = VM2_LOG;

    for (unsigned pass = 0U; pass < VM2_LOG_SLOTS; pass++) {
        uint8_t tail = ring->tail;
        uint8_t slot = tail & (uint8_t)(VM2_LOG_SLOTS - 1U);
        uint8_t len = ring->slots[slot].len;
        if (len == 0U)
            break; /* ring empty */
        __asm__ volatile("dmb ishld" ::: "memory"); /* acquire: data[] after len */
        if (len <= (uint8_t)(VM2_LOG_SLOT_SZ - 1U)) {
            ring->slots[slot].data[VM2_LOG_SLOT_SZ - 1U] = '\0'; /* clamp */
            uart_puts(ring->slots[slot].data);
        }
        ring->slots[slot].len = 0U; /* release slot back to VM2 */
        __asm__ volatile("dmb ish" ::: "memory"); /* release: clear before tail */
        ring->tail = (uint8_t)((tail + 1U) & (VM2_LOG_SLOTS - 1U));
    }
}

/* ── Cross-core IPI latency (VM2 → VM1 hypercall → SGI) ──────────────────── *
 *
 * IPI latency uses read_cntvct() (CNTVCT_EL0), a single system counter shared
 * by all cores. Tick → ns conversion uses CNTFRQ_EL0 (TIMER_FREQ, valid after
 * arch_init()).
 */

static uint32_t g_ipi_count;
static uint64_t g_ipi_sum_delta;
static uint32_t g_ipi_min_ticks = 0xFFFFFFFFUL;
static uint32_t g_ipi_max_ticks;

static uint32_t cntvct_ticks_to_ns(uint32_t ticks)
{
    unsigned long hz = TIMER_FREQ;
    if (hz == 0UL)
        return 0U;
    return (uint32_t)(((uint64_t)ticks * 1000000000ULL) / (uint64_t)hz);
}

/* IPC ISR — runs when VM2 notifies. Stamp arrival, read VM2's send time
 * from shmem, and record the delta. Kept light: no UART here (uart_puts is
 * the TX-ring producer and must stay main-thread only). */
static void ipc_isr(unsigned id)
{
    (void)id;

    uint64_t recv_ticks = read_cntvct();

    shmem_msg_t *msg = SHMEM_MSG;

    /* Acquire: observe ipi_send_ticks only after seeing the data VM2
     * committed before the notify. */
    __asm__ volatile("dmb ishld" ::: "memory");

    uint64_t send_ticks = msg->ipi_send_ticks;
    msg->ready = 0U;
    __dsb_sy();

    uint64_t delta = recv_ticks - send_ticks;
    if (delta > 0x7FFFFFFFULL)
        delta = 0;

    g_ipi_count++;
    g_ipi_sum_delta += delta;
    uint32_t d32 = (uint32_t)delta;
    if (d32 < g_ipi_min_ticks)
        g_ipi_min_ticks = d32;
    if (d32 > g_ipi_max_ticks)
        g_ipi_max_ticks = d32;
}

/* Print the rolling IPI latency summary. Snapshots the ISR-updated counters
 * with IRQs briefly masked to avoid a torn 64-bit read, then prints from
 * main-thread context. */
static void vm1_print_ipi_stats(void)
{
    uint32_t n;
    uint64_t sum;
    uint32_t min_ticks, max_ticks;

    __asm__ volatile("msr daifset, #2" ::: "memory"); /* mask IRQ */
    n = g_ipi_count;
    sum = g_ipi_sum_delta;
    min_ticks = g_ipi_min_ticks;
    max_ticks = g_ipi_max_ticks;
    __asm__ volatile("msr daifclr, #2" ::: "memory"); /* unmask IRQ */

    if (n == 0U)
        return;

    unsigned long hz = TIMER_FREQ;
    uint32_t avg_ns = (hz != 0UL) ? (uint32_t)((sum * 1000000000ULL) / ((uint64_t)hz * (uint64_t)n)) : 0U;

    uart_puts("[VM1] IPI n=");
    uart_put_uint(n);
    uart_puts(" | min=");
    uart_put_uint(cntvct_ticks_to_ns(min_ticks));
    uart_puts(" max=");
    uart_put_uint(cntvct_ticks_to_ns(max_ticks));
    uart_puts(" avg=");
    uart_put_uint(avg_ns);
    uart_puts(" ns\n");
}

void __attribute__((noreturn)) main(void)
{
    /* IRQ TX + IPC first — before any banner or shmem drain. On autoboot VM2
     * is already live; polling uart_puts() here is what made the console crawl
     * and blew the IPI numbers. */
    uart_tx_ring_init(PLAT_UART_ADDR);
    uart_irq_init();

    irq_set_handler(IPC_SGI_ID, ipc_isr);
    irq_enable(IPC_SGI_ID);
    irq_set_prio(IPC_SGI_ID, 0);

    uart_puts("\n*** [VM1] — UART printer\n");

    vm1_log_ring_init();

    uart_puts("[VM1] printer ready\n");

    /* Catch anything VM2 already published (boot banner / early samples)
     * before the first WFI — still on the IRQ TX path, so this is fast. */
    vm1_drain_vm2_log();

    /* Main loop: WFI between interrupts. Wakes on the IPC SGI (VM2 notify)
     * or the UART THRE IRQ. */
    uint32_t last_ipi_stats_at = 0U;

    while (1) {
        __asm__ volatile("wfi" ::: "memory");

        vm1_drain_vm2_log();
        vm1_check_vm2_log_drops();

        uint32_t n = g_ipi_count;
        if (n >= last_ipi_stats_at + IPI_STAT_INTERVAL) {
            vm1_print_ipi_stats();
            last_ipi_stats_at = n;
        }
    }
}
