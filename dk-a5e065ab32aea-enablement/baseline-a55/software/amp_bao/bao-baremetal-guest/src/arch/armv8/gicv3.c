/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#include <gic.h>
#include <sysregs.h>
#include <cpu.h>
#include <spinlock.h>
#include <fences.h>
#include <irq.h>

volatile gicd_t *gicd = (void *)PLAT_GICD_BASE_ADDR;
volatile gicr_t *gicr = (void *)PLAT_GICR_BASE_ADDR;

spinlock_t gicd_lock = SPINLOCK_INITVAL;
spinlock_t gicr_lock = SPINLOCK_INITVAL;

inline unsigned long gic_num_irqs()
{
    uint32_t itlinenumber = bit_extract(gicd->TYPER, GICD_TYPER_ITLN_OFF, GICD_TYPER_ITLN_LEN);
    return 32 * itlinenumber + 1;
}

static inline void gicc_init()
{
    /* Enable system register interface i*/
    sysreg_icc_pmr_el1_write(-1);
    sysreg_icc_ctlr_el1_write(GICC_CTLR_EN_BIT);
    sysreg_icc_igrpen1_el1_write(ICC_IGRPEN_EL1_ENB_BIT);
}

static inline void gicr_init()
{
    gicd->CTLR |= (1ull << 6);
    gicr[get_cpuid()].WAKER &= ~GICR_ProcessorSleep_BIT;
    while (gicr[get_cpuid()].WAKER & GICR_ChildrenASleep_BIT) {
    }

    gicr[get_cpuid()].IGROUPR0 = -1;
    gicr[get_cpuid()].ICENABLER0 = -1;
    gicr[get_cpuid()].ICPENDR0 = -1;
    gicr[get_cpuid()].ICACTIVER0 = -1;

    for (int i = 0; i < GIC_NUM_PRIO_REGS(GIC_CPU_PRIV); i++) {
        gicr[get_cpuid()].IPRIORITYR[i] = -1;
    }
}

void gic_cpu_init()
{
    sysreg_icc_sre_el1_write(sysreg_icc_sre_el1_read() | ICC_SRE_SRE_BIT);
    ISB();
    gicr_init();
    gicc_init();
}

void gicd_init()
{
    size_t int_num = gic_num_irqs();

    /* Bring distributor to known state */
    for (int i = GIC_NUM_PRIVINT_REGS; i < GIC_NUM_INT_REGS(int_num); i++) {
        gicd->IGROUPR[i] = -1;
        /**
         * Make sure all interrupts are not enabled, non pending,
         * non active.
         */
        gicd->ICENABLER[i] = -1;
        gicd->ICPENDR[i] = -1;
        gicd->ICACTIVER[i] = -1;
    }

    /* All interrupts have lowest priority possible by default */
    for (int i = GIC_CPU_PRIV; i < GIC_NUM_PRIO_REGS(int_num); i++) {
        gicd->IPRIORITYR[i] = -1;
    }

    /* No CPU targets for any interrupt by default */
    for (int i = GIC_CPU_PRIV; i < GIC_NUM_TARGET_REGS(int_num); i++) {
        gicd->ITARGETSR[i] = 0;
    }

    /* ICFGR are platform dependent, lets leave them as is */

    /* No need to setup gicd->NSACR as all interrupts are  setup to group 1 */

    /* Enable distributor and affinity routing */
    gicd->CTLR |= GICD_CTLR_ARE_NS_BIT | GICD_CTLR_ENA_BIT;
}

void gic_init()
{
    gic_cpu_init();

    if (get_cpuid() == 0) {
        gicd_init();
    }
}

void gic_handle()
{
    unsigned long ack = sysreg_icc_iar1_el1_read();
    unsigned long id = ack & ((1UL << 24) - 1);

    /* Call the application-provided fast-path hook immediately after
     * IAR ack and BEFORE the generic handler-table dispatch. Default
     * is a weak no-op in src/core/irq.c; applications override with
     * a strong definition to perform latency-sensitive actions (freeze
     * a cycle counter, stamp a timestamp, etc.) at the earliest
     * software point. See <irq.h> for the contract.                   */
    irq_early_hook((unsigned)id);

    if (id >= 1022) {
        return;
    }

    irq_handle(id);

    sysreg_icc_eoir1_el1_write(ack);
}

