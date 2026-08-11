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
#include "socfpga_dma.h"
#include "datamover.h"
#include "datamover_tasks.h"

#define ELEMENT_SIZE sizeof(uint64_t)
#define BLOCK_SIZE (OCM_SIZE / ELEMENT_SIZE)

// 8 DMAC channels, 4 channels from DMAC0 and 4 channels from DMAC1
#define NUM_CHANNELS 8
#define CHANNEL0 0
#define CHANNEL1 1
#define CHANNEL2 2
#define CHANNEL3 3
#define CHANNEL4 4
#define CHANNEL5 5
#define CHANNEL6 6
#define CHANNEL7 7

// DMA transaction done semaphore
osal_semaphore_def_t s2s_done_sem_mem;
osal_semaphore_t s2s_done_sem;

// DMA done callback function
void s2s_dma_done_callback(void *data)
{
    osal_semaphore_post(s2s_done_sem);
}

// Prepare transfer blocks
void prepare_s2s_transfer_blocks(dma_xfer_cfg_t *blk_trnsfr_list, volatile uint64_t *sdram_buf_1,
                                 volatile uint64_t *sdram_buf_2, size_t num_blocks, uint8_t channel_num)
{
    for (size_t i = 0; i < num_blocks; i++) {
        // Transfer descriptor (SDRAM 1 to SDRAM 2)
        blk_trnsfr_list[i].src =
            (uint64_t)(uintptr_t)(&sdram_buf_1[(i * BLOCK_SIZE) + (channel_num * (BLOCK_SIZE / NUM_CHANNELS))]);
        blk_trnsfr_list[i].dst =
            (uint64_t)(uintptr_t)(&sdram_buf_2[(i * BLOCK_SIZE) + (channel_num * (BLOCK_SIZE / NUM_CHANNELS))]);
        blk_trnsfr_list[i].blk_size = (uint32_t)((BLOCK_SIZE / NUM_CHANNELS) * ELEMENT_SIZE);
        if (i != (num_blocks - 1)) {
            blk_trnsfr_list[i].next_xfer_cfg = &blk_trnsfr_list[i + 1];
        }
    }
}

