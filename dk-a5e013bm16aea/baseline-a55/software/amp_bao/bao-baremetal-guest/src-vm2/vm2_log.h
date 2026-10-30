/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 *
 * vm2_log.h — VM2 → VM1 shmem log-ring producer.
 *
 * VM2 (the ILC worker) has no direct UART. It builds log strings in a
 * stack buffer and publishes them into the vm2_log_ring_t in shmem
 * (layout in shmem_msg.h). VM1 (the printer) drains the ring and writes
 * each entry to its owned UART0.
 *
 * The string builders (vm2_log_append_*) write into a caller-supplied
 * buffer of VM2_LOG_SLOT_SZ bytes and clamp to avoid overflow.
 */

#ifndef VM2_LOG_H
#define VM2_LOG_H

#include <stdint.h>
#include <shmem_msg.h>

/* Reset the ring producer state. Call once at startup before any emit. */
void vm2_log_ring_init(void);

/* Publish one NUL-terminated line into the shmem ring. Drops the line and
 * bumps VM2_LOG->dropped if the ring is full (VM1 not draining fast enough). */
void vm2_log_emit(const char *line);

/* Append a NUL-terminated string into buffer b at position *p, advancing
 * *p. Clamps to VM2_LOG_SLOT_SZ - 1 to leave room for the terminator. */
void vm2_log_append_str(char *b, int *p, const char *s);

/* Append the decimal representation of v into buffer b at position *p. */
void vm2_log_append_uint(char *b, int *p, uint32_t v);

#endif /* VM2_LOG_H */
