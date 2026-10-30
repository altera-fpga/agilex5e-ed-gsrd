/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef WFI_H
#define WFI_H

static inline void wfi()
{
    asm volatile("wfi\n\t" ::: "memory");
}

#endif
