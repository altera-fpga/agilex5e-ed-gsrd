/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/*
 * main.c — ILC Interrupt Latency Demo, Agilex5 bare-metal (EL2)
 *
 * Standalone (no hypervisor) version — runs directly from U-Boot 'go' at EL2.
 * Log format is kept deliberately identical in shape to the Bao-guest VM1
 * build so the two can be compared line-for-line. Only the prefix differs:
 *
 *   Bao-guest       : "### [VM1] Agilex5 A76 core 0"
 *                     "[VM1] ILC init done"
 *                     "[VM1] ILC n=5 | min=1390 max=1630 avg=1600 ns"
 *
 *   Standalone (BM) : "### [BM] Agilex5 A76 core 0"
 *                     "[BM] ILC init done"
 *                     "[BM] ILC n=5 | min=... max=... avg=... ns"
 *
 * IRQ path (aligned with Bao baremetal guest VM1):
 *   vectors.S:_sp_elx_irq → gic_handle() → irq_early_hook() → irq_handle() → ilc_isr()
 *
 * Boot flow:
 *   vectors.S _start (EL2) → main()
 *
 * Prerequisites (run from U-Boot before 'go'):
 *   bridge enable     — enable HPS-FPGA bridges
 *   wdt dev watchdog@10d00200; wdt stop  — disable watchdog
 */

#include "uart.h"
#include "ilc_latency.h"
#include "drivers/gic/socfpga_interrupt.h"
#include "drivers/gic/socfpga_gic.h"

/* Stats-print cadence (samples). Must match Bao VM1 side for fair comparison. */
#define ILC_STAT_INTERVAL 5U

int main(void)
{
    uart_puts("### [BM] Agilex5 SoCFPGA \n");

    interrupt_init_gic();
    gic_enable_interrupts();

    ilc_init();
    uart_puts("[BM] ILC init done\n");

    /* Main loop: WFI between interrupts, print summary every STAT_INTERVAL
     * samples.
     *
     * Per-sample log is intentionally OFF so only the summary lines (every
     * ILC_STAT_INTERVAL samples) appear on the console — this keeps the hot
     * path identical to the Bao VM1 build. Enable by defining
     * ILC_PER_SAMPLE_LOG at build time to emit one UART line per interrupt
     * (useful for bring-up, noisy in steady state). The ring is still drained
     * by ilc_print_stats(). */
    uint32_t last_stats_at = 0U;

    for (;;) {
        __asm__ volatile("wfi");
#ifdef ILC_PER_SAMPLE_LOG
        ilc_drain_samples();
#endif
        uint32_t total = g_ilc_ring.total;
        if (total >= last_stats_at + ILC_STAT_INTERVAL) {
            ilc_print_stats();
            last_stats_at = total;
        }
    }

    return 0;
}
