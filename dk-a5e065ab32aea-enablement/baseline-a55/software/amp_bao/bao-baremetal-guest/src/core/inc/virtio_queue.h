/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef VIRTIO_QUEUE_H
#define VIRTIO_QUEUE_H

#include <stdint.h>
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <virtio_memory_pool.h>

/**
 * VirtIO virtqueue descriptor, available, and used table definitions
 * https://docs.oasis-open.org/virtio/virtio/v1.3/csd01/virtio-v1.3-csd01.html#x1-430005
 */

#define VIRTQ_DESC_F_NEXT 1 /**< This marks a buffer as continuing via the next field */
#define VIRTQ_DESC_F_WRITE 2 /**< This marks a buffer as device write-only (otherwise device read-only) */
#define VIRTQ_DESC_F_INDIRECT \
    4 /**< This means the buffer contains a list of buffer descriptors \
       */
#define VIRTQ_DESC_F_AVAIL (1 << 7) /**< This marks a buffer as available for the device to use */
#define VIRTQ_DESC_F_USED (1 << 15) /**< This marks a buffer as used by the device */

/* Default VirtIO queue size */
#define VIRTQ_SIZE 1024 /**< Virtqueue size */

/**
 * @struct virtq_desc
 * @brief VirtIO descriptor ring element
 */
struct virtq_desc {
    uint64_t addr; /**< I/O buffer guest-physical address */
    uint32_t len; /**< Length of the I/O buffer buffer */
    uint16_t flags; /**< Flags (NEXT, WRITE, INDIRECT) */
    uint16_t next; /**< Index (in descriptor ring) of next chained descriptor */
};

/**
 * @struct virtq_avail
 * @brief VirtIO available ring
 */
struct virtq_avail {
    uint16_t flags; /**< Configuration flags */
    uint16_t idx; /**< Index of next available descriptor ring entry */
    uint16_t ring[VIRTQ_SIZE]; /**< The actual available ring array */
};

/**
 * @struct virtq_used_elem
 * @brief VirtIO used ring element
 */
struct virtq_used {
    uint16_t flags; /**< Configuration flags */
    uint16_t idx; /**< Index of next available used ring entry */
    struct virtq_used_elem {
        uint32_t id; /**< Index of descriptor ring this element refers to */
        uint32_t len; /**< Length of data written to descriptor(s) buffer(s) */
    } ring[VIRTQ_SIZE];
};

/**
 * @struct virtq
 * @brief VirtIO virtqueue
 */
struct virtq {
    volatile struct virtq_desc *desc; /**< Descriptor ring */
    volatile struct virtq_avail *avail; /**< Available ring */
    volatile struct virtq_used *used; /**< Used ring */
    uint16_t queue_index; /**< The index of queue */
    uint16_t desc_next_free; /**< The next free descriptor index */
    uint16_t desc_num_free; /**< The number of free descriptors */
    uint16_t avail_last_idx; /**< The last index we checked for available buffers */
    uint16_t last_used_idx; /**< The last index we checked for used buffers */
    struct virtio_memory_pool pool; /**< Memory pool used to allocate memory for the I/O buffers */
};

/**
 * @brief Virtqueue memory layout
 * |------------------|----------------|-----------|-------------|
 * | Descriptor Table | Available Ring | Used Ring | Memory Pool |
 * |       16KB       |      4KB       |    12KB   |    64KB     |
 * |------------------|----------------|-----------|-------------|
 * @note For now, each virtqueue occupies 96KB of memory, so the total of the configured
 * shared memory must be at least 96KB x the number of virtqueues.
 */

#define PAGE_SIZE 4096
#define ROUND_UP_TO_PAGE_SIZE(x) (((x) + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1))

#define VIRTQ_AVAIL_DESC_SIZE (sizeof(uint16_t) + sizeof(uint16_t) + 2 + (sizeof(uint16_t) * VIRTQ_SIZE))
#define VIRTQ_USED_DESC_SIZE \
    (sizeof(uint16_t) + sizeof(uint16_t) + 2 + ((sizeof(uint32_t) + sizeof(uint32_t)) * VIRTQ_SIZE))

#define VIRTQ_DESC_SIZE (sizeof(struct virtq_desc) * VIRTQ_SIZE) // 16KB (for a 1024 queue size)
#define VIRTQ_AVAIL_SIZE (ROUND_UP_TO_PAGE_SIZE(VIRTQ_AVAIL_DESC_SIZE)) // 4KB (for a 1024 queue size)
#define VIRTQ_USED_SIZE (ROUND_UP_TO_PAGE_SIZE(VIRTQ_USED_DESC_SIZE)) // 12KB (for a 1024 queue size)
#define VIRTQ_VRINGS_SIZE_TOTAL (VIRTQ_DESC_SIZE + VIRTQ_AVAIL_SIZE + VIRTQ_USED_SIZE) // Total size for the three rings
#define VIRTQ_MEMORY_POOL_SIZE (VIRTQ_SIZE * 64) // 64KB (for a 1024 queue size)
#define VIRTQ_SIZE_TOTAL (VIRTQ_VRINGS_SIZE_TOTAL + VIRTQ_MEMORY_POOL_SIZE) // Total size for one queue

