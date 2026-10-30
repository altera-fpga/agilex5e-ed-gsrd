/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * main_rpmsg_console.c -- bidirectional rpmsg producer/consumer task.
 *
 * A single FreeRTOS task owns the OpenAMP bring-up AND a 10 s heartbeat
 * that surfaces both directions of the rpmsg link to a Linux-side
 * reader on /dev/rpmsg0:
 *
 *   - prvRpmsgRxCb captures every Linux -> FreeRTOS payload into a
 *     small 64-byte buffer ('g_last_rx[]') under a seqlock and bumps
 *     a monotonic counter ('g_rx_count'). The cb runs in TASK context
 *     (deferred from the kick ISR by platform_rx_dispatch_task in
 *     platform.c -- see the long comment on g_rx_task there) so
 *     FreeRTOS primitives WOULD be safe here, but the seqlock pattern
 *     (volatile + 'dmb ish') is kept because it is also race-safe
 *     against any future hot-path readers without the cost of a
 *     mutex acquire/release per inbound payload.
 *
 *   - prvProducerTask runs the OpenAMP bring-up
 *     (platform_create_rpmsg_vdev + rpmsg_create_ept) and then loops
 *     emitting one heartbeat every 10 s:
 *
 *       [FRT] hb uptime=Xs tx=N txfail=K rx=M last="..."
 *
 *     A Linux-side `cat /dev/rpmsg0` sees a humane liveness signal
 *     (absence of a heartbeat for >30 s means the FreeRTOS guest is
 *     hung). 'txfail' counts how many heartbeats failed to grab a tx
 *     buffer (rpmsg_trysendto returning RPMSG_ERR_NO_BUFF) -- a
 *     non-zero value indicates that no /dev/rpmsg0 reader is consuming
 *     buffers fast enough; the producer never blocks (we use
 *     rpmsg_trysendto, not rpmsg_sendto) so an unattended heartbeat
 *     just gets dropped.
 *
 *     'rx' is the monotonic count of Linux -> FreeRTOS payloads seen by
 *     prvRpmsgRxCb, and 'last' echoes the most recent one (CR/LF
 *     trimmed, truncated to mainLAST_RX_BUF_SIZE). So a manual
 *     `echo "Test Ping" > /dev/rpmsg0` is confirmed on the next
 *     heartbeat as `rx=1 last="Test Ping"`. The pair is sampled under
 *     the g_rx_seq seqlock so the reader never observes a torn buffer
 *     mid-update. (Linux's rpmsg_chrdev never sends an *unsolicited*
 *     reply, so rx stays 0 until you write to /dev/rpmsg0 yourself.)
 *
 * Heartbeats target a FIXED dst (RPMSG_RESERVED_ADDRESSES = 0x400)
 * rather than xEndpoint.dest_addr.  Linux's rpmsg_chrdev allocates
 * a fresh eptdev per open(), so the auto-latched dest_addr would
 * point heartbeats at a userspace endpoint that gets destroyed when
 * its fd is closed -- the next `cat /dev/rpmsg0` opens at a different
 * address and never sees the heartbeat (BAOIRQ counter still climbs
 * on the FRT->Linux side, but the data is silently dropped at the
 * Linux end).  See the comment block above BAO_LINUX_DEFAULT_EPT_ADDR
 * for the empirical evidence.
 */

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "FreeRTOS.h"
#include "task.h"

#include <openamp/open_amp.h>
#include <openamp/rpmsg.h>

#include "platform.h"
#include "ilc_latency.h"

#define mainPRODUCER_TASK_PRIORITY (tskIDLE_PRIORITY + 1)
#define mainPRODUCER_STACK_WORDS (4096U)

/* Heartbeat cadence. 10 s keeps 'cat /dev/rpmsg0' humane to read while
 * still giving a sub-minute liveness signal. Flip to 5000U for a
 * faster cadence with no other code changes. */
#define mainHEARTBEAT_PERIOD_MS (10000U)
#define mainHEARTBEAT_PERIOD_TICKS pdMS_TO_TICKS(mainHEARTBEAT_PERIOD_MS)

/* Snapshot of the most recent Linux -> FreeRTOS payload. 63 chars +
 * NUL is enough for the heartbeat to surface short ad-hoc commands
 * ('echo pingX') while keeping the line under 160 bytes total. Longer
 * payloads are silently truncated; the rx counter still increments. */
#define mainLAST_RX_BUF_SIZE (64U)

