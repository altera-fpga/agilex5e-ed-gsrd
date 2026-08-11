/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * main.c - Main program for SoC FPGA Data Mover Design (single-threaded)
 */

#include <stdlib.h>
#include <stdint.h>
#include "FreeRTOS.h"
#include "FreeRTOSConfig.h"
#include "task.h"
#include "socfpga_interrupt.h"
#include "socfpga_console.h"
#include "socfpga_smmu.h"
#include "socfpga_flash.h"
#include "socfpga_fpga_manager.h"
#include "datamover_tasks.h"
#include "socfpga_dma.h"
#include "socfpga_cache.h"
#include "osal.h"
#include "osal_log.h"

#define TASK_PRIORITY (configMAX_PRIORITIES - 2)

// FPGA bitstream offset in QSPI memory
#define BITSTREAM_OFFSET 0x08000000

void vApplicationTickHook(void)
{
    /*
     * This is called from RTOS tick handler
     * Not used in this demo, but defined to keep the configuration sharing
     * simple
     * */
}

void vApplicationIdleHook(void)
{
    ;
}

void vApplicationMallocFailedHook(void)
{
    /* vApplicationMallocFailedHook() will only be called if
       configUSE_MALLOC_FAILED_HOOK is set to 1 in FreeRTOSConfig.h.  It is a hook
       function that will get called if a call to pvPortMalloc() fails.
       pvPortMalloc() is called internally by the kernel whenever a task, queue,
       timer or semaphore is created. */
    taskDISABLE_INTERRUPTS();
    for (;;)
        ;
}

static void prvSetupHardware(void)
{
    /* Initialize the GIC. */
    interrupt_init_gic();
    /* Enable SMMU */
    (void)smmu_enable();
    /* Initialize the console uart*/
#if configENABLE_CONSOLE_UART
    console_init(configCONSOLE_UART_ID, "115200-8N1");
#endif
}

int load_bitstream_from_qspi(void)
{
    int status = 1; // default to failure

    void *buffer = NULL;

    flash_handle_t flash_handle = flash_open(QSPI_DEV0);
    if (flash_handle == NULL) {
        ERROR("Failed to open flash device");
        return status;
    }

    // The first 4 bytes at the bitstream offset contain the size of the bitstream, followed by the bitstream data itself.
    // Here, we read the size and place it into the bitstream size variable.
    size_t bitstream_size;
    uint8_t bitstream_size_buffer[4];
    int ret = flash_read_sync(flash_handle, BITSTREAM_OFFSET, bitstream_size_buffer, sizeof(uint32_t));
    if (ret != 0) {
        ERROR("Failed to read bitstream length from flash: %d", ret);
        flash_close(flash_handle);
        return status;
    }
    bitstream_size = ((uint32_t)bitstream_size_buffer[3] << 24) | ((uint32_t)bitstream_size_buffer[2] << 16) |
                     ((uint32_t)bitstream_size_buffer[1] << 8) | ((uint32_t)bitstream_size_buffer[0]);
    PRINT("Bitstream size: %u bytes", bitstream_size);

    // Allocate a buffer for the bitstream data.
    buffer = malloc(bitstream_size);
    if (buffer == NULL) {
        ERROR("Failed to allocate memory for bitstream");
        flash_close(flash_handle);
        return status;
    }

    // Read the bitstream data. The bitstream data starts immediately after the 4-byte size field, so we add sizeof(uint32_t) to the offset.
    ret = flash_read_sync(flash_handle, BITSTREAM_OFFSET + sizeof(uint32_t), buffer, bitstream_size);
    if (ret != 0) {
        ERROR("Failed to read bitstream from flash: %d", ret);
        free(buffer);
        flash_close(flash_handle);
        return status;
    }

    // Flush bitstream data from CPU cache to DDR and ensure all memory operation completed before proceeding
    PRINT("Flushing bitstream data from cache to memory...");
    cache_flush(buffer, bitstream_size);
    __asm__ volatile("dsb sy" ::: "memory");

    // load_fpga_bitstream sends the bitstream data to the SDM which programs the FPGA.
    PRINT("Loading FPGA bitstream...");
    ret = load_fpga_bitstream(buffer, bitstream_size);
    if (ret != 0) {
        ERROR("Failed to load FPGA bitstream: %d", ret);
        free(buffer);
        flash_close(flash_handle);
        return status;
    }

    status = 0;

    free(buffer);
    flash_close(flash_handle);
    return status;
}

void run(void *arg)
{
    PRINT("=====================================");
    PRINT("Data Mover FreeRTOS Program Starting.");
    PRINT("=====================================\n");

    // Load the FPGA bitstream from QSPI memory
    if (load_bitstream_from_qspi() != 0) {
        ERROR("Failed to load FPGA bitstream. Halting execution.");
        vTaskSuspend(NULL);
    }
    PRINT("FPGA bitstream loaded successfully.\n");

    // Start the Data Mover Tasks
    PRINT("Starting Data Mover Tasks...\n");
    f2h_task(TEN_SECONDS);
    PRINT("F2H Task completed.\n");
    f2sdram_task(TEN_SECONDS);
    PRINT("F2SDRAM Task completed.\n");
    s2s_dma_task(TEN_SECONDS);
    PRINT("S2S DMA Task completed.\n");
    s2s_task(TEN_SECONDS);
    PRINT("S2S Task completed.\n");
    PRINT("Data Mover FreeRTOS Program Completed.\n");
    vTaskSuspend(NULL);
}

int main(void)
{
    prvSetupHardware();

    BaseType_t xReturn;
    xReturn = xTaskCreate(run, "run", configMINIMAL_STACK_SIZE * 4, NULL, TASK_PRIORITY, NULL);
    if (xReturn == 1) {
        vTaskStartScheduler();
    }

    /* Block here indefinitely; Should never reach here */
    for (;;)
        ;
}
