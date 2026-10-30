/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/*
 * vectors.S — AArch64 exception vectors (Agilex5 standalone EL2 / EL1-capable).
 *
 * IRQ/FIQ entry matches Bao baremetal guest src/arch/armv8/aarch64/exceptions.S:
 *   SAVE_REGS → BL gic_handle → RESTORE_REGS → ERET
 *
 * ICC_IAR1_EL1 read + ICC_EOIR1_EL1 write live in gic_handle.c (same layering as
 * Bao src/arch/armv8/gicv3.c), not in assembly — apples-to-apples with VM1 guest.
 */

#define ENTRY_SIZE (0x80)

.macro SAVE_REGS
    sub sp, sp, #(22 * 8)
    stp x0, x1,   [sp, #(8*0)]
    stp x2, x3,   [sp, #(8*2)]
    stp x4, x5,   [sp, #(8*4)]
    stp x6, x7,   [sp, #(8*6)]
    stp x8, x9,   [sp, #(8*8)]
    stp x10, x11, [sp, #(8*10)]
    stp x12, x13, [sp, #(8*12)]
    stp x14, x15, [sp, #(8*14)]
    stp x16, x17, [sp, #(8*16)]
    stp x18, x19, [sp, #(8*18)]
    stp x29, x30, [sp, #(8*20)]
.endm

.macro RESTORE_REGS
    ldp x0, x1,   [sp, #(8*0)]
    ldp x2, x3,   [sp, #(8*2)]
    ldp x4, x5,   [sp, #(8*4)]
    ldp x6, x7,   [sp, #(8*6)]
    ldp x8, x9,   [sp, #(8*8)]
    ldp x10, x11, [sp, #(8*10)]
    ldp x12, x13, [sp, #(8*12)]
    ldp x14, x15, [sp, #(8*14)]
    ldp x16, x17, [sp, #(8*16)]
    ldp x18, x19, [sp, #(8*18)]
    ldp x29, x30, [sp, #(8*20)]
    add sp, sp, #(22 * 8)
.endm

.section ".text.vectors", "ax"
.balign 2048

.global vector_table
.global _exception_vector
_exception_vector:
vector_table:
 
/* ── Current EL with SP_EL0 (unused) ────────────────────────────────────── */
.balign 128
_sp_el0_sync:    b _unhandled_exception
.balign 128
_sp_el0_irq:     b _unhandled_exception
.balign 128
_sp_el0_fiq:     b _unhandled_exception
.balign 128
_sp_el0_serror:  b _unhandled_exception
 
/* ── Current EL with SP_ELx — our execution path (EL2 or EL1) ───────────── */
.balign 128
_sp_elx_sync:
    b _sync_handler
 
.balign 128
_sp_elx_irq:
    SAVE_REGS
    bl   gic_handle
    RESTORE_REGS
    eret

.balign 128
_sp_elx_fiq:
    SAVE_REGS
    bl   gic_handle
    RESTORE_REGS
    eret
.balign 128
_sp_elx_serror:  b _unhandled_exception
 
/* ── Lower EL AArch64 (not used) ─────────────────────────────────────────── */
.balign 128
_lower_el64_sync:   b _unhandled_exception
.balign 128
_lower_el64_irq:    b _unhandled_exception
.balign 128
_lower_el64_fiq:    b _unhandled_exception
.balign 128
_lower_el64_serror: b _unhandled_exception
 
/* ── Lower EL AArch32 (not used) ─────────────────────────────────────────── */
.balign 128
_lower_el32_sync:   b _unhandled_exception
.balign 128
_lower_el32_irq:    b _unhandled_exception
.balign 128
_lower_el32_fiq:    b _unhandled_exception
.balign 128
_lower_el32_serror: b _unhandled_exception
 
/* ── Sync exception handler ──────────────────────────────────────────────── */
.balign 4
_sync_handler:
    /*
     * Read the EL-appropriate syndrome registers for debugging.
     * At EL1: esr_el1 / elr_el1 / far_el1.
     * At EL2: esr_el2 / elr_el2 / far_el2.
     * Reading the wrong EL's registers produces garbage — fix that here.
     */
    mrs  x3, CurrentEL
    lsr  x3, x3, #2
    cmp  x3, #2
    bne  _sync_at_el1

_sync_at_el2:
    mrs  x0, esr_el2
    mrs  x1, elr_el2
    mrs  x2, far_el2
    b    _unhandled_exception

_sync_at_el1:
    mrs  x0, esr_el1
    mrs  x1, elr_el1
    mrs  x2, far_el1
    /* fall through to spin */
 
.balign 4
_unhandled_exception:
    wfi
    b    _unhandled_exception
 
/* ═══════════════════════════════════════════════════════════════════════════
 * Startup — entered at EL2 from U-Boot 'go', or at EL1 from Bao
 * ═══════════════════════════════════════════════════════════════════════════ */
 
.section ".text.startup", "ax"
.balign 4
.global _start
_start:
    /*
     * Detect current EL.
     * CurrentEL[3:2] = EL number.
     * EL2 → U-Boot bare-metal path.
     * EL1 → Bao guest path.
     */
    mrs  x0, CurrentEL
    lsr  x0, x0, #2
    cmp  x0, #2
    bne  _at_el1
 
    /* ── EL2 path: U-Boot 'go' direct boot ─────────────────────────────── */
 
    /*
     * 1. Install vector table at EL2.
     *    IRQs at EL2 use VBAR_EL2 + offset 0x280 (_sp_elx_irq).
     */
    adr  x0, vector_table
    msr  vbar_el2, x0
    isb
 
    /*
     * 2. ICC_SRE_EL2 = 0xF
     *    bit0 SRE    = 1 — use system registers for GIC CPU interface
     *    bit1 DFB    = 1 — disable FIQ bypass
     *    bit2 DIB    = 1 — disable IRQ bypass
     *    bit3 Enable = 1 — allow EL1 to access ICC_SRE_EL1
     */
    mrs  x0, S3_4_C12_C9_5      /* ICC_SRE_EL2 */
    orr  x0, x0, #0xF
    msr  S3_4_C12_C9_5, x0
    isb
 
    /*
     * 3. ICC_SRE_EL1 = 0x7
     *    Set SRE at EL1 for completeness (accessible from EL2).
     */
    mrs  x0, S3_0_C12_C12_5     /* ICC_SRE_EL1 */
    orr  x0, x0, #0x7
    msr  S3_0_C12_C12_5, x0
    isb
 
    /*
     * 4. HCR_EL2
     *    RW  (bit31) = 1 — EL1 is AArch64
     *    IMO (bit4)  = 1 — physical IRQs routed to EL2
     */
    mrs  x0, hcr_el2
    orr  x0, x0, #(1 << 31)
    orr  x0, x0, #(1 << 4)
    msr  hcr_el2, x0

    /*
     * 5. Invalidate I-cache and TLBs at EL2 before entering C code.
     *    U-Boot leaves I-cache enabled; make sure stale entries from a
     *    previous boot don't pollute the first fetch after VBAR_EL2 is set.
     *    D-cache is NOT enabled here because EL2 has no page tables
     *    (SCTLR_EL2.M=0).  Without a valid Stage-1 MMU at EL2, enabling
     *    the D-cache (SCTLR_EL2.C) produces CONSTRAINED UNPREDICTABLE
     *    behaviour on systems that require a translation table walk.
     *    See README.md for the EL1/EL2 cache asymmetry discussion.
     */
    ic   ialluis          /* invalidate I-cache inner shareable */
    tlbi alle2is          /* invalidate all EL2 TLB entries     */
    dsb  ish
    isb

    /* 6. Enable I-cache at EL2 (SCTLR_EL2.I = bit 12). */
    mrs  x0, sctlr_el2
    orr  x0, x0, #(1 << 12)
    msr  sctlr_el2, x0
    isb

    /* Join common init (stack, BSS, main) */
    b    _common_init


    /* ── EL1 path: Bao guest entry ──────────────────────────────────────── */
_at_el1:
    /*
     * 1. Install vector table at EL1.
     *    Bao vGIC delivers IRQs to EL1 SP_ELx slot (offset 0x280).
     *    Same _sp_elx_irq handler used — ICC_IAR1_EL1 is valid at EL1.
     */
    adr  x0, vector_table
    msr  vbar_el1, x0
    isb
 
     /* Enable dcache + icache at EL1 */
    mrs  x0, sctlr_el1
    orr  x0, x0, #(1 << 2)    /* C  — dcache */
    orr  x0, x0, #(1 << 12)   /* I  — icache */
    msr  sctlr_el1, x0
    isb
    
    /*
     * 2. Unmask IRQs at EL1.
     *    Bao enters with DAIF.I masked — clear it to allow IRQ delivery.
     *    daifclr bit1 = IRQ mask clear.
     */
    msr  daifclr, #0x2
    isb
 
    /* Fall through to _common_init */
 
    /* ── Common init: stack, BSS, C entry ──────────────────────────────── */
_common_init:
    /*
     * Enable FP/SIMD at EL1 (CPACR_EL1.FPEN = 0b11).
     * Our C code is compiled with -mgeneral-regs-only so it never generates
     * NEON/FP instructions; however -lgcc routines may use them on some
     * toolchain versions.  Setting FPEN prevents a silent EL1 trap if a
     * libgcc helper touches the FP register file.
     */
    mrs  x0, cpacr_el1
    orr  x0, x0, #(3 << 20)
    msr  cpacr_el1, x0
    isb

    /*
     * Set up stack pointer.
     * __stack_top is defined by the linker script.
     */
    adr  x0, __stack_top
    mov  sp, x0
 
    /*
     * Clear BSS section.
     */
    adr  x0, __bss_start
    adr  x1, __bss_end
    cmp  x0, x1
    b.ge _bss_done
_bss_loop:
    str  xzr, [x0], #8
    cmp  x0, x1
    b.lt _bss_loop
_bss_done:
 
    /*
     * Jump to C entry point.
     * main() should never return.
     */
    bl   main
    b    _unhandled_exception
 
.global __stack_top