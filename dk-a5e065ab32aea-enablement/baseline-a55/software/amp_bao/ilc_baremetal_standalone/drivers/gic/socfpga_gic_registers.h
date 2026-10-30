/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Altera Corporation. All rights reserved.
 */

#ifndef __SOCFPGA_GIC_REGISTERS_H__
#define __SOCFPGA_GIC_REGISTERS_H__

#include <stdint.h>
#include <stddef.h>

struct gic_v3_dist_if {
    volatile uint32_t GICD_CTLR;
    volatile uint32_t GICD_TYPER;
    volatile uint32_t GICD_IIDR;
    const volatile uint32_t padding1[5];
    volatile uint32_t GICD_FCTLR;
    volatile uint32_t GICD_SAC;
    const volatile uint32_t padding2[6];
    volatile uint32_t GICD_SETSPI_NSR;
    const volatile uint32_t padding3;
    volatile uint32_t GICD_CLRSPI_NSR;
    const volatile uint32_t padding4;
    volatile uint32_t GICD_SETSPI_SR;
    const volatile uint32_t padding5;
    volatile uint32_t GICD_CLRSPI_SR;
    const volatile uint32_t padding6[10];
    volatile uint32_t GICD_IGROUPR[17];
    const volatile uint32_t padding7[15];
    volatile uint32_t GICD_ISENABLER[17];
    const volatile uint32_t padding8[15];
    volatile uint32_t GICD_ICENABLER[17];
    const volatile uint32_t padding9[15];
    volatile uint32_t GICD_ISPENDR[17];
    const volatile uint32_t padding10[15];
    volatile uint32_t GICD_ICPENDR[17];
    const volatile uint32_t padding11[15];
    volatile uint32_t GICD_ISACTIVER[17];
    const volatile uint32_t padding12[15];
    volatile uint32_t GICD_ICACTIVER[17];
    const volatile uint32_t padding13[22];
    volatile uint32_t GICD_IPRIORITYR[136];
    const volatile uint32_t padding14[370];
    volatile uint32_t GICD_ICFGR[34];
    const volatile uint32_t padding15[29];
    volatile uint32_t GICD_IGRPMODR[17];
    const volatile uint32_t padding16[48];
    volatile uint32_t GICD_NSACR[34];
    const volatile uint32_t padding17[5276];
    volatile uint64_t GICD_IROUTER[544];
    const volatile uint32_t padding561[7042];
    volatile uint32_t GICD_ICLAR[34];
    const volatile uint32_t padding562[29];
    volatile uint32_t GICD_IERRR[17];
    const volatile uint32_t padding563[942];
    volatile uint32_t GICD_CFGID;
    const volatile uint32_t padding564[1011];
    volatile uint32_t GICD_PIDR[8];
    volatile uint32_t GICD_CIDR[4];
};

/*
 * Compile-time sanity checks for gic_v3_dist_if field offsets.
 * Any accidental padding change will fail the build immediately.
 *
 * The Agilex5 GIC-600 places GICD_IGROUPR at 0x084 (one 32-bit
 * implementation-defined register at 0x080 shifts every subsequent
 * bank by 4 bytes relative to the GICv3 architecture specification).
 * All offsets below reflect the actual Agilex5 GIC-600 memory map
 * as verified by the working demo.  Do not "correct" them to the
 * textbook GICv3 values (0x080, 0x100, …) without re-testing on HW.
 */
_Static_assert(offsetof(struct gic_v3_dist_if, GICD_IGROUPR) == 0x0084UL, "GICD_IGROUPR offset mismatch");
_Static_assert(offsetof(struct gic_v3_dist_if, GICD_ISENABLER) == 0x0104UL, "GICD_ISENABLER offset mismatch");
_Static_assert(offsetof(struct gic_v3_dist_if, GICD_ICENABLER) == 0x0184UL, "GICD_ICENABLER offset mismatch");
_Static_assert(offsetof(struct gic_v3_dist_if, GICD_ISPENDR) == 0x0204UL, "GICD_ISPENDR offset mismatch");
_Static_assert(offsetof(struct gic_v3_dist_if, GICD_IPRIORITYR) == 0x0420UL, "GICD_IPRIORITYR offset mismatch");
_Static_assert(offsetof(struct gic_v3_dist_if, GICD_ICFGR) == 0x0C08UL, "GICD_ICFGR offset mismatch");
_Static_assert(offsetof(struct gic_v3_dist_if, GICD_IGRPMODR) == 0x0D04UL, "GICD_IGRPMODR offset mismatch");
_Static_assert(offsetof(struct gic_v3_dist_if, GICD_IROUTER) == 0x6100UL, "GICD_IROUTER offset mismatch");

struct gic_v3_rdist_lpis_if {
    volatile uint32_t GICR_CTLR;
    volatile uint32_t GICR_IIDR;
    volatile uint32_t GICR_TYPER[2];
    const volatile uint32_t padding1;
    volatile uint32_t GICR_WAKER;
    const volatile uint32_t padding2[2];
    volatile uint32_t GICR_FCTLR;
    volatile uint32_t GICR_PWRR;
    volatile uint32_t GICR_CLASS;
    const volatile uint32_t padding3[17];
    volatile uint64_t GICR_PROPBASER;
    volatile uint64_t GICR_PENDBASER;
    const volatile uint32_t padding5[16340];
    volatile uint32_t GICR_PIDR[8];
    volatile uint32_t GICR_CIDR[4];
};

struct gic_v3_rdist_sgis_if {
    const volatile uint32_t padding1[32];
    volatile uint32_t GICR_IGROUPR0;
    const volatile uint32_t padding2[31];
    volatile uint32_t GICR_ISENABLER0;
    const volatile uint32_t padding3[31];
    volatile uint32_t GICR_ICENABLER0;
    const volatile uint32_t padding4[31];
    volatile uint32_t GICR_ISPENDR0;
    const volatile uint32_t padding5[31];
    volatile uint32_t GICR_ICPENDR0;
    const volatile uint32_t padding6[31];
    volatile uint32_t GICR_ISACTIVER0;
    const volatile uint32_t padding7[31];
    volatile uint32_t GICR_ICACTIVER0;
    const volatile uint32_t padding8[31];
    volatile uint8_t GICR_IPRIORITYR[32];
    const volatile uint32_t padding9[504];
    volatile uint32_t GICR_ICFGR[2];
    const volatile uint32_t padding10[62];
    volatile uint32_t GICR_IGRPMODR0;
    const volatile uint32_t padding11[63];
    volatile uint32_t GICR_NSACR;
    const volatile uint32_t padding12[11391];
    volatile uint32_t GICR_MISCSTATUSR;
    const volatile uint32_t padding13;
    volatile uint32_t GICR_IERRVR;
    const volatile uint32_t padding14;
    volatile uint64_t GICR_SGIDR;
    const volatile uint32_t padding15[3066];
    volatile uint32_t GICR_CFGID[2];
};

struct gic_v3_rdist_vlpis_if {
    const volatile uint32_t padding1[28];
    volatile uint64_t GICR_VPROPBASER;
    volatile uint64_t GICR_VPENDBASER;
};

struct gic_v3_rdist_res_if {
    const volatile uint32_t padding1[32];
};

struct gic_v3_rdist_if {
    struct gic_v3_rdist_lpis_if lpis __attribute__((aligned(0x10000)));
    struct gic_v3_rdist_sgis_if sgis __attribute__((aligned(0x10000)));
};

#endif /* __SOCFPGA_GIC_REGISTERS_H__ */
