/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef ARCH_IRQ_H
#define ARCH_IRQ_H

#define IPI_IRQ_ID (0)
#define TIMER_IRQ_ID (27)
#define IRQ_NUM (1024)
#define IRQ_MAX_PRIO (0)

#define UART_IRQ_PRIO IRQ_MAX_PRIO
#define TIMER_IRQ_PRIO IRQ_MAX_PRIO
#define IPI_IRQ_PRIO IRQ_MAX_PRIO

#endif /* ARCH_IRQ_H */
