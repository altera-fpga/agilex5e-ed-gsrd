/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 *
 * mmio.h — Volatile 32-bit MMIO read/write accessors.
 *
 * Used by drivers that need direct MMIO access without pulling in
 * platform-specific headers.  The uintptr_t address is cast to a
 * volatile uint32_t pointer so the compiler never elides or reorders
 * the access.  Peripheral ordering still requires explicit DSB/DMB at
 * the call site when the device is nGnRnE or nGnRE.
 */

#ifndef MMIO_H
#define MMIO_H

#include <stdint.h>

static inline uint32_t mmio_read32(uintptr_t addr)
{
    return *((volatile uint32_t *)addr);
}

static inline void mmio_write32(uintptr_t addr, uint32_t val)
{
    *((volatile uint32_t *)addr) = val;
}

#endif /* MMIO_H */
