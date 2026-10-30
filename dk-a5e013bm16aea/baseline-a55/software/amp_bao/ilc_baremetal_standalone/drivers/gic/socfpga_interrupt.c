/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/*
 * socfpga_interrupt.c — GIC init + legacy interrupt_register_isr() shim.
 *
 * IRQ dispatch path matches Bao baremetal guest:
 *   vectors.S → gic_handle() → irq_early_hook → irq_handle → handler(id)
 *
 * The old interrupt_irq_handler() single-file dispatch has been removed so the
 * standalone stack mirrors Bao's split between arch (gic_handle) and core (irq).
 */

#include <stddef.h>
#include <stdint.h>
#include "socfpga_interrupt.h"
#include "socfpga_gic.h"
#include "socfpga_gic_reg.h"
#include "../../irq.h"

/* GICD_CTLR bit definitions (GICv3, single-security state via DS=1) */
#define GICD_CTLR_ENG0 (1U << 0U) /* Enable Grp0 forwarding to CPU  */
#define GICD_CTLR_ENG1NS (1U << 1U) /* Enable Grp1 Non-Secure         */
#define GICD_CTLR_ARE_S (1U << 4U) /* Affinity Routing Enable (Sec)  */
#define GICD_CTLR_DS (1U << 6U) /* Disable Security (1-world)     */

#define SOCFPGA_PPI_START 22
#define SOCFPGA_MAX_PPI 30
#define SOCFPGA_SPI_START SDM_APS_MAILBOX_INTR /* = 32 */
#define SOCFPGA_MAX_SPI MAX_HPU_SPI_INTERRUPT

static uint32_t gic_redis_id;

typedef struct {
    socfpga_interrupt_callback_t cb;
    void *data;
} legacy_slot_t;

static legacy_slot_t legacy_isr[MAX_SPI_HPU_INTERRUPT];

static void legacy_dispatch(unsigned id)
{
    if (id < MAX_SPI_HPU_INTERRUPT && legacy_isr[id].cb != NULL) {
        legacy_isr[id].cb(legacy_isr[id].data);
    }
}

void interrupt_init_gic(void)
{
    for (unsigned i = 0U; i < MAX_SPI_HPU_INTERRUPT; i++) {
        legacy_isr[i].cb = NULL;
        legacy_isr[i].data = NULL;
    }

    uint64_t el;
    __asm__ volatile("mrs %0, CurrentEL" : "=r"(el));
    el >>= 2;

    if (el == 1U) {
        extern void gic_init_pointers_only(void);
        gic_init_pointers_only();

        gic_redis_id = 0U;
        gic_reg_set_priority_mask(0xFF);
        gic_reg_enable_group1_interrupts();

        volatile uint32_t *gicd_ctlr = (volatile uint32_t *)REGISTER_SOCFPGA_DIST_BASE_ADDR;
        *gicd_ctlr = GICD_CTLR_ARE_S | GICD_CTLR_ENG1NS | GICD_CTLR_ENG0;
        __asm__ volatile("dsb sy" ::: "memory");
        return;
    }

    if (gic_enable_gic() != INTERRUPT_RETURN_SUCCESS) {
        return;
    }

    volatile uint32_t *gicd_ctlr = (volatile uint32_t *)REGISTER_SOCFPGA_DIST_BASE_ADDR;
    *gicd_ctlr = GICD_CTLR_DS | GICD_CTLR_ARE_S | GICD_CTLR_ENG1NS | GICD_CTLR_ENG0;
    __asm__ volatile("dsb sy" ::: "memory");

    volatile uint32_t *gicd_igroupr = (volatile uint32_t *)(REGISTER_SOCFPGA_DIST_BASE_ADDR + 0x084U);
    *gicd_igroupr = 0xFFFFFFFFU;
    __asm__ volatile("dsb sy" ::: "memory");

    volatile uint32_t *gicd_igrpmodr = (volatile uint32_t *)(REGISTER_SOCFPGA_DIST_BASE_ADDR + 0xD04U);
    *gicd_igrpmodr = 0x0U;
    __asm__ volatile("dsb sy" ::: "memory");

    volatile uint64_t *irouter = (volatile uint64_t *)(REGISTER_SOCFPGA_DIST_BASE_ADDR + 0x6000UL);
    irouter[50] = (uint64_t)gic_reg_get_cpu_affinity();
    __asm__ volatile("dsb sy" ::: "memory");

    gic_redis_id = (uint32_t)gic_get_redist_id((uint32_t)gic_reg_get_cpu_affinity());

    if (gic_wakeup_redist(gic_redis_id) != INTERRUPT_RETURN_SUCCESS) {
        return;
    }

    gic_reg_set_priority_mask(0xFF);
    gic_reg_enable_group1_interrupts();
}