void s2s_dma_task(EventGroupHandle_t execution_barrier, uint32_t thread_bit, uint32_t all_threads,
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

    ///////////////////////////
    /* Set up done semaphore */
    ///////////////////////////

    s2s_done_sem = osal_semaphore_counting_create(&s2s_done_sem_mem, NUM_CHANNELS, 0);

    /////////////////////////////////////////
    /* Prepare Linked-List transfer blocks */
    /////////////////////////////////////////

    // Transfer block list for channel 0
    // 1 transfer list item per block (SDRAM to SDRAM)
    dma_xfer_cfg_t channel_0_blk_transfr_list[NUM_BLOCKS] = { 0 };
    prepare_s2s_transfer_blocks(channel_0_blk_transfr_list, sdram_buf_1, sdram_buf_2, NUM_BLOCKS, CHANNEL0);

    // Transfer block list for channel 1
    // 1 transfer list item per block (SDRAM to SDRAM)
    dma_xfer_cfg_t channel_1_blk_transfr_list[NUM_BLOCKS] = { 0 };
    prepare_s2s_transfer_blocks(channel_1_blk_transfr_list, sdram_buf_1, sdram_buf_2, NUM_BLOCKS, CHANNEL1);

    // Transfer block list for channel 2
    // 1 transfer list item per block (SDRAM to SDRAM)
    dma_xfer_cfg_t channel_2_blk_transfr_list[NUM_BLOCKS] = { 0 };
    prepare_s2s_transfer_blocks(channel_2_blk_transfr_list, sdram_buf_1, sdram_buf_2, NUM_BLOCKS, CHANNEL2);

    // Transfer block list for channel 3
    // 1 transfer list item per block (SDRAM to SDRAM)
    dma_xfer_cfg_t channel_3_blk_transfr_list[NUM_BLOCKS] = { 0 };
    prepare_s2s_transfer_blocks(channel_3_blk_transfr_list, sdram_buf_1, sdram_buf_2, NUM_BLOCKS, CHANNEL3);

    // Transfer block list for channel 4
    // 1 transfer list item per block (SDRAM to SDRAM)
    dma_xfer_cfg_t channel_4_blk_transfr_list[NUM_BLOCKS] = { 0 };
    prepare_s2s_transfer_blocks(channel_4_blk_transfr_list, sdram_buf_1, sdram_buf_2, NUM_BLOCKS, CHANNEL4);

    // Transfer block list for channel 5
    // 1 transfer list item per block (SDRAM to SDRAM)
    dma_xfer_cfg_t channel_5_blk_transfr_list[NUM_BLOCKS] = { 0 };
    prepare_s2s_transfer_blocks(channel_5_blk_transfr_list, sdram_buf_1, sdram_buf_2, NUM_BLOCKS, CHANNEL5);

    // Transfer block list for channel 6
    // 1 transfer list item per block (SDRAM to SDRAM)
    dma_xfer_cfg_t channel_6_blk_transfr_list[NUM_BLOCKS] = { 0 };
    prepare_s2s_transfer_blocks(channel_6_blk_transfr_list, sdram_buf_1, sdram_buf_2, NUM_BLOCKS, CHANNEL6);

    // Transfer block list for channel 7
    // 1 transfer list item per block (SDRAM to SDRAM)
    dma_xfer_cfg_t channel_7_blk_transfr_list[NUM_BLOCKS] = { 0 };
    prepare_s2s_transfer_blocks(channel_7_blk_transfr_list, sdram_buf_1, sdram_buf_2, NUM_BLOCKS, CHANNEL7);

    /////////////////////////////////////
    /* Open and configure DMA channels */
    /////////////////////////////////////

    dma_handle_t dmac_0_channel_0;
    dma_handle_t dmac_0_channel_1;
    dma_handle_t dmac_0_channel_2;
    dma_handle_t dmac_0_channel_3;
    dma_handle_t dmac_1_channel_0;
    dma_handle_t dmac_1_channel_1;
    dma_handle_t dmac_1_channel_2;
    dma_handle_t dmac_1_channel_3;

    dmac_0_channel_0 = dma_open(0, 0);
    if (dmac_0_channel_0 == NULL) {
        ERROR("Opening DMA0 channel 0 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        free((void *)sdram_buf_1);
        free((void *)sdram_buf_2);
        osal_semaphore_delete(s2s_done_sem);
        return;
    }

    dmac_0_channel_1 = dma_open(0, 1);
    if (dmac_0_channel_1 == NULL) {
        ERROR("Opening DMA0 channel 1 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        free((void *)sdram_buf_1);
        free((void *)sdram_buf_2);
        osal_semaphore_delete(s2s_done_sem);
        dma_close(dmac_0_channel_0);
        return;
    }

    dmac_0_channel_2 = dma_open(0, 2);
    if (dmac_0_channel_2 == NULL) {
        ERROR("Opening DMA0 channel 2 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        free((void *)sdram_buf_1);
        free((void *)sdram_buf_2);
        osal_semaphore_delete(s2s_done_sem);
        dma_close(dmac_0_channel_0);
        dma_close(dmac_0_channel_1);
        return;
    }

    dmac_0_channel_3 = dma_open(0, 3);
    if (dmac_0_channel_3 == NULL) {
        ERROR("Opening DMA0 channel 3 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        free((void *)sdram_buf_1);
        free((void *)sdram_buf_2);
        osal_semaphore_delete(s2s_done_sem);
        dma_close(dmac_0_channel_0);
        dma_close(dmac_0_channel_1);
        dma_close(dmac_0_channel_2);
        return;
    }

    dmac_1_channel_0 = dma_open(1, 0);
    if (dmac_1_channel_0 == NULL) {
        ERROR("Opening DMA1 channel 0 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        free((void *)sdram_buf_1);
        free((void *)sdram_buf_2);
        osal_semaphore_delete(s2s_done_sem);
        dma_close(dmac_0_channel_0);
        dma_close(dmac_0_channel_1);
        dma_close(dmac_0_channel_2);
        dma_close(dmac_0_channel_3);
        return;
    }

    dmac_1_channel_1 = dma_open(1, 1);
    if (dmac_1_channel_1 == NULL) {
        ERROR("Opening DMA1 channel 1 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        free((void *)sdram_buf_1);
        free((void *)sdram_buf_2);
        osal_semaphore_delete(s2s_done_sem);
        dma_close(dmac_0_channel_0);
        dma_close(dmac_0_channel_1);
        dma_close(dmac_0_channel_2);
        dma_close(dmac_0_channel_3);
        dma_close(dmac_1_channel_0);
        return;
    }

    dmac_1_channel_2 = dma_open(1, 2);
    if (dmac_1_channel_2 == NULL) {
        ERROR("Opening DMA1 channel 2 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        free((void *)sdram_buf_1);
        free((void *)sdram_buf_2);
        osal_semaphore_delete(s2s_done_sem);
        dma_close(dmac_0_channel_0);
        dma_close(dmac_0_channel_1);
        dma_close(dmac_0_channel_2);
        dma_close(dmac_0_channel_3);
        dma_close(dmac_1_channel_0);
        dma_close(dmac_1_channel_1);
        return;
    }

    dmac_1_channel_3 = dma_open(1, 3);
    if (dmac_1_channel_3 == NULL) {
        ERROR("Opening DMA1 channel 3 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        free((void *)sdram_buf_1);
        free((void *)sdram_buf_2);
        osal_semaphore_delete(s2s_done_sem);
        dma_close(dmac_0_channel_0);
        dma_close(dmac_0_channel_1);
        dma_close(dmac_0_channel_2);
        dma_close(dmac_0_channel_3);
        dma_close(dmac_1_channel_0);
        dma_close(dmac_1_channel_1);
        dma_close(dmac_1_channel_2);
        return;
    }

    int config_ret;
    dma_config_t dma0channel0config;
    dma_config_t dma0channel1config;
    dma_config_t dma0channel2config;
    dma_config_t dma0channel3config;
    dma_config_t dma1channel0config;
    dma_config_t dma1channel1config;
    dma_config_t dma1channel2config;
    dma_config_t dma1channel3config;

    dma0channel0config.ch_dir = DMA_MEM_TO_MEM_DMAC;
    dma0channel0config.ch_prio = 0;
    dma0channel0config.callback = s2s_dma_done_callback;

    config_ret = dma_config(dmac_0_channel_0, &dma0channel0config);
    if (config_ret != 0) {
        ERROR("Configuring DMA0 channel 0 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        goto cleanup;
    }

    dma0channel1config.ch_dir = DMA_MEM_TO_MEM_DMAC;
    dma0channel1config.ch_prio = 0;
    dma0channel1config.callback = s2s_dma_done_callback;

    config_ret = dma_config(dmac_0_channel_1, &dma0channel1config);
    if (config_ret != 0) {
        ERROR("Configuring DMA0 channel 1 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        goto cleanup;
    }

    dma0channel2config.ch_dir = DMA_MEM_TO_MEM_DMAC;
    dma0channel2config.ch_prio = 0;
    dma0channel2config.callback = s2s_dma_done_callback;

    config_ret = dma_config(dmac_0_channel_2, &dma0channel2config);
    if (config_ret != 0) {
        ERROR("Configuring DMA0 channel 2 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        goto cleanup;
    }

    dma0channel3config.ch_dir = DMA_MEM_TO_MEM_DMAC;
    dma0channel3config.ch_prio = 0;
    dma0channel3config.callback = s2s_dma_done_callback;

    config_ret = dma_config(dmac_0_channel_3, &dma0channel3config);
    if (config_ret != 0) {
        ERROR("Configuring DMA0 channel 3 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        goto cleanup;
    }

    dma1channel0config.ch_dir = DMA_MEM_TO_MEM_DMAC;
    dma1channel0config.ch_prio = 0;
    dma1channel0config.callback = s2s_dma_done_callback;

    config_ret = dma_config(dmac_1_channel_0, &dma1channel0config);
    if (config_ret != 0) {
        ERROR("Configuring DMA1 channel 0 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        goto cleanup;
    }

    dma1channel1config.ch_dir = DMA_MEM_TO_MEM_DMAC;
    dma1channel1config.ch_prio = 0;
    dma1channel1config.callback = s2s_dma_done_callback;

    config_ret = dma_config(dmac_1_channel_1, &dma1channel1config);
    if (config_ret != 0) {
        ERROR("Configuring DMA1 channel 1 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        goto cleanup;
    }

    dma1channel2config.ch_dir = DMA_MEM_TO_MEM_DMAC;
    dma1channel2config.ch_prio = 0;
    dma1channel2config.callback = s2s_dma_done_callback;

    config_ret = dma_config(dmac_1_channel_2, &dma1channel2config);
    if (config_ret != 0) {
        ERROR("Configuring DMA1 channel 2 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        goto cleanup;
    }

    dma1channel3config.ch_dir = DMA_MEM_TO_MEM_DMAC;
    dma1channel3config.ch_prio = 0;
    dma1channel3config.callback = s2s_dma_done_callback;

    config_ret = dma_config(dmac_1_channel_3, &dma1channel3config);
    if (config_ret != 0) {
        ERROR("Configuring DMA1 channel 3 failed");
        vTaskDelay(pdMS_TO_TICKS(5));
        goto cleanup;
    }

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

    // Function return value variables
    uint32_t setup_ret;
    uint32_t sem_ret;

    PRINT("Starting S2S DMA transfers for %u seconds ...", transaction_seconds);
    vTaskDelay(pdMS_TO_TICKS(5));

    // Wait for all threads to be ready before starting transactions
    xEventGroupSync(execution_barrier, thread_bit, all_threads, portMAX_DELAY);

    // Record initial timer value
    READ_TIMER(transfer_start);
    READ_TIMER(transfer_end);

    // Perform back-to-back data transfers in a loop until the specified transaction duration has elapsed
    while ((transfer_end - transfer_start) < transaction_cycles) {
        // Set up DMA transfer (1 transfer LLI per data block)
        setup_ret = dma_setup_transfer(dmac_0_channel_0, &channel_0_blk_transfr_list[0], NUM_BLOCKS, DMA_XFER_WIDTH8,
                                       DMA_XFER_WIDTH8);
        if (setup_ret != 0) {
            ERROR("Setting up DMA0 channel 0 transfer failed");
            vTaskDelay(pdMS_TO_TICKS(5));
            goto cleanup;
        }

        setup_ret = dma_setup_transfer(dmac_0_channel_1, &channel_1_blk_transfr_list[0], NUM_BLOCKS, DMA_XFER_WIDTH8,
                                       DMA_XFER_WIDTH8);
        if (setup_ret != 0) {
            ERROR("Setting up DMA0 channel 1 transfer failed");
            vTaskDelay(pdMS_TO_TICKS(5));
            goto cleanup;
        }

        setup_ret = dma_setup_transfer(dmac_0_channel_2, &channel_2_blk_transfr_list[0], NUM_BLOCKS, DMA_XFER_WIDTH8,
                                       DMA_XFER_WIDTH8);
        if (setup_ret != 0) {
            ERROR("Setting up DMA0 channel 2 transfer failed");
            vTaskDelay(pdMS_TO_TICKS(5));
            goto cleanup;
        }

        setup_ret = dma_setup_transfer(dmac_0_channel_3, &channel_3_blk_transfr_list[0], NUM_BLOCKS, DMA_XFER_WIDTH8,
                                       DMA_XFER_WIDTH8);
        if (setup_ret != 0) {
            ERROR("Setting up DMA0 channel 3 transfer failed");
            vTaskDelay(pdMS_TO_TICKS(5));
            goto cleanup;
        }

        setup_ret = dma_setup_transfer(dmac_1_channel_0, &channel_4_blk_transfr_list[0], NUM_BLOCKS, DMA_XFER_WIDTH8,
                                       DMA_XFER_WIDTH8);
        if (setup_ret != 0) {
            ERROR("Setting up DMA1 channel 0 transfer failed");
            vTaskDelay(pdMS_TO_TICKS(5));
            goto cleanup;
        }

        setup_ret = dma_setup_transfer(dmac_1_channel_1, &channel_5_blk_transfr_list[0], NUM_BLOCKS, DMA_XFER_WIDTH8,
                                       DMA_XFER_WIDTH8);
        if (setup_ret != 0) {
            ERROR("Setting up DMA1 channel 1 transfer failed");
            vTaskDelay(pdMS_TO_TICKS(5));
            goto cleanup;
        }

        setup_ret = dma_setup_transfer(dmac_1_channel_2, &channel_6_blk_transfr_list[0], NUM_BLOCKS, DMA_XFER_WIDTH8,
                                       DMA_XFER_WIDTH8);
        if (setup_ret != 0) {
            ERROR("Setting up DMA1 channel 2 transfer failed");
            vTaskDelay(pdMS_TO_TICKS(5));
            goto cleanup;
        }

        setup_ret = dma_setup_transfer(dmac_1_channel_3, &channel_7_blk_transfr_list[0], NUM_BLOCKS, DMA_XFER_WIDTH8,
                                       DMA_XFER_WIDTH8);
        if (setup_ret != 0) {
            ERROR("Setting up DMA1 channel 3 transfer failed");
            vTaskDelay(pdMS_TO_TICKS(5));
            goto cleanup;
        }

        // Start DMA transfer
        dma_start_transfer(dmac_0_channel_0);
        dma_start_transfer(dmac_0_channel_1);
        dma_start_transfer(dmac_0_channel_2);
        dma_start_transfer(dmac_0_channel_3);
        dma_start_transfer(dmac_1_channel_0);
        dma_start_transfer(dmac_1_channel_1);
        dma_start_transfer(dmac_1_channel_2);
        dma_start_transfer(dmac_1_channel_3);

        // Wait for all channels to complete the transfer
        for (int ch = 0; ch < NUM_CHANNELS; ch++) {
            sem_ret = osal_semaphore_wait(s2s_done_sem, 10000);
            if (sem_ret != pdTRUE) {
                ERROR("DMA transfer timed out");
                vTaskDelay(pdMS_TO_TICKS(5));
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

    PRINT("Total data transferred for S2S transfers in %f seconds: %lu MB -- Average transfer bandwidth is: %f MB/s",
          elapsed_time, total_data_transferred, (total_data_transferred / elapsed_time));
    vTaskDelay(pdMS_TO_TICKS(5));

    ///////////////////////
    /* Clean up and exit */
    ///////////////////////

cleanup:
    free((void *)sdram_buf_1);
    free((void *)sdram_buf_2);
    osal_semaphore_delete(s2s_done_sem);
    dma_close(dmac_0_channel_0);
    dma_close(dmac_0_channel_1);
    dma_close(dmac_0_channel_2);
    dma_close(dmac_0_channel_3);
    dma_close(dmac_1_channel_0);
    dma_close(dmac_1_channel_1);
    dma_close(dmac_1_channel_2);
    dma_close(dmac_1_channel_3);
    return;
}