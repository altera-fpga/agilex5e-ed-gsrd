/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * uart.c — UART helpers for Agilex5 bare-metal Bao guest (VM1)
 *
 * uart_puts() routes on g_uart_irq_ready:
 *   false — polling fallback (busy-wait on LSR.THRE via uart_putc).
 *   true  — TX ring + THRE IRQ (uart_tx_ring_push; uart_thre_isr drains).
 *
 * VM1 main() calls uart_irq_init() before any uart_puts(), so the normal
 * path is ring-only. Polling remains only if something prints earlier.
 * See uart_tx_ring.{c,h} for the SPSC (single producer/consumer) contract.
 */

#include "uart.h"
#include "uart_tx_ring.h"
#include <uart.h> /* platform uart_putc — from src/core/inc/uart.h */

/*
 * Caller contract: uart_puts() is the sole ring producer (main-thread only,
 * never from an ISR); uart_thre_isr is the consumer. SINGLE_CORE=y, not SMP-safe.
 * No DAIF masking needed: pre-irq the UART IRQ isn't enabled yet; post-irq the
 * SPSC ring tolerates THRE-ISR preemption, and leaving IRQs unmasked lets the
 * higher-priority IPC SGI (0x00 vs THRE 0xa0) preempt even mid-print.
 */
void uart_puts(const char *s)
{
    if (!s)
        return;

    if (g_uart_irq_ready) {
        uart_tx_ring_push(s);
        uart_thre_irq_enable();
    } else {
        while (*s) {
            if (*s == '\n')
                uart_putc('\r');
            uart_putc(*s++);
        }
    }
}

/*
 * uart_put_uint / uart_put_int build the digits in a local buffer and emit one
 * uart_puts() call, so output routes through the TX ring (no per-digit polls).
 */
void uart_put_uint(uint32_t val)
{
    char buf[11]; /* 10 digits of UINT32_MAX + NUL */
    int pos = (int)sizeof(buf) - 1;
    buf[pos] = '\0';
    if (val == 0U) {
        buf[--pos] = '0';
    } else {
        while (val > 0U && pos > 0) {
            buf[--pos] = (char)('0' + (val % 10U));
            val /= 10U;
        }
    }
    uart_puts(&buf[pos]);
}

void uart_put_int(int32_t val)
{
    if (val >= 0) {
        uart_put_uint((uint32_t)val);
        return;
    }
    char buf[12]; /* '-' + 10 digits + NUL */
    int pos = (int)sizeof(buf) - 1;
    buf[pos] = '\0';
    /* INT32_MIN-safe two-step negate: -(val+1) is in [0, INT32_MAX],
     * then add 1 to reach the magnitude as an unsigned value. */
    uint32_t u = (uint32_t)(-(val + 1)) + 1U;
    do {
        buf[--pos] = (char)('0' + (u % 10U));
        u /= 10U;
    } while (u > 0U && pos > 1);
    buf[--pos] = '-';
    uart_puts(&buf[pos]);
}

void uart_put_hex(uint32_t val, unsigned digits)
{
    static const char hex[] = "0123456789ABCDEF";

    if (digits == 0U)
        digits = 1U;
    if (digits > 8U)
        digits = 8U;

    char buf[9]; /* up to 8 digits + NUL */
    buf[digits] = '\0';
    for (int i = (int)digits - 1; i >= 0; i--) {
        buf[i] = hex[val & 0xFU];
        val >>= 4;
    }
    uart_puts(buf);
}
