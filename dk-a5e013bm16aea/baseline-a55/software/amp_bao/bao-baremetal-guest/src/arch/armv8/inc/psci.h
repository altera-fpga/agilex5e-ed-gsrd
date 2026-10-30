/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef __PSCI_H__
#define __PSCI_H__

#include <core.h>

#define PSCI_VERSION (0x84000000)
#define PSCI_CPU_SUSPEND_AARCH32 (0x84000001)
#define PSCI_CPU_SUSPEND_AARCH64 (0xc4000001)
#define PSCI_CPU_OFF (0x84000002)
#define PSCI_CPU_ON_AARCH32 (0x84000003)
#define PSCI_CPU_ON_AARCH64 (0xc4000003)
#define PSCI_AFFINITY_INFO_AARCH32 (0x84000004)
#define PSCI_AFFINITY_INFO_AARCH64 (0xc4000004)

#ifdef AARCH32
#define PSCI_CPU_SUSPEND PSCI_CPU_SUSPEND_AARCH32
#define PSCI_CPU_ON PSCI_CPU_ON_AARCH32
#define PSCI_AFFINITY_INFO PSCI_AFFINITY_INFO_AARCH32
#else
#define PSCI_CPU_SUSPEND PSCI_CPU_SUSPEND_AARCH64
#define PSCI_CPU_ON PSCI_CPU_ON_AARCH64
#define PSCI_AFFINITY_INFO PSCI_AFFINITY_INFO_AARCH64
#endif

#define PSCI_POWER_STATE_LVL_0 0x0000000
#define PSCI_POWER_STATE_LVL_1 0x1000000
#define PSCI_POWER_STATE_LVL_2 0x2000000
#define PSCI_STATE_TYPE_STANDBY 0x00000
#define PSCI_STATE_TYPE_POWERDOWN (1UL << 30)
#define PSCI_STATE_TYPE_BIT (1UL << 30)

#define PSCI_CPU_IS_ON 0
#define PSCI_CPU_IS_OFF 1

#define PSCI_INVALID_ADDRESS (-1L)
#define PSCI_E_SUCCESS 0
#define PSCI_E_NOT_SUPPORTED -1
#define PSCI_E_INVALID_PARAMS -2
#define PSCI_E_DENIED -3
#define PSCI_E_ALREADY_ON -4
#define PSCI_E_ON_PENDING -5
#define PSCI_E_INTERN_FAIL -6
#define PSCI_E_NOT_PRESENT -7
#define PSCI_E_DISABLED -8
#define PSCI_E_INVALID_ADDRESS -9

#ifdef MPU
#define PSCI_CONDUIT hvc
#endif

/* psci wake up from off entry point */
void _psci_wake_up();

int32_t psci_version(void);

int32_t psci_cpu_suspend(uint32_t power_state, uintptr_t entrypoint, unsigned long context_id);

int32_t psci_cpu_off(void);

int32_t psci_cpu_on(unsigned long target_cpu, uintptr_t entrypoint, unsigned long context_id);

int32_t psci_affinity_info(unsigned long target_affinity, uint32_t lowest_affinity_level);

#endif /* __PSCI_H__ */
