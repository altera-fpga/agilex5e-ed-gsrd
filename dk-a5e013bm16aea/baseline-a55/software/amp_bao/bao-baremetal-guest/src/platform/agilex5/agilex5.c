/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 *
 * Platform init for Intel Agilex5 SoCFPGA — 8250-compatible UART.
 *
 * uart_init/uart_putc/uart_getchar/uart_enable_rxirq/uart_clear_rxirq
 * are the symbols required by the upstream bao-baremetal-runtime UART
 * API (see src/core/inc/uart.h). uart_putc() uses polling for early
 * boot; after uart_irq_init() is called the higher-level uart_puts()
 * in src-vm1/drivers/uart/uart.c routes output through the IRQ-driven TX
 * ring instead of uart_putc().
 *
 * RX is not currently used by this demo but the RX-IRQ stubs are kept
 * so the platform implements the full upstream API contract.
 */

#include <plat.h>
#include <8250_uart.h>

void uart_init(void)
{
    /*
     * UART already configured by U-Boot/ATF (115200, 8N1).
     * Only set the base/shift/width so putc/getc know where to write.
     * Do NOT reprogram divisor/LCR/FCR — that causes garbage output.
     */
    uart8250_set_base(PLAT_UART_ADDR, 2, 4);
}

void uart_putc(char c)
{
    uart8250_putc(c);
}

char uart_getchar(void)
{
    return (char)uart8250_getc();
}

void uart_enable_rxirq(void)
{
    uart8250_enable_rx_int();
}

void uart_clear_rxirq(void)
{
    (void)uart8250_getc(); /* read and discard — 8250 RBR read clears DR */
}
