/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * libmetal Bao port surface.
 * ------------------------------------------------------------------
 * The libmetal Bao machine port lives upstream in
 * lib/system/freertos/bao/ (see patches/libmetal/xxx/
 * 0001-add-bao-port.patch). This header is the SAMPLE-side glue: a
 * single shmem io_region wired up for OpenAMP, the kick path that
 * issues HVC SMCC32_FID_VND_HYP_SRVC|HC_IPC, and the vIRQ 52 ISR
 * registration helper that fans every kick out to
 * rproc_virtio_notified() for both vrings.
 *
 *   x0 = 0x86000001  (= SMCC32_FID_VND_HYP_SRVC | HC_IPC)
 *   x1 = ipc_id      (0 -- matches `bao,ipc-id = <0>` in linux.dts
 *                     and shmem_id=0 in configs/.../config.c)
 *   x2 = event_id    (vqid: 0 / 1 -- both wired to SPI 52 by
 *                     configs/linux_freertos/config.c's
 *                     ipcs[0].interrupts = { 52, 52 })
 *
 * Bao's aborts.c routes vendor-hyp-svc 0x86000000..0x8600FFFF to
 * hypercall(fid & 0xFFFF); HC_IPC=1 dispatches into ipc_hypercall in
 * src/bao/src/core/ipc.c which looks up vm->ipcs[ipc_id].interrupts
 * [event_id] and injects that IRQ on the peer.
 */

#ifndef LIBMETAL_BAO_H
#define LIBMETAL_BAO_H

#include <stdint.h>

/* HVC ABI for kicks. */
#define BAO_HC_IPC_FID 0x86000001U
#define BAO_RPMSG_IPC_ID 0U

/* Kick IRQ on this guest = SPI 52 = FPGA2HPS_INTERRUPT3 in the
 * socfpga_hpu_interrupt_t enum. The enum's FPGA2HPS_INTERRUPT0 starts at
 * 49 (= INTERRUPT_CCU + 1 after SECMGR_TRIPLE_REDUN_ERROR=46), so
 * SPI 52 = FPGA2HPS_INTERRUPT3 (49 + 3). The Bao config wires
 * ipcs[0].interrupts = { 52, 52 } for both VMs so a kick from either
 * peer (event_id = vqid in {0,1}) lands here, and the ISR dispatches
 * rproc_virtio_notified() for BOTH vrings on every fire. */
#include "socfpga_interrupt.h"
#define BAO_RPMSG_VIRQ_ID FPGA2HPS_INTERRUPT3

/* Forward decl: libmetal's struct metal_io_region. We hand callers a
 * pointer to the single shmem io_region the sample owns; OpenAMP plugs
 * it into rproc_virtio_create_vdev / rproc_virtio_init_vring /
 * rpmsg_init_vdev for descriptor address translation. */
struct metal_io_region;

/*
 * Bring up the libmetal Bao port:
 *   - metal_init() with default params (registers the metal_generic_bus)
 *   - metal_io_init() over the 64 KiB shmem at IPA 0xC4000000
 *
 * Idempotent: subsequent calls are no-ops and return the same io_region.
 * Returns NULL on metal_init() failure.
 */
struct metal_io_region *libmetal_bao_init(void);

/*
 * Kick path: nudge the peer (Linux's bao-rproc) when OpenAMP has added
 * a buffer to vqid's vring. Backed by HVC SMCC32_FID_VND_HYP_SRVC|HC_IPC
 * with x1=BAO_RPMSG_IPC_ID, x2=vqid.
 *
 * Bao's ipc_hypercall does `event_id < ipc->interrupt_num` validation;
 * with our 2-entry interrupts table, both vqid=0 and vqid=1 are valid
 * and both fire SPI 52 on the peer.
 */
void libmetal_bao_kick(uint32_t vqid);

/*
 * Register the vIRQ 52 ISR. The caller must supply the per-IRQ ISR
 * (typically platform.c's platform_kick_isr); we centralise the
 * freertos-socfpga socfpga_interrupt API plumbing here so platform.c
 * stays free of GIC SPI knobs.
 *
 * Call once from main.c's prvSetupHardware -- AFTER interrupt_init_gic
 * -- so the SPI is enabled and the ISR is in place by the time the
 * FreeRTOS scheduler starts and OpenAMP issues its first kick.
 */
typedef void (*libmetal_bao_isr_t)(void *user_data);
void libmetal_bao_register_kick_isr(libmetal_bao_isr_t cb, void *user_data);

#endif /* LIBMETAL_BAO_H */
