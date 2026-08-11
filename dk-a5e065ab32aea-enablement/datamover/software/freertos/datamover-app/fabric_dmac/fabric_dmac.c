/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * Data Mover Design MSGDMA2AXI4 subsystem driver
 */

#include <stdint.h>
#include "osal_log.h"
#include "socfpga_defines.h"
#include "socfpga_interrupt.h"
#include "datamover.h"
#include "fabric_dmac.h"

/**
 * @brief configure F2H dma controller
 *
 * This will configure the appropriate msgdma IP with the appropriate settings.
 * msgdma IPs have prefetcher mode enabled
 * 
 * @param[in] operation    READ_OPERATION or WRITE_OPERATION
 *
 * @return
 * - 0, on success
 * - ERR_INVALID_PARAMS, on invalid parameters
 *
 */
uint32_t configure_f2h_fdmac(operation_t operation)
{
    uint32_t reg_val;
    if (operation == READ_OPERATION) {
        // reset dispatcher
        reg_val = RD_REG32(F2H_DMAC_READ_DISPATCHER_CTL_ADDR);
        WR_REG32(F2H_DMAC_READ_DISPATCHER_CTL_ADDR, reg_val | DISPATCHER_RESET_MSK);

        // wait for dispatcher reset to complete
        while ((RD_REG32(F2H_DMAC_READ_DISPATCHER_STATUS_ADDR) & DISPATCHER_RESET_STATUS_MSK) != 0x0)
            ;

        // configure stop on error for dispatcher
        reg_val = RD_REG32(F2H_DMAC_READ_DISPATCHER_CTL_ADDR);
        WR_REG32(F2H_DMAC_READ_DISPATCHER_CTL_ADDR, reg_val | DISPATCHER_STOP_ON_ERR_MSK);

        // configure interrupt for dispatcher
        reg_val = RD_REG32(F2H_DMAC_READ_DISPATCHER_CTL_ADDR);
        WR_REG32(F2H_DMAC_READ_DISPATCHER_CTL_ADDR, reg_val | DISPATCHER_INTR_ENABLE_MSK);

        return 0;
    } else if (operation == WRITE_OPERATION) {
        // reset dispatcher
        reg_val = RD_REG32(F2H_DMAC_WRITE_DISPATCHER_CTL_ADDR);
        WR_REG32(F2H_DMAC_WRITE_DISPATCHER_CTL_ADDR, reg_val | DISPATCHER_RESET_MSK);

        // wait for dispatcher reset to complete
        while ((RD_REG32(F2H_DMAC_WRITE_DISPATCHER_STATUS_ADDR) & DISPATCHER_RESET_STATUS_MSK) != 0x0)
            ;

        // configure stop on error for dispatcher
        reg_val = RD_REG32(F2H_DMAC_WRITE_DISPATCHER_CTL_ADDR);
        WR_REG32(F2H_DMAC_WRITE_DISPATCHER_CTL_ADDR, reg_val | DISPATCHER_STOP_ON_ERR_MSK);

        // configure interrupt for dispatcher
        reg_val = RD_REG32(F2H_DMAC_WRITE_DISPATCHER_CTL_ADDR);
        WR_REG32(F2H_DMAC_WRITE_DISPATCHER_CTL_ADDR, reg_val | DISPATCHER_INTR_ENABLE_MSK);

        return 0;
    } else {
        ERROR("Invalid operation for Fabric DMAC configuration");
        return ERR_INVALID_PARAMS;
    }
}

/**
 * @brief configure F2SDRAM dma controller
 *
 * This will configure the appropriate msgdma IP with the appropriate settings.
 * msgdma IPs have prefetcher mode enabled
 * 
 * @param[in] operation    READ_OPERATION or WRITE_OPERATION
 *
 * @return
 * - 0, on success
 * - ERR_INVALID_PARAMS, on invalid parameters
 *
 */
