/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * rpmsg_console -- FreeRTOS-on-Bao guest entry.
 * ----------------------------------------------------------------------
 * Three things happen before the scheduler starts:
 *
 *   1. interrupt_init_gic()         -- baremetal-runtime brings up GICv3
 *                                      vCPU IF + the FreeRTOS scheduler
 *                                      tick (vtimer PPI 27).
 *   2. resource_table_publish()     -- copy the OpenAMP resource_table
 *                                      image into IPA 0xC4000000 + dc
 *                                      cvac so Linux's bao-rproc reads
 *                                      a coherent table the moment
 *                                      `echo start > .../state` lands.
 *   3. platform_register_kick_isr() -- install the vIRQ 52 ISR via
 *                                      libmetal_bao_register_kick_isr;
 *                                      every kick from Linux's
 *                                      virtqueue_kick (FID 0x86000001)
 *                                      then fans out to
 *                                      rproc_virtio_notified() inside
 *                                      platform.c so OpenAMP advances
 *                                      the rings. Must be after gic
 *                                      init (the SPI must be enable-
 *                                      able) and after table publish
 *                                      (g_vdev is still NULL but the
 *                                      ISR safely no-ops on early
 *                                      kicks until prvProducerTask
 *                                      constructs g_vdev).
 *
 * UART policy: Linux owns UART0 exclusively; this VM does not map it.
 * All output goes over /dev/rpmsg0 (heartbeats + ILC lines).
 */

#include "FreeRTOS.h"
#include <task.h>

#include "socfpga_interrupt.h"

#include "platform.h"
#include "resource_table.h"
#include "drivers/gpio/gpio_led.h"

void main_rpmsg_console(void);

void vApplicationMallocFailedHook(void);
void vApplicationIdleHook(void);
void vApplicationStackOverflowHook(TaskHandle_t pxTask, char *pcTaskName);

static void prvSetupHardware(void)
{
    interrupt_init_gic();
    resource_table_publish();
    platform_register_kick_isr();
    gpio_led_init();
}

int main(void)
{
    prvSetupHardware();

    main_rpmsg_console();

    /* main_rpmsg_console() starts the scheduler and never returns; if
     * vTaskStartScheduler() ever does return, sit in a tight loop so a
     * subsequent watchdog reset (or operator inspecting via gdb) sees a
     * deterministic spin instead of running off into junk. */
    for (;;) {
    }
}

void vApplicationMallocFailedHook(void)
{
    taskDISABLE_INTERRUPTS();
    for (;;) {
    }
}

void vApplicationStackOverflowHook(TaskHandle_t pxTask, char *pcTaskName)
{
    (void)pxTask;
    (void)pcTaskName;
    taskDISABLE_INTERRUPTS();
    for (;;) {
    }
}

void vApplicationIdleHook(void)
{
}
