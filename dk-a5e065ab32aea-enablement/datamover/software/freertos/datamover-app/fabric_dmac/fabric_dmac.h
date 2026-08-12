/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * Header file for fabric DMAC driver
 */

#ifndef __FABRIC_DMA_H__
#define __FABRIC_DMA_H__

#include <stdint.h>
#include "osal.h"
#include "datamover.h"

typedef struct msgdma_descriptor {
    uint32_t src_addr;
    uint32_t dest_addr;
    uint32_t length;
    uint32_t control;
} msgdma_descriptor_t;

typedef struct fdmac_irq_context {
    uint32_t register_addr;
    osal_semaphore_t semaphore;
} fdmac_irq_context_t;

#define F2H_DMAC_OFF 0x10000000
#define F2SDRAM_DMAC_OFF 0x11000000

#define MSGDMA_READ_DISPATCHER_CSR_OFF 0x20
#define MSGDMA_READ_DESCRIPTOR_SLAVE_OFF 0x50
#define MSGDMA_WRITE_DISPATCHER_CSR_OFF 0x00
#define MSGDMA_WRITE_DESCRIPTOR_SLAVE_OFF 0x40

#define F2H_DMAC_READ_DISPATCHER_STATUS_ADDR (LWH2F_BASE_ADDR + F2H_DMAC_OFF + MSGDMA_READ_DISPATCHER_CSR_OFF + 0x0)
#define F2H_DMAC_READ_DISPATCHER_CTL_ADDR (LWH2F_BASE_ADDR + F2H_DMAC_OFF + MSGDMA_READ_DISPATCHER_CSR_OFF + 0x4)
#define F2H_DMAC_READ_DESCRIPTOR_SLAVE_ADDR (LWH2F_BASE_ADDR + F2H_DMAC_OFF + MSGDMA_READ_DESCRIPTOR_SLAVE_OFF)
#define F2H_DMAC_WRITE_DISPATCHER_STATUS_ADDR (LWH2F_BASE_ADDR + F2H_DMAC_OFF + MSGDMA_WRITE_DISPATCHER_CSR_OFF + 0x0)
#define F2H_DMAC_WRITE_DISPATCHER_CTL_ADDR (LWH2F_BASE_ADDR + F2H_DMAC_OFF + MSGDMA_WRITE_DISPATCHER_CSR_OFF + 0x4)
#define F2H_DMAC_WRITE_DESCRIPTOR_SLAVE_ADDR (LWH2F_BASE_ADDR + F2H_DMAC_OFF + MSGDMA_WRITE_DESCRIPTOR_SLAVE_OFF)

#define F2SDRAM_DMAC_READ_DISPATCHER_STATUS_ADDR \
    (LWH2F_BASE_ADDR + F2SDRAM_DMAC_OFF + MSGDMA_READ_DISPATCHER_CSR_OFF + 0x0)
#define F2SDRAM_DMAC_READ_DISPATCHER_CTL_ADDR \
    (LWH2F_BASE_ADDR + F2SDRAM_DMAC_OFF + MSGDMA_READ_DISPATCHER_CSR_OFF + 0x4)
#define F2SDRAM_DMAC_READ_DESCRIPTOR_SLAVE_ADDR (LWH2F_BASE_ADDR + F2SDRAM_DMAC_OFF + MSGDMA_READ_DESCRIPTOR_SLAVE_OFF)
#define F2SDRAM_DMAC_WRITE_DISPATCHER_STATUS_ADDR \
    (LWH2F_BASE_ADDR + F2SDRAM_DMAC_OFF + MSGDMA_WRITE_DISPATCHER_CSR_OFF + 0x0)
#define F2SDRAM_DMAC_WRITE_DISPATCHER_CTL_ADDR \
    (LWH2F_BASE_ADDR + F2SDRAM_DMAC_OFF + MSGDMA_WRITE_DISPATCHER_CSR_OFF + 0x4)
#define F2SDRAM_DMAC_WRITE_DESCRIPTOR_SLAVE_ADDR \
    (LWH2F_BASE_ADDR + F2SDRAM_DMAC_OFF + MSGDMA_WRITE_DESCRIPTOR_SLAVE_OFF)

#define DISPATCHER_INTR_ENABLE_MSK 0x10
#define DISPATCHER_RESET_MSK 0x02
#define DISPATCHER_STOP_ON_ERR_MSK 0x04

#define DISPATCHER_INTR_STATUS_MSK 0x200
#define DISPATCHER_RESET_STATUS_MSK 0x040

// Descriptor control field masks
#define DESC_CTRL_GO_MSK 0x80000000
#define DESC_CTRL_IRQ_ENABLE_MSK 0x4000

#define GIC_INTERRUPT_PRIORITY_F2H 14
#define GIC_INTERRUPT_PRIORITY_F2SDRAM 14

#define ERR_INVALID_PARAMS 0xd

typedef enum { READ_OPERATION = 0, WRITE_OPERATION = 1 } operation_t;

uint32_t configure_f2h_fdmac(operation_t operation);
uint32_t setup_f2h_fdmac_interrupt(operation_t operation, osal_semaphore_t done_sem);
uint32_t f2h_dmac_push_descriptor(operation_t operation, uint32_t *descriptor);
uint32_t start_f2h_fdmac(operation_t operation, uint32_t *descriptor);

uint32_t configure_f2sdram_fdmac(operation_t operation);
uint32_t setup_f2sdram_fdmac_interrupt(operation_t operation, osal_semaphore_t done_sem);
uint32_t f2sdram_dmac_push_descriptor(operation_t operation, uint32_t *descriptor);
uint32_t start_f2sdram_fdmac(operation_t operation, uint32_t *descriptor);

#endif /* __FABRIC_DMA_H__ */
