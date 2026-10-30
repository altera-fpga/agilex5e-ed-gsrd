/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#include <sysregs.h>
#include <plat.h>

#define STACK_SIZE  0x1000

#define GENERIC_TIMER_CNTCTL_CNTCR_EN   (0x1)
#define GENERIC_TIMER_CNTCTL_CNTCR_OFFSET  (0x0)
#define GENERIC_TIMER_CNTCTL_CNTDIF0_OFFSET  (0x20)

.extern plat_mpu_regs
.extern plat_mpu_num_regs
.weak plat_early_init

.section .start, "ax"
.global _start
_start:

    mrs r0, cpsr
    and r1, r0, #CPSR_M_MSK
    cmp r1, #CPSR_M_HYP
    beq 1f
    cps #MODE_SVC
    b entry_el1
1:
    /* This is a weak symbol needed for early platform initialization routines when the baremetal
       guest is used standalone. If not defined, the compiler replaces the branch with a NOP */
    bl plat_early_init

#if GIC_VERSION == GICV3
    mrc p15, 4, r0, c12, c9, 5 // icc_hsre
    orr r0, r0, #0x9
    mcr p15, 4, r0, c12, c9, 5 // icc_hsre
#endif

#if defined(MPU)
#if defined(PLAT_GENERIC_TIMER_FIXED_FREQ)
    ldr r1, =PLAT_GENERIC_TIMER_FIXED_FREQ
#elif defined(PLAT_GENERIC_TIMER_CNTCTL_BASE)
    ldr r0, =PLAT_GENERIC_TIMER_CNTCTL_BASE
    ldr r1, [r0, #GENERIC_TIMER_CNTCTL_CNTCR_OFFSET]
    orr r1, r1, #GENERIC_TIMER_CNTCTL_CNTCR_EN
    str r1, [r0, #GENERIC_TIMER_CNTCTL_CNTCR_OFFSET]
    ldr r1, [r0, #GENERIC_TIMER_CNTCTL_CNTDIF0_OFFSET]
#else
    #error "No generic timer frequency source defined"
#endif
    mcr p15, 0, r1, c14, c0, 0 // cntfrq
#endif  /* defined(MPU) */

    mrs r0, cpsr
    mov r1, #MODE_SVC
    bfi r0, r1, #0, #5
    msr spsr_hyp, r0
    ldr r0, =entry_el1
    msr elr_hyp, r0
    dsb
    isb
    eret

entry_el1:
    mrc p15, 0, r0, c0, c0, 5 // mpidr
    and r0, r0, #MPIDR_CPU_MASK

    ldr r1, =_exception_vector
    mcr	p15, 0, r1, c12, c0, 0 // vbar

    // Enable floating point
    mov r1, #(0xf << 20)
    mcr p15, 0, r1, c1, c0, 2 // cpacr
    isb
    mov r1, #(0x1 << 30)
    vmsr fpexc, r1

    // TODO: invalidate caches, bp, etc...

    ldr r4, =MAIR_EL1_DFLT
    mcr p15, 0, r4, c10, c2, 0 // mair

#ifdef MPU

    // Program MPU regions from the platform descriptor array.
    ldr r5, =plat_mpu_regs
    ldr r6, =plat_mpu_num_regs
    ldr r6, [r6]

    mov r7, #0
1:
    cmp r7, r6
    bge 2f

    mcr p15, 0, r7, c6, c2, 1  // prselr

    add r8, r5, r7, lsl #3     // sizeof(struct mpu_region) = 8 bytes
    ldr r1, [r8]               // prbar
    mcr p15, 0, r1, c6, c3, 0  // prbar

    ldr r1, [r8, #4]           // prlar
    mcr p15, 0, r1, c6, c3, 1  // prlar

    add r7, r7, #1
    b 1b
2:
    dsb
    isb

    ldr r1, =(SCTLR_RES1 | SCTLR_C | SCTLR_I | SCTLR_BR | SCTLR_M)
    mcr p15, 0, r1, c1, c0, 0 // sctlr

#else

    ldr r1, =0x55555555
    mcr p15, 0, r1, c3, c0, 0 // dacr

    mov r1, #0
    mcr p15, 0, r1, c2, c0, 2 // ttbcr

    ldr r1, =page_table
    ldr r2, =(TTBR_IRGN1 | TTBR_RGN_0 | TTBR_S | TTBR_NOS)
    orr r1, r1, r2
    mcr p15, 0, r1, c2, c0, 0 // ttbr0

    dsb
    isb

    ldr r1, =(SCTLR_AFE | SCTLR_C | SCTLR_I | SCTLR_M)
    mcr p15, 0, r1, c1, c0, 0 // sctlr

    dsb
    isb

#endif

    dsb	nsh
    isb

    cmp r0, #0
    bne 1f

#ifdef MEM_NON_UNIFIED
    /* Copy data from RX to RWX */
    ldr r7,  =__data_load_start         // LMA start
    ldr r11, =__data_start              // VMA start
    ldr r12, =__data_load_end           // LMA end

    bl  copy_data
#endif

    ldr r11, =__bss_start
    ldr r12, =__bss_end
    bl  clear

    .pushsection .data
    .balign 4
wait_flag:
    .word 0x0
    .popsection

    ldr r1, =wait_flag
    mov r2, #1
    str r2, [r1]
1:
    ldr r1, =wait_flag
    ldr r2, [r1]
    cmp r2, #0
    beq 1b

    ldr r1, =_stack_base
    ldr r2, =STACK_SIZE
    add r3, r2, r2 // r3 = 2 * STACK_SIZE
#ifndef SINGLE_CORE
    mul r4, r3, r0 // r4 = cpuid * (2*STACK_SIZE)
    add r1, r1, r4
#endif
    add sp, r1, r2
    cps #MODE_IRQ
    isb
    add sp, r1, r3
    cps #MODE_SVC
    isb

    // TODO: other c runtime init (eg ctors)

    bl _init
    b _exit

.global psci_wake_up
psci_wake_up:
    b .

.func clear
clear:
    mov r10, #0
2:
    cmp r11, r12
    bge 1f
    str r10, [r11]
    add r11, r11, #4
    b   2b
1:
    bx lr
.endfunc

/* Copies data from r7 to r11 up to the r12 limit */
.global copy_data
copy_data:
1:
    ldr r8, [r7], #4
    str r8, [r11], #4
    cmp r7, r12
    bne 1b
    bx lr
