/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * main.c - Main program for SoC FPGA Data Mover Design (multi-threaded)
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
#include "event_groups.h"
#include "socfpga_bridge.h"
#include "datamover_tasks.h"
#include "qos_generator.h"
#include "socfpga_dma.h"
#include "socfpga_cache.h"
#include "osal.h"
#include "osal_log.h"

#define TASK_PRIORITY (configMAX_PRIORITIES - 2)

// FPGA bitstream offset in QSPI memory
#define BITSTREAM_OFFSET 0x08000000

#define SETUP_FPGA_THREAD_BIT (1 << 0)
#define F2H_THREAD_BIT (1 << 1)
#define F2SDRAM_THREAD_BIT (1 << 2)
#define S2S_DMA_THREAD_BIT (1 << 5)
#define S2S_THREAD_BIT (1 << 6)

// Add thread bit if the thread is enabled
#define ALL_THREADS (F2H_THREAD_BIT | S2S_THREAD_BIT)

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

void setup_fpga(void *arg)
{
    EventGroupHandle_t execution_barrier = (EventGroupHandle_t)arg;

    PRINT("=====================================");
    PRINT("Data Mover FreeRTOS Program Starting.");
    PRINT("=====================================\n");

    // Load the FPGA bitstream from QSPI memory
    if (load_bitstream_from_qspi() != 0) {
        ERROR("Failed to load FPGA bitstream. Halting execution.");
        for (;;)
            ;
    }
    PRINT("FPGA bitstream loaded successfully.\n");

    // disable f2h bridge
    uint32_t ret = disable_fpga2hps_bridge();
    if (ret != 0) {
        // Failed to disable bridge, cannot continue
        for (;;)
            ;
    }

    // enable f2h bridge
    ret = enable_fpga2hps_bridge();
    if (ret != 0) {
        // Failed to enable bridge, cannot continue
        for (;;)
            ;
    }

    /* Uncomment the following code to enable F2SDRAM transactions */
    // // disable f2sdram bridge
    // ret = disable_fpga2sdram_bridge();
    // if (ret != 0) {
    //     // Failed to disable bridge, cannot continue
    //     for (;;)
    //         ;
    // }

    // // enable f2sdram bridge
    // ret = enable_fpga2sdram_bridge();
    // if (ret != 0) {
    //     // Failed to enable bridge, cannot continue
    //     for (;;)
    //         ;
    // }

    // configure qos generator
    configure_qos_generator(TBU2NOC_QOS_MODE_REG_ADDR, 0x0);
    configure_qos_generator(TBU2NOC_QOS_PRIORITY_REG_ADDR, 0x0);

    configure_qos_generator(DMA_QOS_MODE_REG_ADDR, 0x0);
    configure_qos_generator(DMA_QOS_PRIORITY_REG_ADDR, 0x0);

    configure_qos_generator(CCU_DMI0_QOS_MODE_REG_ADDR, 0x0);
    configure_qos_generator(CCU_DMI0_QOS_PRIORITY_REG_ADDR, 0x0);

    configure_qos_generator(CCU_DMI1_QOS_MODE_REG_ADDR, 0x0);
    configure_qos_generator(CCU_DMI1_QOS_PRIORITY_REG_ADDR, 0x0);

    PRINT("FPGA setup complete.");

    // signal that the FPGA setup is complete
    xEventGroupSetBits(execution_barrier, SETUP_FPGA_THREAD_BIT);

    vTaskSuspend(NULL);
}

void f2h(void *arg)
{
    EventGroupHandle_t execution_barrier = (EventGroupHandle_t)arg;

    // wait for the FPGA setup to complete
    xEventGroupWaitBits(execution_barrier, SETUP_FPGA_THREAD_BIT, pdFALSE, pdTRUE, portMAX_DELAY);

    PRINT("F2H Task Started.");
    vTaskDelay(pdMS_TO_TICKS(5));
    f2h_task(execution_barrier, F2H_THREAD_BIT, ALL_THREADS, TEN_SECONDS);
    vTaskSuspend(NULL);
}

