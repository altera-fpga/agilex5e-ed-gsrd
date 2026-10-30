/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef VIRTIO_H
#define VIRTIO_H

/**
 * VirtIO reserved feature bits
 * https://docs.oasis-open.org/virtio/virtio/v1.3/csd01/virtio-v1.3-csd01.html#x1-7080006
 */

#define VIRTIO_F_INDIRECT_DESC (1UL << 28) /**< Driver can use descriptors with the VIRTQ_DESC_F_INDIRECT flag set */
#define VIRTIO_F_EVENT_IDX (1UL << 29) /**< Enables the used_event and the avail_event fields */
#define VIRTIO_F_VERSION_1 \
    (1UL << 32) /**< Compliance with this specification, giving a simple way to detect legacy \
                   devices or drivers */
#define VIRTIO_F_ACCESS_PLATFORM \
    (1UL << 33) /**< Device can be used on a platform where device access to data in memory is \
                   limited and/or translated */
#define VIRTIO_F_RING_PACKED (1UL << 34) /**< Indicates support for the packed virtqueue layout */
#define VIRTIO_F_IN_ORDER \
    (1UL << 35) /**< All buffers are used by the device in the same order in which they have been \
                   made available */
#define VIRTIO_F_ORDER_PLATFORM \
    (1UL << 36) /**< Memory accesses by the driver and the device are ordered in a way described \
                   by the platform */
#define VIRTIO_F_SR_IOV \
    (1UL << 37) /**< Device supports Single Root I/O Virtualization. Currently only PCI devices \
                   support this feature */
#define VIRTIO_F_NOTIFICATION_DATA \
    (1UL << 38) /**< Driver passes extra data (besides identifying the virtqueue) in its device \
                   notifications */
#define VIRTIO_F_NOTIF_CONFIG_DATA \
    (1UL << 39) /**< Driver uses the data provided by the device as a virtqueue identifier in \
                   available buffer notifications */
#define VIRTIO_F_RING_RESET (1UL << 40) /**< Driver can reset a queue individually */
#define VIRTIO_F_ADMIN_VQ (1UL << 41) /**< Device supports an admin queue */

#define VIRTIO_BASE_FEATURES (VIRTIO_F_VERSION_1 | VIRTIO_F_ACCESS_PLATFORM)

/**
 * VIrtIO device status field values
 * https://docs.oasis-open.org/virtio/virtio/v1.3/csd01/virtio-v1.3-csd01.html#x1-110001
 */

#define RESET (0)
#define ACKNOWLEDGE (1)
#define DRIVER (2)
#define DRIVER_OK (4)
#define FEATURES_OK (8)
#define DEVICE_NEEDS_RESET (64)
#define FAILED (128)

/**
 * Other VirtIO constants
 */

#define VIRTIO_MAGIC_VALUE 0x74726976
#define VIRTIO_VERSION_NO_LEGACY 0x2

#endif
