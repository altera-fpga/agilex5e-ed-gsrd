/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef __UART_H__
#define __UART_H__

void uart_init(void);
void uart_putc(char c);
char uart_getchar(void);
void uart_enable_rxirq();
void uart_clear_rxirq();

#endif