uint32_t configure_f2sdram_fdmac(operation_t operation)
{
    uint32_t reg_val;
    if (operation == READ_OPERATION) {
        // reset dispatcher
        reg_val = RD_REG32(F2SDRAM_DMAC_READ_DISPATCHER_CTL_ADDR);
        WR_REG32(F2SDRAM_DMAC_READ_DISPATCHER_CTL_ADDR, reg_val | DISPATCHER_RESET_MSK);

        // wait for dispatcher reset to complete
        while ((RD_REG32(F2SDRAM_DMAC_READ_DISPATCHER_STATUS_ADDR) & DISPATCHER_RESET_STATUS_MSK) != 0x0)
            ;

        // configure stop on error for dispatcher
        reg_val = RD_REG32(F2SDRAM_DMAC_READ_DISPATCHER_CTL_ADDR);
        WR_REG32(F2SDRAM_DMAC_READ_DISPATCHER_CTL_ADDR, reg_val | DISPATCHER_STOP_ON_ERR_MSK);

        // configure interrupt for dispatcher
        reg_val = RD_REG32(F2SDRAM_DMAC_READ_DISPATCHER_CTL_ADDR);
        WR_REG32(F2SDRAM_DMAC_READ_DISPATCHER_CTL_ADDR, reg_val | DISPATCHER_INTR_ENABLE_MSK);

        return 0;
    } else if (operation == WRITE_OPERATION) {
        // reset dispatcher
        reg_val = RD_REG32(F2SDRAM_DMAC_WRITE_DISPATCHER_CTL_ADDR);
        WR_REG32(F2SDRAM_DMAC_WRITE_DISPATCHER_CTL_ADDR, reg_val | DISPATCHER_RESET_MSK);

        // wait for dispatcher reset to complete
        while ((RD_REG32(F2SDRAM_DMAC_WRITE_DISPATCHER_STATUS_ADDR) & DISPATCHER_RESET_STATUS_MSK) != 0x0)
            ;

        // configure stop on error for dispatcher
        reg_val = RD_REG32(F2SDRAM_DMAC_WRITE_DISPATCHER_CTL_ADDR);
        WR_REG32(F2SDRAM_DMAC_WRITE_DISPATCHER_CTL_ADDR, reg_val | DISPATCHER_STOP_ON_ERR_MSK);

        // configure interrupt for dispatcher
        reg_val = RD_REG32(F2SDRAM_DMAC_WRITE_DISPATCHER_CTL_ADDR);
        WR_REG32(F2SDRAM_DMAC_WRITE_DISPATCHER_CTL_ADDR, reg_val | DISPATCHER_INTR_ENABLE_MSK);

        return 0;
    } else {
        ERROR("Invalid operation for Fabric DMAC configuration");
        return ERR_INVALID_PARAMS;
    }
}

// F2H DMAC interrupt contexts
static fdmac_irq_context_t f2h_dmac_irq_contexts[2] = { 0 };

// F2SDRAM DMAC interrupt contexts
static fdmac_irq_context_t f2sdram_dmac_irq_contexts[2] = { 0 };

/**
 * @brief interrupt handler for fabric dma controller
 *
 * Interrupt handler gets triggered when a transfer is complete.
 * Clears the interrupt status and posts the semaphore to unblock
 * 
 * @param[in] f2X_dmac_irq_contexts  context containing register address and semaphore
 *
 */
void fdmac_irq_handler(void *data)
{
    fdmac_irq_context_t *irq_context = (fdmac_irq_context_t *)data;
    WR_REG32(irq_context->register_addr, DISPATCHER_INTR_STATUS_MSK);
    osal_semaphore_post(irq_context->semaphore);
}

/**
 * @brief setup interrupt for F2H dma controller or F2SDRAM dma controller
 *
 * This will set up the appropriate interrupt for different operations.
 * 
 * @param[in] operation    READ_OPERATION or WRITE_OPERATION
 * @param[in] done_sem     semaphore to post when interrupt occurs
 *
 * @return
 * - 0, on success
 * - Interrupt setup error code, on interrupt setup failure
 * - ERR_INVALID_PARAMS, on invalid parameters
 *
 */
