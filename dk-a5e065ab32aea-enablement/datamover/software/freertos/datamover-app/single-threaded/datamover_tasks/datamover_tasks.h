/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * Header file for Data Mover tasks
 */

#ifndef __DATAMOVER_TASKS_H__
#define __DATAMOVER_TASKS_H__

#include <stdint.h>

#define NUM_BLOCKS 40
#define OCM_SIZE 524288

#define TEN_SECONDS 10

#define READ_TIMER(val) __asm__ volatile("mrs %0, cntvct_el0" : "=r"(val))
#define READ_TIMER_FRQ(val) __asm__ volatile("mrs %0, cntfrq_el0" : "=r"(val))

void f2h_task(uint32_t transaction_seconds);
void f2sdram_task(uint32_t transaction_seconds);
void s2s_dma_task(uint32_t transaction_seconds);
void s2s_task(uint32_t transaction_seconds);

#endif /* __DATAMOVER_TASKS_H__ */
