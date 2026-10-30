/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#include <psci.h>
#include <plat.h>

#define STR(S) #S
#define XSTR(S) STR(S)

#ifndef PSCI_CONDUIT
#define PSCI_CONDUIT smc
#endif

int smc_call(unsigned long x0, unsigned long x1, unsigned long x2, unsigned long x3)
{
    register unsigned long r0 asm("r0") = x0;
    register unsigned long r1 asm("r1") = x1;
    register unsigned long r2 asm("r2") = x2;
    register unsigned long r3 asm("r3") = x3;

    asm volatile(XSTR(PSCI_CONDUIT) " #0\n" : "=r"(r0) : "r"(r0), "r"(r1), "r"(r2) : "r3");

    return r0;
}

/* --------------------------------
    SMC PSCI interface
--------------------------------- */

int32_t psci_version(void)
{
    return smc_call(PSCI_VERSION, 0, 0, 0);
}

int32_t psci_cpu_suspend(uint32_t power_state, uintptr_t entrypoint, unsigned long context_id)
{
    return smc_call(PSCI_CPU_SUSPEND, power_state, entrypoint, context_id);
}

int32_t psci_cpu_off(void)
{
    return smc_call(PSCI_CPU_OFF, 0, 0, 0);
}

int32_t psci_cpu_on(unsigned long target_cpu, uintptr_t entrypoint, unsigned long context_id)
{
    return smc_call(PSCI_CPU_ON, target_cpu, entrypoint, context_id);
}

int32_t psci_affinity_info(unsigned long target_affinity, uint32_t lowest_affinity_level)
{
    return smc_call(PSCI_AFFINITY_INFO, target_affinity, lowest_affinity_level, 0);
}
