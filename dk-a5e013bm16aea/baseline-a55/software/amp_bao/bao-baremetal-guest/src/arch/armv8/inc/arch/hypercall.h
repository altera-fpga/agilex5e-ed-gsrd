/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef __ARCH_HYPERCALL_H__
#define __ARCH_HYPERCALL_H__

#define SMCC32_FID_VND_HYP_SRVC 0x86000000

static uint64_t bao_hypercall(uint64_t hc_id, uint64_t arg1, uint64_t arg2, uint64_t arg3)
{
    register uint64_t r0 asm("x0") = SMCC32_FID_VND_HYP_SRVC | hc_id;
    register uint64_t r1 asm("x1") = arg1;
    register uint64_t r2 asm("x2") = arg2;
    register uint64_t r3 asm("x3") = arg3;

    asm volatile("hvc   #0\n" : "=r"(r0) : "r"(r0), "r"(r1), "r"(r2), "r"(r3));
    return r0;
}

#endif /* __ARCH_HYPERCALL_H__ */
