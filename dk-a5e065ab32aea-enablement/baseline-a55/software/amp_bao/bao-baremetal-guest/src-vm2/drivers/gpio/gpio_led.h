/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 *
 * gpio_led.h — Minimal GPIO LED driver for Agilex5 bare-metal Bao guest
 *
 * Self-contained (snps,dw-apb-gpio). HW: GPIO0 @ 0x10C03200, GPIO1 @ 0x10C03300.
 * LEDs (E-Series 013B DevKit): hps_led0 = GPIO0 pin 0, hps_led1 = GPIO0 pin 11.
 */

#ifndef GPIO_LED_H
#define GPIO_LED_H

#include <stdint.h>

/* ── Hardware base addresses ─────────────────────────────────────────────── */

#define GPIO0_BASE_ADDR (0x10C03200UL) /* snps,dw-apb-gpio porta */
#define GPIO1_BASE_ADDR (0x10C03300UL) /* snps,dw-apb-gpio portb */

/* ── snps,dw-apb-gpio register offsets ──────────────────────────────────── */

#define GPIO_SWPORTA_DR (0x0000U) /* Port A data register */
#define GPIO_SWPORTA_DDR (0x0004U) /* Port A direction (1=out) */
#define GPIO_EXT_PORTA (0x0050U) /* Port A read-back */

/* ── LED pin assignment (2 LEDs active) ─────────────────────────────────── */

#define LED0_BASE GPIO0_BASE_ADDR
#define LED0_PIN (0U) /* porta bit 0 */

/* #define LED1_ENABLED (1) */
#define LED1_BASE GPIO0_BASE_ADDR
#define LED1_PIN (11U) /* porta bit 11 */

/* ── Public API ──────────────────────────────────────────────────────────── */

/* Configure LED pin(s) as outputs (initial OFF); deasserts GPIO reset.
 * Call once from main() before ilc_init(). */
void gpio_led_init(void);

/* Invert all configured LED pin(s). ISR-safe (RMW on GPIO_SWPORTA_DR). */
void gpio_led_toggle(void);

/* Drive all configured LED pin(s): on=1 ON (active-high), on=0 OFF. */
void gpio_led_set(uint32_t on);

#endif /* GPIO_LED_H */
