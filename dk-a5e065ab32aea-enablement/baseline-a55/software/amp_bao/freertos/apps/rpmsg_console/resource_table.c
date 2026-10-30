/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * resource_table.c -- builds and publishes the OpenAMP resource_table
 * at offset 0 of the Bao IPC shmem (IPA 0xC4000000) so Linux remoteproc
 * can attach to the bao-rproc device.
 *
 * Layout & wire format documented in resource_table.h. Each dirty cache
 * line is flushed with `dc cvac` + `dsb sy` so the data lands in DRAM
 * before Linux's bao-rproc mapping observes it.
 */

#include "resource_table.h"

#include <openamp/remoteproc.h>
#include <openamp/rpmsg_virtio.h>
#include <openamp/virtio.h>

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define CL_BYTES 64U
#define CL_MASK ((uintptr_t)(CL_BYTES - 1U))

static inline void cache_clean_range(volatile const void *addr, size_t len)
{
    uintptr_t start = (uintptr_t)addr & ~CL_MASK;
    uintptr_t end = ((uintptr_t)addr + len + CL_BYTES - 1U) & ~CL_MASK;
    for (uintptr_t p = start; p < end; p += CL_BYTES) {
        __asm__ volatile("dc cvac, %0" : : "r"(p) : "memory");
    }
    __asm__ volatile("dsb sy" ::: "memory");
}

/* Source-of-truth resource table image. Sits in .rodata; copied verbatim
 * into shmem at boot. Keeping it const lets the compiler verify field
 * offsets at compile time and lets a future reader of the .elf locate
 * the table via `aarch64-none-elf-objdump -t | grep g_rsc_table_image`.
 *
 * Note on struct member naming: OpenAMP's struct fw_rsc_vdev declares
 * `vring[0]` as a flex array, so the two vring entries must live in
 * the wrapper struct's separate vring_rpmsg[2] field (see header). The
 * C99 designated-init form below makes the on-disk layout obvious to
 * the reader. */
static const struct rpmsg_resource_table g_rsc_table_image = {
    .ver = 1U,
    .num = 1U,
    .reserved = { 0U, 0U },
    /* Offset of vdev_rpmsg from the start of struct rpmsg_resource_table.
     * The Linux parser uses this to step from the header to each resource
     * entry. With one entry the math is simple: header is 16 + 4*num bytes
     * (ver/num/reserved + offset[num]). For num=1 -> 20 bytes. */
    .offset = { offsetof(struct rpmsg_resource_table, vdev_rpmsg) },

    .vdev_rpmsg = {
        .type           = RSC_VDEV,
        .id             = VIRTIO_ID_RPMSG,
        .notifyid       = 0U,
        .dfeatures      = (1U << VIRTIO_RPMSG_F_NS),
        .gfeatures      = 0U,
        .config_len     = 0U,
        .status         = 0U,
        .num_of_vrings  = 2U,
        .reserved       = { 0U, 0U },
    },
    .vring_rpmsg = {
        [0] = {
            .da       = (uint32_t)RPMSG_VRING0_DA,
            .align    = RPMSG_VRING_ALIGN,
            .num      = RPMSG_VRING_NUM_BUFFERS,
            .notifyid = 0U,
            .reserved = 0U,
        },
        [1] = {
            .da       = (uint32_t)RPMSG_VRING1_DA,
            .align    = RPMSG_VRING_ALIGN,
            .num      = RPMSG_VRING_NUM_BUFFERS,
            .notifyid = 1U,
            .reserved = 0U,
        },
    },
};

/* Compile-time guard: the published table must fit inside the 1 KiB
 * window the bao-rproc shim exposes via ->get_loaded_rsc_table. The
 * static_assert will fail the build if a future entry grows the table
 * past 1024 bytes -- a runtime symptom would be Linux silently reading
 * past the window into the vring0 carveout, which is much harder to
 * diagnose than a build break. */
_Static_assert(sizeof(g_rsc_table_image) <= RPMSG_RSC_TABLE_RESERVED,
               "resource_table > 1 KiB; bao-rproc only exposes 1 KiB");

void resource_table_publish(void)
{
    volatile uint8_t *dst = (volatile uint8_t *)(RPMSG_RSC_TABLE_BASE + RPMSG_RSC_TABLE_OFFSET);

    /* Bytewise copy into the shmem region. The size is small so the
     * per-byte cost is negligible, and the volatile access pattern
     * prevents the compiler from eliding stores to the mapped window. */
    const uint8_t *src = (const uint8_t *)&g_rsc_table_image;
    for (size_t i = 0U; i < sizeof(g_rsc_table_image); i++) {
        dst[i] = src[i];
    }

    /* Push the dirty cache lines back to DRAM so the Linux-side
     * `devm_ioremap_wc` mapping in bao-rproc observes the published
     * table on its first read. */
    cache_clean_range((const void *)dst, sizeof(g_rsc_table_image));
}
