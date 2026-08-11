/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * S2S Task for SoC FPGA Data Mover Design
 */

#include <stdlib.h>
#include <stdint.h>
#include "osal.h"
#include "osal_log.h"
#include "socfpga_cache.h"
#include "event_groups.h"
#include "datamover.h"
#include "datamover_tasks.h"

#define ELEMENT_SIZE sizeof(uint64_t)
#define BLOCK_SIZE (OCM_SIZE / ELEMENT_SIZE)

void s2s_task(EventGroupHandle_t execution_barrier, uint32_t thread_bit, uint32_t all_threads,
              uint32_t transaction_seconds)
{
    //////////////////////////
    /* Prepare data buffers */
    //////////////////////////

    volatile uint64_t *sdram_buf_1 = aligned_alloc(4096, NUM_BLOCKS * BLOCK_SIZE * ELEMENT_SIZE);
    if (sdram_buf_1 == NULL) {
        ERROR("Allocating SDRAM buffer 1 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        return;
    }

    volatile uint64_t *sdram_buf_2 = aligned_alloc(4096, NUM_BLOCKS * BLOCK_SIZE * ELEMENT_SIZE);
    if (sdram_buf_2 == NULL) {
        ERROR("Allocating SDRAM buffer 2 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        free((void *)sdram_buf_1);
        return;
    }

    for (size_t i = 0; i < NUM_BLOCKS * BLOCK_SIZE; i++) {
        sdram_buf_1[i] = (uint64_t)((i + 1) * 0xE);
        sdram_buf_2[i] = (uint64_t)0;
    }

    cache_flush((void *)sdram_buf_1, NUM_BLOCKS * BLOCK_SIZE * ELEMENT_SIZE);
    cache_flush((void *)sdram_buf_2, NUM_BLOCKS * BLOCK_SIZE * ELEMENT_SIZE);
    // Ensure all memory operations completed before proceeding
    __asm__ volatile("dsb sy" ::: "memory");

    /////////////////////////
    /* Start S2S transfers */
    /////////////////////////

    // Timer-related variables
    uint64_t counter_freq;
    READ_TIMER_FRQ(counter_freq);
    uint64_t transaction_cycles = transaction_seconds * counter_freq;

    uint64_t transfer_start;
    uint64_t transfer_end;

    uint64_t num_iterations = 0;

    PRINT("Starting S2S transfers for %u seconds ...", transaction_seconds);
    vTaskDelay(pdMS_TO_TICKS(5));

    // Wait for all threads to be ready before starting transactions
    xEventGroupSync(execution_barrier, thread_bit, all_threads, portMAX_DELAY);

    // Record initial timer value
    READ_TIMER(transfer_start);
    READ_TIMER(transfer_end);

    // Perform back-to-back data transfers in a loop until the specified transaction duration has elapsed
    while ((transfer_end - transfer_start) < transaction_cycles) {
        // Start transfer
        for (size_t i = 0; i < NUM_BLOCKS * BLOCK_SIZE; i++) {
            sdram_buf_2[i] = sdram_buf_1[i];
        }

        num_iterations++;

        READ_TIMER(transfer_end);
    }

    /////////////////////////////////////////////
    /* Calculate and print transfer statistics */
    /////////////////////////////////////////////

    double elapsed_time = (double)(transfer_end - transfer_start) / (double)counter_freq;
    uint64_t total_data_transferred = (NUM_BLOCKS * BLOCK_SIZE * ELEMENT_SIZE) * 2 * num_iterations / ONE_MIL_BYTES;

    PRINT("Total data transferred for S2S transfers in %f seconds: %lu MB -- Average transfer bandwidth is: %f MB/s",
          elapsed_time, total_data_transferred, (total_data_transferred / elapsed_time));
    vTaskDelay(pdMS_TO_TICKS(5));

    ///////////////////////
    /* Clean up and exit */
    ///////////////////////

cleanup:
    free((void *)sdram_buf_1);
    free((void *)sdram_buf_2);
}