/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * platform.h -- OpenAMP / RPMsg bring-up glue.
 * ----------------------------------------------------------------
 * Three responsibilities, exposed as the smallest possible surface so
 * main.c / main_rpmsg_console.c don't drag <openamp/...> headers into
 * the boot path:
 *
 *   - platform_register_kick_isr   (called from prvSetupHardware) --
 *     registers the vIRQ 52 ISR via libmetal_bao_register_kick_isr so
 *     every kick from Linux's virtqueue_kick() fans out to
 *     rproc_virtio_notified(g_vdev, RSC_NOTIFY_ID_ANY).
 *
 *   - platform_create_rpmsg_vdev   (called from the producer task) --
 *     runs libmetal_bao_init(), rproc_virtio_create_vdev (role =
 *     VIRTIO_DEV_DEVICE because FreeRTOS is the firmware-side virtio
 *     device, Linux is the driver-side host), rproc_virtio_init_vring
 *     for both vrings, rpmsg_virtio_init_shm_pool over vdev0buffer,
 *     then BLOCKS in rpmsg_init_vdev until Linux flips DRIVER_OK in
 *     fw_rsc_vdev.status. Returns the rpmsg_device on which
 *     rpmsg_create_ept will publish the NS_ANNOUNCE.
 *
 *   - RPMSG_BAO_CHANNEL_NAME       -- the channel name shipped in the
 *     NS_ANNOUNCE. Linux's rpmsg_chrdev driver
 *     (drivers/rpmsg/rpmsg_char.c) auto-binds via an explicit id_table:
 *
 *         static struct rpmsg_device_id rpmsg_chrdev_id_table[] = {
 *             { .name = "rpmsg-raw"     },
 *             { .name = "rpmsg_chrdev"  },
 *             { }
 *         };
 *
 *     -- there is NO wildcard. We MUST name our channel one of those
 *     two strings so virtio_rpmsg_bus probes rpmsg_chrdev and
 *     userspace gets /dev/rpmsg0. Picking "rpmsg-raw" because that is
 *     the upstream-canonical name for unstructured rpmsg byte streams
 *     (the "_chrdev" alias is a leftover for older boards).
 *
 * Internals live in platform.c; everything else (kick HVC, ISR
 * registration, io_region init) is in libmetal_bao/metal_bao.[ch].
 */

#ifndef RPMSG_CONSOLE_PLATFORM_H
#define RPMSG_CONSOLE_PLATFORM_H

#include <openamp/rpmsg.h>

/* Must equal one of the names in Linux's
 * drivers/rpmsg/rpmsg_char.c::rpmsg_chrdev_id_table[] -- otherwise
 * NS_ANNOUNCE registers the rpmsg_device on the bus but no driver
 * binds and /dev/rpmsg0 is NOT created. See header comment above. */
#define RPMSG_BAO_CHANNEL_NAME "rpmsg-raw"

void platform_register_kick_isr(void);
struct rpmsg_device *platform_create_rpmsg_vdev(void);

#endif /* RPMSG_CONSOLE_PLATFORM_H */
