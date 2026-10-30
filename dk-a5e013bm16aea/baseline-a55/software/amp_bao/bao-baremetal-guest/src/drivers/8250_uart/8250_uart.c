/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#include <8250_uart.h>

#define readb(addr) (*((volatile uint8_t *)addr))
#define writeb(val, addr) (*(volatile uint8_t *)(addr) = val)
#define readw(addr) (*((volatile uint16_t *)addr))
#define writew(val, addr) (*(volatile uint16_t *)(addr) = val)
#define readl(addr) (*((volatile uint32_t *)addr))
#define writel(val, addr) (*((volatile uint32_t *)addr) = val)

/* Register offsets and LSR bits are defined in <8250_uart.h> so that
 * helper drivers (e.g. the IRQ-driven TX ring) can share the same
 * symbolic names. Only additions local to this file live here: */
#define UART_MDR1_OFFSET 8U /* I/O: Mode Register (OMAP/DT ext.) */
#define UART_LSR_BRK_ERROR_BITS 0x1EU /* BI, FE, PE, OE bits */

static volatile void *uart8250_base;
static u32 uart8250_reg_width;
static u32 uart8250_reg_shift;

void uart8250_set_base(unsigned long base, u32 reg_shift, u32 reg_width)
{
    uart8250_base = (volatile void *)base;
    uart8250_reg_shift = reg_shift;
    uart8250_reg_width = reg_width;
}

static volatile u32 get_reg(u32 num)
{
    u32 offset = num << uart8250_reg_shift;

    if (uart8250_reg_width == 1) {
        return readb(uart8250_base + offset);
    } else if (uart8250_reg_width == 2) {
        return readw(uart8250_base + offset);
    } else {
        return readl(uart8250_base + offset);
    }
}

static void set_reg(u32 num, u32 val)
{
    u32 offset = num << uart8250_reg_shift;

    if (uart8250_reg_width == 1) {
        writeb(val, uart8250_base + offset);
    } else if (uart8250_reg_width == 2) {
        writew(val, uart8250_base + offset);
    } else {
        writel(val, uart8250_base + offset);
    }
}

void uart8250_putc(char ch)
{
    /* DW-APB UART: LSR.THRE only asserts when the TX FIFO is fully empty, so
     * a plain THRE poll can spin under continuous output. Also accept
     * USR.TFNF (TX FIFO not full). No spin cap — a timeout here was what made
     * the autoboot console crawl at ~1 char/s when THRE/TFNF were late. */
    for (;;) {
        if (get_reg(UART_LSR_OFFSET) & UART_LSR_THRE) {
            break;
        }
        if (get_reg(UART_USR_OFFSET) & UART_USR_TFNF) {
            break;
        }
    }

    set_reg(UART_THR_OFFSET, ch);
}

int uart8250_getc(void)
{
    if (get_reg(UART_LSR_OFFSET) & UART_LSR_DR) {
        return get_reg(UART_RBR_OFFSET);
    }
    return -1;
}

void uart8250_interrupt_handler(void)
{
    (void)get_reg(UART_RBR_OFFSET);
}

void uart8250_enable_rx_int(void)
{
    set_reg(UART_IER_OFFSET, 1);
}
