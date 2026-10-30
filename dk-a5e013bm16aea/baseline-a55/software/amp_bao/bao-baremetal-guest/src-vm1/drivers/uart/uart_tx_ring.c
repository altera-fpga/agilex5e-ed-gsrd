/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * uart_tx_ring.c — IRQ-driven UART TX ring buffer for Agilex5 VM1
 *
 *   Producer (uart_puts): copy string into the SW ring, then arm the THRE IRQ.
 *   Consumer (uart_thre_isr): drain SW ring -> HW FIFO while LSR.THRE set;
 *                             disable THRE IRQ once empty (no spurious firing).
 * The ring is the single serialisation point (arrival order, no FIFO interleave).
 *
 * ISR priorities: IPC SGI 0x00 (always preempts) > THRE 0xa0.
 * HW (Agilex5 8250 / DW-APB): FIFO 64B; 32-bit regs, reg_shift 2; LSR.THRE (bit5).
 * SPSC, same core (SINGLE_CORE=y) — NOT SMP-safe as-is.
 */

#include "uart_tx_ring.h"
#include <stdbool.h>
#include <8250_uart.h>
#include <plat.h>
#include <irq.h>

/* ── Globals ─────────────────────────────────────────────────────────────── */

uart_tx_ring_t g_uart_tx_ring;
bool g_uart_irq_ready = false;

/* Byte-addressable MMIO base; register offsets are explicitly shifted
 * by PLAT_UART_REG_SHIFT inside the helpers below. */
static volatile uint8_t *uart_base;

/* SPSC ordering barriers: producer makes buf[head] visible before head=next;
 * consumer keeps the buf[tail] load after the head read that authorised it.
 * Effectively free on single-core, but encode the contract for a future SMP port. */
#define SMP_STORE_BARRIER_STORE() __asm__ volatile("dmb ishst" ::: "memory")
#define SMP_LOAD_BARRIER() __asm__ volatile("dmb ishld" ::: "memory")

/* 32-bit MMIO only; fail the build loudly if a platform needs 8/16-bit. */
_Static_assert(PLAT_UART_REG_WIDTH == 4U, "uart_tx_ring only supports 32-bit UART MMIO accesses "
                                          "(PLAT_UART_REG_WIDTH must be 4)");

/* ── Internal helpers ────────────────────────────────────────────────────── */

static inline uint32_t uart_reg_read(uint32_t reg)
{
    return *(volatile uint32_t *)(uart_base + (reg << PLAT_UART_REG_SHIFT));
}

static inline void uart_reg_write(uint32_t reg, uint32_t val)
{
    *(volatile uint32_t *)(uart_base + (reg << PLAT_UART_REG_SHIFT)) = val;
}

/* ── Public API ──────────────────────────────────────────────────────────── */

void uart_tx_ring_init(unsigned long base)
{
    uart_base = (volatile uint8_t *)base;
    g_uart_tx_ring.head = 0U;
    g_uart_tx_ring.tail = 0U;
    g_uart_tx_ring.dropped = 0U;
    /* g_uart_irq_ready stays false until uart_irq_init() is called */
}

void uart_irq_init(void)
{
    irq_set_handler(UART_IRQ_ID, uart_thre_isr);
    irq_enable(UART_IRQ_ID);
    /* Priority 0xa0 — lower than ILC (0x00) so ILC always preempts THRE ISR */
    irq_set_prio(UART_IRQ_ID, 0xa0);
    g_uart_irq_ready = true;
}

/*
 * uart_tx_ring_push — copy string into TX ring (SPSC producer, main-thread
 * only). Bumps r->dropped for every byte that does not fit.
 */
