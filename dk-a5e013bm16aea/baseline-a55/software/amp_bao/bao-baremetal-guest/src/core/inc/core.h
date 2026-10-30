/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef CORE_H
#define CORE_H

#ifndef __ASSEMBLER__

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <plat.h>

#endif /* __ASSEMBLER__ */

#ifdef STD_ADDR_SPACE
#if defined(MPU) || defined(MEM_NON_UNIFIED)
#error Cannot provide STD_ADDR_SPACE for MPU or MEM_NON_UNIFIED systems
#endif
#if defined(MEM_BASE) || defined(MEM_SIZE)
#error Cannot define MEM_BASE or MEM_SIZE for STD_ADDR_SPACE
#endif
#define MEM_BASE (0x00000000)
#define MEM_SIZE (0x80000000)
#define UART_ADDR (0xff000000)
#else

#if !defined(MEM_NON_UNIFIED)
#ifndef MEM_BASE
#define MEM_BASE PLAT_MEM_BASE
#endif

#ifndef MEM_SIZE
#define MEM_SIZE PLAT_MEM_SIZE
#endif

#else /* non-unified */

#ifndef RO_MEM_BASE
#define RO_MEM_BASE PLAT_RO_MEM_BASE
#endif

#ifndef RO_MEM_SIZE
#define RO_MEM_SIZE PLAT_RO_MEM_SIZE
#endif

#ifndef RW_MEM_BASE
#define RW_MEM_BASE PLAT_RW_MEM_BASE
#endif

#ifndef RW_MEM_SIZE
#define RW_MEM_SIZE PLAT_RW_MEM_SIZE
#endif
#endif

#ifndef STACKHEAP_SIZE
#define STACKHEAP_SIZE PLAT_STACKHEAP_SIZE
#endif

#define UART_ADDR PLAT_UART_ADDR
#endif

#ifdef MEM_NON_UNIFIED
#if !defined(RO_MEM_BASE) || !defined(RO_MEM_SIZE) || !defined(RW_MEM_BASE) || !defined(RW_MEM_SIZE)
#error "Non-unified model requires RO_MEM_BASE/RO_MEM_SIZE and RW_MEM_BASE/RW_MEM_SIZE."
#endif

#if defined(MEM_BASE) || defined(MEM_SIZE)
#error "Non-unified model must not define MEM_BASE/MEM_SIZE."
#endif
#else /* unified */
#if !defined(MEM_BASE) || !defined(MEM_SIZE)
#error "Unified model requires MEM_BASE and MEM_SIZE."
#endif
#endif

#ifndef SHMEM_BASE
#define SHMEM_BASE (0UL)
#endif

#ifndef SHMEM_SIZE
#define SHMEM_SIZE (0UL)
#endif

#if (SHMEM_SIZE > 0)
#if ((SHMEM_SIZE) > (0x100000000ULL - (SHMEM_BASE)))
#error "Invalid SHMEM_BASE and/or SHMEM_SIZE: SHMEM region crosses 4GiB boundary"
#endif

#if ((SHMEM_BASE) < ((MEM_BASE) + (MEM_SIZE)))
#error "Invalid SHMEM_BASE SHMEM region must be after MEM"
#endif
#endif

#endif /* CORE_H */
