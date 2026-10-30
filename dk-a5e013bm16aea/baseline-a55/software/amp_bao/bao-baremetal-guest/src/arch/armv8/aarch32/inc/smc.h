/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef SMC_H
#define SMC_H

static inline int smc_call(uint64_t x0, uint64_t x1, uint64_t x2, uint64_t x3)
{
    register uint64_t r0 asm("r0") = x0;
    register uint64_t r1 asm("r1") = x1;
    register uint64_t r2 asm("r2") = x2;
    register uint64_t r3 asm("r3") = x3;

    asm volatile("smc	#0\n" : "=r"(r0) : "r"(r0), "r"(r1), "r"(r2) : "r3");

    return r0;
}

#endif
