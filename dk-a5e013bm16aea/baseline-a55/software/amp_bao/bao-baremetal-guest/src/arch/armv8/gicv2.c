/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#include "gic.h"
#include <irq.h>
#include <cpu.h>
#include <spinlock.h>

volatile gicd_t *gicd = (void *)PLAT_GICD_BASE_ADDR;
volatile gicc_t *gicc = (void *)PLAT_GICC_BASE_ADDR;

spinlock_t gicd_lock = SPINLOCK_INITVAL;

static size_t gic_num_int()
{
    return ((gicd->TYPER & BIT_MASK(GICD_TYPER_ITLINENUM_OFF, GICD_TYPER_ITLINENUM_LEN) >> GICD_TYPER_ITLINENUM_OFF) +
            1) *
           32;
}

void gicc_init()
{
    for (int i = 0; i < GIC_NUM_INT_REGS(GIC_CPU_PRIV); i++) {
        /**
         * Make sure all private interrupts are not enabled, non pending,
         * non active.
         */
        gicd->ICENABLER[i] = -1;
        gicd->ICPENDR[i] = -1;
        gicd->ICACTIVER[i] = -1;
    }

    /* Clear any pending SGIs. */
    for (int i = 0; i < GIC_NUM_SGI_REGS; i++) {
        gicd->CPENDSGIR[i] = -1;
    }

    for (int i = 0; i < GIC_NUM_TARGET_REGS(GIC_CPU_PRIV); i++) {
        gicd->IPRIORITYR[i] = -1;
    }

    for (int i = 0; i < GIC_NUM_PRIO_REGS(GIC_CPU_PRIV); i++) {
        gicd->IPRIORITYR[i] = -1;
    }

    gicc->PMR = -1;
    gicc->CTLR |= GICC_CTLR_EN_BIT;
}

void gicd_init()
{
    size_t int_num = gic_num_int();

    /* Bring distributor to known state */
    for (int i = GIC_NUM_PRIVINT_REGS; i < GIC_NUM_INT_REGS(int_num); i++) {
        /**
         * Make sure all interrupts are not enabled, non pending,
         * non active.
         */
        gicd->ICENABLER[i] = -1;
        gicd->ICPENDR[i] = -1;
        gicd->ICACTIVER[i] = -1;
    }

    /* All interrupts have lowest priority possible by default */
    for (int i = 0; i < GIC_NUM_PRIO_REGS(int_num); i++) {
        gicd->IPRIORITYR[i] = -1;
    }

    /* No CPU targets for any interrupt by default */
    for (int i = 0; i < GIC_NUM_TARGET_REGS(int_num); i++) {
        gicd->ITARGETSR[i] = 0;
    }

    /* No CPU targets for any interrupt by default */
    for (int i = 0; i < GIC_NUM_CONFIG_REGS(int_num); i++) {
        gicd->ICFGR[i] = 0xAAAAAAAA;
    }

    /* No need to setup gicd->NSACR as all interrupts are  setup to group 1 */

    /* Enable distributor */
    gicd->CTLR |= GICD_CTLR_EN_BIT;
}

void gic_init()
{
    if (get_cpuid() == 0) {
        gicd_init();
    }
    gicc_init();
}

void gic_set_enable(unsigned long int_id, bool en)
{
    unsigned long reg_ind = int_id / (sizeof(uint32_t) * 8);
    unsigned long bit = (1UL << int_id % (sizeof(uint32_t) * 8));

    spin_lock(&gicd_lock);

    if (en) {
        gicd->ISENABLER[reg_ind] = bit;
    } else {
        gicd->ICENABLER[reg_ind] = bit;
    }

    spin_unlock(&gicd_lock);
}

void gic_set_trgt(unsigned long int_id, uint8_t trgt)
{
    unsigned long reg_ind = (int_id * GIC_TARGET_BITS) / (sizeof(uint32_t) * 8);
    unsigned long off = (int_id * GIC_TARGET_BITS) % (sizeof(uint32_t) * 8);
    uint32_t mask = ((1U << GIC_TARGET_BITS) - 1) << off;

    spin_lock(&gicd_lock);

    gicd->ITARGETSR[reg_ind] = (gicd->ITARGETSR[reg_ind] & ~mask) | ((trgt << off) & mask);

    spin_unlock(&gicd_lock);
}

uint8_t gic_get_trgt(unsigned long int_id)
{
    unsigned long reg_ind = (int_id * GIC_TARGET_BITS) / (sizeof(uint32_t) * 8);
    unsigned long off = (int_id * GIC_TARGET_BITS) % (sizeof(uint32_t) * 8);
    uint32_t mask = ((1U << GIC_TARGET_BITS) - 1) << off;

    return (gicd->ITARGETSR[reg_ind] & mask) >> off;
}

void gic_send_sgi(unsigned long cpu_target, unsigned long sgi_num)
{
    gicd->SGIR = (1UL << (GICD_SGIR_CPUTRGLST_OFF + cpu_target)) | (sgi_num & GICD_SGIR_SGIINTID_MSK);
}

void gic_set_prio(unsigned long int_id, uint8_t prio)
{
    unsigned long reg_ind = (int_id * GIC_PRIO_BITS) / (sizeof(uint32_t) * 8);
    unsigned long off = (int_id * GIC_PRIO_BITS) % (sizeof(uint32_t) * 8);
    unsigned long mask = ((1 << GIC_PRIO_BITS) - 1) << off;

    spin_lock(&gicd_lock);

    gicd->IPRIORITYR[reg_ind] = (gicd->IPRIORITYR[reg_ind] & ~mask) | ((prio << off) & mask);

    spin_unlock(&gicd_lock);
}

bool gic_is_pending(unsigned long int_id)
{
    unsigned long reg_ind = int_id / (sizeof(uint32_t) * 8);
    unsigned long off = int_id % (sizeof(uint32_t) * 8);

    return ((1U << off) & gicd->ISPENDR[reg_ind]) != 0;
}

void gic_set_pending(unsigned long int_id, bool pending)
{
    unsigned long reg_ind = int_id / (sizeof(uint32_t) * 8);
    unsigned long mask = 1U << int_id % (sizeof(uint32_t) * 8);

    spin_lock(&gicd_lock);

    if (pending) {
        gicd->ISPENDR[reg_ind] = mask;
    } else {
        gicd->ICPENDR[reg_ind] = mask;
    }

    spin_unlock(&gicd_lock);
}

bool gic_is_active(unsigned long int_id)
{
    unsigned long reg_ind = int_id / (sizeof(uint32_t) * 8);
    unsigned long off = int_id % (sizeof(uint32_t) * 8);

    return ((1U << off) & gicd->ISACTIVER[reg_ind]) != 0;
}

void gic_handle()
{
    unsigned long ack = gicc->IAR;
    unsigned long id = ack & GICC_IAR_ID_MSK;
    unsigned long src = (ack & GICC_IAR_CPU_MSK) >> GICC_IAR_CPU_OFF;

    if (id >= 1022) {
        return;
    }

    irq_handle(id);

    gicc->EOIR = ack;
}
