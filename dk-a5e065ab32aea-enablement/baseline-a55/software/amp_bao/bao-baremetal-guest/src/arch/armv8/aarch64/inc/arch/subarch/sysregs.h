/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef ARCH_PROFILE_SYSREGS_H
#define ARCH_PROFILE_SYSREGS_H

#define STR(s) #s
#define XSTR(s) STR(s)

#define mpuir_el1 S3_0_C0_C0_4
#define prselr_el1 S3_0_C6_C2_1
#define prbar_el1 S3_0_C6_C8_0
#define prlar_el1 S3_0_C6_C8_1
#define prenr_el1 S3_0_C6_C1_1
#define icc_iar1_el1 S3_0_C12_C12_0
#define icc_eoir1_el1 S3_0_C12_C12_1
#define icc_dir_el1 S3_0_C12_C11_1
#define icc_sre_el1 S3_0_C12_C12_5
#define icc_pmr_el1 S3_0_C4_C6_0
#define icc_bpr0_el1 S3_0_C12_C8_3
#define icc_bpr1_el1 S3_0_C12_C12_3
#define icc_rpr_el1 S3_0_C12_C11_3
#define icc_ctlr_el1 S3_0_C12_C12_4
#define icc_igrpen1_el1 S3_0_C12_C12_7
#define icc_sgi1r_el1 S3_0_C12_C11_5

#ifndef __ASSEMBLER__

#include <core.h>

#define SYSREG_GEN_ACCESSORS_NAME(reg, name)                      \
    static inline unsigned long sysreg##reg##read()               \
    {                                                             \
        unsigned long _temp;                                      \
        asm volatile("mrs %0, " XSTR(name) "\n\r" : "=r"(_temp)); \
        return _temp;                                             \
    }                                                             \
    static inline void sysreg##reg##write(unsigned long val)      \
    {                                                             \
        asm volatile("msr " XSTR(name) ", %0\n\r" ::"r"(val));    \
    }

#define SYSREG_GEN_ACCESSORS(reg) SYSREG_GEN_ACCESSORS_NAME(_##reg##_, reg)

SYSREG_GEN_ACCESSORS(esr_el1);
SYSREG_GEN_ACCESSORS(elr_el1);
SYSREG_GEN_ACCESSORS(far_el1);
SYSREG_GEN_ACCESSORS(vbar_el1);
SYSREG_GEN_ACCESSORS(clidr_el1);
SYSREG_GEN_ACCESSORS(csselr_el1);
SYSREG_GEN_ACCESSORS(ccsidr_el1);
SYSREG_GEN_ACCESSORS(ccsidr2_el1);
SYSREG_GEN_ACCESSORS(ctr_el0);
SYSREG_GEN_ACCESSORS(mpidr_el1);
SYSREG_GEN_ACCESSORS(sctlr_el1);
SYSREG_GEN_ACCESSORS(cntkctl_el1);
SYSREG_GEN_ACCESSORS(pmcr_el0);
SYSREG_GEN_ACCESSORS(par_el1);
SYSREG_GEN_ACCESSORS(tcr_el1);
SYSREG_GEN_ACCESSORS(ttbr0_el1);
SYSREG_GEN_ACCESSORS(mair_el1);
SYSREG_GEN_ACCESSORS(cptr_el1);
SYSREG_GEN_ACCESSORS(id_aa64mmfr0_el1);
SYSREG_GEN_ACCESSORS(tpidr_el1);
SYSREG_GEN_ACCESSORS(cntfrq_el0);
SYSREG_GEN_ACCESSORS(cntv_ctl_el0);
SYSREG_GEN_ACCESSORS(cntvct_el0);
SYSREG_GEN_ACCESSORS(cntv_cval_el0);
SYSREG_GEN_ACCESSORS(cntv_tval_el0);
SYSREG_GEN_ACCESSORS(mpuir_el1);
SYSREG_GEN_ACCESSORS(prselr_el1);
SYSREG_GEN_ACCESSORS(prbar_el1);
SYSREG_GEN_ACCESSORS(prlar_el1);
SYSREG_GEN_ACCESSORS(prenr_el1);
SYSREG_GEN_ACCESSORS(icc_iar1_el1);
SYSREG_GEN_ACCESSORS(icc_eoir1_el1);
SYSREG_GEN_ACCESSORS(icc_dir_el1);
SYSREG_GEN_ACCESSORS(icc_sre_el1);
SYSREG_GEN_ACCESSORS(icc_pmr_el1);
SYSREG_GEN_ACCESSORS(icc_bpr0_el1);
SYSREG_GEN_ACCESSORS(icc_bpr1_el1);
SYSREG_GEN_ACCESSORS(icc_rpr_el1);
SYSREG_GEN_ACCESSORS(icc_ctlr_el1);
SYSREG_GEN_ACCESSORS(icc_igrpen1_el1);
SYSREG_GEN_ACCESSORS(icc_sgi1r_el1);
SYSREG_GEN_ACCESSORS(pmcntenclr_el0);
SYSREG_GEN_ACCESSORS(pmcntenset_el0);
SYSREG_GEN_ACCESSORS(pmselr_el0);
SYSREG_GEN_ACCESSORS(pmxevtyper_el0);
SYSREG_GEN_ACCESSORS(pmxevcntr_el0);
SYSREG_GEN_ACCESSORS(pmccntr_el0);
SYSREG_GEN_ACCESSORS(pmccfiltr_el0);

static inline void arm_dc_civac(uintptr_t cache_addr)
{
    asm volatile("dc civac, %0\n\t" ::"r"(cache_addr));
}

static inline void arm_at_s1e2w(uintptr_t vaddr)
{
    asm volatile("at s1e2w, %0" ::"r"(vaddr));
}

static inline void arm_at_s12e1w(uintptr_t vaddr)
{
    asm volatile("at s12e1w, %0" ::"r"(vaddr));
}

static inline void arm_unmask_irq()
{
    asm volatile("MSR   DAIFClr, #2\n\t");
}

#endif /* |__ASSEMBLER__ */

#endif /* __ARCH_SYSREGS_H__ */
