/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * ilc_latency.h -- ILC Interrupt Latency Counter, FreeRTOS-on-Bao port.
 * --------------------------------------------------------------------
 * Measures interrupt latency from the FPGA Interval Timer (period frozen
 * in the FPGA bitstream, ~x seconds) to the FreeRTOS guest's GIC IRQ-handler
 * entry, and surfaces the captured cycle counts on /dev/rpmsg0 alongside
 * the rpmsg heartbeat.
 *
 */

#ifndef ILC_LATENCY_H
#define ILC_LATENCY_H

#include <stdint.h>

#include <openamp/rpmsg.h>

/* Bao-injected GIC SPI for the FPGA F2H IRQ1 line. The
 * socfpga_hpu_interrupt_t enum value FPGA2HPS_INTERRUPT1 = 50 (since
 * INTERRUPT_CCU = 48, FPGA2HPS_INTERRUPT0 = 49). The Bao FreeRTOS-VM
 * device map exposes this intid via configs/linux_freertos/config.c. */
#define ILC_INTID 50U

/* MMIO bases. Identity-mapped into the FreeRTOS guest IPA via the
 * 0x20000000 / 0x1000 dev_region in Bao's config; Stage-2 attrs are
 * Device-nGnRnE so all loads/stores below are strictly ordered against
 * each other without explicit DSBs. */
#define ITIMER_BASE 0x20000000UL
#define ILC_BASE 0x20000100UL

/* Interval Timer registers (offsets from ITIMER_BASE). PERIOD_LO/HI
 * are programmed by the FPGA Soft-IP at power-on reset and are
 * effectively read-only here -- the ~x seconds tick cadence is a property
 * of the bitstream, not software. */
#define ITIMER_STATUS_REG (ITIMER_BASE + 0x00UL)
#define ITIMER_CTRL_REG (ITIMER_BASE + 0x04UL)
#define ITIMER_PERIOD_LO (ITIMER_BASE + 0x08UL)
#define ITIMER_PERIOD_HI (ITIMER_BASE + 0x0CUL)

#define ITIMER_CTRL_ITO (1U << 0)
#define ITIMER_CTRL_CONT (1U << 1)
#define ITIMER_CTRL_START (1U << 2)
#define ITIMER_CTRL_STOP (1U << 3)
#define ITIMER_CTRL_RUN (ITIMER_CTRL_ITO | ITIMER_CTRL_CONT | ITIMER_CTRL_START)

/* ILC registers (offsets from ILC_BASE) -- mirrors altera_ilc.c. */
#define ILC_CNT_REG (ILC_BASE + 0x00UL)
#define ILC_CTRL_REG (ILC_BASE + 0x80UL)
#define ILC_FREQ_REG (ILC_BASE + 0x84UL)
#define ILC_STP_REG (ILC_BASE + 0x88UL)
#define ILC_VLD_REG (ILC_BASE + 0x8CUL)

/* ILC clock = 100 MHz -> 10 ns per latched cycle. Match the bitstream
 * IP; if a future bitstream rev clocks the ILC differently, update
 * this value (FREQ_REG offset 0x84 reports it for runtime cross-check
 * but we do not consume that read in the hot path). */
#define ILC_FREQ_HZ 100000000UL
#define ILC_NS_PER_TICK (1000000000UL / ILC_FREQ_HZ)

/* SPSC ring sized to comfortably absorb one drain-task wake-up
 * latency (~1 s polling cadence) at the 4 s sample cadence. 64 is
 * deep overkill in steady state but cheap. Power-of-two so head/tail
 * wrap with a mask. */
#define ILC_RING_SIZE 64U

typedef struct {
    uint32_t cycles; /* raw ILC count, snapshotted in the ISR */
    uint32_t ns; /* cycles * ILC_NS_PER_TICK, precomputed for the drain */
} ilc_sample_t;

typedef struct {
    ilc_sample_t buf[ILC_RING_SIZE];

    /* head: ISR writes, drain reads.  tail: drain writes, ISR reads.
     * Single-writer / single-reader on the same vCPU -- a 'dmb ishst'
     * pair before/after head-update is sufficient.  See ilc_latency.c. */
    volatile uint32_t head;
    volatile uint32_t tail;

    /* Cumulative counters maintained by the ISR. The drain task may
     * read these without locking -- non-atomic 32-bit reads will at
     * worst observe an in-flight value, never a torn one (single
     * vCPU + ARMv8 single-copy atomic 32-bit aligned loads). */
    volatile uint32_t total;
    volatile uint32_t overruns; /* ISR writes, drain task reads */
    uint32_t min_cycles; /* ISR-only */
    uint32_t max_cycles; /* ISR-only */
    uint64_t sum_cycles; /* ISR-only */
} ilc_ring_t;

/*
 * Spin up the full ILC measurement pipeline:
 *
 *   1. Initialise the SPSC ring + cumulative stats.
 *   2. Program the ILC (CTRL=0 -> STP=0 -> CTRL=0x205) and the
 *      Interval Timer (STOP -> STATUS=0 -> CTRL=RUN).
 *   3. Register the SPI 50 ISR via interrupt_register_isr and enable it
 *      level-triggered at GIC priority 0 (highest) so it preempts the
 *      rpmsg-kick SPI 52.
 *   4. Spawn the low-priority drain task that consumes the ring and
 *      emits one '[FRT] ilc n=10 ...' summary line per 10 samples
 *      via rpmsg_trysendto on the supplied endpoint.
 *
 * MUST be called from task context AFTER:
 *   - interrupt_init_gic()           (main.c::prvSetupHardware)
 *   - platform_register_kick_isr()   (main.c::prvSetupHardware)
 *   - platform_create_rpmsg_vdev()   (main_rpmsg_console.c::prvProducerTask)
 *   - rpmsg_create_ept(&xEndpoint, ...)  (main_rpmsg_console.c)
 * because the drain task immediately starts trying to publish over
 * rpmsg and the ISR begins firing as soon as interrupt_spi_enable
 * lands -- so the endpoint must be alive before we get here.
 *
 * `endpoint` must remain valid for the lifetime of the guest (the
 * drain task captures the pointer); ilc_start() does not copy it.
 *
 * Returns 0 on success, negative errno on configuration failure
 * (interrupt registration or task creation).
 */
int ilc_start(struct rpmsg_endpoint *endpoint);

/* Exposed for unit-test / debug; not used in normal operation. */
extern ilc_ring_t g_ilc_ring;

/* Registered as the SPI 50 handler by ilc_start() -- declared here so
 * the function symbol is available for cross-checks but callers should
 * not invoke it directly.
 *
 * Signature matches the freertos-socfpga socfpga_interrupt_callback_t
 * (void (*)(void *user_data)); user_data is unused. */
void ilc_isr(void *user_data);

#endif /* ILC_LATENCY_H */
