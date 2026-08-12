/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * F2H Task for SoC FPGA Data Mover Design
 */

#include <stdlib.h>
#include <stdint.h>
#include "osal.h"
#include "osal_log.h"
#include "socfpga_bridge.h"
#include "datamover.h"
#include "datamover_tasks.h"
#include "fabric_dmac.h"

#define ELEMENT_SIZE sizeof(uint64_t)
#define BLOCK_SIZE (OCM_SIZE / ELEMENT_SIZE)

// DMA transaction done semaphore
osal_semaphore_def_t f2h_done_sem_mem;
osal_semaphore_t f2h_done_sem;

void f2h_task(uint32_t transaction_seconds)
{
    ///////////////////////////////
    /* Set up FPGA-to-HPS bridge */
    ///////////////////////////////

    int bridge_ret;

    bridge_ret = disable_fpga2hps_bridge();
    if (bridge_ret != 0) {
        ERROR("Failed to disable FPGA2HPS bridge");
        return;
    }
    PRINT("FPGA2HPS bridge disabled");

    bridge_ret = enable_fpga2hps_bridge();
    if (bridge_ret != 0) {
        ERROR("Failed to enable FPGA2HPS bridge");
        return;
    }
    PRINT("FPGA2HPS bridge enabled");

    //////////////////////////
    /* Prepare data buffers */
    //////////////////////////

    volatile uint64_t *sdram_buf_1 = aligned_alloc(4096, NUM_BLOCKS * BLOCK_SIZE * ELEMENT_SIZE);
    if (sdram_buf_1 == NULL) {
        ERROR("Allocating SDRAM buffer 1 failed");
        return;
    }

    volatile uint64_t *sdram_buf_2 = aligned_alloc(4096, NUM_BLOCKS * BLOCK_SIZE * ELEMENT_SIZE);
    if (sdram_buf_2 == NULL) {
        ERROR("Allocating SDRAM buffer 2 failed");
        free((void *)sdram_buf_1);
        return;
    }

    for (size_t i = 0; i < NUM_BLOCKS * BLOCK_SIZE; i++) {
        sdram_buf_1[i] = (uint64_t)((i + 1) * 0xC);
        sdram_buf_2[i] = (uint64_t)0;
    }

    // Ensure all memory operations completed before proceeding
    __asm__ volatile("dsb sy" ::: "memory");

    ////////////////////////////////////
    /* Prepare MSGDMA descriptor list */
    ////////////////////////////////////

    volatile msgdma_descriptor_t *descriptors = aligned_alloc(
        4096, (2 * NUM_BLOCKS) * sizeof(msgdma_descriptor_t)); // 2 descriptors per block (one for read, one for write)
    if (descriptors == NULL) {
        ERROR("Allocating MSGDMA descriptor list failed");
        free((void *)sdram_buf_1);
        free((void *)sdram_buf_2);
        return;
    }

    for (size_t i = 0; i < NUM_BLOCKS; i++) {
        // Read descriptor (SDRAM to OCM)
        descriptors[i * 2].src_addr = (uint32_t)(uintptr_t)(&sdram_buf_1[i * BLOCK_SIZE]);
        descriptors[i * 2].dest_addr = (uint32_t)(uintptr_t)(OCM_C_ADDR);
        descriptors[i * 2].length = BLOCK_SIZE * ELEMENT_SIZE;
        descriptors[i * 2].control = DESC_CTRL_GO_MSK | DESC_CTRL_IRQ_ENABLE_MSK;

        // Write descriptor (OCM to SDRAM)
        descriptors[i * 2 + 1].src_addr = (uint32_t)(uintptr_t)(OCM_C_ADDR);
        descriptors[i * 2 + 1].dest_addr = (uint32_t)(uintptr_t)(&sdram_buf_2[i * BLOCK_SIZE]);
        descriptors[i * 2 + 1].length = BLOCK_SIZE * ELEMENT_SIZE;
        descriptors[i * 2 + 1].control = DESC_CTRL_GO_MSK | DESC_CTRL_IRQ_ENABLE_MSK;
    }

    ///////////////////////////
    /* Set up done semaphore */
    ///////////////////////////

    f2h_done_sem = osal_semaphore_create(&f2h_done_sem_mem);

    ////////////////////////
    /* Configure F2H DMAC */
    ////////////////////////

    uint32_t config_ret;

    config_ret = configure_f2h_fdmac(READ_OPERATION);
    if (config_ret != 0) {
        ERROR("Failed to configure F2H DMAC for read operation");
        goto cleanup;
    }

    config_ret = configure_f2h_fdmac(WRITE_OPERATION);
    if (config_ret != 0) {
        ERROR("Failed to configure F2H DMAC for write operation");
        goto cleanup;
    }

    ////////////////////////////////
    /* Set up F2H DMAC interrupts */
    ////////////////////////////////

    uint32_t int_ret;

    int_ret = setup_f2h_fdmac_interrupt(READ_OPERATION, f2h_done_sem);
    if (int_ret != 0) {
        ERROR("Failed to setup F2H DMAC read interrupt");
        goto cleanup;
    }

    int_ret = setup_f2h_fdmac_interrupt(WRITE_OPERATION, f2h_done_sem);
    if (int_ret != 0) {
        ERROR("Failed to setup F2H DMAC write interrupt");
        goto cleanup;
    }

    /////////////////////////
    /* Start F2H transfers */
    /////////////////////////

    // Timer-related variables
    uint64_t counter_freq;
    READ_TIMER_FRQ(counter_freq);
    uint64_t transaction_cycles = transaction_seconds * counter_freq;

    uint64_t transfer_start;
    uint64_t transfer_end;

    uint64_t num_iterations = 0;

    // Function return value variables
    uint32_t write_desc_ret;
    uint32_t start_ret;
    uint32_t sem_ret;

    PRINT("Starting F2H transfers for %u seconds ...", transaction_seconds);

    // Record initial timer value
    READ_TIMER(transfer_start);
    READ_TIMER(transfer_end);

    // Perform back-to-back data transfers in a loop until the specified transaction duration has elapsed
    while ((transfer_end - transfer_start) < transaction_cycles) {
        for (size_t i = 0; i < NUM_BLOCKS; i++) {
            // Push the read descriptor
            write_desc_ret = f2h_dmac_push_descriptor(READ_OPERATION, (uint32_t *)&descriptors[i * 2]);
            if (write_desc_ret != 0) {
                ERROR("Failed to write F2H DMAC read descriptor");
                goto cleanup;
            }

            // Start read transfer
            start_ret = start_f2h_fdmac(READ_OPERATION, (uint32_t *)&descriptors[i * 2]);
            if (start_ret != 0) {
                ERROR("Failed to start F2H DMAC read transfer");
                goto cleanup;
            }

            // Wait for read transfer to complete
            sem_ret = osal_semaphore_wait(f2h_done_sem, 10000);
            if (sem_ret != pdTRUE) {
                ERROR("F2H transfer timed out");
                goto cleanup;
            }

            // Push the write descriptor
            write_desc_ret = f2h_dmac_push_descriptor(WRITE_OPERATION, (uint32_t *)&descriptors[i * 2 + 1]);
            if (write_desc_ret != 0) {
                ERROR("Failed to write F2H DMAC write descriptor");
                goto cleanup;
            }

            // Start write transfer
            start_ret = start_f2h_fdmac(WRITE_OPERATION, (uint32_t *)&descriptors[i * 2 + 1]);
            if (start_ret != 0) {
                ERROR("Failed to start F2H DMAC write transfer");
                goto cleanup;
            }

            // Wait for write transfer to complete
            sem_ret = osal_semaphore_wait(f2h_done_sem, 10000);
            if (sem_ret != pdTRUE) {
                ERROR("F2H transfer timed out");
                goto cleanup;
            }
        }

        num_iterations++;

        READ_TIMER(transfer_end);
    }

    /////////////////////////////////////////////
    /* Calculate and print transfer statistics */
    /////////////////////////////////////////////

    double elapsed_time = (double)(transfer_end - transfer_start) / (double)counter_freq;
    uint64_t total_data_transferred = (NUM_BLOCKS * BLOCK_SIZE * ELEMENT_SIZE) * 2 * num_iterations / ONE_MIL_BYTES;

    PRINT("Total data transferred for F2H transfers in %f seconds: %lu MB -- Average transfer bandwidth is: %f MB/s",
          elapsed_time, total_data_transferred, (total_data_transferred / elapsed_time));

    ///////////////////////
    /* Clean up and exit */
    ///////////////////////

cleanup:
    free((void *)sdram_buf_1);
    free((void *)sdram_buf_2);
    free((void *)descriptors);
    osal_semaphore_delete(f2h_done_sem);
    return;
}