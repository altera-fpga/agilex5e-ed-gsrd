/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * platform.c -- OpenAMP bring-up + IRQ fan-out.
 *
 * Three layers, top-down:
 *
 *   platform_create_rpmsg_vdev (called from producer task)
 *     |- libmetal_bao_init()       (metal_init + io_region over shmem)
 *     |- rproc_virtio_create_vdev  (role = VIRTIO_DEV_DEVICE,
 *     |                             rsc = &g_rsc_table.vdev_rpmsg)
 *     |- rproc_virtio_init_vring x2 (RX vring0 + TX vring1)
 *     |- rpmsg_virtio_init_shm_pool over the vdev0buffer carveout
 *     |- rpmsg_init_vdev            (BLOCKS until Linux DRIVER_OK)
 *     `- return &rvdev.rdev
 *
 *   platform_notify (called by OpenAMP from rproc_virtio_set_status /
 *                   virtqueue_notify) -> libmetal_bao_kick(vqid)
 *
 *   platform_register_kick_isr / platform_kick_isr ->
 *     rproc_virtio_notified(g_vdev, RSC_NOTIFY_ID_ANY)
 *
 * RSC_NOTIFY_ID_ANY (= 0xFFFFFFFF in OpenAMP) tells the dispatcher to
 * fire every virtqueue's callback. That's exactly the behaviour we
 * want: both vrings deliver on the same vIRQ 52 in our Bao config
 * (ipcs[0].interrupts = { 52, 52 } -- see configs/.../config.c) and
 * the receiver has no cheap way to discriminate which vring caused
 * the kick, so we just sweep both. OpenAMP's own header documents
 * this as the canonical pattern for shared-IRQ remoteproc backends.
 */

#include "platform.h"
#include "libmetal_bao/metal_bao.h"
#include "resource_table.h"

#include <openamp/open_amp.h>
#include <openamp/remoteproc.h>
#include <openamp/remoteproc_virtio.h>
#include <openamp/rpmsg_virtio.h>
#include <openamp/virtio.h>

#include <metal/io.h>

#include "FreeRTOS.h"
#include "task.h"

#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* RSC_NOTIFY_ID_ANY (see <openamp/remoteproc.h>) sweeps every vq when
 * rproc_virtio_notified() doesn't know which one fired. */
#ifndef RSC_NOTIFY_ID_ANY
#define RSC_NOTIFY_ID_ANY 0xFFFFFFFFU
#endif

/*
 * Module-private state -- the producer task creates the vdev once and
 * leaves the pointer behind so the kick ISR can find it. We use a
 * single rpmsg_virtio_device because the demo publishes a single
 * RSC_VDEV with one rpmsg channel.
 *
 * g_vdev_ready gates the ISR. Why a separate flag, instead of just
 * checking g_vdev != NULL? Because rproc_virtio_notified iterates the
 * vrings_info[] array allocated by rproc_virtio_create_vdev and calls
 * virtqueue_notification(vring_info->vq) for each entry. The per-vring
 * `vq` pointer is NOT populated by rproc_virtio_create_vdev /
 * rproc_virtio_init_vring; it is allocated later by rpmsg_init_vdev's
 * virtio_create_virtqueues path (see openamp/lib/virtio/virtqueue.c).
 *
 * Linux's virtio_rpmsg_bus probe -- the one that prints "rpmsg host is
 * online" -- posts initial RX buffers and kicks vring0 BEFORE FreeRTOS
 * has run rpmsg_init_vdev to completion. If we let the ISR through at
 * that point, virtqueue_notification dereferences a NULL vq and Bao
 * traps on guest IPA 0x18 (= NULL + offsetof(struct virtqueue,
 * callback)).
 *
 * Setting g_vdev_ready only after rpmsg_init_vdev returns guarantees
 * the vrings[] array is fully populated before the ISR processes a
 * kick. Early kicks are silently dropped; OpenAMP doesn't lose data
 * because the vring is shared memory -- the next kick (or any
 * rpmsg_recv poll) will see the buffers Linux already pushed. The
 * stdatomic store/load pair gives us the release/acquire barrier the
 * ISR needs to observe the fully initialised g_vdev/g_rvdev/g_shpool
 * state on a multi-core SMP host (a Cortex-A55 cluster's Inner
 * Shareable domain spans both cores in our demo, but the producer
 * task and the IRQ may still run on different vCPUs).
 */
static struct virtio_device *g_vdev = NULL;
static struct rpmsg_virtio_device g_rvdev;
static struct rpmsg_virtio_shm_pool g_shpool;
static atomic_bool g_vdev_ready = ATOMIC_VAR_INIT(false);

/*
 * RX dispatch is deferred from ISR -> task context. rproc_virtio_notified
 * fans out to rpmsg_virtio_rx_callback which calls
 * metal_mutex_acquire(&rdev->lock) -- on FreeRTOS that maps to
 * xSemaphoreTake(mutex, portMAX_DELAY), which is illegal in ISR context
 * AND deadlocks against the producer task whenever the task is in the
 * middle of rpmsg_send_offchannel_raw (which holds the same mutex
 * around the get-tx-buffer / virtqueue_kick window). The deadlock is
 * latent on FRT->Linux-only traffic (no inbound kick = no rx-cb in
 * ISR) but bites the moment Linux echoes anything back, freezing the
 * producer at the next heartbeat.
 *
 * Fix: ISR just records "kick pending" via xTaskNotifyGiveFromISR; a
 * dedicated rx-dispatch task wakes on ulTaskNotifyTake and invokes
 * rproc_virtio_notified() in task context, where mutex_acquire is
 * legal and contends correctly with the producer.
 */
static TaskHandle_t g_rx_task = NULL;

/*
 * The Bao shmem lives at IPA 0xC4000000. resource_table_publish() has
 * already written the rodata image there. OpenAMP edits
 * fw_rsc_vdev.status / .gfeatures in-place over this region, so the
 * pointer passed to rproc_virtio_create_vdev must point at shmem.
 */
static struct fw_rsc_vdev *bao_shmem_rsc_vdev(void)
{
    uintptr_t base = (uintptr_t)RPMSG_RSC_TABLE_BASE;
    return (struct fw_rsc_vdev *)(base + offsetof(struct rpmsg_resource_table, vdev_rpmsg));
}

/*
 * OpenAMP -> Bao kick. Invoked from rproc_virtio_set_status (initial
 * negotiation) and from virtqueue_notify (each TX from FreeRTOS). The
 * vq id is the OpenAMP notifyid we passed to rproc_virtio_init_vring,
 * which we set equal to the vring index (0 / 1). Our Bao ipc[] table
 * uses event_id == vqid for the same {0,1} -> SPI 52 mapping, so this
 * passes through verbatim.
 */
static int platform_notify(void *priv, uint32_t vqid)
{
    (void)priv;
    libmetal_bao_kick(vqid);
    return 0;
}

/*
 * vIRQ 52 ISR. Called from the GIC dispatch path in baremetal-runtime
 * (freertos-socfpga SOCFPGA interrupt layer). The g_vdev_ready acquire-load
 * is the only legal observation point inside this ISR -- see the long
 * comment on g_vdev_ready above for why g_vdev != NULL is NOT enough.
 * Early kicks (Linux's virtio_rpmsg_bus probe pushing RX buffers
 * before FreeRTOS has finished rpmsg_init_vdev) are silently dropped;
 * the next kick after we go ready will sweep both vrings via
 * RSC_NOTIFY_ID_ANY.
 *
 * We MUST NOT call rproc_virtio_notified() here -- see the long
 * comment on g_rx_task above. Instead we just notify the rx-dispatch
 * task; the actual virtio fan-out runs in task context.
 */
static void platform_kick_isr(void *user_data)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    (void)user_data;
    if (!atomic_load_explicit(&g_vdev_ready, memory_order_acquire)) {
        return;
    }
    if (g_rx_task == NULL) {
        return;
    }
    vTaskNotifyGiveFromISR(g_rx_task, &xHigherPriorityTaskWoken);
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

/*
 * Task-context RX dispatcher. Sleeps on the notification counter set
 * by platform_kick_isr; on wake, sweeps every vring via
 * RSC_NOTIFY_ID_ANY (same semantics the old in-ISR call had). Looping
 * on ulTaskNotifyTake collapses bursts of kicks into a single sweep,
 * which is correct: rproc_virtio_notified drains all currently
 * available buffers each call.
 */
static void platform_rx_dispatch_task(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        (void)ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        if (g_vdev != NULL) {
            (void)rproc_virtio_notified(g_vdev, RSC_NOTIFY_ID_ANY);
        }
    }
}

void platform_register_kick_isr(void)
{
    /*
     * Create the dispatch task BEFORE registering the ISR -- otherwise
     * a kick that arrives between ISR registration and task creation
     * would dereference g_rx_task = NULL. We bound the priority just
     * above the producer's idle+1 so RX completes promptly relative to
     * heartbeat formatting.
     */
    if (g_rx_task == NULL) {
        BaseType_t rc = xTaskCreate(platform_rx_dispatch_task, "rpmsgRX", (configSTACK_DEPTH_TYPE)2048U, NULL,
                                    (UBaseType_t)(tskIDLE_PRIORITY + 2), &g_rx_task);
        configASSERT(rc == pdPASS);
    }
    libmetal_bao_register_kick_isr(platform_kick_isr, NULL);
}

struct rpmsg_device *platform_create_rpmsg_vdev(void)
{
    struct metal_io_region *io;
    struct fw_rsc_vdev *vdev_rsc;
    int ret;

    io = libmetal_bao_init();
    if (io == NULL) {
        return NULL;
    }

    /*
     * VIRTIO_DEV_DEVICE = firmware side. Linux's bao-rproc owns the
     * driver side (VIRTIO_DEV_DRIVER). With this role split, OpenAMP's
     * rproc_virtio sets up RX as vring0 (Linux -> us) and TX as
     * vring1 (us -> Linux) which mirrors our fw_rsc_vdev_vring
     * publication order.
     *
     * The notifyid argument to rproc_virtio_create_vdev is the vdev
     * notifyid (fw_rsc_vdev.notifyid in the table = 0); the per-vring
     * notifyids are set independently by rproc_virtio_init_vring
     * below.
     */
    vdev_rsc = bao_shmem_rsc_vdev();

    g_vdev = rproc_virtio_create_vdev(VIRTIO_DEV_DEVICE, vdev_rsc->notifyid, vdev_rsc, io, NULL, platform_notify, NULL);
    if (g_vdev == NULL) {
        return NULL;
    }

    /* vring0 -- RX (Linux pushes buffers here for us to consume).
     * Notifyid 0 matches the fw_rsc_vdev_vring[0].notifyid we
     * publish at boot. */
    ret = rproc_virtio_init_vring(g_vdev, 0, vdev_rsc->vring[0].notifyid, (void *)(uintptr_t)RPMSG_VRING0_DA, io,
                                  vdev_rsc->vring[0].num, vdev_rsc->vring[0].align);
    if (ret != 0) {
        return NULL;
    }

    /* vring1 -- TX (we push buffers here for Linux to consume). */
    ret = rproc_virtio_init_vring(g_vdev, 1, vdev_rsc->vring[1].notifyid, (void *)(uintptr_t)RPMSG_VRING1_DA, io,
                                  vdev_rsc->vring[1].num, vdev_rsc->vring[1].align);
    if (ret != 0) {
        return NULL;
    }

    /* Shared buffer pool over the vdev0buffer carveout. Linux's
     * virtio_rpmsg_bus splits this 16 KiB region into rbufs (first
     * 8 KiB, used for FreeRTOS -> Linux) and sbufs (second 8 KiB, used
     * for Linux -> FreeRTOS). We just hand the whole region to OpenAMP
     * and let rpmsg_virtio carve it up internally. */
    rpmsg_virtio_init_shm_pool(&g_shpool, (void *)(uintptr_t)RPMSG_VDEV0_BUFFER_DA, RPMSG_VDEV0_BUFFER_SIZE);

    /*
     * BLOCKING call. rpmsg_init_vdev internally calls
     * rproc_virtio_wait_remote_ready which polls
     * fw_rsc_vdev.status & VIRTIO_CONFIG_STATUS_DRIVER_OK every
     * metal_yield (= AArch64 `wfe`). Linux's bao-rproc writes
     * DRIVER_OK when it finishes virtio probe (i.e. right after
     * `attached`). The producer task runs at priority idle+1 so the
     * spin doesn't starve the scheduler tick or any future co-task.
     */
    ret = rpmsg_init_vdev(&g_rvdev, g_vdev, NULL, io, &g_shpool);
    if (ret != 0) {
        return NULL;
    }

    /*
     * Release-store: g_vdev / g_rvdev / per-vring vq pointers are
     * fully initialised at this point (rpmsg_init_vdev's
     * virtio_create_virtqueues populates vrings_info[i].vq inside
     * rproc_virtio_create_virtqueues). The ISR's matching
     * memory_order_acquire load on g_vdev_ready synchronises with
     * this store, so any subsequent kick observes the fully
     * initialised state.
     */
    atomic_store_explicit(&g_vdev_ready, true, memory_order_release);

    return rpmsg_virtio_get_rpmsg_device(&g_rvdev);
}
