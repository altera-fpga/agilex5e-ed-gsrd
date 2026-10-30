/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef __BIT_H__
#define __BIT_H__

#include <core.h>

#define BIT_MASK(OFF, LEN) (((1UL << (OFF + LEN)) - 1) & ~((1UL << (OFF)) - 1))

#ifndef __ASSEMBLER__

static inline unsigned long bit_get(unsigned long word, unsigned long off)
{
    return word & (1UL << off);
}

static inline unsigned long bit_set(unsigned long word, unsigned long off)
{
    return word |= (1UL << off);
}

static inline unsigned long bit_clear(unsigned long word, unsigned long off)
{
    return word &= ~(1UL << off);
}

static inline unsigned long bit_extract(unsigned long word, unsigned long off, unsigned long len)
{
    return (word >> off) & BIT_MASK(0, len);
}

static inline unsigned long bit_insert(unsigned long word, unsigned long val, unsigned long off, unsigned long len)
{
    return (~BIT_MASK(off, len) & word) | ((BIT_MASK(0, len) & val) << off);
}

#endif /* |__ASSEMBLER__ */

#endif /* __BIT_H__ */