unsigned long gicd_get_prio(unsigned long int_id)
{
    unsigned long reg_ind = GIC_PRIO_REG(int_id);
    unsigned long off = GIC_PRIO_OFF(int_id);

    spin_lock(&gicd_lock);

    unsigned long prio = gicd->IPRIORITYR[reg_ind] >> off & BIT_MASK(off, GIC_PRIO_BITS);

    spin_unlock(&gicd_lock);

    return prio;
}

void gicd_set_icfgr(unsigned long int_id, uint8_t cfg)
{
    spin_lock(&gicd_lock);

    unsigned long reg_ind = (int_id * GIC_CONFIG_BITS) / (sizeof(uint32_t) * 8);
    unsigned long off = (int_id * GIC_CONFIG_BITS) % (sizeof(uint32_t) * 8);
    unsigned long mask = ((1U << GIC_CONFIG_BITS) - 1) << off;

    gicd->ICFGR[reg_ind] = (gicd->ICFGR[reg_ind] & ~mask) | ((cfg << off) & mask);

    spin_unlock(&gicd_lock);
}

void gicd_set_prio(unsigned long int_id, uint8_t prio)
{
    unsigned long reg_ind = GIC_PRIO_REG(int_id);
    unsigned long off = GIC_PRIO_OFF(int_id);
    unsigned long mask = BIT_MASK(off, GIC_PRIO_BITS);

    spin_lock(&gicd_lock);

    gicd->IPRIORITYR[reg_ind] = (gicd->IPRIORITYR[reg_ind] & ~mask) | ((prio << off) & mask);

    spin_unlock(&gicd_lock);
}

enum int_state gicd_get_state(unsigned long int_id)
{
    unsigned long reg_ind = GIC_INT_REG(int_id);
    unsigned long mask = GIC_INT_MASK(int_id);

    spin_lock(&gicd_lock);

    enum int_state pend = (gicd->ISPENDR[reg_ind] & mask) ? PEND : 0;
    enum int_state act = (gicd->ISACTIVER[reg_ind] & mask) ? ACT : 0;

    spin_unlock(&gicd_lock);

    return pend | act;
}

static void gicd_set_pend(unsigned long int_id, bool pend)
{
    spin_lock(&gicd_lock);

    if (gic_is_sgi(int_id)) {
        unsigned long reg_ind = GICD_SGI_REG(int_id);
        unsigned long off = GICD_SGI_OFF(int_id);

        if (pend) {
            gicd->SPENDSGIR[reg_ind] = (1U) << (off + get_cpuid());
        } else {
            gicd->CPENDSGIR[reg_ind] = BIT_MASK(off, 8);
        }
    } else {
        unsigned long reg_ind = GIC_INT_REG(int_id);

        if (pend) {
            gicd->ISPENDR[reg_ind] = GIC_INT_MASK(int_id);
        } else {
            gicd->ICPENDR[reg_ind] = GIC_INT_MASK(int_id);
        }
    }

    spin_unlock(&gicd_lock);
}

void gicd_set_act(unsigned long int_id, bool act)
{
    unsigned long reg_ind = GIC_INT_REG(int_id);

    spin_lock(&gicd_lock);

    if (act) {
        gicd->ISACTIVER[reg_ind] = GIC_INT_MASK(int_id);
    } else {
        gicd->ICACTIVER[reg_ind] = GIC_INT_MASK(int_id);
    }

    spin_unlock(&gicd_lock);
}

void gicd_set_state(unsigned long int_id, enum int_state state)
{
    gicd_set_act(int_id, state & ACT);
    gicd_set_pend(int_id, state & PEND);
}

void gicd_set_trgt(unsigned long int_id, uint8_t trgt)
{
    unsigned long reg_ind = GIC_TARGET_REG(int_id);
    unsigned long off = GIC_TARGET_OFF(int_id);
    uint32_t mask = BIT_MASK(off, GIC_TARGET_BITS);

    spin_lock(&gicd_lock);

    gicd->ITARGETSR[reg_ind] = (gicd->ITARGETSR[reg_ind] & ~mask) | ((trgt << off) & mask);

    spin_unlock(&gicd_lock);
}

