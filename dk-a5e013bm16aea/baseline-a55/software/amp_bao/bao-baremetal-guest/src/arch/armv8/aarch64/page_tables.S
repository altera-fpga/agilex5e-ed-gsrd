/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#include <core.h>
#include <page_tables.h>
#include <plat.h>

.section .page_tables, "aw"
.balign PAGE_SIZE

l2_page_tables:
    .set ADDR, 0

    .set COUNT, MEM_BASE/L2_BLOCK_SIZE
    .rept   COUNT
    .8byte (PTE_SUPERPAGE | PTE_DEV_FLAGS) + ADDR
    .set ADDR, ADDR + L2_BLOCK_SIZE
    .endr

    .set COUNT, MEM_SIZE/L2_BLOCK_SIZE
    .rept   COUNT
    .8byte (PTE_SUPERPAGE | PTE_MEM_FLAGS) + ADDR
    .set ADDR, ADDR + L2_BLOCK_SIZE
    .endr

#if SHMEM_SIZE > 0
    .set COUNT, (SHMEM_BASE - ADDR)/L2_BLOCK_SIZE
    .rept   COUNT
    .8byte (PTE_SUPERPAGE | PTE_DEV_FLAGS) + ADDR
    .set ADDR, ADDR + L2_BLOCK_SIZE
    .endr

    /* Shmem: Stage-1 cacheability must match SHMEM_IS flag to agree with Stage-2 */
#if SHMEM_IS
    /* SHMEM_IS=1: Normal WB Inner Shareable (MAIR index 1) - hardware coherent */
    .set COUNT, (SHMEM_BASE + SHMEM_SIZE - ADDR)/L2_BLOCK_SIZE
    .rept   COUNT
    .8byte (PTE_SUPERPAGE | PTE_IS_FLAGS) + ADDR
    .set ADDR, ADDR + L2_BLOCK_SIZE
    .endr
#else
    /* SHMEM_IS=0: Normal Non-Cacheable (MAIR index 3) - original */
    .set COUNT, (SHMEM_BASE + SHMEM_SIZE - ADDR)/L2_BLOCK_SIZE
    .rept   COUNT
    .8byte (PTE_SUPERPAGE | PTE_NC_FLAGS) + ADDR
    .set ADDR, ADDR + L2_BLOCK_SIZE
    .endr
#endif
#endif

    .set COUNT, (0x100000000 - ADDR)/L2_BLOCK_SIZE
    .rept   COUNT
    .8byte (PTE_SUPERPAGE | PTE_DEV_FLAGS) + ADDR
    .set ADDR, ADDR + L2_BLOCK_SIZE
    .endr

    .balign PAGE_SIZE

l1_page_table:
    .8byte (PTE_TABLE) + l2_page_tables + PAGE_SIZE*0
    .8byte (PTE_TABLE) + l2_page_tables + PAGE_SIZE*1
    .8byte (PTE_TABLE) + l2_page_tables + PAGE_SIZE*2
    .8byte (PTE_TABLE) + l2_page_tables + PAGE_SIZE*3
    .balign PAGE_SIZE

.global root_page_table
root_page_table:
    .8byte (PTE_TABLE) + l1_page_table
    .balign PAGE_SIZE
