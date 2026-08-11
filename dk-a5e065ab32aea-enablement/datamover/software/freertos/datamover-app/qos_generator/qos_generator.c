/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * QOS Generator driver for SoC FPGA Data Mover Design
 */

#include <stdint.h>
#include "socfpga_defines.h"
#include "qos_generator.h"

void configure_qos_generator(uintptr_t register_addr, uint32_t qos_value)
{
    WR_REG32(register_addr, qos_value);
}