/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 *
 * shmem_msg.h — shared memory protocol between VM2 (ILC worker / sender) and VM1 (printer / receiver)
 *
 * Both VMs map the shmem region at IPA SHMEM_BASE (see build / Bao ipc base).
 * VM2 stamps each ILC sample then notifies VM1 via Bao IPC hypercall (HVC):
 *
 *   VM2: HVC FID 0xC6000001 → Bao ipc_hypercall → cpu_send_msg → VM1's physical CPU
 *        → inject virtual SGI 2 (see Bao ipc.interrupts[]) → VM1 ISR.
 *
 * Shmem cacheability — demo toggle:
 *   make ... SHMEM_IS=1      # Inner Shareable WB  (cacheable)
 *   make ... SHMEM_IS=0      # Non-Cacheable       (simpler ordering)
 *
 * Ordering: DSB ISH for IS shmem; DSB SY for NC shmem.
 */

#ifndef SHMEM_MSG_H
#define SHMEM_MSG_H

#include <stdint.h>
#include <core.h> /* provides SHMEM_BASE default (0UL) if not in CPPFLAGS */

/* ── SHMEM_BASE must be set at build time ────────────────────────────────── */
/* core.h falls back to 0UL when the build did not pass SHMEM_BASE=... . A    */
/* zero base would place the shmem_msg_t and the VM2 log ring at IPA 0, which */
/* dereferences to NULL on the first access. Catch that at compile time.      */
_Static_assert(SHMEM_BASE != 0UL, "SHMEM_BASE must be set at build time (e.g. SHMEM_BASE=0xc0000000)");

/* ── Stats print cadence (shared by VM1 and VM2) ─────────────────────────── */
/* Number of samples between each min/max/avg summary line. Kept identical   */
/* for VM2 (ILC) and VM1 (IPI) so their stats print in sync.                 */
#ifndef ILC_STAT_INTERVAL
#define ILC_STAT_INTERVAL 5U /* VM2: every N ILC samples */
#endif
#ifndef IPI_STAT_INTERVAL
#define IPI_STAT_INTERVAL 5U /* VM1: every N IPI samples */
#endif

/* ── Shared message layout (at SHMEM_BASE) ──────────────────────────────── */

typedef struct {
    volatile uint32_t seq; /* sequence number, incremented by VM2 */
    volatile uint32_t latency_cycles; /* raw ILC cycle count */
    volatile uint32_t latency_ns; /* latency in nanoseconds */
    volatile uint64_t ipi_send_ticks; /* CNTVCT_EL0 sampled by VM2 just before notify */
    volatile uint32_t ready; /* 1 = VM2 wrote data; VM1 clears after reading */
} shmem_msg_t;

#define SHMEM_MSG ((shmem_msg_t *)(uintptr_t)SHMEM_BASE)

/* ── Shmem cacheability selection ───────────────────────────────────────── */
/* SHMEM_IS=1 → Inner Shareable WB (hardware coherent, lower IPI latency)   */
/* SHMEM_IS=0 → Non-Cacheable (simpler, no coherency dependency)            */
/* Default: SHMEM_IS=1. Override at build time: make ... SHMEM_IS=0         */
#ifndef SHMEM_IS
#define SHMEM_IS 1
#endif

/* ── Memory barriers ─────────────────────────────────────────────────────── */

static inline void __dsb_sy(void)
{
#if SHMEM_IS
    __asm__ volatile("dsb ish" ::: "memory"); /* Inner Shareable shmem */
#else
    __asm__ volatile("dsb sy" ::: "memory"); /* Non-Cacheable shmem */
#endif
}

static inline uint64_t read_cntvct(void)
{
    uint64_t val;
    __asm__ volatile("mrs %0, cntvct_el0" : "=r"(val));
    return val;
}

