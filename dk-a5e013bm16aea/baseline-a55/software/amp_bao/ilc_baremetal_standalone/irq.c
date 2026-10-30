/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/*
 * irq.c — Handler table + weak irq_early_hook (matches Bao src/core/irq.c shape).
 *
 * irq_log from full Bao is omitted to keep standalone small; comparison target
 * is ILC path identity, not debug logging.
 */

#include <stddef.h>
#include "irq.h"

/* GICv3 supports up to 1020 SPIs (IDs 32-1019) plus 32 SGI/PPIs.
 * 1024 is the next power-of-two that covers the full Agilex5 SPI range
 * (MAX_HPU_SPI_INTERRUPT ≈ 274) with room for any future additions.
 * Bao guest's src/arch/armv8/inc/arch/irq.h uses the same value.     */
#define IRQ_NUM 1024U

static irq_handler_t irq_handlers[IRQ_NUM];

void irq_set_handler(unsigned id, irq_handler_t handler)
{
    if (id < IRQ_NUM) {
        irq_handlers[id] = handler;
    }
}

void irq_handle(unsigned id)
{
    if (id < IRQ_NUM && irq_handlers[id] != NULL) {
        irq_handlers[id](id);
    }
}

__attribute__((weak)) void irq_early_hook(unsigned id)
{
    (void)id;
}