void uart_tx_ring_push(const char *s)
{
    uart_tx_ring_t *r = &g_uart_tx_ring;
    const uint16_t mask = (uint16_t)(UART_TX_RING_SZ - 1U);

    while (*s) {
        char c = *s++;

        if (c == '\n') {
            /* Emit '\n' as "\r\n" atomically: reserve both slots or drop both
             * (never leave a bare '\r' on the wire). */
            uint16_t next1 = (r->head + 1U) & mask;
            uint16_t next2 = (next1 + 1U) & mask;
            if (next1 == r->tail || next2 == r->tail) {
                /* No room for \r\n — drop both + the rest so the count is real. */
                r->dropped += 2U;
                while (*s) {
                    r->dropped++;
                    s++;
                }
                break;
            }
            r->buf[r->head] = '\r';
            r->buf[next1] = '\n';
            SMP_STORE_BARRIER_STORE();
            r->head = next2;
            continue;
        }

        uint16_t next = (r->head + 1U) & mask;
        if (next == r->tail) {
            /* Ring full — count this byte plus everything remaining. */
            r->dropped++;
            while (*s) {
                r->dropped++;
                s++;
            }
            break;
        }
        r->buf[r->head] = c;
        SMP_STORE_BARRIER_STORE();
        r->head = next;
    }
}

uint32_t uart_tx_ring_dropped(void)
{
    return g_uart_tx_ring.dropped;
}

void uart_thre_irq_enable(void)
{
    uart_reg_write(UART_IER_OFFSET, UART_IER_ETBEI);
}

void uart_thre_isr(unsigned id)
{
    (void)id;
    uart_tx_ring_t *r = &g_uart_tx_ring;
    const uint16_t mask = (uint16_t)(UART_TX_RING_SZ - 1U);

    if (r->tail == r->head) {
        /* Spurious or already-drained: disable THRE IRQ and exit. */
        uart_reg_write(UART_IER_OFFSET, 0U);
        return;
    }

    /* Pair with the producer store barrier (buf[tail] loads after head read). */
    SMP_LOAD_BARRIER();

    /* Batched push: THRE asserts only when the TX FIFO is fully empty, so after
     * one THRE read we can write up to PLAT_UART_TX_FIFO_DEPTH bytes without
     * re-checking LSR per byte. */
    if (uart_reg_read(UART_LSR_OFFSET) & UART_LSR_THRE) {
        unsigned pushed = 0U;
        while (r->tail != r->head && pushed < PLAT_UART_TX_FIFO_DEPTH) {
            uart_reg_write(UART_THR_OFFSET, (uint32_t)r->buf[r->tail]);
            r->tail = (r->tail + 1U) & mask;
            pushed++;
        }
    }

    /* Disable THRE IRQ when ring empty to avoid spurious firing.
     * NOTE: TX-only driver, so clearing IER to 0 is safe. Revisit if
     * RX interrupts are added — use read-modify-write on UART_IER_ETBEI. */
    if (r->tail == r->head) {
        uart_reg_write(UART_IER_OFFSET, 0U);
    }
}

/*
 * uart_tx_ring_flush_sync — block until all queued bytes are on the wire
 * (SW ring empty AND LSR.TEMT set). For panic / pre-reset paths.
 * Relies on the THRE ISR, so call from main-thread with the UART IRQ
 * unmasked — deadlocks if DAIF.I is set or called from an ISR.
 */
void uart_tx_ring_flush_sync(void)
{
    uart_tx_ring_t *r = &g_uart_tx_ring;

    if (!g_uart_irq_ready) {
        /* Polling mode: ring is unused, nothing queued — just drain HW. */
        while (!(uart_reg_read(UART_LSR_OFFSET) & UART_LSR_TEMT)) {
        }
        return;
    }

    /* Make sure the THRE IRQ is armed; otherwise a previously-emptied
     * ring that has just been re-filled would never start draining. */
    if (r->tail != r->head) {
        uart_thre_irq_enable();
    }

    while (r->tail != r->head) {
        /* Spin; the THRE ISR advances r->tail. */
    }

    /* SW ring drained — wait for the HW path to fully quiesce. */
    while (!(uart_reg_read(UART_LSR_OFFSET) & UART_LSR_TEMT)) {
    }
}
