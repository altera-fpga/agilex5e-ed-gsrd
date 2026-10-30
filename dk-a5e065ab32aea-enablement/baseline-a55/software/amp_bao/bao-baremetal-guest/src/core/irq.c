/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#include <core.h>
#include <irq.h>

irq_handler_t irq_handlers[IRQ_NUM];

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

__attribute__((weak)) void irq_clear_ipi(void)
{
    // Default implementation, doing nothing
    // Each architecture should rewrite and override this function if need
}

/* Weak default for the arch-level early IRQ hook. Application code may
 * provide a strong override to run latency-sensitive work as soon as
 * the IRQ is ack'd, before the generic handler-table dispatch. See
 * the declaration in <irq.h> for the contract.                        */
__attribute__((weak)) void irq_early_hook(unsigned id)
{
    (void)id;
}
