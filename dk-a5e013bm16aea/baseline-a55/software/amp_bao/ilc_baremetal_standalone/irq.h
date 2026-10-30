/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/*
 * irq.h — Minimal IRQ dispatch API matching Bao baremetal guest (Phase 9).
 *
 * Standalone links the same logical path as:
 *   src/arch/armv8/aarch64/exceptions.S → gic_handle() → irq_early_hook → irq_handle
 */

#ifndef IRQ_H
#define IRQ_H

#include <stdint.h>

typedef void (*irq_handler_t)(unsigned id);

void irq_handle(unsigned id);
void irq_set_handler(unsigned id, irq_handler_t handler);

void irq_early_hook(unsigned id);

#endif /* IRQ_H */
