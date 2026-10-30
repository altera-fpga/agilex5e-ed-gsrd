/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef __SPINLOCK__
#define __SPINLOCK__

#include <core.h>

typedef volatile uint32_t spinlock_t;

#define SPINLOCK_INITVAL (0)

static inline void spin_lock(spinlock_t *lock)
{
    uint32_t const ONE = 1;
    spinlock_t tmp;

    asm volatile("1:\n\t"
                 "ldaxr %w0, %1 \n\t"
                 "cbnz %w0, 1b \n\t"
                 "stxr %w0, %w2, %1 \n\t"
                 "cbnz %w0, 1b \n\t"
                 : "=&r"(tmp), "+Q"(*lock)
                 : "r"(ONE));
}

static inline void spin_unlock(spinlock_t *lock)
{
    asm volatile("stlr wzr, %0\n\t" ::"Q"(*lock));
}

#endif
