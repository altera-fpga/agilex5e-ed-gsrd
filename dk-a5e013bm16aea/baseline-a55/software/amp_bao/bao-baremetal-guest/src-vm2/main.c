/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */
/**
 * main.c — VM2: ILC Interrupt Latency worker (Agilex5)
 *
 * VM2 owns the interval timer and ILC soft-IP (MMIO @ 0x20000000).
 * It publishes the latency-measurement samples into a vm2_log_ring_t in shmem
 * (shmem_msg.h / vm2_log.h). VM1 (the printer) drains the ring from its main
 * loop and prints to its owned UART0. Each string already embeds the [VM2]
 * prefix.
 *
 * On every ILC sample the ILC ISR also publishes shmem_msg_t (seq +
 * ipi_send_ticks) and fires the Bao IPC hypercall (HVC). Bao injects a
 * virtual SGI 2 into VM1, which wakes VM1 to drain the log ring and lets
 * VM1 measure the cross-core VM2 → VM1 hypercall latency.
 *
 * SHMEM IPA: 0xC0000000 (256 MB, Bao IPC shmem_id=0).
 */

#include <core.h>
#include <cpu.h>
#include <plat.h>
#include <irq.h>

#include <shmem_msg.h>
#include "ilc_latency.h"
#include "vm2_log.h"
#include "drivers/gpio/gpio_led.h"

void __attribute__((noreturn)) main(void)
{
    /* Zero the log ring and reset head — DRAM is undefined at reset, so the
     * slot len[] must be cleared before the first emit. */
    vm2_log_ring_init();

    {
        char b[VM2_LOG_SLOT_SZ];
        int q = 0;
        vm2_log_append_str(b, &q, "*** [VM2] — ILC worker\n");
        b[q] = '\0';
        vm2_log_emit(b);
    }

    /* Configure GPIO LED for visual interrupt indication. Done before
     * ilc_init() so the LED is ready the first time the ILC ISR fires. */
    gpio_led_init();

    /* Init ILC hardware + GIC SPI 50 + interval timer. Also resets the
     * shmem_msg_t fields (VM2 is the IPC sender). */
    ilc_init();

    {
        char b[VM2_LOG_SLOT_SZ];
        int q = 0;
        vm2_log_append_str(b, &q, "[VM2] ILC init done\n");
        b[q] = '\0';
        vm2_log_emit(b);
    }

    /* Main loop: WFI between interrupts. Wakes on the ILC SPI; the ISR has
     * already measured the sample, published shmem, and notified VM1. */
    uint32_t last_stats_at = 0U;

    while (1) {
        __asm__ volatile("wfi" ::: "memory");

        /* Toggle LED when the ILC ring has new entries (head != tail). */
        if (g_ilc_ring.head != g_ilc_ring.tail) {
            gpio_led_toggle();
        }

        /* Per-sample log is intentionally OFF so only the summary lines
         * (every ILC_STAT_INTERVAL samples) reach the console. Define
         * ILC_PER_SAMPLE_LOG at build time to emit one line per interrupt. */
#ifdef ILC_PER_SAMPLE_LOG
        ilc_drain_samples();
#endif
        uint32_t total = g_ilc_ring.total;

        if (total >= last_stats_at + ILC_STAT_INTERVAL) {
            ilc_print_stats();
            last_stats_at = total;
        }
    }
}