uint32_t setup_f2h_fdmac_interrupt(operation_t operation, osal_semaphore_t done_sem)
{
    uint32_t interrupt_ret;

    if (operation == READ_OPERATION) {
        f2h_dmac_irq_contexts[0].register_addr = F2H_DMAC_READ_DISPATCHER_STATUS_ADDR;
        f2h_dmac_irq_contexts[0].semaphore = done_sem;

        interrupt_ret = interrupt_register_isr(FPGA2HPS_INTERRUPT0, fdmac_irq_handler, &f2h_dmac_irq_contexts[0]);
        if (interrupt_ret != 0) {
            return interrupt_ret;
        }

        interrupt_ret = interrupt_enable(FPGA2HPS_INTERRUPT0, GIC_INTERRUPT_PRIORITY_F2H);
        if (interrupt_ret != 0) {
            return interrupt_ret;
        }
    } else if (operation == WRITE_OPERATION) {
        f2h_dmac_irq_contexts[1].register_addr = F2H_DMAC_WRITE_DISPATCHER_STATUS_ADDR;
        f2h_dmac_irq_contexts[1].semaphore = done_sem;

        interrupt_ret = interrupt_register_isr(FPGA2HPS_INTERRUPT1, fdmac_irq_handler, &f2h_dmac_irq_contexts[1]);
        if (interrupt_ret != 0) {
            return interrupt_ret;
        }

        interrupt_ret = interrupt_enable(FPGA2HPS_INTERRUPT1, GIC_INTERRUPT_PRIORITY_F2H);
        if (interrupt_ret != 0) {
            return interrupt_ret;
        }
    } else {
        ERROR("Invalid operation for Fabric DMAC interrupt setup");
        return ERR_INVALID_PARAMS;
    }

    return 0;
}

/**
 * @brief setup interrupt for F2SDRAM dma controller or F2SDRAM dma controller
 *
 * This will set up the appropriate interrupt for different operations.
 * 
 * @param[in] operation    READ_OPERATION or WRITE_OPERATION
 * @param[in] done_sem     semaphore to post when interrupt occurs
 *
 * @return
 * - 0, on success
 * - Interrupt setup error code, on interrupt setup failure
 * - ERR_INVALID_PARAMS, on invalid parameters
 *
 */
uint32_t setup_f2sdram_fdmac_interrupt(operation_t operation, osal_semaphore_t done_sem)
{
    uint32_t interrupt_ret;

    if (operation == READ_OPERATION) {
        f2sdram_dmac_irq_contexts[0].register_addr = F2SDRAM_DMAC_READ_DISPATCHER_STATUS_ADDR;
        f2sdram_dmac_irq_contexts[0].semaphore = done_sem;

        interrupt_ret = interrupt_register_isr(FPGA2HPS_INTERRUPT2, fdmac_irq_handler, &f2sdram_dmac_irq_contexts[0]);
        if (interrupt_ret != 0) {
            return interrupt_ret;
        }

        interrupt_ret = interrupt_enable(FPGA2HPS_INTERRUPT2, GIC_INTERRUPT_PRIORITY_F2SDRAM);
        if (interrupt_ret != 0) {
            return interrupt_ret;
        }
    } else if (operation == WRITE_OPERATION) {
        f2sdram_dmac_irq_contexts[1].register_addr = F2SDRAM_DMAC_WRITE_DISPATCHER_STATUS_ADDR;
        f2sdram_dmac_irq_contexts[1].semaphore = done_sem;

        interrupt_ret = interrupt_register_isr(FPGA2HPS_INTERRUPT3, fdmac_irq_handler, &f2sdram_dmac_irq_contexts[1]);
        if (interrupt_ret != 0) {
            return interrupt_ret;
        }

        interrupt_ret = interrupt_enable(FPGA2HPS_INTERRUPT3, GIC_INTERRUPT_PRIORITY_F2SDRAM);
        if (interrupt_ret != 0) {
            return interrupt_ret;
        }
    } else {
        ERROR("Invalid operation for Fabric DMAC interrupt setup");
        return ERR_INVALID_PARAMS;
    }

    return 0;
}

/**
 * @brief push descriptor into mSGDMAs in the F2H dma controller
 *
 * This will push mSGDMA descriptor into the appropriate msgdma IP.
 * msgdma IPs have prefetcher mode disabled
 * 
 * @param[in] operation    READ_OPERATION or WRITE_OPERATION
 *
 * @return
 * - 0, on success
 * - ERR_INVALID_PARAMS, on invalid parameters
 *
 */
uint32_t f2h_dmac_push_descriptor(operation_t operation, uint32_t *descriptor)
{
    if (operation == READ_OPERATION) {
        WR_REG32(F2H_DMAC_READ_DESCRIPTOR_SLAVE_ADDR, descriptor[0]); // write source address
        WR_REG32(F2H_DMAC_READ_DESCRIPTOR_SLAVE_ADDR + 0x4, descriptor[1]); // write destination address
        WR_REG32(F2H_DMAC_READ_DESCRIPTOR_SLAVE_ADDR + 0x8, descriptor[2]); // write length
        return 0;
    } else if (operation == WRITE_OPERATION) {
        WR_REG32(F2H_DMAC_WRITE_DESCRIPTOR_SLAVE_ADDR, descriptor[0]); // write source address
        WR_REG32(F2H_DMAC_WRITE_DESCRIPTOR_SLAVE_ADDR + 0x4, descriptor[1]); // write destination address
        WR_REG32(F2H_DMAC_WRITE_DESCRIPTOR_SLAVE_ADDR + 0x8, descriptor[2]); // write length
        return 0;
    } else {
        ERROR("Invalid operation for Fabric DMAC descriptor address retrieval");
        return ERR_INVALID_PARAMS;
    }
}