void f2sdram(void *arg)
{
    EventGroupHandle_t execution_barrier = (EventGroupHandle_t)arg;

    // wait for the FPGA setup to complete
    xEventGroupWaitBits(execution_barrier, SETUP_FPGA_THREAD_BIT, pdFALSE, pdTRUE, portMAX_DELAY);

    PRINT("F2SDRAM Task Started.");
    vTaskDelay(pdMS_TO_TICKS(5));
    f2sdram_task(execution_barrier, F2SDRAM_THREAD_BIT, ALL_THREADS, TEN_SECONDS);
    vTaskSuspend(NULL);
}

void s2s_dma(void *arg)
{
    EventGroupHandle_t execution_barrier = (EventGroupHandle_t)arg;

    // wait for the FPGA setup to complete
    xEventGroupWaitBits(execution_barrier, SETUP_FPGA_THREAD_BIT, pdFALSE, pdTRUE, portMAX_DELAY);

    PRINT("S2S_DMA Task Started.");
    vTaskDelay(pdMS_TO_TICKS(5));
    s2s_dma_task(execution_barrier, S2S_DMA_THREAD_BIT, ALL_THREADS, TEN_SECONDS);
    vTaskSuspend(NULL);
}

void s2s(void *arg)
{
    EventGroupHandle_t execution_barrier = (EventGroupHandle_t)arg;

    // wait for the FPGA setup to complete
    xEventGroupWaitBits(execution_barrier, SETUP_FPGA_THREAD_BIT, pdFALSE, pdTRUE, portMAX_DELAY);

    PRINT("S2S Task Started.");
    vTaskDelay(pdMS_TO_TICKS(5));
    s2s_task(execution_barrier, S2S_THREAD_BIT, ALL_THREADS, TEN_SECONDS);
    vTaskSuspend(NULL);
}

int main(void)
{
    prvSetupHardware();

    // create task execution barrier
    EventGroupHandle_t execution_barrier;
    execution_barrier = xEventGroupCreate();
    if (execution_barrier == NULL) {
        ERROR("Failed to create event group");
        for (;;)
            ;
    }

    // create tasks
    BaseType_t setup_xReturn = pdPASS;
    setup_xReturn = xTaskCreate(setup_fpga, "SETUP_FPGA", configMINIMAL_STACK_SIZE * 4, (void *)execution_barrier,
                                TASK_PRIORITY, NULL);

    BaseType_t f2h_xReturn = pdPASS;
    f2h_xReturn = xTaskCreate(f2h, "F2H", configMINIMAL_STACK_SIZE * 4, (void *)execution_barrier, TASK_PRIORITY, NULL);

    /* Uncomment the following code to enable F2SDRAM transactions */
    BaseType_t f2sdram_xReturn = pdPASS;
    // f2sdram_xReturn =
    //     xTaskCreate(f2sdram, "F2SDRAM", configMINIMAL_STACK_SIZE * 4, (void *)execution_barrier, TASK_PRIORITY, NULL);

    /* Uncomment the following code to enable S2S DMA transactions */
    BaseType_t s2s_dma_xReturn = pdPASS;
    // s2s_dma_xReturn = xTaskCreate(s2s_dma, "S2S_DMA", configMINIMAL_STACK_SIZE * 4, (void *)execution_barrier, TASK_PRIORITY, NULL);

    BaseType_t s2s_xReturn = pdPASS;
    s2s_xReturn = xTaskCreate(s2s, "S2S", configMINIMAL_STACK_SIZE * 4, (void *)execution_barrier, TASK_PRIORITY, NULL);

    if (setup_xReturn == pdPASS && f2h_xReturn == pdPASS && f2sdram_xReturn == pdPASS && s2s_dma_xReturn == pdPASS &&
        s2s_xReturn == pdPASS) {
        vTaskStartScheduler();
    }

    /* Block here indefinitely; Should never reach here */
    for (;;)
        ;
}
