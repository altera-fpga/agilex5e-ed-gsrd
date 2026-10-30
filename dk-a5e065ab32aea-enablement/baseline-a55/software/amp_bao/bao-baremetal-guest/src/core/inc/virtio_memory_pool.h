/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#ifndef VIRTIO_MEMORY_POOL_H
#define VIRTIO_MEMORY_POOL_H

#include <stdint.h>
#include <virtio_queue.h>

/**
 * @struct virtio_memory_pool
 * @brief VirtIO memory pool used to allocate memory for the the VirtIO I/O buffers
 */
struct virtio_memory_pool {
    char *base; /**< Base address of the memory pool */
    unsigned long size; /**< Size of the memory pool */
    unsigned long offset; /**< Offset of the next available memory */
};

/**
 * @brief Initialize the VirtIO memory pool
 * @param pool VirtIO memory pool to initialize
 * @param base Base address of the memory pool
 * @param size Length of the memory to allocate
 */
static inline void virtio_memory_pool_init(struct virtio_memory_pool *pool, char *base, unsigned long size)
{
    pool->base = base;
    pool->size = size;
    pool->offset = 0;

    /* Mark all memory as free */
    for (unsigned long i = 0; i < size; i++) {
        pool->base[i] = 0;
    }
}

/**
 * @brief Allocate memory from the VirtIO memory pool
 * @param pool VirtIO memory pool
 * @param alloc_size Size of the memory to allocate
 * @return Returns a pointer to the allocated memory, or NULL if the allocation failed
 */
static inline char *virtio_memory_pool_alloc(struct virtio_memory_pool *pool, unsigned long alloc_size)
{
    /** Check if the requested allocation size is larger than the pool size */
    if (alloc_size > pool->size) {
        return NULL;
    }

    /** Check if there is enough space from the current offset to the end of the pool */
    if (pool->offset + alloc_size <= pool->size) {
        /* Get the pointer to the possible allocated memory */
        char *ptr = pool->base + pool->offset;

        /* Check if the memory is already allocated */
        for (unsigned long i = 0; i < alloc_size; i++) {
            if (pool->base[pool->offset + i] != 0) {
                return NULL;
            }
        }

        /* Increment the offset for the next allocation */
        pool->offset += alloc_size;

        /* Return the pointer to the allocated memory */
        return ptr;
    }

    /** If we reached the end of the pool, wrap around (circular buffer behavior) */
    if (alloc_size <= pool->offset) {
        /* Get the pointer to the possible allocated memory */
        char *ptr = pool->base;

        /* Check if the memory is already allocated */
        for (unsigned long i = 0; i < alloc_size; i++) {
            if (pool->base[i] != 0) {
                return NULL;
            }
        }

        /* Reset the offset */
        pool->offset = 0;

        /* Increment the offset for the next allocation */
        pool->offset += alloc_size;

        /* Return the pointer to the allocated memory */
        return ptr;
    }

    /** No sufficient contiguous space available */
    return NULL;
}

/**
 * @brief Free memory from the VirtIO memory pool
 * @param pool VirtIO memory pool
 * @param ptr Pointer to the memory to free
 * @param size Size of the memory to free
 * @return Returns true if the memory was successfully freed, false otherwise
 */
static inline bool virtio_memory_pool_free(struct virtio_memory_pool *pool, char *ptr, unsigned long size)
{
    /** Check if the pointer is within the pool */
    if (ptr < pool->base || ptr >= pool->base + pool->size) {
        return false;
    }

    /** Check if the size is within the pool */
    if (size > pool->size) {
        return false;
    }

    /** Calculate the offset */
    unsigned long offset = ptr - pool->base;

    /** Check if the offset is within the pool */
    if (offset < 0 || offset >= pool->size) {
        return false;
    }

    /** Free the memory */
    for (unsigned long i = 0; i < size; i++) {
        pool->base[offset + i] = 0;
    }

    return true;
}

#endif
