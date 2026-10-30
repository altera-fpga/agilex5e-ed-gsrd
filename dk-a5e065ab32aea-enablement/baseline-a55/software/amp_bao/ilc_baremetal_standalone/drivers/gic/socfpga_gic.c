/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

/*
 * socfpga_gic.c — GICv3 / GIC-600 driver for Agilex5 SoCFPGA
 */

#include <stdint.h>
#include <string.h>
#include "socfpga_gic_registers.h"
#include "socfpga_gic.h"

#define INTERRUPT_DCTRL_ENG0 (1U << 0U)
#define INTERRUPT_DCTRL_ENG1NS (1U << 1U)
#define INTERRUPT_DCTRL_ENG1S (1U << 2U)
#define INTERRUPT_DCTRL_ARE_S (1U << 4U)
#define INTERRUPT_DCTRL_ARE_NS (1U << 5U)
/*
 * INTERRUPT_DCTRL_DS — Disable Security bit (GICv3 GICD_CTLR[6]).
 *
 * Setting DS=1 puts the GIC into single-security state: all interrupts are
 * treated as Non-Secure Group 1, removing the Secure/Non-Secure distinction.
 * This is correct for Agilex5 when booted in Non-Secure EL2/EL1 (i.e. after
 * ATF hands off to U-Boot without TrustZone secure world).
 *
 * WARNING: if the platform is ever booted with ATF in two-security-state mode
 * (PLAT_TRUSTED_FIRMWARE=y or similar), writing DS=1 from Non-Secure EL2 will
 * be IGNORED or TRAP — verify the security configuration before enabling this.
 */
#define INTERRUPT_DCTRL_DS (1U << 6U)
#define portPRIORITY_SHIFT 4U

#define INTERRUPT_MAKE_PRIORITY(x) (((uint32_t)(x) << portPRIORITY_SHIFT) & 0xFFU)

static struct gic_v3_dist_if *gic_dist = (void *)0;
static struct gic_v3_rdist_if *gic_rdist = (void *)0;
static uint32_t gic_max_rd = 0U;

/* ── EL1 helper: set gic_dist/gic_rdist pointers without HW init ────────── */
/*
 * Under Bao, GICD/GICR MMIO is trap-and-emulate.  We only need the
 * pointers so that gic_enable_int(), gic_set_int_priority(), etc.
 * can do their MMIO writes (which Bao intercepts via vgic emulation).
 * No redistributor walk or GICD_CTLR programming — Bao owns those.
 */
void gic_init_pointers_only(void)
{
    gic_dist = (struct gic_v3_dist_if *)((void *)REGISTER_SOCFPGA_DIST_BASE_ADDR);
    gic_rdist = (struct gic_v3_rdist_if *)((void *)REGISTER_SOCFPGA_RD_BASE_ADDR);
    gic_max_rd = 0U; /* single-PE guest under Bao */
}

/* ── Enable GIC distributor ──────────────────────────────────────────────── */

int32_t gic_enable_gic(void)
{
    uint32_t index = 0U;

    gic_dist = (struct gic_v3_dist_if *)((void *)REGISTER_SOCFPGA_DIST_BASE_ADDR);
    gic_rdist = (struct gic_v3_rdist_if *)((void *)REGISTER_SOCFPGA_RD_BASE_ADDR);

    if (gic_dist == (void *)0) {
        return INTERRUPT_RETURN_ERROR;
    }

    /* Walk redistributors until GICR_TYPER.Last == 1 */
    while ((gic_rdist[index].lpis.GICR_TYPER[0] & (1U << 4U)) == 0U) {
        index++;
    }
    gic_max_rd = index;

    /* Step 1: set ARE bits first (layout changes once ARE==1) */
    gic_dist->GICD_CTLR = INTERRUPT_DCTRL_ARE_S | INTERRUPT_DCTRL_ARE_NS | INTERRUPT_DCTRL_DS;

    /* Step 2: enable all groups */
    gic_dist->GICD_CTLR = INTERRUPT_DCTRL_ENG0 | INTERRUPT_DCTRL_ENG1NS | INTERRUPT_DCTRL_ENG1S |
                          INTERRUPT_DCTRL_ARE_S | INTERRUPT_DCTRL_ARE_NS | INTERRUPT_DCTRL_DS;

    return INTERRUPT_RETURN_SUCCESS;
}

