/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * resource_table.h -- OpenAMP / Linux remoteproc resource table for the
 * Bao IPC shmem at IPA 0xC4000000.
 *
 * Linux discovers this table via the bao-rproc shim whose
 * ->get_loaded_rsc_table returns shmem_va + 0, size SZ_1K.
 * `echo start > /sys/class/remoteproc/remoteproc0/state` parses the table
 * and flips the rproc state from `detached` to `attached`. /dev/rpmsg0
 * appears once the FreeRTOS-side OpenAMP endpoint sends NS_ANNOUNCE.
 *
 * Shmem layout (offsets from 0xC4000000, 64 KiB total):
 *
 *   0x00000 .. 0x000FF   resource_table: header + RSC_VDEV + two vring entries
 *   0x01000 .. 0x02FFF   vring0 -- Linux->FreeRTOS RX (8 KiB)
 *   0x03000 .. 0x04FFF   vring1 -- FreeRTOS->Linux TX (8 KiB)
 *   0x05000 .. 0x08FFF   vdev0buffer -- shared rpmsg buffer pool (16 KiB)
 *   0x09000 .. 0x0FFFF   reserved (growth)
 */

#ifndef RPMSG_CONSOLE_RESOURCE_TABLE_H
#define RPMSG_CONSOLE_RESOURCE_TABLE_H

#include <stdint.h>

#include <openamp/open_amp.h>
#include <openamp/remoteproc.h>

#define RPMSG_RSC_TABLE_BASE 0xC4000000UL
#define RPMSG_RSC_TABLE_OFFSET 0x0000U
#define RPMSG_RSC_TABLE_RESERVED 0x400U /* Linux reads 1 KiB max */
#define RPMSG_SHMEM_SIZE 0x00010000UL /* 64 KiB Bao IPC shmem */

/* Vring and buffer pool placement inside the 64 KiB shmem.
 * Each vring is 8 KiB == PAGE_ALIGN(vring_size(num=16, align=0x1000)).
 * vring0 [0x1000..0x2FFF], vring1 [0x3000..0x4FFF], buffer pool starts
 * at 0x5000 (16 KiB). Must match the bao-rproc da_to_va range. */
#define RPMSG_VRING0_DA 0xC4001000UL /* Linux -> FreeRTOS */
#define RPMSG_VRING1_DA 0xC4003000UL /* FreeRTOS -> Linux */
#define RPMSG_VRING_ALIGN 0x1000U
#define RPMSG_VRING_NUM_BUFFERS 16U /* power of 2 */

/* Shared rpmsg buffer pool (vdev0buffer carveout on the Linux side).
 * Linux's virtio_rpmsg_bus splits this 16 KiB region into rbufs
 * (first 8 KiB) + sbufs (second 8 KiB).  Used by the FreeRTOS-side
 * libmetal_bao port to back rpmsg_virtio_init_shm_pool() so OpenAMP
 * descriptor addresses point inside the same region Linux's
 * dma_declare_coherent_memory zone covers. */
#define RPMSG_VDEV0_BUFFER_DA 0xC4005000UL
#define RPMSG_VDEV0_BUFFER_SIZE (16U * 1024U)
#define RPMSG_VDEV0_BUFFER_SIZE_PER_BUF 512U
#define RPMSG_VDEV0_BUFFER_COUNT (RPMSG_VDEV0_BUFFER_SIZE / RPMSG_VDEV0_BUFFER_SIZE_PER_BUF)

/* On-disk resource_table image. Inherits OpenAMP's wire format (struct
 * resource_table header + struct fw_rsc_vdev entry + inline
 * fw_rsc_vdev_vring entries) from <openamp/remoteproc.h>, but adds a
 * single offset[] slot up front to match the layout Linux remoteproc
 * parses. Linux walks offset[i] to find each resource entry, so the
 * vdev_rpmsg field must sit at a byte offset Linux can derive from
 * offset[0]. With one entry the math is simple: offset[0] = sizeof
 * (struct resource_table) + sizeof(uint32_t) (the offset[] slot itself).
 *
 * METAL_PACKED_BEGIN/END from libmetal expands to __attribute__((packed))
 * on GCC. The OpenAMP structs are already packed so the nested layout
 * stays bit-compatible with what Linux parses.
 *
 * OpenAMP's struct fw_rsc_vdev has a zero-length `vring[0]` flex array
 * at the end; we materialise the two fw_rsc_vdev_vring entries inline
 * here (vring_rpmsg[2]) so the rodata image carries the exact bytes
 * Linux expects. C99 + GCC layout rules with __attribute__((packed))
 * place vring_rpmsg[] immediately after the last byte of vdev_rpmsg,
 * which is the same address OpenAMP's flex-array `vdev_rpmsg.vring[0]`
 * would resolve to.
 */
METAL_PACKED_BEGIN
struct rpmsg_resource_table {
    uint32_t ver; /* must be 1 -- Linux rejects other values */
    uint32_t num; /* number of resource entries (we publish 1) */
    uint32_t reserved[2];
    uint32_t offset[1];
    struct fw_rsc_vdev vdev_rpmsg;
    struct fw_rsc_vdev_vring vring_rpmsg[2];
} METAL_PACKED_END;

/*
 * resource_table_publish() -- copy the rodata resource_table image into
 * the Bao IPC shmem at IPA 0xC4000000 and flush the dirty cache lines
 * so bao-rproc sees the table before the first `echo start > .../state`.
 * Must be called before vTaskStartScheduler.
 */
void resource_table_publish(void);

#endif /* RPMSG_CONSOLE_RESOURCE_TABLE_H */
