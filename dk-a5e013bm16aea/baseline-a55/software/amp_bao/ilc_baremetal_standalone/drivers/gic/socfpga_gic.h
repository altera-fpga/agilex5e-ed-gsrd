/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

#ifndef __SOCFPGA_GIC_H__
#define __SOCFPGA_GIC_H__

#include <stdint.h>

/*
 * Agilex5 SoCFPGA GIC-600 base addresses — REAL HARDWARE
 * Source: https://www.intel.com/content/www/us/en/programmable/hps/agilex5-es/topics/addressblock_GIC_summary.html
 *
 * GICD  : 0x1D000000
 * Rlpi0 : 0x1D060000  ← CPU0 (A55) redistributor LPI frame
 * Rsgi0 : 0x1D070000  ← CPU0 (A55) redistributor SGI frame  (handled by struct layout)
 * Rlpi1 : 0x1D080000  ← CPU1 redistributor (A55 #1 or A76 depending on config)
 *
 * gic_v3_rdist_if struct = 128KB per PE (lpis @+0x0000, sgis @+0x10000)
 * So GICR base = 0x1D060000 covers CPU0 lpis+sgis correctly.
 */
#define REGISTER_SOCFPGA_DIST_BASE_ADDR (0x1D000000U)
#define REGISTER_SOCFPGA_RD_BASE_ADDR (0x1D060000U)

#define GICV3_GROUP0 (0U)
#define GICV3_GROUP1_SECURE (1U)
#define GICV3_GROUP1_NON_SECURE (2U)

#define GICV3_CONFIG_LEVEL (0U)
#define GICV3_CONFIG_EDGE (2U)
#define GICV3_ROUTE_MODE_ANY (0x80000000U)
#define GICV3_ROUTE_MODE_COORDINATE (0U)

/* Return codes */
#define INTERRUPT_RETURN_SUCCESS 0
#define INTERRUPT_RETURN_ERROR -1
#define INTERRUPT_RETURN_INVALID_PRIORITY -2
#define INTERRUPT_RETURN_INVALID_RDIST -3
#define INTERRUPT_RETURN_INVALID_ID -4
#define INTERRUPT_RETURN_INVALID_GROUP -5
#define INTERRUPT_RETURN_INVALID_SPI -6

int32_t gic_enable_gic(void);
int32_t gic_get_redist_id(uint32_t affinity);
int32_t gic_wakeup_redist(uint32_t rd);

int32_t gic_set_int_priority(uint32_t id, uint32_t rd, uint8_t priority);
int32_t gic_set_int_group(uint32_t id, uint32_t rd, uint32_t security);
int32_t gic_set_int_route(uint32_t id, uint32_t mode, uint32_t affinity);

int32_t gic_enable_int(uint32_t id, uint32_t rd);
int32_t gic_disable_int(uint32_t id, uint32_t rd);
int32_t gic_set_int_type(uint32_t id, uint32_t rd, uint32_t type);
int32_t gic_clear_int_pending(uint32_t id, uint32_t rd);
int32_t gic_set_int_pending(uint32_t id, uint32_t rd);

void gic_enable_interrupts(void);

#endif /* __SOCFPGA_GIC_H__ */
