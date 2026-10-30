/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef CYCLE_COUNTER_H_
#define CYCLE_COUNTER_H_

#include <core.h>
#include <arch/cycle_counter.h>

static inline uint64_t cc_get_count()
{
    return arch_cc_get_count();
}

static inline void cc_reset_count()
{
    arch_cc_reset_count();
}

static inline void cc_enable()
{
    arch_cc_enable();
}

static inline void cc_start()
{
    arch_cc_start();
}

#endif /* CYCLE_COUNTER_H_ */