/*
 * Linux's rpmsg_chrdev never sends a "hello" message back to the firmware
 * after binding /dev/rpmsg0 -- it just creates the cdev and starts queuing
 * inbound traffic for read(2). Our endpoint's dest_addr therefore stays
 * at RPMSG_ADDR_ANY until Linux ever writes back to us, and
 * rpmsg_send_offchannel_raw rejects dst == RPMSG_ADDR_ANY -- so we drive
 * the dst explicitly.
 *
 * We deliberately target a FIXED dst (RPMSG_RESERVED_ADDRESSES = 0x400)
 * for every heartbeat instead of consuming whatever
 * rpmsg_virtio_rx_callback latched into xEndpoint.dest_addr from the
 * last inbound payload.  Why:  Linux's rpmsg_chrdev allocates a fresh
 * eptdev per open(), so the inbound msg->src points at a userspace
 * endpoint that gets DESTROYED on close().  Reading the latched value
 * once that fd is closed sends heartbeats into the void; the next
 * `cat /dev/rpmsg0` opens at a different address and never sees them
 * (verified empirically: BAOIRQ counter still climbs on the FRT->Linux
 * side, but the data is dropped at the Linux end because no endpoint
 * is bound to the latched addr).
 *
 * 0x400 is the first idr_alloc() id from RPMSG_RESERVED_ADDRESSES on
 * the Linux side, so virtio_rpmsg_bus assigns it as the default ept
 * for the rpmsg-raw channel.  It is also the first address OpenAMP
 * allocates on the FreeRTOS side (visible in the matching "creating
 * channel rpmsg-raw addr 0x400" line on the Linux console).  Linux
 * userspace (cat / rpmsg-bidir-check.sh / future cdev consumers) all
 * inherit that default ept on first-open, so a fixed-dst heartbeat
 * lands in whichever reader currently holds /dev/rpmsg0 open.
 */
#define BAO_LINUX_DEFAULT_EPT_ADDR RPMSG_RESERVED_ADDRESSES

static struct rpmsg_endpoint xEndpoint;

/*
 * Seqlock guarding (g_rx_count, g_last_rx). Even = stable, odd =
 * writer in flight. The writer (prvRpmsgRxCb) and the reader
 * (prvProducerTask, format-heartbeat path) BOTH run in task context
 * (the rx-cb is dispatched from platform_rx_dispatch_task in
 * platform.c, not directly from the kick ISR). Using only volatile +
 * 'dmb ish' is still the cheapest correct primitive for this
 * single-writer / single-reader pair, and stays correct should the
 * dispatch path ever move back into ISR context.
 *
 * Worst case for the reader: it observes g_rx_seq odd or sees a
 * mismatch between the s1/s2 bracket samples; it retries. Worst case
 * for the writer: zero -- the cb path is straight-line.
 */
static volatile uint32_t g_rx_seq;
static volatile uint32_t g_rx_count;
static char g_last_rx[mainLAST_RX_BUF_SIZE];

void vApplicationTickHook(void)
{
}

/*
 * RX path. Captures the payload into the seqlock-protected slot and
 * bumps the rx counter. We deliberately do NOT echo back. The seqlock
 * keeps the path lock-free; the cb is invoked from
 * platform_rx_dispatch_task (task context), so any FreeRTOS primitive
 * would also be legal here.
 */
static int prvRpmsgRxCb(struct rpmsg_endpoint *ept, void *data, size_t len, uint32_t src, void *priv)
{
    (void)ept;
    (void)src;
    (void)priv;

    g_rx_seq++; /* now odd */
    __asm__ volatile("dmb ish" ::: "memory");

    size_t copy = (len < (mainLAST_RX_BUF_SIZE - 1U)) ? len : (mainLAST_RX_BUF_SIZE - 1U);
    if (copy > 0U && data != NULL) {
        memcpy(g_last_rx, data, copy);
    }
    /* Trim trailing CR/LF so the heartbeat line stays single-line --
     * 'echo pingX > /dev/rpmsg0' arrives with a trailing '\n' that we
     * don't want re-emitted into 'last_rx="pingX\n"'. */
    while (copy > 0U && (g_last_rx[copy - 1U] == '\n' || g_last_rx[copy - 1U] == '\r')) {
        copy--;
    }
    g_last_rx[copy] = '\0';

    g_rx_count++;
    __asm__ volatile("dmb ish" ::: "memory");
    g_rx_seq++; /* now even */
    return RPMSG_SUCCESS;
}

