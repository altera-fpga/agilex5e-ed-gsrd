/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/**
 * agilex5_amp.ld — Linker script for bare-metal ILC demo on Agilex5
 *
 */

OUTPUT_FORMAT("elf64-littleaarch64")
OUTPUT_ARCH(aarch64)
ENTRY(_start)

MEMORY
{
    /*
     * A55 bare-metal region in DDR.
     * CHANGE these to match your actual AMP DDR partition.
     */
    DRAM (rwx) : ORIGIN = 0xa0000000, LENGTH = 4M

    /*
     * MMIO regions — not allocated by linker but listed so PROVIDE
     * symbols can reference them if needed.
     */
}

/* Stack size: 64 KB */
STACK_SIZE = 64K;

/*
 * Explicit program headers — split code (RX) and data (RW) so the linker
 * does not create a single RWX PT_LOAD segment.  The sections still share
 * the same DRAM region (no MMU enforcement in this bare-metal demo), but
 * the ELF metadata is clean for static-analysis and objdump tools.
 */
PHDRS
{
    text PT_LOAD FLAGS(5);  /* R-X */
    data PT_LOAD FLAGS(6);  /* RW- */
}

SECTIONS
{
    . = ORIGIN(DRAM);

    /* ── Reset / vector entry — must be at load address ── */
    .text.startup : {
        KEEP(*(.text.startup))
    } > DRAM :text

    /* ── Vector table — must be 2KB-aligned ── */
    .text.vectors : ALIGN(2048) {
        KEEP(*(.text.vectors))
    } > DRAM :text

    /* ── Code ── */
    .text : ALIGN(4) {
        *(.text)
        *(.text.*)
    } > DRAM :text

    /* ── Read-only data ── */
    .rodata : ALIGN(8) {
        *(.rodata)
        *(.rodata.*)
    } > DRAM :text

    /* ── Initialised data ── */
    .data : ALIGN(8) {
        *(.data)
        *(.data.*)
    } > DRAM :data

    /* ── BSS — zero-initialised ── */
    . = ALIGN(8);
    __bss_start = .;
    .bss : {
        *(.bss)
        *(.bss.*)
        *(COMMON)
    } > DRAM :data
    . = ALIGN(8);
    __bss_end = .;

    /* ── Stack ── */
    . = ALIGN(16);
    __stack_bottom = .;
    . += STACK_SIZE;
    . = ALIGN(16);
    __stack_top = .;

    /* ── End of image ── */
    __image_end = .;

    /* Discard debug/unwinding sections to keep image small */
    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.ARM.exidx*)
        *(.ARM.extab*)
    }
}