void gicd_set_route(unsigned long int_id, unsigned long trgt)
{
    if (gic_is_priv(int_id)) {
        return;
    }

    /**
     * In aarch32 the compiler might issue a single strd access. However, this
     * instruction is complex to emulate since it does not generate a valid
     * syndrome register. Bao has no support for its emulation. Therefore
     * we perform the 64-bit access explicitly as two 32-bit stores.
     */

    uint64_t _trgt = trgt;
    volatile uint32_t *irouter = (uint32_t *)&gicd->IROUTER[int_id];
    irouter[0] = _trgt;
    irouter[1] = (_trgt >> 32);
}

void gicd_set_enable(unsigned long int_id, bool en)
{
    unsigned long bit = GIC_INT_MASK(int_id);

    unsigned long reg_ind = GIC_INT_REG(int_id);
    spin_lock(&gicd_lock);
    if (en) {
        gicd->ISENABLER[reg_ind] = bit;
    } else {
        gicd->ICENABLER[reg_ind] = bit;
    }
    spin_unlock(&gicd_lock);
}

void gicr_set_prio(unsigned long int_id, uint8_t prio, uint32_t gicr_id)
{
    unsigned long reg_ind = GIC_PRIO_REG(int_id);
    unsigned long off = GIC_PRIO_OFF(int_id);
    unsigned long mask = BIT_MASK(off, GIC_PRIO_BITS);

    spin_lock(&gicr_lock);

    gicr[gicr_id].IPRIORITYR[reg_ind] = (gicr[gicr_id].IPRIORITYR[reg_ind] & ~mask) | ((prio << off) & mask);

    spin_unlock(&gicr_lock);
}

unsigned long gicr_get_prio(unsigned long int_id, uint32_t gicr_id)
{
    unsigned long reg_ind = GIC_PRIO_REG(int_id);
    unsigned long off = GIC_PRIO_OFF(int_id);

    spin_lock(&gicr_lock);

    unsigned long prio = gicr[gicr_id].IPRIORITYR[reg_ind] >> off & BIT_MASK(off, GIC_PRIO_BITS);

    spin_unlock(&gicr_lock);

    return prio;
}

void gicr_set_icfgr(unsigned long int_id, uint8_t cfg, uint32_t gicr_id)
{
    spin_lock(&gicr_lock);

    unsigned long reg_ind = (int_id * GIC_CONFIG_BITS) / (sizeof(uint32_t) * 8);
    unsigned long off = (int_id * GIC_CONFIG_BITS) % (sizeof(uint32_t) * 8);
    unsigned long mask = ((1U << GIC_CONFIG_BITS) - 1) << off;

    if (reg_ind == 0) {
        gicr[gicr_id].ICFGR0 = (gicr[gicr_id].ICFGR0 & ~mask) | ((cfg << off) & mask);
    } else {
        gicr[gicr_id].ICFGR1 = (gicr[gicr_id].ICFGR1 & ~mask) | ((cfg << off) & mask);
    }

    spin_unlock(&gicr_lock);
}

enum int_state gicr_get_state(unsigned long int_id, uint32_t gicr_id)
{
    unsigned long mask = GIC_INT_MASK(int_id);

    spin_lock(&gicr_lock);

    enum int_state pend = (gicr[gicr_id].ISPENDR0 & mask) ? PEND : 0;
    enum int_state act = (gicr[gicr_id].ISACTIVER0 & mask) ? ACT : 0;

    spin_unlock(&gicr_lock);

    return pend | act;
}

static void gicr_set_pend(unsigned long int_id, bool pend, uint32_t gicr_id)
{
    spin_lock(&gicr_lock);
    if (pend) {
        gicr[gicr_id].ISPENDR0 = (1U) << (int_id);
    } else {
        gicr[gicr_id].ICPENDR0 = (1U) << (int_id);
    }
    spin_unlock(&gicr_lock);
}

void gicr_set_act(unsigned long int_id, bool act, uint32_t gicr_id)
{
    spin_lock(&gicr_lock);

    if (act) {
        gicr[gicr_id].ISACTIVER0 = GIC_INT_MASK(int_id);
    } else {
        gicr[gicr_id].ICACTIVER0 = GIC_INT_MASK(int_id);
    }

    spin_unlock(&gicr_lock);
}