/* ── Bao IPC hypercall ───────────────────────────────────────────────────── */
/*
 * FID = 0xC6000001
 *   Bit 31    = 1    → SMC64 (64-bit calling convention)
 *   Bits 29-24= 0x06 → Vendor Hypervisor Service (OEM range)
 *   Bits 15-0 = 0x01 → HC_IPC (Bao inter-partition communication)
 *
 * Note: this uses the SMCC64 variant (0xC6000000 base).  The generic
 * bao_hypercall() in src/arch/armv8/inc/arch/hypercall.h uses the
 * SMCC32 base (0x86000000) for YIELD/CACHE_FLUSH.  IPC is a separate
 * hypercall path in Bao with its own 64-bit FID — keep them distinct.
 *
 * If you update the Bao hypervisor version, verify this FID against
 * Bao's src/core/ipc.c hypercall dispatch table.
 *
 * x0=FID, x1=ipc_id, x2=event_id
 */
#define BAO_HC_IPC_FID 0xC6000001UL

static inline void bao_ipc_notify(unsigned long ipc_id, unsigned long event_id)
{
    register unsigned long x0 asm("x0") = BAO_HC_IPC_FID;
    register unsigned long x1 asm("x1") = ipc_id;
    register unsigned long x2 asm("x2") = event_id;
    __asm__ volatile("hvc #0" : "+r"(x0) : "r"(x1), "r"(x2) : "memory");
}

/** Notify the peer VM via Bao IPC (ipc_id/event_id 0). With the worker/printer
 *  split this is called by VM2 to wake VM1; Bao injects VM1's ipc.interrupts[0]
 *  (SGI 2). The hypercall args are symmetric, so the helper is direction-agnostic
 *  — it always notifies the other VM(s) sharing shmem_id 0. */
static inline void ipi_notify(void)
{
    bao_ipc_notify(0UL, 0UL);
}

/* ── VM2 → VM1 log ring ───────────────────────────────────────────────────── */
/*
 * VM2 has no direct UART access. Log strings are written into a small SPSC
 * ring buffer placed one cache line past shmem_msg_t in the shmem region.
 * VM1 drains the ring from its main loop and prints each entry directly to its
 * owned UART0. The prefix "[VM2] " is embedded by VM2 in each string.
 *
 * Write protocol (VM2 producer):
 *   1. Check slots[head].len == 0 (empty slot). If non-zero, ring full → drop.
 *   2. Copy string bytes into slots[head].data[].
 *   3. DSB ISH (ensure data visible before len).
 *   4. Set slots[head].len = length (non-zero = published/ready).
 *   5. Advance head = (head + 1) & (VM2_LOG_SLOTS - 1).
 *
 * Read protocol (VM1 consumer):
 *   1. Poll slots[tail].len != 0.
 *   2. DMB ISHLD (acquire: data[] visible after len).
 *   3. Read slots[tail].data[0..len-1] and print.
 *   4. Clear slots[tail].len = 0 (release slot).
 *   5. DMB ISH (release: clear visible before tail advance).
 *   6. Advance tail = (tail + 1) & (VM2_LOG_SLOTS - 1).
 */

#define VM2_LOG_SLOTS 8U /* ring depth */
#define VM2_LOG_SLOT_SZ 256U /* max bytes per entry (including '\n' + '\0') */
#define VM2_LOG_OFFSET 64U /* byte offset from SHMEM_BASE (one cache line past shmem_msg_t) */

typedef struct {
    char data[VM2_LOG_SLOT_SZ];
    volatile uint8_t len; /* 0 = empty; >0 = length, slot is ready to read */
    uint8_t _pad[3]; /* 4-byte alignment */
} vm2_log_slot_t; /* 260 bytes (256 data + 1 len + 3 pad) */

typedef struct {
    volatile uint8_t head; /* VM2 next-write index (owned by VM2) */
    volatile uint8_t tail; /* VM1 next-read  index (owned by VM1) */
    uint8_t _pad[2];
    volatile uint32_t dropped; /* VM2 increments on ring-full; VM1 reads to warn */
    vm2_log_slot_t slots[VM2_LOG_SLOTS];
} vm2_log_ring_t;

#define VM2_LOG ((vm2_log_ring_t *)((uintptr_t)SHMEM_BASE + VM2_LOG_OFFSET))

#endif /* SHMEM_MSG_H */
