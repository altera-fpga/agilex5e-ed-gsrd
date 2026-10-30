/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef ARCH_CYCLE_COUNTER_H_
#define ARCH_CYCLE_COUNTER_H_

#include <core.h>
#include <sysregs.h>

#define PMCNTENSET_C (1 << 31)
#define PMCCFILTR_NSH (1 << 27)
#define PMCR_C (1 << 2)
#define PMCR_P (1 << 1)
#define PMCR_E (1 << 0)

static inline uint64_t arch_cc_get_count(void)
{
    uint64_t val = sysreg_pmccntr_el0_read();
    return val;
}

static inline void arch_cc_enable(void)
{
    sysreg_pmccfiltr_el0_write(PMCCFILTR_NSH);
    sysreg_pmcntenset_el0_write(PMCNTENSET_C);
}

static inline void arch_cc_reset_count(void)
{
    sysreg_pmcr_el0_write(sysreg_pmcr_el0_read() | PMCR_C);
}

static inline void arch_cc_start(void)
{
    sysreg_pmcr_el0_write(sysreg_pmcr_el0_read() | PMCR_E);
}

static inline void arch_cc_stop(void)
{
    sysreg_pmcr_el0_write(sysreg_pmcr_el0_read() & ~PMCR_E);
}

#endif /* ARCH_CYCLE_COUNTER_H_ */