#define VIRTQ_DESC_ADDR(vq_base_addr) (vq_base_addr)
#define VIRTQ_AVAIL_ADDR(vq_base_addr) (vq_base_addr + VIRTQ_DESC_SIZE)
#define VIRTQ_USED_ADDR(vq_base_addr) (vq_base_addr + VIRTQ_DESC_SIZE + VIRTQ_AVAIL_SIZE)
#define VIRTQ_MEMORY_POOL_ADDR(vq_base_addr) (vq_base_addr + VIRTQ_VRINGS_SIZE_TOTAL)

/**
 * @brief Initialize the virtqueue
 * @param vq VirtIO virtqueue
 * @param queue_index Queue index
 * @param vq_base_addr Base address of the virtqueue
 */
static inline void virtq_init(struct virtq *vq, uint16_t queue_index, char *vq_base_addr)
{
    /* Initialize the descriptor ring */
    vq->desc = (volatile struct virtq_desc *)VIRTQ_DESC_ADDR(vq_base_addr);
    for (int i = 0; i < VIRTQ_SIZE; i++) {
        vq->desc[i].addr = 0;
        vq->desc[i].len = 0;
        vq->desc[i].flags = 0;
        vq->desc[i].next = i + 1;
    }
    vq->desc[VIRTQ_SIZE - 1].next = 0;
    vq->desc_next_free = 0;
    vq->desc_num_free = VIRTQ_SIZE;

    /* Initialize the available ring */
    vq->avail = (volatile struct virtq_avail *)VIRTQ_AVAIL_ADDR(vq_base_addr);
    vq->avail->flags = 0;
    vq->avail->idx = 0;
    for (int i = 0; i < VIRTQ_SIZE; i++) {
        vq->avail->ring[i] = 0;
    }
    vq->avail_last_idx = 0;

    /* Initialize the used ring */
    vq->used = (volatile struct virtq_used *)VIRTQ_USED_ADDR(vq_base_addr);
    vq->used->flags = 0;
    vq->used->idx = 0;
    for (int i = 0; i < VIRTQ_SIZE; i++) {
        vq->used->ring[i].id = 0;
        vq->used->ring[i].len = 0;
    }
    vq->last_used_idx = 0;

    vq->queue_index = queue_index;

    /* Initialize the memory pool */
    virtio_memory_pool_init(&vq->pool, (char *)VIRTQ_MEMORY_POOL_ADDR(vq_base_addr), VIRTQ_MEMORY_POOL_SIZE);
}

/**
 * @brief Get the descriptor at the specified index
 * @param vq VirtIO virtqueue
 * @param id Descriptor index
 * @return Returns the descriptor at the specified index
 */
static inline volatile struct virtq_desc *virtq_get_desc_by_id(struct virtq *vq, uint16_t id)
{
    return &vq->desc[id % VIRTQ_SIZE];
}

/**
 * @brief Check if the virtqueue has free descriptor slots
 * @param vq VirtIO virtqueue
 * @return true if there are free slots, false otherwise
 */
static inline bool virtq_has_free_slots(struct virtq *vq)
{
    return vq->desc_num_free != 0;
}

/**
 * @brief Get the next free descriptor index
 * @param vq VirtIO virtqueue
 * @return Returns the next free descriptor index
 */
static inline uint16_t virtq_get_free_desc_id(struct virtq *vq)
{
    assert(virtq_has_free_slots(vq));
    uint16_t idx = vq->desc_next_free;
    vq->desc_next_free = virtq_get_desc_by_id(vq, idx)->next;
    vq->desc_num_free--;
    return idx;
}

/**
 * @brief Put a descriptor back into the free list
 * @param vq VirtIO virtqueue
 * @param id Descriptor index
 */
static inline void virtq_put_free_desc(struct virtq *vq, uint16_t id)
{
    assert(vq->desc_num_free < VIRTQ_SIZE);
    virtq_get_desc_by_id(vq, id)->next = vq->desc_next_free;
    vq->desc_next_free = id;
    vq->desc_num_free++;
}

/**
 * @brief Initialize a descriptor
 * @param desc VirtIO descriptor
 * @param addr I/O buffer guest-physical address
 * @param len Length of the I/O buffer buffer
 */
static inline void virtq_desc_init(volatile struct virtq_desc *desc, uint64_t addr, uint32_t len)
{
    desc->addr = addr;
    desc->len = len;
    desc->flags = 0;
    desc->next = 0;
}

/**
 * @brief Set the descriptor as read only
 * @param desc VirtIO descriptor
 */
static inline void virtq_desc_set_read_only(volatile struct virtq_desc *desc)
{
    desc->flags &= ~VIRTQ_DESC_F_WRITE;
}

/**
 * @brief Set the descriptor as write only
 * @param desc VirtIO descriptor
 */
static inline void virtq_desc_set_write_only(volatile struct virtq_desc *desc)
{
    desc->flags |= VIRTQ_DESC_F_WRITE;
}

