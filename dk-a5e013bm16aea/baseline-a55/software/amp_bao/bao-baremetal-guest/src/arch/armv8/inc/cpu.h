/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef ARCH_CPU_H
#define ARCH_CPU_H

#include <core.h>
#include <sysregs.h>

static inline unsigned long get_cpuid()
{
    unsigned long cpuid = sysreg_mpidr_el1_read();
    return cpuid & MPIDR_CPU_MASK;
}

static bool cpu_is_master()
{
    return get_cpuid() == 0;
}

#endif
