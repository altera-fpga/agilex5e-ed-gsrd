/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/**
 * uart.c — Minimal polled UART driver for Agilex5 SoCFPGA (16550-compatible)
 *
 * TX only, interrupt-free, no DMA.
 * Assumes UART is already configured by U-Boot / ATF (baud rate, 8N1).
 * We only need to poll THRE and push characters.
 *
 * If Linux owns UART0, either:
 *   a) Use UART1 (0x10C02100) — change UART0_BASE in platform.h
 *   b) Use HPS UART with a dedicated A55 UART instance
 *   c) Use Bao HVC console (no UART needed in that case)
 */

#include "uart.h"
#include <stdint.h>

/* UART0 base — Agilex5 SoCFPGA */
#define UART0_BASE 0x10C02000UL
#define UART_THR 0x00U
#define UART_LSR 0x14U
#define UART_LSR_THRE (1U << 5)

static inline uint32_t mmio_read32_uart(uintptr_t addr)
{
    return *((volatile uint32_t *)addr);
}
static inline void mmio_write32_uart(uintptr_t addr, uint32_t val)
{
    *((volatile uint32_t *)addr) = val;
}

/* ── Internal helpers ────────────────────────────────────────────────────── */

static inline void _uart_wait_tx_ready(void)
{
    while (!(mmio_read32_uart(UART0_BASE + UART_LSR) & UART_LSR_THRE)) {
    }
}

/* ── Public API ──────────────────────────────────────────────────────────── */

void uart_putc(char c)
{
    if (c == '\n') {
        _uart_wait_tx_ready();
        mmio_write32_uart(UART0_BASE + UART_THR, '\r');
    }
    _uart_wait_tx_ready();
    mmio_write32_uart(UART0_BASE + UART_THR, (uint32_t)(unsigned char)c);
}

void uart_puts(const char *s)
{
    while (*s) {
        uart_putc(*s++);
    }
}

/* ── Minimal printf — no heap, no libc ──────────────────────────────────── */
/*
 * Supports: %d (int32), %u (uint32), %x (uint32 hex lower), %s, %c, %%
 * Does NOT support: %f, %lld, %p, width/precision specifiers
 * Sufficient for "[ILC] cycles=%d ns=%d\r\n" style output.
 */

/*
 * _put_uint — render an unsigned 32-bit value in the given base.
 *
 * Base is restricted to 10 (decimal) or 16 (hex) by the callers above;
 * buf[12] is sized for the longest decimal representation of UINT32_MAX
 * (10 digits).  Passing base < 2 or base > 36 would produce garbage
 * characters — callers must not do so.  On aarch64, int == int32_t, so
 * the %d path in uart_printf() correctly passes a 32-bit signed value.
 */
static void _put_uint(uint32_t val, uint32_t base)
{
    char buf[12];
    int pos = 0;

    if (val == 0) {
        uart_putc('0');
        return;
    }

    while (val > 0 && pos < (int)sizeof(buf)) {
        uint32_t digit = val % base;
        buf[pos++] = (digit < 10) ? (char)('0' + digit) : (char)('a' + digit - 10);
        val /= base;
    }

    /* buf holds digits in reverse order */
    while (pos > 0) {
        uart_putc(buf[--pos]);
    }
}

static void _put_int(int32_t val)
{
    if (val < 0) {
        uart_putc('-');
        /* avoid UB on INT32_MIN by casting to unsigned before negating */
        _put_uint((uint32_t)(-(val + 1)) + 1U, 10U);
    } else {
        _put_uint((uint32_t)val, 10U);
    }
}

int uart_printf(const char *fmt, ...)
{
    /*
     * Manual va_list — uses __builtin_va_* which works with
     * aarch64-none-elf-gcc without pulling in libc headers.
     */
    __builtin_va_list ap;
    __builtin_va_start(ap, fmt);

    const char *p = fmt;
    while (*p) {
        if (*p != '%') {
            uart_putc(*p++);
            continue;
        }
        p++; /* skip '%' */
        switch (*p) {
        case 'd':
            _put_int(__builtin_va_arg(ap, int));
            break;
        case 'u':
            _put_uint(__builtin_va_arg(ap, unsigned int), 10U);
            break;
        case 'x':
            _put_uint(__builtin_va_arg(ap, unsigned int), 16U);
            break;
        case 's': {
            const char *s = __builtin_va_arg(ap, const char *);
            if (s)
                uart_puts(s);
            else
                uart_puts("(null)");
            break;
        }
        case 'c':
            uart_putc((char)__builtin_va_arg(ap, int));
            break;
        case '%':
            uart_putc('%');
            break;
        default:
            uart_putc('%');
            uart_putc(*p);
            break;
        }
        p++;
    }

    __builtin_va_end(ap);
    return 0; /* return value unused */
}
