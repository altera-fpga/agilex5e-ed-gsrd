/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef PAGE_TABLES_H
#define PAGE_TABLES_H

#define PTE_TYPE_MSK (0x3)
#define PTE_TABLE (0x1)
#define PTE_PAGE (0x2)
#define PTE_SUPERPAGE (PTE_PAGE)

#define PTE_PXN (0x1U << 1)
#define PTE_B (0x1U << 2)
#define PTE_C (0x1U << 3)
#define PTE_XN (0x1U << 4)
#define PTE_DOMAIN_OFF (5)
#define PTE_DOMAIN_MSK (0xfU << PTE_DOMAIN_OFF)
#define PTE_DOMAIN(N) (((N) << PTE_DOMAIN_OFF) & PTE_DOMAIN_MSK)
#define PTE_A (1 << 10) // AP[0]
#define PTE_AP_OFF (11)
#define PTE_AP_MSK (0x11U << PTE_AP_OFF)
#define PTE_AP_RW_PRIV (0x00U << PTE_AP_OFF)
#define PTE_AP_RW (0x01U << PTE_AP_OFF)
#define PTE_AP_RO_PRIV (0x10U << PTE_AP_OFF)
#define PTE_AP_RO (0x11U << PTE_AP_OFF)
#define PTE_TEX_OFF (12)
#define PTE_TEX_MSK (0x7 << PTE_TEX_OFF)
#define PTE_TEX(T) (((T) << PTE_TEX_OFF) & PTE_TEX_MSK)
#define PTE_S (0x1U << 16)
#define PTE_nG (0x1U << 17)

#define PTE_DEVnGnRnE (PTE_TEX(0))
#define PTE_DEVnGnRE (PTE_TEX(0) | PTE_B)
#define PTE_OI_WT_RA_NWA (PTE_TEX(0) | PTE_C)
#define PTE_OI_WB_RA_NWA (PTE_TEX(0) | PTE_C | PTE_B)
#define PTE_OI_NC (PTE_TEX(1))
#define PTE_OI_WB_RA_WA (PTE_TEX(1) | PTE_C | PTE_B)
/**
 * There are other possible encodings for different inner/outer attributes
 * which are not defined here.
 */

#define PAGE_SIZE 0x1000
#define L1_BLOCK_SIZE 0x100000
#define PTE_MEM_FLAGS (PTE_OI_WB_RA_WA | PTE_A | PTE_AP_RW_PRIV | PTE_DOMAIN(0) | PTE_S)
#define PTE_DEV_FLAGS (PTE_DEVnGnRnE | PTE_A | PTE_AP_RW_PRIV | PTE_DOMAIN(0) | PTE_S)

#endif
