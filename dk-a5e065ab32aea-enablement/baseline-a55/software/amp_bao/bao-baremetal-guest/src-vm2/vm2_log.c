/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 *
 * vm2_log.c — VM2 → VM1 shmem log-ring producer (see vm2_log.h).
 *
 * SPSC ring: VM2 is the sole producer, VM1 the sole
 * consumer. Write protocol (matches the consumer in src-vm1/main.c):
 *   1. slots[head].len == 0 ? continue : drop (ring full).
 *   2. copy bytes into slots[head].data[].
 *   3. dsb ish  — data visible before len.
 *   4. slots[head].len = length (publish).
 *   5. advance head.
 */

#include "vm2_log.h"

void vm2_log_append_str(char *b, int *p, const char *s)
{
    while (*s && *p < (int)(VM2_LOG_SLOT_SZ - 1))
        b[(*p)++] = *s++;
}

void vm2_log_append_uint(char *b, int *p, uint32_t v)
{
    char tmp[10];
    int n = 0;
    if (v == 0U) {
        if (*p < (int)(VM2_LOG_SLOT_SZ - 1))
            b[(*p)++] = '0';
        return;
    }
    while (v > 0U && n < 10) {
        tmp[n++] = (char)('0' + v % 10U);
        v /= 10U;
    }
    while (n > 0 && *p < (int)(VM2_LOG_SLOT_SZ - 1))
        b[(*p)++] = tmp[--n];
}

void vm2_log_emit(const char *line)
{
    vm2_log_ring_t *ring = VM2_LOG;
    uint8_t h = ring->head;
    uint8_t slot = h & (uint8_t)(VM2_LOG_SLOTS - 1U);

    if (ring->slots[slot].len != 0U) {
        ring->dropped++;
        return;
    }

    int pos = 0;
    while (*line && pos < (int)(VM2_LOG_SLOT_SZ - 1)) {
        ring->slots[slot].data[pos++] = *line++;
    }
    ring->slots[slot].data[pos] = '\0';
    __asm__ volatile("dsb ish" ::: "memory");
    ring->slots[slot].len = (uint8_t)pos;
    ring->head = (uint8_t)((h + 1U) & (VM2_LOG_SLOTS - 1U));
}

void vm2_log_ring_init(void)
{
    vm2_log_ring_t *ring = VM2_LOG;
    ring->head = ring->tail = 0U;
    ring->dropped = 0U;
    for (size_t i = 0; i < VM2_LOG_SLOTS; i++) {
        ring->slots[i].len = 0U;
    }
}