/* ── Find redistributor index for this PE ────────────────────────────────── */

int32_t gic_get_redist_id(uint32_t affinity)
{
    int32_t index = 0;

    if (gic_rdist == (void *)0) {
        return INTERRUPT_RETURN_ERROR;
    }

    do {
        if (gic_rdist[index].lpis.GICR_TYPER[1] == affinity) {
            return index;
        }
        index++;
    } while ((uint32_t)index <= gic_max_rd);

    return INTERRUPT_RETURN_SUCCESS;
}

/* ── Wake redistributor for this PE ─────────────────────────────────────── */

int32_t gic_wakeup_redist(uint32_t rd)
{
    uint32_t tmp;

    if (gic_rdist == (void *)0) {
        return INTERRUPT_RETURN_ERROR;
    }

    tmp = gic_rdist[rd].lpis.GICR_WAKER;
    tmp &= ~0x2U; /* clear ProcessorSleep */
    gic_rdist[rd].lpis.GICR_WAKER = tmp;

    /* Poll until ChildrenAsleep clears */
    do {
        tmp = gic_rdist[rd].lpis.GICR_WAKER;
    } while ((tmp & 0x4U) != 0U);

    return INTERRUPT_RETURN_SUCCESS;
}

/* ── Helpers ─────────────────────────────────────────────────────────────── */

static uint32_t gic_is_valid_ext_spi(uint32_t id)
{
    uint32_t max_spi;
    if (((gic_dist->GICD_TYPER >> 8U) & 0x1U) == 0U) {
        return 0U;
    }
    max_spi = ((gic_dist->GICD_TYPER >> 27U) & 0x1FU);
    max_spi = (max_spi + 1U) * 32U;
    max_spi = max_spi + 4096U;
    return (id < max_spi) ? 1U : 0U;
}

#define GIC_PRIORITY_MASK(o) ((uint32_t)(0xFFU << (o)))
#define GIC_PRIORITY_SHIFT_VAL(v, o) ((uint32_t)((v) << (o)))
#define GIC_CLEAR_PRI(d, o) ((d) &= ~GIC_PRIORITY_MASK(o))
#define GIC_SET_PRI(d, v, o) \
    GIC_CLEAR_PRI(d, o);     \
    (d) |= GIC_PRIORITY_SHIFT_VAL(v, o)

/* ── Set interrupt priority ──────────────────────────────────────────────── */

int32_t gic_set_int_priority(uint32_t id, uint32_t rd, uint8_t priority)
{
    if ((priority & 0xF0U) == 0xF0U) {
        return INTERRUPT_RETURN_INVALID_PRIORITY;
    }
    if ((gic_rdist == (void *)0) || (gic_dist == (void *)0)) {
        return INTERRUPT_RETURN_ERROR;
    }

    if (id < 31U) {
        if (rd > gic_max_rd)
            return INTERRUPT_RETURN_INVALID_RDIST;
        gic_rdist[rd].sgis.GICR_IPRIORITYR[id] = (uint8_t)INTERRUPT_MAKE_PRIORITY(priority);
    } else if (id < 1020U) {
        if (id == 31U)
            return INTERRUPT_RETURN_INVALID_SPI;
        id -= 32U;
        uint32_t index = id / 4U;
        uint32_t offset = (id & 0x03U) * 8U;
        uint32_t pri = gic_dist->GICD_IPRIORITYR[index];
        GIC_SET_PRI(pri, INTERRUPT_MAKE_PRIORITY(priority), offset);
        gic_dist->GICD_IPRIORITYR[index] = pri;
    } else {
        return INTERRUPT_RETURN_INVALID_ID;
    }
    return INTERRUPT_RETURN_SUCCESS;
}

/* ── Set interrupt group ─────────────────────────────────────────────────── */

