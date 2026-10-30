/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * libmetal Bao port -- sample-side glue.
 *
 * - libmetal_bao_init():            metal_init + io_region over shmem.
 * - libmetal_bao_kick(vqid):        HVC into Bao -> vIRQ on Linux.
 * - libmetal_bao_register_kick_isr: register vIRQ 52 ISR via the
 *                                   freertos-socfpga socfpga_interrupt API.
 *
 * The libmetal machine port itself (sys.h / sys.c implementing
 * sys_irq_save_disable, metal_machine_cache_flush/invalidate,
 * metal_machine_io_mem_map, metal_generic_default_poll) lives upstream
 * in lib/system/freertos/bao/ under libmetal's source tree -- added by
 * patches/libmetal/v2025.04.0/0001-add-bao-port.patch.
 */

#include "metal_bao.h"
#include "resource_table.h"

#include <metal/sys.h>
#include <metal/io.h>

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

/* Single shmem io_region over the Bao IPC shmem at IPA 0xC4000000.
 * Static so the pointer handed to OpenAMP remains valid for the
 * lifetime of the guest. */
static struct metal_io_region g_shmem_io;
static const metal_phys_addr_t g_shmem_phys[] = { RPMSG_RSC_TABLE_BASE };
static bool g_initialised = false;

struct metal_io_region *libmetal_bao_init(void)
{
    if (g_initialised) {
        return &g_shmem_io;
    }

    /* metal_init() registers the libmetal generic bus (so subsequent
     * metal_device_open() calls work; OpenAMP itself doesn't use
     * devices, but rpmsg_create_ept walks the metal device list during
     * teardown). With WITH_DEFAULT_LOGGER=OFF in CMakeLists.txt,
     * metal_log() is a no-op so we don't accidentally trip newlib's
     * stdio retargeting. */
    struct metal_init_params metal_params = METAL_INIT_DEFAULTS;
    if (metal_init(&metal_params) != 0) {
        return NULL;
    }

    /*
     * page_shift = -1U is libmetal's "single contiguous page" convention
     * (i.e. physmap[0] applies to the whole region); mem_flags = 0 is
     * read by libmetal but our metal_machine_io_mem_map is identity so
     * it has no effect on the resulting mapping -- both sides already
     * see the shmem region as Normal Cacheable WB and OpenAMP's
     * RSC_TABLE_INVALIDATE / RSC_TABLE_FLUSH funnel through
     * metal_machine_cache_invalidate / _flush which do `dc ivac` /
     * `dc cvac` + `dsb sy` over the dirty range.
     */
    metal_io_init(&g_shmem_io, (void *)RPMSG_RSC_TABLE_BASE, g_shmem_phys, RPMSG_SHMEM_SIZE, -1U,
                  0U, /* mem_flags: ignored by our identity
                              * metal_machine_io_mem_map; both VMs
                              * already map the shmem region as
                              * Normal Cacheable WB outer-shareable. */
                  NULL);

    g_initialised = true;
    return &g_shmem_io;
}

void libmetal_bao_kick(uint32_t vqid)
{
    /*
     * Bao routes vendor-hyp-svc 0x86000000..0x8600FFFF in
     * src/bao/src/arch/armv8/aborts.c -> hypercall(fid & 0xFFFF).
     * HC_IPC=1 hits ipc_hypercall (src/bao/src/core/ipc.c) which uses
     * x1=ipc_id to look up vm->ipcs[] and x2=event_id to index
     * ipc->interrupts[]. With our 2-entry interrupts = { 52, 52 }, both
     * vqid=0 and vqid=1 fire SPI 52 on the peer (no silent swallow).
     *
     * Return value (in x0) is currently ignored -- if Bao reports
     * -HC_E_INVAL_ARGS it just means the peer hasn't accepted the
     * notify (e.g. shmem unmapped), which we cannot meaningfully
     * recover from here. OpenAMP retries on the next vring kick.
     */
    register uint64_t x0 __asm__("x0") = BAO_HC_IPC_FID;
    register uint64_t x1 __asm__("x1") = BAO_RPMSG_IPC_ID;
    register uint64_t x2 __asm__("x2") = (uint64_t)vqid;
    __asm__ volatile("hvc #0" : "+r"(x0) : "r"(x1), "r"(x2) : "memory");
}

void libmetal_bao_register_kick_isr(libmetal_bao_isr_t cb, void *user_data)
{
    /* Register first so a kick that arrives between the GIC enable and
     * the first scheduler tick reaches our handler. interrupt_spi_enable
     * configures the SPI as level-triggered (matches Bao's vGIC default
     * for injected SPIs) and routes to any CPU (we only have one CPU in
     * this guest, so MODE_ANY is fine). */
    interrupt_register_isr(BAO_RPMSG_VIRQ_ID, (socfpga_interrupt_callback_t)cb, user_data);
    interrupt_spi_enable(BAO_RPMSG_VIRQ_ID, SPI_INTERRUPT_TYPE_LEVEL, SPI_INTERRUPT_MODE_ANY,
                         interrupt_min_interrupt_priority);
}
