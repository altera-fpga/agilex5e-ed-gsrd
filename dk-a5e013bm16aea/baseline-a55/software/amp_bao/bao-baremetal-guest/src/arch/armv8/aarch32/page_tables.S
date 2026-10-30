/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#include <core.h>
#include <page_tables.h>
#include <plat.h>

.section .page_tables, "aw"

.balign (16 * 0x400)
.global page_table
page_table:
    .set ADDR, 0

    .set COUNT, MEM_BASE/L1_BLOCK_SIZE
    .rept   COUNT
    .4byte (PTE_SUPERPAGE | PTE_DEV_FLAGS) + ADDR
    .set ADDR, ADDR + L1_BLOCK_SIZE
    .endr

    .set COUNT, MEM_SIZE/L1_BLOCK_SIZE
    .rept   COUNT
    .4byte (PTE_SUPERPAGE | PTE_MEM_FLAGS) + ADDR
    .set ADDR, ADDR + L1_BLOCK_SIZE
    .endr

    .set COUNT, (0x100000000 - ADDR)/L1_BLOCK_SIZE
    .rept   COUNT
    .4byte (PTE_SUPERPAGE | PTE_DEV_FLAGS) + ADDR
    .set ADDR, ADDR + L1_BLOCK_SIZE
    .endr