/**
 * @brief Check if the descriptor is read only
 * @param desc VirtIO descriptor
 * @return Returns true if the descriptor is read only, false otherwise
 */
static inline bool virtq_desc_is_read_only(volatile struct virtq_desc *desc)
{
    return !(desc->flags & VIRTQ_DESC_F_WRITE);
}

/**
 * @brief Set the descriptor as chainable with the next descriptor index
 * @param desc VirtIO descriptor
 * @param next Index of next chained descriptor
 */
static inline void virtq_desc_set_next(volatile struct virtq_desc *desc, uint16_t next)
{
    desc->flags |= VIRTQ_DESC_F_NEXT;
    desc->next = next;
}

/**
 * @brief Check if the descriptor is chainable
 * @param desc VirtIO descriptor
 * @return Returns true if the descriptor is chainable, false otherwise
 */
static inline bool virtq_desc_has_next(volatile struct virtq_desc *desc)
{
    return desc->flags & VIRTQ_DESC_F_NEXT;
}

/**
 * @brief Get the next chained descriptor index
 * @param desc VirtIO descriptor
 * @return Returns the next chained descriptor index
 */
static inline uint16_t virtq_desc_get_next(volatile struct virtq_desc *desc)
{
    return desc->next;
}

/**
 * @brief Check if the virtqueue has available buffers
 * @param vq VirtIO virtqueue
 * @return true if there are available buffers, false otherwise
 */
static inline bool virtq_avail_has_buf(struct virtq *vq)
{
    return vq->avail->idx != vq->avail_last_idx;
}

/**
 * @brief Check if the virtqueue has used buffers
 * @param vq VirtIO virtqueue
 * @return true if there are used buffers, false otherwise
 */
static inline bool virtq_used_has_buf(struct virtq *vq)
{
    return vq->used->idx != vq->last_used_idx;
}

/**
 * @brief Add a buffer to the virtqueue available ring
 * @param vq VirtIO virtqueue
 * @param id Descriptor index
 */
static inline void virtq_add_avail_buf(struct virtq *vq, uint16_t id)
{
    vq->avail->ring[vq->avail->idx % VIRTQ_SIZE] = id;
    vq->avail->idx++;
}

/**
 * @brief Add a buffer to the virtqueue used ring
 * @param vq VirtIO virtqueue
 * @param id Descriptor index
 * @param len Length of data written to the buffer
 */
static inline void virtq_add_used_buf(struct virtq *vq, uint16_t id, uint32_t len)
{
    vq->used->ring[vq->used->idx % VIRTQ_SIZE].id = id;
    vq->used->ring[vq->used->idx % VIRTQ_SIZE].len = len;

    vq->used->idx++;
}

/**
 * @brief Get the next available buffer index
 * @param vq VirtIO virtqueue
 * @return Returns the next available buffer index
 */
static inline uint16_t virtq_get_avail_buf_id(struct virtq *vq)
{
    assert(virtq_avail_has_buf(vq));
    return vq->avail->ring[vq->avail_last_idx++ % VIRTQ_SIZE];
}

static inline uint16_t virtq_get_used_buf_id(struct virtq *vq)
{
    assert(virtq_used_has_buf(vq));
    return vq->used->ring[vq->last_used_idx++ % VIRTQ_SIZE].id;
}

static inline void virtq_dump(struct virtq *vq)
{
    printf("queue index = 0x%x\n", vq->queue_index);
    printf("desc_next_free = 0x%x\n", vq->desc_next_free);
    printf("desc_num_free = 0x%x\n", vq->desc_num_free);
    printf("avail_last_idx = 0x%x\n", vq->avail_last_idx);
    printf("last_used_idx = 0x%x\n", vq->last_used_idx);

    if (!vq->desc) {
        printf("virtq_desc is NULL\n");
    } else {
        for (int i = 0; i < VIRTQ_SIZE; i++) {
            printf("desc[%d] addr = 0x%lx (data = %s), len = 0x%x, flags = 0x%x, next = 0x%x\n", i, vq->desc[i].addr,
                   (char *)vq->desc[i].addr, vq->desc[i].len, vq->desc[i].flags, vq->desc[i].next);
        }
    }
    if (!vq->avail) {
        printf("virtq_avail is NULL\n");
    } else {
        printf("avail flags = 0x%x, idx = 0x%x\n", vq->avail->flags, vq->avail->idx);
        for (int i = 0; i < VIRTQ_SIZE; i++) {
            printf("avail ring[%d] = 0x%x\n", i, vq->avail->ring[i]);
        }
    }
    if (!vq->used) {
        printf("virtq_used is NULL\n");
    } else {
        printf("used flags = 0x%x, idx = 0x%x\n", vq->used->flags, vq->used->idx);
        for (int i = 0; i < VIRTQ_SIZE; i++) {
            printf("used ring[%d] id = 0x%x, len = 0x%x\n", i, vq->used->ring[i].id, vq->used->ring[i].len);
        }
    }
}

#endif
