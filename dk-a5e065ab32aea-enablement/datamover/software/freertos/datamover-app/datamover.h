/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * Header file for Data Mover Design Example
 */

#ifndef __DATAMOVER_H__
#define __DATAMOVER_H__

typedef enum { H2F_BRIDGE = 0, LWH2F_BRIDGE = 1, F2H_BRIDGE = 2, F2SDRAM_BRIDGE = 3 } bridge_type_t;

#define H2F_BASE_ADDR 0x40000000
#define LWH2F_BASE_ADDR 0x20000000

#define OCM_A_OFFSET 0x00000000
#define OCM_A_ADDR (H2F_BASE_ADDR + OCM_A_OFFSET)

#define OCM_B_OFFSET 0x00000000
#define OCM_B_ADDR (LWH2F_BASE_ADDR + OCM_B_OFFSET)

#define OCM_C_ADDR 0x00000000

#define OCM_D_ADDR 0x00000000

#define ONE_MIL_BYTES 1000000

#endif /* __DATAMOVER_H__ */
