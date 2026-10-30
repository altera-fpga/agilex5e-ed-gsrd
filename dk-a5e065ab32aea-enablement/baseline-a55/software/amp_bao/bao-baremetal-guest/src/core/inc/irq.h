/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef IRQ_H
#define IRQ_H

#include <core.h>
#include <arch/irq.h>

typedef void (*irq_handler_t)(unsigned id);

void irq_handle(unsigned id);
void irq_set_handler(unsigned id, irq_handler_t handler);
void irq_enable(unsigned id);
void irq_set_prio(unsigned id, unsigned prio);
void irq_send_ipi(unsigned long target_cpu_mask);

void irq_clear_ipi(void);

/* irq_early_hook(id)
 *
 * Called by the arch-level IRQ dispatcher (e.g. gic_handle on armv8)
 * IMMEDIATELY after the interrupt is acknowledged at the CPU interface
 * and BEFORE the generic handler-table dispatch in irq_handle().
 *
 * Purpose: provide a customer-overridable fast-path slot for the most
 * latency-sensitive work a driver can possibly do on an interrupt —
 * freezing a cycle counter, stamping a timestamp, toggling a GPIO,
 * kicking a DMA, etc. — at the earliest software point reachable in
 * the guest.
 *
 * Default is a no-op (see src/core/irq.c). Override with a strong
 * definition in application code, typically in the same .c file
 * that owns the fast-path IRQ.
 *
 * Contract:
 *   - Runs with DAIF.I masked (same as any ISR body in this codebase).
 *   - Must be leaf and short: a typical body is a single compare-and-
 *     branch plus one MMIO store. No printf, no uart_puts, no ring
 *     operations, no HVCs.
 *   - Must remain deterministic in branch prediction: prefer a single
 *     `switch` with `default: break` over deeply nested logic.
 *   - Does not acknowledge or EOI the interrupt — that remains the job
 *     of the arch dispatcher / the registered handler.
 */
void irq_early_hook(unsigned id);

#endif // IRQ_H
