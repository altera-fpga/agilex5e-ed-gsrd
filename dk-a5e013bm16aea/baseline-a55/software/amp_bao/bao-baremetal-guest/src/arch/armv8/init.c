/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#include <core.h>
#include <cpu.h>
#include <psci.h>
#include <gic.h>
#include <timer.h>
#include <sysregs.h>

void _start();

__attribute__((weak)) void arch_init()
{
    unsigned long cpuid = get_cpuid();
    gic_init();
    TIMER_FREQ = timer_get_freq();
    timer_int_en(false);

#if !(defined(SINGLE_CORE) || defined(NO_FIRMWARE))
    if (cpuid == 0) {
        size_t i = 0;
        int ret = PSCI_E_SUCCESS;
        do {
            if (i == cpuid) {
                continue;
            }
            ret = psci_cpu_on(i, (uintptr_t)_start, 0);
        } while (i++, ret == PSCI_E_SUCCESS);
    }
#endif
    arm_unmask_irq();
}
