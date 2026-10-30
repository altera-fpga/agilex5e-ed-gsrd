/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef VIRTIO_MMIO_H
#define VIRTIO_MMIO_H

#include <stdint.h>

#define VIRTIO_MMIO_FEATURE_SEL_SIZE (2) /**< Feature selection size */
#define VIRTIO_MMIO_INT_VRING (1 << 0) /**< Virtio used buffer notification */
#define VIRTIO_MMIO_INT_CONFIG (1 << 1) /**< Virtio configuration change notification */
#define VIRTIO_MMIO_VRING_ALIGN (4096) /**< Virtio ring alignment */

/**
 * @struct virtio_mmio_reg
 * @brief VirtIO MMIO register layout
 * @note https://docs.oasis-open.org/virtio/virtio/v1.3/csd01/virtio-v1.3-csd01.html#x1-1800002
 */
struct virtio_mmio_reg {
    /* Magic value ("virt" string) - Read Only */
    uint32_t MagicValue; // offset 0x000

    /* Virtio device version - Read Only */
    uint32_t Version; // offset 0x004

    /* Virtio device ID - Read Only */
    uint32_t DeviceID; // offset 0x008

    /* Virtio vendor ID - Read Only */
    uint32_t VendorID; // offset 0x00c

    /* Bitmask of the features supported by the device (host) - Read Only */
    uint32_t DeviceFeatures; // offset 0x010

    /* Device (host) features set selector - Write Only */
    uint32_t DeviceFeaturesSel; // offset 0x014

    uint8_t pad0[0x020 - 0x018]; // padding

    /* Bitmask of features activated by the driver (guest) - Write Only */
    uint32_t DriverFeatures; // offset 0x020

    /* Activated features set selector - Write Only */
    uint32_t DriverFeaturesSel; // offset 0x024

    uint8_t pad1[0x030 - 0x028]; // padding

    /* Queue selector - Write Only */
    uint32_t QueueSel; // offset 0x030

    /* Maximum size of the currently selected queue - Read Only */
    uint32_t QueueNumMax; // offset 0x034

    /* Queue size for the currently selected queue - Write Only */
    uint32_t QueueNum; // offset 0x038

    uint8_t pad2[0x044 - 0x03c]; // padding

    /* Ready bit for the currently selected queue - Read Write */
    uint32_t QueueReady; // offset 0x044

    uint8_t pad3[0x050 - 0x048]; // padding

    /* Queue notifier - Write Only */
    uint32_t QueueNotify; // offset 0x050

    uint8_t pad4[0x060 - 0x054]; // padding

    /* Interrupt status - Read Only */
    uint32_t InterruptStatus; // offset 0x060

    /* Interrupt acknowledge - Write Only */
    uint32_t InterruptACK; // offset 0x064

    uint8_t pad5[0x070 - 0x068]; // padding

    /* Device status register - Read Write */
    uint32_t Status; // offset 0x070

    uint8_t pad6[0x080 - 0x074]; // padding

    /* Selected queue's Descriptor Table address, 64 bits in two halves */
    uint32_t QueueDescLow; // offset 0x080
    uint32_t QueueDescHigh; // offset 0x084

    uint8_t pad7[0x090 - 0x088]; // padding

    /* Selected queue's Driver Area address, 64 bits in two halves */
    uint32_t QueueDriverLow; // offset 0x090
    uint32_t QueueDriverHigh; // offset 0x094

    uint8_t pad8[0x0a0 - 0x098]; // padding

    /* Selected queue's Device Area address, 64 bits in two halves */
    uint32_t QueueDeviceLow; // offset 0x0a0
    uint32_t QueueDeviceHigh; // offset 0x0a4

    uint8_t pad9[0x0ac - 0x0a8]; // padding

    /* Shared memory region id */
    uint32_t SHMSel; // offset 0x0ac

    /* Shared memory region length, 64 bits in two halves */
    uint32_t SHMLenLow; // offset 0x0b0
    uint32_t SHMLenHigh; // offset 0x0b4

    /* Shared memory region base address, 64 bits in two halves */
    uint32_t SHMBaseLow; // offset 0x0b8
    uint32_t SHMBaseHigh; // offset 0x0bc

    uint32_t QueueReset; // offset 0x0c0

    uint8_t pad10[0x0fc - 0x0c4]; // padding

    /* Configuration atomicity value */
    uint32_t ConfigGeneration; // offset 0x0fc

    /* The config space is defined by each driver as
     * the per-driver configuration space - Read Write */
    uint32_t Config; // offset 0x100
} __attribute__((__packed__, aligned(0x1000)));

static inline void virtio_mmio_queue_notify(volatile struct virtio_mmio_reg *mmio, uint32_t queue_id)
{
    mmio->QueueNotify = queue_id;
}

#endif