int32_t gic_set_int_group(uint32_t id, uint32_t rd, uint32_t security)
{
    uint32_t bank, group, mod, ret = 0U;

    if ((gic_rdist == (void *)0) || (gic_dist == (void *)0)) {
        return INTERRUPT_RETURN_ERROR;
    }

    if (id < 31U) {
        if (rd > gic_max_rd)
            return INTERRUPT_RETURN_INVALID_RDIST;
        uint32_t bit = 1U << id;
        group = gic_rdist[rd].sgis.GICR_IGROUPR0;
        mod = gic_rdist[rd].sgis.GICR_IGRPMODR0;
        switch (security) {
        case GICV3_GROUP0:
            group &= ~bit;
            mod &= ~bit;
            break;
        case GICV3_GROUP1_SECURE:
            group &= ~bit;
            mod |= bit;
            break;
        case GICV3_GROUP1_NON_SECURE:
            group |= bit;
            mod &= ~bit;
            break;
        default:
            ret = 1U;
            break;
        }
        if (ret)
            return INTERRUPT_RETURN_INVALID_GROUP;
        gic_rdist[rd].sgis.GICR_IGROUPR0 = group;
        gic_rdist[rd].sgis.GICR_IGRPMODR0 = mod;
    } else if (id < 1020U) {
        if (id == 31U)
            return INTERRUPT_RETURN_INVALID_SPI;
        id -= 32U;
        bank = id / 32U;
        uint32_t bit = 1U << (id & 0x1fU);
        group = gic_dist->GICD_IGROUPR[bank];
        mod = gic_dist->GICD_IGRPMODR[bank];
        switch (security) {
        case GICV3_GROUP0:
            group &= ~bit;
            mod &= ~bit;
            break;
        case GICV3_GROUP1_SECURE:
            group &= ~bit;
            mod |= bit;
            break;
        case GICV3_GROUP1_NON_SECURE:
            group |= bit;
            mod &= ~bit;
            break;
        default:
            ret = 2U;
            break;
        }
        if (ret)
            return INTERRUPT_RETURN_INVALID_GROUP;
        gic_dist->GICD_IGROUPR[bank] = group;
        gic_dist->GICD_IGRPMODR[bank] = mod;
    } else {
        return INTERRUPT_RETURN_INVALID_ID;
    }
    return INTERRUPT_RETURN_SUCCESS;
}

/* ── Set SPI routing ─────────────────────────────────────────────────────── */

#define GICV3_ROUTE_AFF3_SHIFT 8U

int32_t gic_set_int_route(uint32_t id, uint32_t mode, uint32_t affinity)
{
    if (gic_dist == (void *)0)
        return INTERRUPT_RETURN_ERROR;

    if (!((id > 31U) && (id < 1020U))) {
        if (!((id > 4095U) && (id < 5120U)))
            return INTERRUPT_RETURN_INVALID_SPI;
        if (gic_is_valid_ext_spi(id) == 0U)
            return INTERRUPT_RETURN_INVALID_SPI;
    }

    uint32_t reg_id = id - 32U;
    uint64_t tmp = (uint64_t)(affinity & 0x00FFFFFFU) | (((uint64_t)affinity & 0xFF000000U) << GICV3_ROUTE_AFF3_SHIFT) |
                   (uint64_t)mode;

    if ((reg_id > 31U) && (reg_id < 1020U)) {
        gic_dist->GICD_IROUTER[reg_id] = tmp;
    }
    return INTERRUPT_RETURN_SUCCESS;
}

/* ── Enable interrupt ────────────────────────────────────────────────────── */

int32_t gic_enable_int(uint32_t id, uint32_t rd)
{
    if ((gic_rdist == (void *)0) || (gic_dist == (void *)0))
        return INTERRUPT_RETURN_ERROR;

    if (id < 31U) {
        if (rd > gic_max_rd)
            return INTERRUPT_RETURN_INVALID_RDIST;
        gic_rdist[rd].sgis.GICR_ISENABLER0 = (1U << id);
    } else if (id < 1020U) {
        if (id == 31U)
            return INTERRUPT_RETURN_INVALID_SPI;
        uint32_t adj = id - 32U;
        uint32_t bank = adj / 32U;
        uint32_t bit = 1U << (adj & 0x1fU);
        gic_dist->GICD_ISENABLER[bank] = bit;
    } else {
        return INTERRUPT_RETURN_ERROR;
    }
    return INTERRUPT_RETURN_SUCCESS;
}

/* ── Disable interrupt ───────────────────────────────────────────────────── */

