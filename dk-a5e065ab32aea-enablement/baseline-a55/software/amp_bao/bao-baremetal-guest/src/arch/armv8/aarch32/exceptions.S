/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#include <sysregs.h>

.text

.balign 0x20
.global _exception_vector
_exception_vector:
    b .
    b .
    b .
    b .
    b .
    b .
    b irq_handler

irq_handler:
    push {r0-r12, r14}
    bl gic_handle
    pop {r0-r12, r14}
    SUBS PC, lr, #4
