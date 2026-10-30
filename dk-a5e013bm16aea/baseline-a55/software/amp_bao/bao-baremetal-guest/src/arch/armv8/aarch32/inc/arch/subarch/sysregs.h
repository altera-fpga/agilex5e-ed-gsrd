/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef ARCH_PROFILE_SYSREGS_H
#define ARCH_PROFILE_SYSREGS_H

#define STR(s) #s
#define XSTR(s) STR(s)

#ifndef __ASSEMBLER__

#include <core.h>

#define SYSREG_GEN_ACCESSORS(name, op1, crn, crm, op2)                                              \
    static inline unsigned long sysreg_##name##_read()                                              \
    {                                                                                               \
        unsigned long _temp;                                                                        \
        asm volatile("mrc p15, " #op1 ", %0, " #crn ", " #crm ", %1\n\r" : "=r"(_temp) : "i"(op2)); \
        return _temp;                                                                               \
    }                                                                                               \
    static inline void sysreg_##name##_write(unsigned long val)                                     \
    {                                                                                               \
        asm volatile("mcr p15, " #op1 ", %0, " #crn ", " #crm ", " #op2 "\n\r" : : "r"((val)));     \
    }

#define SYSREG_GEN_ACCESSORS_BANKED(name, reg)                    \
    static inline unsigned long sysreg_##name##_read()            \
    {                                                             \
        unsigned long _temp;                                      \
        asm volatile("mrs %0, " XSTR(reg) "\n\r" : "=r"(_temp));  \
        return _temp;                                             \
    }                                                             \
    static inline void sysreg_##name##_write(unsigned long val)   \
    {                                                             \
        asm volatile("msr " XSTR(reg) ", %0\n\r" : : "r"((val))); \
    }

#define SYSREG_GEN_ACCESSORS_64(reg, op1, crm)                                                \
    static inline unsigned long long sysreg_##reg##_read()                                    \
    {                                                                                         \
        unsigned long long _temp, _tempH;                                                     \
        asm volatile("mrrc p15, " #op1 ", %0, %1, " #crm "\n\r" : "=r"(_temp), "=r"(_tempH)); \
        return ((_tempH << 32) | (unsigned long)_temp);                                       \
    }                                                                                         \
    static inline void sysreg_##reg##_write(unsigned long long val)                           \
    {                                                                                         \
        unsigned long long _tempH = (val >> 32);                                              \
        asm volatile("mcrr p15, " #op1 ", %0, %1, " #crm "\n\r" : : "r"(val), "r"(_tempH));   \
    }

#define SYSREG_GEN_ACCESSORS_MERGE(reg, reg1, reg2)                                         \
    static inline unsigned long long sysreg_##reg##_read()                                  \
    {                                                                                       \
        return ((unsigned long long)sysreg_##reg2##_read() << 32) | sysreg_##reg1##_read(); \
    }                                                                                       \
    static inline void sysreg_##reg##_write(unsigned long long val)                         \
    {                                                                                       \
        sysreg_##reg1##_write(val);                                                         \
        sysreg_##reg2##_write(val >> 32);                                                   \
    }

/**
 * We give aarch32 registers the same name as aarch64's to which they are
 * architecturally mapped to, so that we can use the same name in common code.
 */
SYSREG_GEN_ACCESSORS(esr_el1, 4, c5, c2, 0);
SYSREG_GEN_ACCESSORS_BANKED(elr_el1, elr_hyp);
SYSREG_GEN_ACCESSORS(far_el1, 4, c6, c0, 0);
SYSREG_GEN_ACCESSORS(vbar_el1, 0, c12, c0, 0);
SYSREG_GEN_ACCESSORS(clidr_el1, 1, c0, c0, 1);
SYSREG_GEN_ACCESSORS(csselr_el1, 2, c0, c0, 0);
SYSREG_GEN_ACCESSORS(ctr_el0, 0, c0, c0, 1);
SYSREG_GEN_ACCESSORS(mpidr_el1, 0, c0, c0, 5);
SYSREG_GEN_ACCESSORS(sctlr_el1, 0, c1, c0, 0);
SYSREG_GEN_ACCESSORS(cntkctl_el1, 0, c14, c1, 0);
SYSREG_GEN_ACCESSORS(pmcr_el0, 0, c9, c12, 0);
SYSREG_GEN_ACCESSORS_64(par_el1, 0, c7);
SYSREG_GEN_ACCESSORS(tcr_el1, 4, c2, c0, 2);
SYSREG_GEN_ACCESSORS_64(ttbr0_el1, 4, c2);
SYSREG_GEN_ACCESSORS(cptr_el1, 4, c1, c1, 2);
SYSREG_GEN_ACCESSORS(tpidr_el1, 4, c13, c0, 2);
SYSREG_GEN_ACCESSORS(ccsidr_el1, 1, c0, c0, 0);
SYSREG_GEN_ACCESSORS(ccsidr2, 1, c0, c0, 2);
SYSREG_GEN_ACCESSORS(mair0, 4, c10, c2, 0);
SYSREG_GEN_ACCESSORS(mair1, 4, c10, c2, 1);
SYSREG_GEN_ACCESSORS_MERGE(mair_el1, mair0, mair1);

SYSREG_GEN_ACCESSORS(cntfrq_el0, 0, c14, c0, 0);
SYSREG_GEN_ACCESSORS(cntv_ctl_el0, 0, c14, c3, 1);
SYSREG_GEN_ACCESSORS_64(cntvct_el0, 1, c14);
SYSREG_GEN_ACCESSORS_64(cntv_cval_el0, 3, c14);
SYSREG_GEN_ACCESSORS(cntv_tval_el0, 0, c14, c3, 0);

SYSREG_GEN_ACCESSORS(icc_iar1_el1, 0, c12, c12, 0);
SYSREG_GEN_ACCESSORS(icc_eoir1_el1, 0, c12, c12, 1);
SYSREG_GEN_ACCESSORS(icc_dir_el1, 0, c12, c11, 1);
SYSREG_GEN_ACCESSORS(icc_sre_el1, 0, c12, c12, 5);
SYSREG_GEN_ACCESSORS(icc_pmr_el1, 0, c4, c6, 0);
SYSREG_GEN_ACCESSORS(icc_bpr0_el1, 0, c12, c8, 3);
SYSREG_GEN_ACCESSORS(icc_bpr1_el1, 0, c12, c12, 3);
SYSREG_GEN_ACCESSORS(icc_rpr_el1, 0, c12, c11, 3);
SYSREG_GEN_ACCESSORS(icc_ctlr_el1, 0, c12, c12, 4);
SYSREG_GEN_ACCESSORS(icc_igrpen1_el1, 0, c12, c12, 7);
SYSREG_GEN_ACCESSORS_64(icc_sgi1r_el1, 0, c12);

SYSREG_GEN_ACCESSORS(pmcntenclr_el0, 0, c9, c12, 2)
SYSREG_GEN_ACCESSORS(pmcntenset_el0, 0, c9, c12, 1)
SYSREG_GEN_ACCESSORS(pmselr_el0, 0, c9, c12, 5)
SYSREG_GEN_ACCESSORS(pmxevtyper_el0, 0, c9, c13, 1)
SYSREG_GEN_ACCESSORS(pmxevcntr_el0, 0, c9, c13, 2)
SYSREG_GEN_ACCESSORS(pmintenset_el1, 0, c9, c14, 1)
SYSREG_GEN_ACCESSORS(pmintenclr_el1, 0, c9, c14, 2)
SYSREG_GEN_ACCESSORS(pmovsclr_el0, 0, c9, c12, 3)
SYSREG_GEN_ACCESSORS(pmccfiltr_el0, 0, c14, c15, 7)
SYSREG_GEN_ACCESSORS(pmccntr_el0, 0, c9, c13, 0)

SYSREG_GEN_ACCESSORS(dccivac, 0, c7, c14, 1);
static inline void arm_dc_civac(uintptr_t cache_addr)
{
    sysreg_dccivac_write(cache_addr);
}

static inline void arm_unmask_irq()
{
    asm volatile("cpsie i");
}

#endif /* |__ASSEMBLER__ */

#endif /* ARCH_PROFILE_SYSREGS_H */