static void prvProducerTask(void *pvParameters)
{
    struct rpmsg_device *rdev;
    TickType_t xNextWakeTime;
    int ret;
    unsigned long ulTxCount = 0U;
    unsigned long ulTxFailures = 0U;
    char szLine[192];

    (void)pvParameters;

    /* Blocks until Linux flips DRIVER_OK in fw_rsc_vdev.status (i.e.
     * until `echo start > /sys/class/remoteproc/remoteproc0/state` has
     * driven virtio_rpmsg_bus through its probe). */
    rdev = platform_create_rpmsg_vdev();
    if (rdev == NULL) {
        for (;;) {
            vTaskDelay(portMAX_DELAY);
        }
    }

    /* Sends NS_ANNOUNCE on TX vring1 -- Linux's rpmsg_chrdev binds this
     * endpoint by exact channel name (RPMSG_BAO_CHANNEL_NAME), and
     * userspace gets /dev/rpmsg0 within a few hundred us of this call. */
    ret =
        rpmsg_create_ept(&xEndpoint, rdev, RPMSG_BAO_CHANNEL_NAME, RPMSG_ADDR_ANY, RPMSG_ADDR_ANY, prvRpmsgRxCb, NULL);
    if (ret != 0) {
        for (;;) {
            vTaskDelay(portMAX_DELAY);
        }
    }

    /* Bring up the ILC interrupt-latency pipeline now that the rpmsg
     * endpoint is alive. ilc_start():
     *   - registers the SPI 50 ISR (Bao maps F2H IRQ1 -> intid 50 via
     *     the dev_region in configs/linux_freertos/config.c),
     *   - programs the LWH2F Interval Timer + ILC at 0x20000000, and
     *   - spawns prvIlcDrainTask which emits a '[FRT] ilc n=10 ...'
     *     summary line on this same xEndpoint every 10 samples
     *     (~40 s at the ~4 s ITIMER period).
     *
     * Prereqs satisfied here: prvSetupHardware() has run
     * interrupt_init_gic(); platform_create_rpmsg_vdev() has flipped
     * Linux into DRIVER_OK; and the endpoint above is bound.
     *
     * The LWH2F bridge at 0x20000000 MUST be enabled before Bao launches
     * the FreeRTOS VM: the FPGA fabric is programmed at U-Boot time via
     * `fpga load` + `bridge enable` (see boot.cmd). Without this the
     * bridge stays "FPGA not ready" and any MMIO write inside
     * ilc_start() stalls the FreeRTOS vCPU on the open bus transaction.
     *
     * On failure we deliberately keep the heartbeat loop running -- a
     * broken ILC must not silently kill the liveness signal. The failure
     * is observable via the absence of '[FRT] ilc' lines on
     * /dev/rpmsg0. */
    (void)ilc_start(&xEndpoint);

    xNextWakeTime = xTaskGetTickCount();
    for (;;) {
        unsigned long ulUptime;
        unsigned long ulRxCount;
        char szLastRx[mainLAST_RX_BUF_SIZE];
        uint32_t s1, s2;
        int n;

        vTaskDelayUntil(&xNextWakeTime, mainHEARTBEAT_PERIOD_TICKS);

        ulUptime = (unsigned long)(xTaskGetTickCount() / configTICK_RATE_HZ);
        ulTxCount++;

        /* Seqlock read of the (g_rx_count, g_last_rx) pair the RX cb
         * publishes. Retry while the writer is mid-update (g_rx_seq
         * odd) or the bracketing samples disagree, so we never format a
         * torn buffer. Single writer / single reader, both in task
         * context, so this loop converges immediately in practice. */
        do {
            s1 = g_rx_seq;
            __asm__ volatile("dmb ish" ::: "memory");
            ulRxCount = (unsigned long)g_rx_count;
            memcpy(szLastRx, g_last_rx, sizeof(szLastRx));
            __asm__ volatile("dmb ish" ::: "memory");
            s2 = g_rx_seq;
        } while ((s1 & 1U) || (s1 != s2));
        szLastRx[mainLAST_RX_BUF_SIZE - 1U] = '\0';

        n = snprintf(szLine, sizeof(szLine), "[FRT] hb uptime=%lus tx=%lu txfail=%lu rx=%lu last=\"%s\"\r\n", ulUptime,
                     ulTxCount, ulTxFailures, ulRxCount, szLastRx);
        if (n <= 0) {
            continue;
        }
        if ((size_t)n >= sizeof(szLine)) {
            n = (int)(sizeof(szLine) - 1U);
        }

        /* Non-blocking send (rpmsg_trysendto) -- with a blocking send,
         * if Linux's chrdev queue is wedged or no eptdev is currently
         * bound at 0x400, the producer can spin up to 15 s inside
         * rpmsg_send_offchannel_raw waiting for a tx buffer; that
         * stalls the heartbeat cadence in user-visible ways. We bump
         * a 'txfail' counter on RPMSG_ERR_NO_BUFF so the next
         * heartbeat carries the evidence forward.
         *
         * Always target Linux's chrdev default ept (0x400) -- see the
         * BAO_LINUX_DEFAULT_EPT_ADDR comment block above for why the
         * RX-callback latch is the WRONG thing to read here. */
        ret = rpmsg_trysendto(&xEndpoint, szLine, n, (uint32_t)BAO_LINUX_DEFAULT_EPT_ADDR);
        if (ret < 0) {
            ulTxFailures++;
        }
    }
}

void main_rpmsg_console(void)
{
    BaseType_t rc =
        xTaskCreate(prvProducerTask, "rpmsgPROD", mainPRODUCER_STACK_WORDS, NULL, mainPRODUCER_TASK_PRIORITY, NULL);
    configASSERT(rc == pdPASS);

    vTaskStartScheduler();

    /* Should never reach here; if vTaskStartScheduler returns, fall
     * through to main()'s tight-loop fallback. */
    for (;;) {
    }
}
