#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "FreeRTOS.h"
#include "FreeRTOSConfig.h"
#include "task.h"
#include "socfpga_interrupt.h"
#include "socfpga_console.h"
#include "socfpga_smmu.h"
#include "socfpga_bridge.h"
#include "socfpga_flash.h"
#include "socfpga_fpga_manager.h"
#include "osal_log.h"
#include "socfpga_cache.h"

// FPGA bitstream offset in QSPI memory
#define BITSTREAM_OFFSET 0x08000000

#define LWH2F_BRIDGE_ADDR 0x20000000
// L2H2F peripherals
#define SYSID_OFFSET 0x00010000
#define SYSID_ADDR (LWH2F_BRIDGE_ADDR + SYSID_OFFSET)
#define LED_PIO_OFFSET 0x00010080
#define LED_PIO_ADDR (LWH2F_BRIDGE_ADDR + LED_PIO_OFFSET)
#define SWITCH_PIO_OFFSET 0x00010070
#define SWITCH_PIO_ADDR (LWH2F_BRIDGE_ADDR + SWITCH_PIO_OFFSET)

#define H2F_BRIDGE_ADDR 0x40000000
// H2F peripherals
#define OCM_OFFSET 0x00000000
#define OCM_ADDR (H2F_BRIDGE_ADDR + OCM_OFFSET)
#define OCM_SIZE 0x00010000

static void setup_hardware(void)
{
    interrupt_init_gic();
    (void)smmu_enable();
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

void task_main()
{
    PRINT("======================================");
    PRINT("FreeRTOS Hello World Program Starting.");
    PRINT("======================================\n");

    PRINT("Loading FPGA bitstream...");
    if (load_bitstream_from_qspi() != 0) {
        ERROR("Failed to load FPGA bitstream");
        return;
    }
    PRINT("FPGA bitstream loaded successfully.\n");

    PRINT("Initializing H2F and LWH2F bridges...");
    if (disable_hps2fpga_bridge() != 0) {
        ERROR("Failed to disable H2F");
        return;
    }
    if (enable_hps2fpga_bridge() != 0) {
        ERROR("Failed to enable H2F");
        return;
    }
    if (disable_lwhps2fpga_bridge() != 0) {
        ERROR("Failed to disable LWH2F");
        return;
    }
    if (enable_lwhps2fpga_bridge() != 0) {
        ERROR("Failed to enable LWH2F");
        return;
    }
    PRINT("H2F and LWH2F bridges initialized successfully.");

    volatile uint32_t *ocm = (volatile uint32_t *)OCM_ADDR;
    PRINT("Writing to On-Chip Memory through H2F bridge...");
    for (uint32_t i = 0; i < OCM_SIZE / sizeof(uint32_t); i++) {
        ocm[i] = i;
    }
    PRINT("Reading from On-Chip Memory through H2F bridge...");
    for (uint32_t i = 0; i < OCM_SIZE / sizeof(uint32_t); i++) {
        uint32_t read_value = ocm[i];
        if (read_value != i) {
            PRINT("Incorrect value at offset %x: expected %u, got %u", i * sizeof(uint32_t), i, read_value);
        }
    }
    PRINT("H2F bridge test successful.");

    uint32_t sysid = RD_REG32(SYSID_ADDR);
    PRINT("SysID: %d (0x%x)", sysid, sysid);

    while (1) {
        WR_REG32(LED_PIO_ADDR, RD_REG32(SWITCH_PIO_ADDR)); // mirror switch state to LEDs
        vTaskDelay(pdMS_TO_TICKS(10)); // check every 10 ms
    }
}

int main()
{
    setup_hardware();
    BaseType_t result = xTaskCreate(task_main, "task_main", configMINIMAL_STACK_SIZE * 4, NULL, 1, NULL);
    if (result == pdPASS) {
        vTaskStartScheduler();
    }
    // infinite loop if scheduler exits
    for (;;)
        ;
}

void vApplicationIdleHook(void)
{
}

void vApplicationTickHook(void)
{
}

void vApplicationMallocFailedHook(void)
{
    taskDISABLE_INTERRUPTS();
    for (;;)
        ;
}

void vPortSocfpgaInterruptHandler(void)
{
}