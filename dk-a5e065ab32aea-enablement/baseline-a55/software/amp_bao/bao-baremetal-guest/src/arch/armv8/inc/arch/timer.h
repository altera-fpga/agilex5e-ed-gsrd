/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef ARCH_TIMER_H
#define ARCH_TIMER_H

#include <core.h>
#include <sysregs.h>

extern unsigned long TIMER_FREQ;

#define CNTV_CTL_ENABLE (1 << 0)
#define CNTV_CTL_IMASK (1 << 1)

static inline unsigned long timer_get_freq(void)
{
    return sysreg_cntfrq_el0_read();
}

static inline void timer_int_en(bool en)
{
    if (en) {
        sysreg_cntv_ctl_el0_write(sysreg_cntv_ctl_el0_read() & ~CNTV_CTL_IMASK);
    } else {
        sysreg_cntv_ctl_el0_write(sysreg_cntv_ctl_el0_read() | CNTV_CTL_IMASK);
    }
}

static inline void timer_enable(void)
{
    timer_int_en(true);
    sysreg_cntv_ctl_el0_write(CNTV_CTL_ENABLE);
}

static inline void timer_disable()
{
    sysreg_cntv_ctl_el0_write(0);
}

static uint64_t timer_set(uint64_t n)
{
    uint64_t current = sysreg_cntvct_el0_read();
    sysreg_cntv_cval_el0_write(current + n);
    return current + n;
}

static inline uint64_t timer_get()
{
    uint64_t time = sysreg_cntvct_el0_read();
    return time; // assumes plat_freq = 100MHz
}

#endif
