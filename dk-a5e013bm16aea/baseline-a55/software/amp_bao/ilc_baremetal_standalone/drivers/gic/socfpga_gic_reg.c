/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/*
 * socfpga_gic_reg.c — GICv3 CPU interface system register accessors
 *
 * Uses MSR/MRS encoding for EL1 NS CPU interface registers.
 * s3_0_c12_c12_6 = ICC_IGRPEN0_EL1 (Group 0 enable)
 * s3_0_c12_c12_7 = ICC_IGRPEN1_EL1 (Group 1 NS enable)
 * s3_0_c4_c6_0   = ICC_PMR_EL1     (priority mask)
 * MPIDR_EL1       = CPU affinity
 *
 * Note: gic_reg_write_group1_end_of_interrupt() writes ICC_EOIR1_EL1.
 * In the original Ignitarium code this was commented out for bare-metal.
 * We restore it here — it is called from interrupt_irq_handler() via
 * socfpga_interrupt.c after every IRQ to deactivate the interrupt.
 */

#include <stdint.h>
#include "socfpga_gic_reg.h"

#define GIC_REG_WRITE(reg, val) __asm__ __volatile__("MSR " #reg ", %0\n\tDSB SY\n\tISB" ::"r"(val))

void gic_reg_enable_group0_interrupts(void)
{
    /* Intentionally empty.
     * Group 0 interrupts are delivered as FIQ and FIQ is owned by EL3
     * (ATF / SMC handler) on this platform. Writing ICC_IGRPEN0_EL1
     * here would cause unexpected FIQs to escape to EL3. The stub is
     * kept so init code can call it symmetrically with the Group 1
     * enable path without #ifdef guards. */
}

void gic_reg_write_dir(uint32_t intid)
{
    GIC_REG_WRITE(S3_0_C12_C11_1, (uint64_t)intid); /* ICC_DIR_EL1 */
}

void gic_reg_enable_group1_interrupts(void)
{
    GIC_REG_WRITE(s3_0_c12_c12_7, (uint64_t)1);
}

void gic_reg_write_group1_end_of_interrupt(uint32_t interrupt_id)
{
    GIC_REG_WRITE(ICC_EOIR1_EL1, (uint64_t)interrupt_id);
}

void gic_reg_set_priority_mask(uint32_t priority)
{
    GIC_REG_WRITE(s3_0_c4_c6_0, (uint64_t)priority);
}

uint64_t gic_reg_get_cpu_affinity(void)
{
    uint64_t affinity = 0U;
    __asm__ volatile("MRS x0, MPIDR_EL1  \n\t"
                     "UBFX x1, x0, #32, #8 \n\t"
                     "BFI w0, w1, #24, #8 \n\t"
                     "MOV %0, x0"
                     : "=r"(affinity)
                     :
                     : "x0", "x1");
    return affinity;
}
