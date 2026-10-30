/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef __SERIAL_UART8250_H__
#define __SERIAL_UART8250_H__

#include <core.h>

typedef uint32_t u32;
typedef uint16_t u16;

/* ── Register offsets (16550-compatible, pre-shift) ────────────────────────
 * Final MMIO byte offset is (offset << reg_shift); on Agilex5 / DW-APB-UART
 * reg_shift=2, so e.g. LSR is at byte offset 0x14.
 * Defined here so TX/RX helper drivers can share symbolic names. */
#ifndef UART_RBR_OFFSET
#define UART_RBR_OFFSET 0U /* In:  Receive Buffer Register */
#define UART_THR_OFFSET 0U /* Out: Transmitter Holding Register */
#define UART_DLL_OFFSET 0U /* Out: Divisor Latch Low */
#define UART_IER_OFFSET 1U /* I/O: Interrupt Enable Register */
#define UART_DLM_OFFSET 1U /* Out: Divisor Latch High */
#define UART_FCR_OFFSET 2U /* Out: FIFO Control Register */
#define UART_IIR_OFFSET 2U /* I/O: Interrupt Identification Register */
#define UART_LCR_OFFSET 3U /* Out: Line Control Register */
#define UART_MCR_OFFSET 4U /* Out: Modem Control Register */
#define UART_LSR_OFFSET 5U /* In:  Line Status Register */
#define UART_MSR_OFFSET 6U /* In:  Modem Status Register */
#define UART_SCR_OFFSET 7U /* I/O: Scratch Register */

/* IER bits */
#define UART_IER_ERBFI (1U << 0) /* RX data available */
#define UART_IER_ETBEI (1U << 1) /* TX holding reg empty (THRE) */
#define UART_IER_ELSI (1U << 2) /* Receiver line status */
#define UART_IER_EDSSI (1U << 3) /* Modem status */

/* LSR bits */
#define UART_LSR_DR (1U << 0) /* Data ready */
#define UART_LSR_OE (1U << 1) /* Overrun error */
#define UART_LSR_PE (1U << 2) /* Parity error */
#define UART_LSR_FE (1U << 3) /* Framing error */
#define UART_LSR_BI (1U << 4) /* Break indicator */
#define UART_LSR_THRE (1U << 5) /* TX holding register empty */
#define UART_LSR_TEMT (1U << 6) /* Transmitter empty (FIFO+THR drained) */
#define UART_LSR_FIFOE (1U << 7) /* FIFO error */

/* DesignWare APB UART extension: UART Status Register (USR) at byte offset
 * 0x7C (register 31 when reg_shift=2, as on Agilex5). On this UART LSR.THRE
 * only asserts when the TX FIFO is *fully* empty and can remain 0 under
 * continuous output, so a plain THRE poll can spin forever. USR.TFNF
 * ("TX FIFO not full") reliably reports writable FIFO space. */
#define UART_USR_OFFSET 31U /* 0x7C >> reg_shift(2) */
#define UART_USR_TFNF (1U << 1) /* TX FIFO not full */
#endif /* UART_RBR_OFFSET */

void uart8250_enable_rx_int(void);

void uart8250_putc(char ch);

int uart8250_getc(void);

void uart8250_set_base(unsigned long base, u32 reg_shift, u32 reg_width);
void uart8250_interrupt_handler(void);

#endif