void gicr_set_state(unsigned long int_id, enum int_state state, uint32_t gicr_id)
{
    gicr_set_act(int_id, state & ACT, gicr_id);
    gicr_set_pend(int_id, state & PEND, gicr_id);
}

void gicr_set_trgt(unsigned long int_id, uint8_t trgt, uint32_t gicr_id)
{
    (void)int_id;
    (void)trgt;
    (void)gicr_id;
    /* Routing to a specific redistributor is not used in this single-core
     * guest — SGIs and PPIs are always targeted at the local CPU via the
     * redistributor selected in gic_cpu_init().  This stub intentionally
     * does nothing; remove the spin_lock pair to avoid an empty critical
     * section.  Implement if multi-core SPI affinity routing is needed. */
}

void gicr_set_route(unsigned long int_id, uint8_t trgt, uint32_t gicr_id)
{
    gicr_set_trgt(int_id, trgt, gicr_id);
}

void gicr_set_enable(unsigned long int_id, bool en, uint32_t gicr_id)
{
    unsigned long bit = GIC_INT_MASK(int_id);

    spin_lock(&gicr_lock);
    if (en) {
        gicr[gicr_id].ISENABLER0 = bit;
    } else {
        gicr[gicr_id].ICENABLER0 = bit;
    }
    spin_unlock(&gicr_lock);
}

static bool irq_in_gicd(unsigned long int_id)
{
    if (int_id > 32 && int_id < 1025) {
        return true;
    } else {
        return false;
    }
}

void gic_send_sgi(unsigned long cpu_target, unsigned long sgi_num)
{
    if (sgi_num >= GIC_MAX_SGIS) {
        return;
    }

    unsigned long sgi = (1UL << (cpu_target & 0xffull)) | (sgi_num << 24);
    sysreg_icc_sgi1r_el1_write(sgi);
}

void gic_set_prio(unsigned long int_id, uint8_t prio)
{
    if (irq_in_gicd(int_id)) {
        return gicd_set_prio(int_id, prio);
    } else {
        return gicr_set_prio(int_id, prio, get_cpuid());
    }
}

unsigned long gic_get_prio(unsigned long int_id)
{
    if (irq_in_gicd(int_id)) {
        return gicd_get_prio(int_id);
    } else {
        return gicr_get_prio(int_id, get_cpuid());
    }
}

void gic_set_icfgr(unsigned long int_id, uint8_t cfg)
{
    if (irq_in_gicd(int_id)) {
        return gicd_set_icfgr(int_id, cfg);
    } else {
        return gicr_set_icfgr(int_id, cfg, get_cpuid());
    }
}

enum int_state gic_get_state(unsigned long int_id)
{
    if (irq_in_gicd(int_id)) {
        return gicd_get_state(int_id);
    } else {
        return gicr_get_state(int_id, get_cpuid());
    }
}

static void gic_set_pend(unsigned long int_id, bool pend)
{
    if (irq_in_gicd(int_id)) {
        return gicd_set_pend(int_id, pend);
    } else {
        return gicr_set_pend(int_id, pend, get_cpuid());
    }
}

void gic_set_act(unsigned long int_id, bool act)
{
    if (irq_in_gicd(int_id)) {
        return gicd_set_act(int_id, act);
    } else {
        return gicr_set_act(int_id, act, get_cpuid());
    }
}

void gic_set_state(unsigned long int_id, enum int_state state)
{
    if (irq_in_gicd(int_id)) {
        return gicd_set_state(int_id, state);
    } else {
        return gicr_set_state(int_id, state, get_cpuid());
    }
}

void gic_set_trgt(unsigned long int_id, uint8_t trgt)
{
    if (irq_in_gicd(int_id)) {
        return gicd_set_trgt(int_id, trgt);
    } else {
        return gicr_set_trgt(int_id, trgt, get_cpuid());
    }
}

void gic_set_route(unsigned long int_id, unsigned long trgt)
{
    return gicd_set_route(int_id, trgt);
}

void gic_set_enable(unsigned long int_id, bool en)
{
    if (irq_in_gicd(int_id)) {
        return gicd_set_enable(int_id, en);
    } else {
        return gicr_set_enable(int_id, en, get_cpuid());
    }
}
