/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

#ifndef __SOCFPGA_GIC_REG_H__
#define __SOCFPGA_GIC_REG_H__

#include <stdint.h>

void gic_reg_enable_group0_interrupts(void);
void gic_reg_enable_group1_interrupts(void);
void gic_reg_write_group1_end_of_interrupt(uint32_t interrupt_id);
void gic_reg_write_dir(uint32_t interrupt_id);
void gic_reg_set_priority_mask(uint32_t priority);
uint64_t gic_reg_get_cpu_affinity(void);

#endif /* __SOCFPGA_GIC_REG_H__ */
