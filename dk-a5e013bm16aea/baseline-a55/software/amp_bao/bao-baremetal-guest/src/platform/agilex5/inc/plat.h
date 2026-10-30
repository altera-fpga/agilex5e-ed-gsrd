/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 *
 * plat.h — Intel Agilex5 SoCFPGA platform constants
 */
#ifndef PLAT_H
#define PLAT_H

#define PLAT_MEM_BASE 0x82000000
#define PLAT_MEM_SIZE 0x04000000 /* 64 MB — covers binary + raw-ptr working sets */

#define PLAT_GICD_BASE_ADDR (0x1D000000)
#define PLAT_GICC_BASE_ADDR (0x1D000000) /* unused for GICv3 */
#define PLAT_GICR_BASE_ADDR (0x1D060000)

#define PLAT_UART_ADDR 0x10c02000
#define UART_IRQ_ID 140

/* 16550 / DW-APB-UART access shape on Agilex5:
 *   MMIO byte offset = (register_index << PLAT_UART_REG_SHIFT)
 *   Accesses use PLAT_UART_REG_WIDTH-byte loads/stores.
 * Override per-platform by re-defining these in the platform plat.h. */
#define PLAT_UART_REG_SHIFT 2U
#define PLAT_UART_REG_WIDTH 4U

/* TX FIFO depth (bytes). On Agilex5 DW-APB-UART the TX FIFO is 64 bytes.
 * Used by the THRE ISR to batch-push after an LSR.THRE assertion without
 * re-reading LSR per byte. Safe upper bound per 16550A spec when the
 * TX-empty trigger (FCR.TET) is 0 (default) — THRE asserts only when
 * the FIFO is fully empty, so FIFO_DEPTH bytes may always be written. */
#define PLAT_UART_TX_FIFO_DEPTH 64U

/* CNTVCT_EL0 / generic-timer frequency.
 * ATF/U-Boot programs CNTFRQ_EL0 to 400 MHz on Agilex5.  If the timer
 * frequency is changed in the bitstream, update this constant to match.
 * Drivers that need a compile-time tick frequency use this rather than
 * the runtime TIMER_FREQ variable (which is valid only after arch_init). */
#define PLAT_CNTVCT_FREQ_HZ 400000000ULL

/* ── ILC / Interval Timer (LWH2F bridge) ────────────────────────────────── */

#define ILC_INTID 50 /* F2H IRQ1 → GICv3 SPI 50 */

#define ITIMER_BASE 0x20000000UL
#define ILC_BASE 0x20000100UL
#define ILC_FREQ_HZ 100000000UL /* 100 MHz */

#endif
