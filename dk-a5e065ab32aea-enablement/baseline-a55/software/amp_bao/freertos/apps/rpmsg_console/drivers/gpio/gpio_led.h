/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * gpio_led.h -- LED toggle helper for Agilex5 FreeRTOS-on-Bao guest.
 *
 * Uses direct MMIO via volatile uint32_t*.  Does NOT include
 * socfpga_gpio.h / osal.h to keep the include chain clean for files
 * that include this header (main.c, ilc_latency.c) before their own
 * FreeRTOS headers.
 *
 * GPIO register constants are taken from the freertos-socfpga HAL
 * (socfpga_gpio.h / socfpga_gpio_reg.h) -- values must match.
 *
 * LED pin assignments per board variant:
 *
 *   GPIO_LED_BOARD_A5_PREMIUM_DEVKIT  -- Agilex5 Premium Devkit
 *     hps_led0 = GPIO0 porta bit 11
 *     (DTS: <&porta 11 GPIO_ACTIVE_HIGH> in socfpga_agilex5_socdk.dts)
 *
 *   GPIO_LED_BOARD_A5_E_SERIES_013B   -- Agilex5 E-Series 013B
 *     hps_led0 = GPIO0 porta bit 0
 *     hps_led1 = GPIO0 porta bit 11
 */

#ifndef GPIO_LED_H
#define GPIO_LED_H

#include <stdint.h>

/* ------------------------------------------------------------------ */
/*  Board variant selection -- edit GPIO_LED_BOARD to switch boards.  */
/* ------------------------------------------------------------------ */

#define GPIO_LED_BOARD_A5_PREMIUM_DEVKIT 1
#define GPIO_LED_BOARD_A5_E_SERIES_013B 2

#ifndef GPIO_LED_BOARD
#define GPIO_LED_BOARD GPIO_LED_BOARD_A5_PREMIUM_DEVKIT
#endif

/* ------------------------------------------------------------------ */
/*  GPIO peripheral base addresses (from freertos-socfpga socfpga_gpio.h) */
/* ------------------------------------------------------------------ */

/* GPIO0 DesignWare APB GPIO -- porta at PA 0x10C03000 + 0x200 */
#define GPIO0_BASE_ADDR (0x10C03200UL)
/* GPIO1 DesignWare APB GPIO -- portb at PA 0x10C03000 + 0x300 */
#define GPIO1_BASE_ADDR (0x10C03300UL)

/* GPIO data-output register (porta) */
#define GPIO_SWPORTA_DR (0x000U)
/* GPIO data-direction register (porta, 1 = output) */
#define GPIO_SWPORTA_DDR (0x004U)

/* Reset Manager PER1MODRST register -- bits 24 (GPIO0) and 25 (GPIO1) */
#define RSTMGR_BASE (0x10D11000UL)
#define RSTMGR_PER1MODRST (0x028U)

/* ------------------------------------------------------------------ */

#if GPIO_LED_BOARD == GPIO_LED_BOARD_A5_PREMIUM_DEVKIT

#define LED0_BASE GPIO0_BASE_ADDR /* 0x10C03200 -- GPIO0 porta */
#define LED0_PIN (11U) /* porta bit 11 -> hps_led0 */
#define LED1_ENABLED (0)

#elif GPIO_LED_BOARD == GPIO_LED_BOARD_A5_E_SERIES_013B

#define LED0_BASE GPIO0_BASE_ADDR /* 0x10C03200 */
#define LED0_PIN (0U) /* porta bit 0  -> hps_led0 */
#define LED1_ENABLED (1)
#define LED1_BASE GPIO0_BASE_ADDR
#define LED1_PIN (11U) /* porta bit 11 -> hps_led1 */

#else
#error "Unsupported GPIO_LED_BOARD -- use GPIO_LED_BOARD_A5_PREMIUM_DEVKIT or GPIO_LED_BOARD_A5_E_SERIES_013B"
#endif

/* ------------------------------------------------------------------ */

/**
 * gpio_led_init() -- Deassert GPIO0 reset and configure LED pin(s) as
 * push-pull outputs (initial state OFF).  Safe to call from
 * prvSetupHardware() before vTaskStartScheduler().
 */
void gpio_led_init(void);

/**
 * gpio_led_toggle() -- Invert the current state of all LED pin(s).
 * Safe to call from task context.
 */
void gpio_led_toggle(void);

/**
 * gpio_led_set() -- Drive all LED pin(s) to an explicit level.
 * @param on  1 = ON, 0 = OFF.
 */
void gpio_led_set(uint32_t on);

#endif /* GPIO_LED_H */
