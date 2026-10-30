/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef VIRTIO_CONSOLE_H
#define VIRTIO_CONSOLE_H

#include <stdint.h>
#include <spinlock.h>
#include <virtio.h>
#include <virtio_queue.h>
#include <virtio_mmio.h>

#define VIRTIO_CONSOLE_F_SIZE (1 << 0) /**< Configuration cols and rows are valid */
#define VIRTIO_CONSOLE_F_MULTIPORT \
    (1 << 1) /**< Device has support for multiple ports; max_nr_ports is valid and control \
                virtqueues will be used */
#define VIRTIO_CONSOLE_F_EMERG_WRITE \
    (1 << 2) /**< Device has support for emergency write. Configuration field emerg_wr is valid */

#define VIRTIO_CONSOLE_NUM_VQS (2) /**< Number of virtqueues */
#define VIRTIO_CONSOLE_FEATURES (VIRTIO_BASE_FEATURES) /**< VirtIO console features */
#define VIRTIO_CONSOLE_RX_VQ_IDX (0) /**< Receive virtqueue index */
#define VIRTIO_CONSOLE_TX_VQ_IDX (1) /**< Transmit virtqueue index */
#define VIRTIO_CONSOLE_DEVICE_ID (3) /**< VirtIO console device ID */

#define VIRTIO_CONSOLE_RX_BUFFER_SIZE (64) /**< Default eceive buffer size */
#define VIRTIO_CONSOLE_RX_CONSOLE_SIZE (VIRTIO_CONSOLE_RX_BUFFER_SIZE * 4) /**< Default console RX size */

/**
 * @struct virtio_console_config_space
 * @brief VirtIO console configuration space
 */
struct virtio_console_config_space {
    uint16_t cols; /**< Number of columns */
    uint16_t rows; /**< Number of rows */
    uint32_t max_nr_ports; /**< Maximum number of ports */
    uint32_t emerg_wr; /**< Emergency write */
};

/**
 * @struct virtio_console
 * @brief VirtIO console device
 */
struct virtio_console {
    struct virtq vqs[VIRTIO_CONSOLE_NUM_VQS]; /**< VirtIO console virtqueues */

    volatile struct virtio_mmio_reg *mmio; /**< VirtIO MMIO register */
    struct virtio_console_config_space config_space; /**< VirtIO console configuration space */

    char rx_buffer[VIRTIO_CONSOLE_RX_CONSOLE_SIZE]; /**< Receive buffer */
    size_t rx_buffer_pos; /**< Receive buffer position */
    spinlock_t rx_lock; /**< receive spinlock */

    spinlock_t tx_lock; /**< Transmit spinlock */

    uint16_t device_id; /**< Device ID */
    uint64_t negotiated_feature_bits; /**< Negotiated feature bits */
    bool ready; /**< Device is ready */
};

/**
 * @brief Initialize VirtIO console device
 *
 * @param console VirtIO console device
 * @param shmem_base Shared memory base address
 * @param mmio_base MMIO base address
 * @return true on success, false otherwise
 */
bool virtio_console_init(struct virtio_console *console, char *shmem_base, long mmio_base);

/**
 * @brief Initialize VirtIO MMIO register
 *
 * @param console VirtIO console device
 * @return true on success, false otherwise
 */
bool virtio_console_mmio_init(struct virtio_console *console);

/**
 * @brief Transmit data to the VirtIO console device
 *
 * @param console VirtIO console device
 * @param data Data to transmit
 */
void virtio_console_transmit(struct virtio_console *console, char *const data);

/**
 * @brief Receive data from the VirtIO console device
 *
 * @param console VirtIO console device
 * @return true if data was received, false otherwise
 * @note This function should be called from the RX interrupt handler
 * and it will extract the received message from the VirtIO console device
 * and store it in the console receive buffer.
 * The received message can be extracted using the virtio_console_rx_get_buffer() function.
 */
bool virtio_console_receive(struct virtio_console *console);

/**
 * @brief Extract the received message from the VirtIO console device
 *
 * @param console VirtIO console device
 * @return Received message
 */
char *virtio_console_rx_get_buffer(struct virtio_console *console);

/**
 * @brief Print the receive buffer
 *
 * @param console VirtIO console device
 */
void virtio_console_rx_print_buffer(struct virtio_console *console);

#endif
