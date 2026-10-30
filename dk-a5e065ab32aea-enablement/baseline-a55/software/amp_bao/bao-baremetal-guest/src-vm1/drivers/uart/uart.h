/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * uart.h — Public UART API for Agilex5 bare-metal Bao guest.
 *
 * Single include point (pulls in the TX-ring API). Init in main():
 *   1. uart_tx_ring_init(PLAT_UART_ADDR);   // before GIC ready
 *   2. ...GIC ready (framework arch init)...
 *   3. uart_irq_init();                     // flip to IRQ/ring mode
 * After step 3 uart_puts() is non-blocking; use uart_tx_ring_flush_sync()
 * on panic / pre-reset paths.
 */

#ifndef DRIVERS_UART_H
#define DRIVERS_UART_H

#include <stdint.h>
#include "uart_tx_ring.h" /* ring init / flush / dropped API */

/* Print a NUL-terminated string. Safe to pass NULL (no-op).
 * Ring/IRQ mode after uart_irq_init(); polling only if called before that. */
void uart_puts(const char *s);

/* Decimal-print an unsigned 32-bit integer. */
void uart_put_uint(uint32_t val);

/* Decimal-print a signed 32-bit integer (handles INT32_MIN correctly). */
void uart_put_int(int32_t val);

/* Hex-print val as exactly `digits` uppercase hex digits, no 0x prefix,
 * leading zeros kept (stable width for register/address dumps).
 * digits is clamped to 1..8. */
void uart_put_hex(uint32_t val, unsigned digits);

#endif /* DRIVERS_UART_H */