int32_t gic_disable_int(uint32_t id, uint32_t rd)
{
    if ((gic_rdist == (void *)0) || (gic_dist == (void *)0))
        return INTERRUPT_RETURN_ERROR;

    if (id < 31U) {
        if (rd > gic_max_rd)
            return 1;
        gic_rdist[rd].sgis.GICR_ICENABLER0 = (1U << (id & 0x1fU));
    } else if (id < 1020U) {
        if (id == 31U)
            return INTERRUPT_RETURN_INVALID_SPI;
        uint32_t adj = id - 32U;
        uint32_t bank = adj / 32U;
        uint32_t bit = 1U << (adj & 0x1fU);
        gic_dist->GICD_ICENABLER[bank] = bit;
    } else {
        return INTERRUPT_RETURN_ERROR;
    }
    return INTERRUPT_RETURN_SUCCESS;
}

/* ── Set trigger type ────────────────────────────────────────────────────── */

int32_t gic_set_int_type(uint32_t id, uint32_t rd, uint32_t type)
{
    if ((gic_dist == (void *)0) || (gic_rdist == (void *)0))
        return INTERRUPT_RETURN_ERROR;

    if (id < 31U) {
        if (id < 16U)
            return 1;
        uint32_t ppi_shift = (id - 16U) << 1U;
        uint32_t ppi_tmp = gic_rdist[rd].sgis.GICR_ICFGR[1];
        ppi_tmp &= ~(0x3U << ppi_shift);
        ppi_tmp |= (type & 0x3U) << ppi_shift;
        gic_rdist[rd].sgis.GICR_ICFGR[1] = ppi_tmp;
    } else if (id < 1020U) {
        if (id == 31U)
            return INTERRUPT_RETURN_INVALID_SPI;
        uint32_t adj = id - 32U;
        uint32_t bank = adj / 16U;
        uint32_t shift = (adj & 0xFU) * 2U;
        uint32_t conf = (type & 0x3U) << shift;
        uint32_t tmp = gic_dist->GICD_ICFGR[bank];
        tmp &= ~(0x3U << shift);
        tmp |= conf;
        gic_dist->GICD_ICFGR[bank] = tmp;
    } else {
        return INTERRUPT_RETURN_ERROR;
    }
    return INTERRUPT_RETURN_SUCCESS;
}

/* ── Clear pending ───────────────────────────────────────────────────────── */

int32_t gic_clear_int_pending(uint32_t id, uint32_t rd)
{
    if ((gic_dist == (void *)0) || (gic_rdist == (void *)0))
        return INTERRUPT_RETURN_ERROR;

    if (id < 31U) {
        if (rd > gic_max_rd)
            return 1;
        gic_rdist[rd].sgis.GICR_ICPENDR0 |= (1U << id);
    } else if (id < 1020U) {
        if (id == 31U)
            return INTERRUPT_RETURN_INVALID_SPI;
        uint32_t adj = id - 32U;
        uint32_t bank = adj / 32U;
        uint32_t bit = 1U << (adj & 0x1fU);
        gic_dist->GICD_ICPENDR[bank] = bit;
    } else {
        return INTERRUPT_RETURN_ERROR;
    }
    return INTERRUPT_RETURN_SUCCESS;
}

/* ── Set pending ─────────────────────────────────────────────────────────── */

int32_t gic_set_int_pending(uint32_t id, uint32_t rd)
{
    if ((gic_dist == (void *)0) || (gic_rdist == (void *)0))
        return INTERRUPT_RETURN_ERROR;

    if (id < 32U) {
        if (rd > gic_max_rd)
            return 1;
        gic_rdist[rd].sgis.GICR_ISPENDR0 |= (1U << (id & 0x1fU));
    } else if (id < 1020U) {
        uint32_t adj = id - 32U;
        uint32_t bank = adj / 32U;
        uint32_t bit = 1U << (adj & 0x1fU);
        gic_dist->GICD_ISPENDR[bank] |= bit;
    } else {
        return INTERRUPT_RETURN_ERROR;
    }
    return INTERRUPT_RETURN_SUCCESS;
}

/* ── Enable IRQs at CPU ──────────────────────────────────────────────────── */

void gic_enable_interrupts(void)
{
    /* Clear IRQ mask only (DAIF.I bit). FIQ and SError stay masked —
     * FIQ is owned by EL3/ATF on this platform and SError is handled
     * by the _unhandled_exception vector in vectors.S.               */
    __asm__ volatile("msr daifclr, #0x2" ::: "memory");
}
