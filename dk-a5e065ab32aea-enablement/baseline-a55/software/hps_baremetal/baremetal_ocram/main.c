#include <stdint.h>
#include <stddef.h>

#include "uart_api.h"
#include "platform_def.h"
#include "socfpga_interrupt.h"

/* Defined in examples/hello_world/hello_world.c */
void cmd_hello_world(const char *args);

/* CPU busy-loop count per millisecond. In OCRAM boot the hardware timers aren't
 * running (no ATF/U-Boot to start them), so we time the delay with a CPU spin.
 * Adjust if the blink rate is too fast or too slow; can also be overridden at
 * build time with -DDELAY_ITERS_PER_MS=<n>. */
#ifndef DELAY_ITERS_PER_MS
#define DELAY_ITERS_PER_MS 1000ULL
#endif

/* Busy-wait for (approximately) the requested number of milliseconds. */
static void delay_ms(uint32_t ms)
{
    uint64_t spin = (uint64_t)ms * DELAY_ITERS_PER_MS;

    /* nop keeps the loop from being optimized away without a volatile counter. */
    while (spin != 0U) {
        __asm__ volatile("nop");
        spin--;
    }
}

void main(void)
{
    /* OCRAM/FSBL boot: lock the PLLs to 100 MHz, then set the console baud
     * from the live L4_SP clock (no hardcoded rate). */
    platform_pll_init();
    uart_init(0, 115200, platform_get_l4sp_clk());

    /* Print platform and version info */
    platform_print_info();

    while (1) {
        cmd_hello_world(NULL);
        delay_ms(1000);
    }
}
