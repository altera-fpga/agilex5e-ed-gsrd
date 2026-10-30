/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * uart_tx_ring.h — IRQ-driven UART TX ring buffer for Agilex5 VM1
 *
 * uart_puts() copies into the ring and returns; the THRE ISR drains it to the
 * HW FIFO. Single serialisation point (arrival order). Size is a power of 2;
 * 2 KB covers the worst burst (~50B IPI stats + a few 256B VM2 log slots).
 */

#ifndef UART_TX_RING_H
#define UART_TX_RING_H

#include <stdint.h>
#include <stdbool.h>

#define UART_TX_RING_SZ 2048U /* power of 2 */

typedef struct {
    volatile uint16_t head; /* producer index (uart_puts) */
    volatile uint16_t tail; /* consumer index (THRE ISR)  */
    char buf[UART_TX_RING_SZ];
    uint32_t dropped; /* producer-only: bytes dropped on full ring (via
                       * uart_tx_ring_dropped()), monotonic */
} uart_tx_ring_t;

extern uart_tx_ring_t g_uart_tx_ring;
extern bool g_uart_irq_ready;

/* Initialise ring and cache UART base. Called before GIC is ready.
 * g_uart_irq_ready stays false until uart_irq_init() is called. */
void uart_tx_ring_init(unsigned long base);

/* Register UART THRE ISR with GIC and enable the interrupt.
 * Call from main() once the GIC is ready.
 * Sets g_uart_irq_ready = true so uart_puts() switches to ring mode. */
void uart_irq_init(void);

/* Push a NUL-terminated string into the TX ring. SPSC producer: main-thread
 * only, never from an ISR (consumer is uart_thre_isr). Drops silently if full. */
void uart_tx_ring_push(const char *s);

/* Enable THRE interrupt to start draining the ring. */
void uart_thre_irq_enable(void);

/* THRE ISR — registered via irq_set_handler(UART_IRQ_ID, uart_thre_isr) */
void uart_thre_isr(unsigned id);

/* Total bytes dropped since boot due to a full ring (monotonic). Non-zero means
 * output is outrunning the THRE drain — grow UART_TX_RING_SZ, raise baud, or
 * throttle the producer. */
uint32_t uart_tx_ring_dropped(void);

/* Block until all queued bytes are transmitted (SW ring empty AND LSR.TEMT).
 * For panic / pre-reset paths; main-thread with UART IRQ unmasked (else deadlock). */
void uart_tx_ring_flush_sync(void);

#endif /* UART_TX_RING_H */
