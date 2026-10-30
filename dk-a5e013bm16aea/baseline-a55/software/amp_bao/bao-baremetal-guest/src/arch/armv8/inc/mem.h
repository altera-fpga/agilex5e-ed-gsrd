/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef ARCH_MPU_H
#define ARCH_MPU_H

#include <sysregs.h>

#ifndef __ASSEMBLER__

#if defined(MPU)

/* MAIR attribute indices for memory regions */
#define PRBAR_ATTR_NORMAL 1 /* Normal memory (cacheable, code/data) */
#define PRBAR_ATTR_DEVICE 2 /* Device memory (peripherals, IO) */

/* MPU-based platforms need to define their MPU regions in the platform description. This involves
 * defining the base address, size, and access permissions for each region using the
 * MPU_REGION_DESC macro. The platform must also define the number of regions using the
 * DEFINE_PLAT_MPU_NUM_REGS macro.
 */
struct mpu_region {
    unsigned long prbar;
    unsigned long prlar;
};

#define MPU_REGION_DESC(_base, _size, _sh, _perm, _attr)                            \
    {                                                                               \
        .prbar = PRBAR_BASE((_base)) | (_sh) | (_perm),                             \
        .prlar = PRLAR_LIMIT((_base) + (_size) - 1) | PRLAR_ATTR(_attr) | PRLAR_EN, \
    }

extern const struct mpu_region plat_mpu_regs[];
extern const size_t plat_mpu_num_regs;

#define DEFINE_PLAT_MPU_NUM_REGS() const size_t plat_mpu_num_regs = sizeof(plat_mpu_regs) / sizeof(plat_mpu_regs[0])
#endif

#endif /* __ASSEMBLER__ */

#endif /* ARCH_MPU_H */