/**
 * @brief push descriptor into mSGDMAs in the F2SDRAM dma controller
 *
 * This will push mSGDMA descriptor into the appropriate msgdma IP.
 * msgdma IPs have prefetcher mode disabled
 * 
 * @param[in] operation    READ_OPERATION or WRITE_OPERATION
 *
 * @return
 * - 0, on success
 * - ERR_INVALID_PARAMS, on invalid parameters
 *
 */
uint32_t f2sdram_dmac_push_descriptor(operation_t operation, uint32_t *descriptor)
{
    if (operation == READ_OPERATION) {
        WR_REG32(F2SDRAM_DMAC_READ_DESCRIPTOR_SLAVE_ADDR, descriptor[0]); // write source address
        WR_REG32(F2SDRAM_DMAC_READ_DESCRIPTOR_SLAVE_ADDR + 0x4, descriptor[1]); // write destination address
        WR_REG32(F2SDRAM_DMAC_READ_DESCRIPTOR_SLAVE_ADDR + 0x8, descriptor[2]); // write length
        return 0;
    } else if (operation == WRITE_OPERATION) {
        WR_REG32(F2SDRAM_DMAC_WRITE_DESCRIPTOR_SLAVE_ADDR, descriptor[0]); // write source address
        WR_REG32(F2SDRAM_DMAC_WRITE_DESCRIPTOR_SLAVE_ADDR + 0x4, descriptor[1]); // write destination address
        WR_REG32(F2SDRAM_DMAC_WRITE_DESCRIPTOR_SLAVE_ADDR + 0x8, descriptor[2]); // write length
        return 0;
    } else {
        ERROR("Invalid operation for Fabric DMAC descriptor address retrieval");
        return ERR_INVALID_PARAMS;
    }
}

/**
 * @brief start dma transfer on F2H dma controller
 *
 * This will start data transfer by writing the run bit to the appropriate msgdma IP.
 * msgdma IPs have prefetcher mode disabled
 * 
 * @param[in] operation    READ_OPERATION or WRITE_OPERATION
 *
 * @return
 * - 0, on success
 * - ERR_INVALID_PARAMS, on invalid parameters
 *
 */
uint32_t start_f2h_fdmac(operation_t operation, uint32_t *descriptor)
{
    if (operation == READ_OPERATION) {
        WR_REG32(F2H_DMAC_READ_DESCRIPTOR_SLAVE_ADDR + 0xC, descriptor[3]); // write control bits (GO bit)
        return 0;
    } else if (operation == WRITE_OPERATION) {
        WR_REG32(F2H_DMAC_WRITE_DESCRIPTOR_SLAVE_ADDR + 0xC, descriptor[3]); // write control bits (GO bit)
        return 0;
    } else {
        ERROR("Invalid operation for Fabric DMAC start");
        return ERR_INVALID_PARAMS;
    }
}

/**
 * @brief start dma transfer on F2SDRAM dma controller
 *
 * This will start data transfer by writing the run bit to the appropriate msgdma IP.
 * msgdma IPs have prefetcher mode disabled
 * 
 * @param[in] operation    READ_OPERATION or WRITE_OPERATION
 *
 * @return
 * - 0, on success
 * - ERR_INVALID_PARAMS, on invalid parameters
 *
 */
uint32_t start_f2sdram_fdmac(operation_t operation, uint32_t *descriptor)
{
    if (operation == READ_OPERATION) {
        WR_REG32(F2SDRAM_DMAC_READ_DESCRIPTOR_SLAVE_ADDR + 0xC, descriptor[3]); // write control bits (GO bit)
        return 0;
    } else if (operation == WRITE_OPERATION) {
        WR_REG32(F2SDRAM_DMAC_WRITE_DESCRIPTOR_SLAVE_ADDR + 0xC, descriptor[3]); // write control bits (GO bit)
        return 0;
    } else {
        ERROR("Invalid operation for Fabric DMAC start");
        return ERR_INVALID_PARAMS;
    }
}