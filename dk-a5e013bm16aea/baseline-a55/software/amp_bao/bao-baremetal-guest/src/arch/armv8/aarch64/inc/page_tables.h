/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef PAGE_TABLES_H
#define PAGE_TABLES_H

#define PTE_TYPE_MSK (0x3)
#define PTE_VALID (0x1)
#define PTE_SUPERPAGE (0x1)
#define PTE_TABLE (0x3)
#define PTE_PAGE (0x3)

#define PTE_NSTable (1LL << 63)
#define PTE_APTable_OFF (61)
#define PTE_APTable_MSK (0x3LL << PTE_APTable_OFF)
#define PTE_APTable_ALL (0x0LL << PTE_APTable_OFF)
#define PTE_APTable_NOEL0 (0x1LL << PTE_APTable_OFF)
#define PTE_APTable_RO (0x2LL << PTE_APTable_OFF)
#define PTE_APTable_RO_NOEL0 (0x3LL << PTE_APTable_OFF)
#define PTE_XNTable (1LL << 60)
#define PTE_PXNTable (1LL << 59)

#define PTE_PBHA_OFF (59)
#define PTE_PBHA_MSK (0xf << PTE_PBHA_OFF)
#define PTE_PBHA(VAL) ((VAL << PTE_PBHA_OFF) & PTE_PBHA_MSK)
#define PTE_XN (1LL << 54)
#define PTE_PXN (1LL << 53)
#define PTE_Con (1LL << 52)
#define PTE_DBM (1LL << 51)
#define PTE_nG (1LL << 11)
#define PTE_AF (1LL << 10)
#define PTE_SH_OFF (8)
#define PTE_SH_MSK (0x3LL << PTE_SH_OFF)
#define PTE_SH_NS (0x0LL << PTE_SH_OFF)
#define PTE_SH_OS (0x2LL << PTE_SH_OFF)
#define PTE_SH_IS (0x3LL << PTE_SH_OFF)
#define PTE_AP_OFF (6)
#define PTE_AP_MSK (0x3LL << PTE_AP_OFF)
#define PTE_AP_RW_PRIV (0x0LL << PTE_AP_OFF)
#define PTE_AP_RO_PRIV (0x2LL << PTE_AP_OFF)
#define PTE_AP_RW (0x1LL << PTE_AP_OFF)
#define PTE_AP_RO (0x3LL << PTE_AP_OFF)
#define PTE_NS (1 << 5)
#define PTE_ATTR_OFF (2)
#define PTE_ATTR_MSK (0x7LL << PTE_ATTR_OFF)
#define PTE_ATTR(N) ((N << PTE_ATTR_OFF) & PTE_ATTR_MSK)

#define PAGE_SIZE 0x1000
#define L1_BLOCK_SIZE 0x4000000
#define L2_BLOCK_SIZE 0x200000
#define PTE_MEM_FLAGS (PTE_ATTR(1) | PTE_AP_RW_PRIV | PTE_SH_IS | PTE_AF)
#define PTE_DEV_FLAGS (PTE_ATTR(2) | PTE_AP_RW_PRIV | PTE_SH_IS | PTE_AF)
/* Normal Non-Cacheable — used for Stage-1 shmem when SHMEM_IS=0 (MAIR index 3) */
#define PTE_NC_FLAGS (PTE_ATTR(3) | PTE_AP_RW_PRIV | PTE_SH_IS | PTE_AF)
/* Normal WB Inner Shareable — used for Stage-1 shmem when SHMEM_IS=1 (MAIR index 1) */
#define PTE_IS_FLAGS (PTE_ATTR(1) | PTE_AP_RW_PRIV | PTE_SH_IS | PTE_AF)

#if ((MEM_BASE) % L2_BLOCK_SIZE)
#error MEM_BASE is misaligned. It should be align to L2_BLOCK_SIZE.
#endif
#if ((MEM_SIZE) % L2_BLOCK_SIZE)
#error MEM_SIZE is misaligned. It should be align to L2_BLOCK_SIZE.
#endif

#if ((SHMEM_BASE) % L2_BLOCK_SIZE)
#error SHMEM_BASE is misaligned. It should be align to L2_BLOCK_SIZE.
#endif
#if ((SHMEM_SIZE) % L2_BLOCK_SIZE)
#error SHMEM_SIZE is misaligned. It should be align to L2_BLOCK_SIZE.
#endif

#endif
