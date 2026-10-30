/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#include <core.h>
#include <plat.h>

MEMORY
{
  RO_MEM : ORIGIN = RO_MEM_BASE, LENGTH = RO_MEM_SIZE
  RW_MEM : ORIGIN = RW_MEM_BASE, LENGTH = RW_MEM_SIZE
}

ENTRY(_start)

SECTIONS {

    .start : {
        *(.start*)
    } > RO_MEM

    .text :  {
        *(.text*)
    } > RO_MEM

    .const : {
        *(.const*)
        *(.rodata*)
    } > RO_MEM

    /* .data initial contents stored in RO_MEM must be copied to RW_MEM */
    .data : ALIGN(8) {
        __data_start = .;
        *(.data .data.*)
        PROVIDE(__global_pointer$ = . + 0x800);
        __gp = . + 0x800;
        *(.sdata .sdata.* .sdata2.*)
        __data_end = .;
    } > RW_MEM AT > RO_MEM

    /* LMA (RO_MEM) for startup copy */
    __data_load_start = LOADADDR(.data);
    __data_load_end   = LOADADDR(.data) + SIZEOF(.data);

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss* .sbss*)
        *(COMMON)
        __bss_end = .;
    } > RW_MEM

    .stackheap (NOLOAD) : ALIGN(16) {
        PROVIDE(_stack_base = .);
        . = . + STACKHEAP_SIZE;
        PROVIDE(_heap_base = .);
        PROVIDE(__heap_base = .); /* needed for RH850 */
    } > RW_MEM
}
