/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/*
 * gic_handle.c — Arch IRQ dispatcher matching Bao src/arch/armv8/gicv3.c::gic_handle().
 *
 * Called from vectors.S with no arguments; IAR read stays here (not in assembly)
 * so the sequence matches the Bao baremetal guest byte-for-byte in structure.
 */

#include <stdint.h>
#include "irq.h"

static inline unsigned long icc_iar1_el1_read(void)
{
    unsigned long v;
    __asm__ volatile("mrs %0, S3_0_C12_C12_0" : "=r"(v)); /* ICC_IAR1_EL1 */
    return v;
}

static inline void icc_eoir1_el1_write(unsigned long v)
{
    __asm__ volatile("msr S3_0_C12_C12_1, %0" ::"r"(v)); /* ICC_EOIR1_EL1 */
}

void gic_handle(void)
{
    unsigned long ack = icc_iar1_el1_read();
    unsigned long id = ack & (((1UL << 24) - 1UL));

    irq_early_hook((unsigned)id);

    if (id >= 1022UL) {
        return;
    }

    irq_handle((unsigned)id);

    icc_eoir1_el1_write(ack);
}
