/**
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 */

#include <core.h>
#include <plat.h>

MEMORY {
    RAM (rwx)    : ORIGIN = MEM_BASE, LENGTH = MEM_SIZE
}

ENTRY(_start)

SECTIONS {

    .start : {
        *(.start)
    }

    .text :  {
        *(.text*)
    }

    .rodata :  {
        *(.rodata*)
    }

    .data : {
        *(.data .data.*)
        PROVIDE(__global_pointer$ = . + 0x800);
        *(.sdata .sdata.* .sdata2.*)
    }

    .bss (NOLOAD) :  {
        __bss_start = .;
        *(.bss* .sbss*)
        *(COMMON)
        __bss_end = .;
    }

    . = ALIGN(16);
    PROVIDE(_stack_base = .);
    . = . + 32K; /* 32K of total stack size */
    PROVIDE(_heap_base = .);
}
