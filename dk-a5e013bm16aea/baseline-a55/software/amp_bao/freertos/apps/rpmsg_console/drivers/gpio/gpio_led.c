/*
 * SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
 *
 * SPDX-License-Identifier: MIT-0
 *
 * gpio_led.c -- LED toggle helper for Agilex5 FreeRTOS-on-Bao guest.
 *
 * Bao config prerequisites (configs/linux_freertos/config.c):
 *   - 0x10c03000 / 0x1000  -- GPIO0+GPIO1 register page (covers +0x200 and +0x300)
 *   - 0x10d11000 / 0x1000  -- Reset Manager (RSTMGR_PER1MODRST)
 */

#include "gpio_led.h"

/* Toggle state tracked in software (avoids a read-back per toggle). */
static uint32_t s_led_state = 0U;

/* Inline volatile MMIO helpers -- equivalent to RD_REG32/WR_REG32. */
static inline uint32_t mmio_read(uint32_t addr)
{
    return *((volatile uint32_t *)(uintptr_t)addr);
}

static inline void mmio_write(uint32_t addr, uint32_t val)
{
    *((volatile uint32_t *)(uintptr_t)addr) = val;
}

/* Set a single bit in the GPIO SWPORTA_DR register. */
static void gpio_led_set_bit(uint32_t base, uint32_t pin, uint32_t val)
{
    uint32_t reg = mmio_read(base + GPIO_SWPORTA_DR);
    reg &= ~(1U << pin);
    reg |= ((val & 1U) << pin);
    mmio_write(base + GPIO_SWPORTA_DR, reg);
}

void gpio_led_init(void)
{
    /* Deassert GPIO reset: clear bits 24 (GPIO0) and 25 (GPIO1) of PER1MODRST.
     * U-Boot has already brought the GPIO blocks out of reset; this is a
     * safety measure. Clear both so the correct block is definitely active
     * regardless of which LED_BASE is selected at compile time. */
    uint32_t rst = mmio_read(RSTMGR_BASE + RSTMGR_PER1MODRST);
    rst &= ~(1U << 24U); /* bit 24 = GPIO0 */
    rst &= ~(1U << 25U); /* bit 25 = GPIO1 */
    mmio_write(RSTMGR_BASE + RSTMGR_PER1MODRST, rst);

    /* Configure LED pin(s) as output, initial state OFF. */
    uint32_t ddr = mmio_read(LED0_BASE + GPIO_SWPORTA_DDR);
    ddr |= (1U << LED0_PIN);
    mmio_write(LED0_BASE + GPIO_SWPORTA_DDR, ddr);
    gpio_led_set_bit(LED0_BASE, LED0_PIN, 0U);

#if LED1_ENABLED
    ddr = mmio_read(LED1_BASE + GPIO_SWPORTA_DDR);
    ddr |= (1U << LED1_PIN);
    mmio_write(LED1_BASE + GPIO_SWPORTA_DDR, ddr);
    gpio_led_set_bit(LED1_BASE, LED1_PIN, 0U);
#endif

    s_led_state = 0U;
}

void gpio_led_toggle(void)
{
    s_led_state ^= 1U;
    gpio_led_set_bit(LED0_BASE, LED0_PIN, s_led_state);

#if LED1_ENABLED
    gpio_led_set_bit(LED1_BASE, LED1_PIN, s_led_state);
#endif
}

void gpio_led_set(uint32_t on)
{
    s_led_state = (on != 0U) ? 1U : 0U;
    gpio_led_set_bit(LED0_BASE, LED0_PIN, s_led_state);

#if LED1_ENABLED
    gpio_led_set_bit(LED1_BASE, LED1_PIN, s_led_state);
#endif
}
