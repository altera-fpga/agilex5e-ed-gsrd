/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/**
 * uart.h — Forward declarations for bare-metal UART driver
 */

#ifndef UART_H
#define UART_H

void uart_putc(char c);
void uart_puts(const char *s);
int uart_printf(const char *fmt, ...);

#endif /* UART_H */
