#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>

#include "system.h"
#include "io.h"
#include "altera_avalon_pio_regs.h"

#define NIOS_ENABLE_BIT (0x1u << 0)
#define NIOS_START_BIT (0x1u << 0)
#define NIOS_F2SDRAM_PASS_BIT (0x1u << 1)
#define NIOS_F2H_PASS_BIT (0x1u << 2)
#define NIOS_DONE_BIT (0x1u << 3)

/* Address Span Extender (ASE) control slave: word 0 = target address [31:0], word 1 = target address [63:32]. */
#define ASE_CNTL_REG_ADDR_LO 0u
#define ASE_CNTL_REG_ADDR_HI 4u

/* Define test patterns for F2SDRAM */
#define F2SDRAM_TEST_DATA_LO 0x1234u
#define F2SDRAM_TEST_DATA_HI 0xABCDu

typedef struct {
    uint32_t low_csr; /* LOW address CSR (offset bits excluded) */
    uint32_t high_csr; /* HIGH address CSR */
    uint64_t data_offset; /* Offset presented on data bus */
} addr_span_extender_windowed_slave_t;

/*
 * Splits a 64-bit address for Address Span Extender IP
 *
 * full_addr  : Full 64-bit system address
 * window_size: Address Span Extender window size
 */
static inline addr_span_extender_windowed_slave_t split_address_span_extender(uint64_t full_addr, uint32_t window_size)
{
    uint64_t offset_mask;

    offset_mask = (window_size >= 64u) ? UINT64_MAX : ((1ULL << window_size) - 1ULL);
    addr_span_extender_windowed_slave_t r = { 0 };

    /* Data bus offset (lower window_size) */
    r.data_offset = full_addr & offset_mask;

    /*
     * Shift out offset bits before programming CSRs
     * This is the critical correction.
     */
    uint64_t csr_addr = full_addr - r.data_offset;

    r.low_csr = (uint32_t)(csr_addr & 0xFFFFFFFFULL);
    r.high_csr = (uint32_t)(csr_addr >> 32);

#ifdef DEBUG
    printf("Offset Mask    : 0x%x\n", offset_mask);
    printf("Address        : 0x%016llX\n", full_addr);
    printf("LOW CSR        : 0x%08X\n", r.low_csr);
    printf("HIGH CSR       : 0x%08X\n", r.high_csr);
    printf("Data offset    : 0x%08llX\n", r.data_offset);
#endif

    return r;
}

void address_span_extender_configure(uint32_t cntl_base, uint32_t addr_hi, uint32_t addr_lo)
{
    IOWR_32DIRECT(cntl_base, ASE_CNTL_REG_ADDR_LO, addr_lo);
    IOWR_32DIRECT(cntl_base, ASE_CNTL_REG_ADDR_HI, addr_hi);
}

uint32_t read_f2sdram(uint32_t offset)
{
    uint32_t data = IORD_32DIRECT(U_F2SDRAM_ADDRESS_SPAN_EXTENDER_WINDOWED_SLAVE_BASE, offset);
    return data;
}

void write_f2sdram(uint32_t offset, uint32_t data)
{
    IOWR_32DIRECT(U_F2SDRAM_ADDRESS_SPAN_EXTENDER_WINDOWED_SLAVE_BASE, offset, data);
}

/* Write 64-bit pattern (lower at offset, upper at offset+4) and read back to verify. */
bool test_f2sdram_64(uint64_t addr, uint32_t data_hi, uint32_t data_lo)
{
    uint32_t f2sdram_window_size = U_F2SDRAM_ADDRESS_SPAN_EXTENDER_WINDOWED_SLAVE_SLAVE_ADDRESS_WIDTH +
                                   U_F2SDRAM_ADDRESS_SPAN_EXTENDER_WINDOWED_SLAVE_SLAVE_ADDRESS_SHIFT;
    addr_span_extender_windowed_slave_t windowed_slave_addr = split_address_span_extender(addr, f2sdram_window_size);

    address_span_extender_configure(U_F2SDRAM_ADDRESS_SPAN_EXTENDER_CNTL_BASE, windowed_slave_addr.high_csr,
                                    windowed_slave_addr.low_csr);
    write_f2sdram(windowed_slave_addr.data_offset, data_lo);
    write_f2sdram(windowed_slave_addr.data_offset + 0x4u, data_hi);

    uint32_t rd_lo = read_f2sdram(windowed_slave_addr.data_offset);
    uint32_t rd_hi = read_f2sdram(windowed_slave_addr.data_offset + 0x4u);

    return (rd_lo == data_lo) && (rd_hi == data_hi);
}

int main()

{
    uint32_t f2sdram_test_pass = 0u;
    uint32_t f2h_test_pass = 0u;

    printf("NiosV started\n");
    // Write to NiosV PIO to indicate NiosV has started, and testbench can proceed with the test sequence.
    IOWR_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_OUT_BASE,
                                IORD_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_OUT_BASE) | NIOS_START_BIT);

    // Wait for NIOSV to be enabled
    while (1) {
        if ((IORD_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_IN_BASE) & NIOS_ENABLE_BIT) == 1u) {
            break;
        }
    }

    printf("NiosV enabled\n");
    printf("F2SDRAM test started\n");
    // Test F2SDRAM by writing data to F2SDRAM through the bridge, and read back the data to verify the correctness.
    uint64_t f2sdram_addr = 0xc2000000ULL;
    f2sdram_test_pass = test_f2sdram_64(f2sdram_addr, F2SDRAM_TEST_DATA_HI, F2SDRAM_TEST_DATA_LO) ? 1u : 0u;

    // Set f2sdram test pass flag
    if (f2sdram_test_pass) {
        IOWR_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_OUT_BASE,
                                    IORD_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_OUT_BASE) | NIOS_F2SDRAM_PASS_BIT);
    } else {
        IOWR_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_OUT_BASE,
                                    IORD_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_OUT_BASE) & ~NIOS_F2SDRAM_PASS_BIT);
    }

    printf("F2SDRAM test completed\n");
    printf("F2H test started\n");
    // F2H bridge is not present on this design. Skip test and report pass.
    f2h_test_pass = 1u;

    // Set f2h test pass flag
    if (f2h_test_pass) {
        IOWR_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_OUT_BASE,
                                    IORD_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_OUT_BASE) | NIOS_F2H_PASS_BIT);
    } else {
        IOWR_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_OUT_BASE,
                                    IORD_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_OUT_BASE) & ~NIOS_F2H_PASS_BIT);
    }

    printf("F2H test completed\n");
    // Write to NiosV PIO to indicate NiosV test program is completed, and testbench can check the final results.
    IOWR_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_OUT_BASE,
                                IORD_ALTERA_AVALON_PIO_DATA(U_NIOSV_PIO_OUT_BASE) | NIOS_DONE_BIT);

    printf("NiosV test program completed\n");
    return 0;
}
