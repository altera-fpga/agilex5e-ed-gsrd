#include <stdint.h>
#include <stddef.h>

#include "uart_api.h"
#include "platform_def.h"
#include "socfpga_interrupt.h"
#include "perf_api.h"

/* Defined in examples/hello_world/hello_world.c */
void cmd_hello_world(const char *args);

/* Busy-wait for the requested number of milliseconds */
static void delay_ms(uint32_t ms)
{
    uint64_t start = perf_counter_ticks();
    uint64_t target_us = (uint64_t)ms * 1000ULL;

    while (perf_elapsed_us(start) < target_us) {
        /* busy-wait */
    }
}

void main(void)
{
    /* UART init for platform */
    uart_init(0, 115200, HPS_PERIP_UART_CLK);

    /* Clock manager initialisation */
    platform_clk_init();

    /* Initialize GIC for interrupt handling */
    interrupt_init_gic();

    /* Print platform and version info */
    platform_print_info();

    while (1) {
        cmd_hello_world(NULL);
        delay_ms(1000);
    }
}
