/*
 * SPDX-License-Identifier: Apache-2.0
 * Copyright (c) Bao Project and Contributors. All rights reserved.
 *
 * gpio_led.c — Minimal GPIO LED driver for Agilex5 bare-metal Bao guest
 *
 * Ported from baremetal-alt/drivers/gpio/socfpga_gpio.c (Altera, MIT-0),
 * keeping only output-direction + data-write. Uses the mmio_read32/write32
 * helpers from mmio.h.
 */

#include "gpio_led.h"
#include <plat.h>
#include <mmio.h>

static inline uint64_t gpio_read_cntvct(void)
{
    uint64_t v;
    __asm__ volatile("mrs %0, cntvct_el0" : "=r"(v));
    return v;
}

#define GPIO_RESET_DELAY_US 10U /* > 1 APB cycle at any reasonable clock */

static inline void gpio_delay_us(uint32_t us)
{
    uint64_t start = gpio_read_cntvct();
    /* Use the platform constant for CNTVCT_EL0 frequency (see plat.h). */
    uint64_t target = start + ((PLAT_CNTVCT_FREQ_HZ * (uint64_t)us) / 1000000ULL);
    while (gpio_read_cntvct() < target) { /* spin */
    }
}

/*
 * Agilex5 Reset Manager — deassert GPIO0/GPIO1 reset (PER1MODRST @ base+0x28,
 * active-low: clear the bit to release). GPIO0 = bit 24, GPIO1 = bit 25.
 * Source: u-boot-socfpga reset_manager_soc64.h.
 */
#define RSTMGR_BASE (0x10D11000UL)
#define RSTMGR_PER1MODRST (RSTMGR_BASE + 0x28U) /* 0x10D11028 */
#define GPIO0_RST_BIT (24U)
#define GPIO1_RST_BIT (25U)

static inline void gpio_deassert_reset(void)
{
    uint32_t val = mmio_read32(RSTMGR_PER1MODRST);
    /* Clear bits to release peripherals from reset (active-low) */
    val &= ~((1U << GPIO0_RST_BIT) | (1U << GPIO1_RST_BIT));
    mmio_write32(RSTMGR_PER1MODRST, val);
    __asm__ volatile("dsb sy" ::: "memory");
    /* Deterministic delay via CNTVCT_EL0 (fixed-rate, DVFS-independent). */
    gpio_delay_us(GPIO_RESET_DELAY_US);
}

/* ── Internal helpers ────────────────────────────────────────────────────── */

/* Set/clear bit <pin> of GPIO_SWPORTA_DR at <base>. */
static inline void gpio_set_output_bit(uintptr_t base, uint32_t pin, uint32_t val)
{
    uint32_t dr = mmio_read32(base + GPIO_SWPORTA_DR);
    dr &= ~(1U << pin);
    dr |= (val & 1U) << pin;
    mmio_write32(base + GPIO_SWPORTA_DR, dr);
    __asm__ volatile("dsb sy" ::: "memory");
}

/* Set bit <pin> of GPIO_SWPORTA_DDR to 1 (output). */
static inline void gpio_set_direction_out(uintptr_t base, uint32_t pin)
{
    uint32_t ddr = mmio_read32(base + GPIO_SWPORTA_DDR);
    ddr |= (1U << pin);
    mmio_write32(base + GPIO_SWPORTA_DDR, ddr);
    __asm__ volatile("dsb sy" ::: "memory");
}

/* ── Public API implementation ───────────────────────────────────────────── */

void gpio_led_init(void)
{
    /* Deassert GPIO0 (and GPIO1) reset via Reset Manager.
     * PER1MODRST @ 0x10D11028, active-low: clear bits 24+25. */
    gpio_deassert_reset();

    /* LED0: GPIO0 porta pin 0 (hps_led0) — set as output, initial state OFF */
    gpio_set_direction_out(LED0_BASE, LED0_PIN);
    gpio_set_output_bit(LED0_BASE, LED0_PIN, 0U);

#if LED1_ENABLED
    /* LED1: GPIO0 porta pin 11 (hps_led1) — set as output, initial state OFF */
    gpio_set_direction_out(LED1_BASE, LED1_PIN);
    gpio_set_output_bit(LED1_BASE, LED1_PIN, 0U);
#endif
}

void gpio_led_toggle(void)
{
    /* Read current DR, flip the LED bit(s), write back */
    uint32_t dr = mmio_read32(LED0_BASE + GPIO_SWPORTA_DR);
    dr ^= (1U << LED0_PIN);

#if LED1_ENABLED
    /* LED1 is on the same GPIO0 instance — toggle in the same RMW */
    dr ^= (1U << LED1_PIN);
#endif

    mmio_write32(LED0_BASE + GPIO_SWPORTA_DR, dr);
    __asm__ volatile("dsb sy" ::: "memory");
}

void gpio_led_set(uint32_t on)
{
    gpio_set_output_bit(LED0_BASE, LED0_PIN, on);

#if LED1_ENABLED
    gpio_set_output_bit(LED1_BASE, LED1_PIN, on);
#endif
}