socfpga_interrupt_err_t interrupt_ppi_enable(socfpga_hpu_interrupt_t id, socfpga_hpu_interrupt_type_t interrupt_type,
                                             uint8_t priority, uint32_t redis_id)
{
    uint32_t type = GICV3_CONFIG_LEVEL;
    if ((id > PPI_MAX) || (id < PPI_START))
        return ERR_PPI_ID;
    if (interrupt_type == SPI_INTERRUPT_TYPE_EDGE)
        type = GICV3_CONFIG_EDGE;

    if (gic_enable_int((uint32_t)id, redis_id) != INTERRUPT_RETURN_SUCCESS)
        return ERR_PPI_ID;
    if (gic_set_int_group((uint32_t)id, redis_id, GICV3_GROUP1_NON_SECURE) != INTERRUPT_RETURN_SUCCESS)
        return ERR_PPI_ID;
    if (gic_set_int_type((uint32_t)id, 0U, type) != INTERRUPT_RETURN_SUCCESS)
        return ERR_PPI_ID;
    if (gic_set_int_priority((uint32_t)id, redis_id, priority) != INTERRUPT_RETURN_SUCCESS)
        return ERR_PPI_ID;
    return ERR_OK;
}

socfpga_interrupt_err_t interrupt_spi_enable(socfpga_hpu_interrupt_t id, socfpga_hpu_interrupt_type_t interrupt_type,
                                             socfpga_hpu_spi_interrupt_mode_t interrupt_mode, uint8_t priority)
{
    uint32_t mode = GICV3_ROUTE_MODE_ANY;
    uint32_t type = GICV3_CONFIG_LEVEL;

    if ((id >= SOCFPGA_MAX_SPI) || (id < SOCFPGA_SPI_START))
        return ERR_SPI_ID;
    if (interrupt_type == SPI_INTERRUPT_TYPE_EDGE)
        type = GICV3_CONFIG_EDGE;
    if (interrupt_mode == SPI_INTERRUPT_MODE_TARGET)
        mode = GICV3_ROUTE_MODE_COORDINATE;

    if (gic_set_int_priority((uint32_t)id, 0U, priority) != INTERRUPT_RETURN_SUCCESS)
        return ERR_SPI_ID;
    if (gic_set_int_group((uint32_t)id, 0U, GICV3_GROUP1_NON_SECURE) != INTERRUPT_RETURN_SUCCESS)
        return ERR_SPI_ID;
    if (gic_set_int_route((uint32_t)id, mode, (uint32_t)gic_reg_get_cpu_affinity()) != INTERRUPT_RETURN_SUCCESS)
        return ERR_SPI_ID;
    if (gic_set_int_type((uint32_t)id, 0U, type) != INTERRUPT_RETURN_SUCCESS)
        return ERR_SPI_ID;
    if (gic_enable_int((uint32_t)id, 0U) != INTERRUPT_RETURN_SUCCESS)
        return ERR_SPI_ID;
    return ERR_OK;
}

socfpga_interrupt_err_t interrupt_enable(socfpga_hpu_interrupt_t id, uint8_t priority)
{
    if (id < SOCFPGA_SPI_START) {
        uint32_t redis = (uint32_t)gic_get_redist_id((uint32_t)gic_reg_get_cpu_affinity());
        return interrupt_ppi_enable(id, SPI_INTERRUPT_TYPE_LEVEL, priority, redis);
    }
    return interrupt_spi_enable(id, SPI_INTERRUPT_TYPE_LEVEL, SPI_INTERRUPT_MODE_TARGET, priority);
}

socfpga_interrupt_err_t interrupt_spi_disable(socfpga_hpu_interrupt_t id)
{
    if (gic_disable_int((uint32_t)id, 0) != INTERRUPT_RETURN_SUCCESS)
        return ERR_SPI_ID;
    return ERR_OK;
}

socfpga_interrupt_err_t interrupt_register_isr(socfpga_hpu_interrupt_t id, socfpga_interrupt_callback_t callback,
                                               void *user_data)
{
    if (id >= MAX_SPI_HPU_INTERRUPT)
        return ERR_SPI_ID;
    if (callback == (void *)0)
        return ERR_INTERRUPT_CALLBACK;
    legacy_isr[id].cb = callback;
    legacy_isr[id].data = user_data;
    irq_set_handler((unsigned)id, legacy_dispatch);
    return ERR_OK;
}
