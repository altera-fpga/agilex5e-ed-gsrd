`timescale 1 ps / 1 ps
//
`default_nettype none

module clocks_and_resets (
    // FPGA fabric Clock
    input  wire fpga_clk_100,
    // External FPGA reset
    input  wire fpga_reset_n,
    // HPS to FPGA reset signal
    input  wire h2f_reset,
    // System clock from PLL
    output wire sys_clk_100,
    // 25 MHz clock from PLL
    output wire pll_clk_25,
    // 2.5 MHz clock from PLL
    output wire pll_clk_2_5,
    // PLL locked signal
    output wire pll_locked,
    // Synchronized system reset signal
    output wire sys_clk_100_reset_n
);

    // Clock and Reset
    wire pll_clk_100;
    wire system_reset;
    assign sys_clk_100 = pll_clk_100;

    // Generate n_initdone
    wire ninit_done;
    user_rst_clkgate u_ninit_done (.ninit_done(ninit_done));

    // Generate a reset signal for the PLL
    // based on the nINIT_DONE signal and the FPGA reset signal
    wire pll_reset;
    assign pll_reset = ninit_done | ~fpga_reset_n;

    // Instantiate the system clock PLL
    // Reset the PLL based on nINIT_DONE
    //wire pll_locked;
    sys_pll u_sys_pll (
        .refclk  (fpga_clk_100),
        .locked  (pll_locked),
        .rst     (pll_reset),
        .outclk_0(pll_clk_100),
        .outclk_1(pll_clk_25),
        .outclk_2(pll_clk_2_5)
    );

    // Generate a system reset based on the PLL lock status
    // and the HPS to FPGA reset signal
    assign system_reset = ~pll_locked | h2f_reset;

    // Create a synchronized system reset signal
    // to the system clock domain
    altera_std_synchronizer #(
        .depth(3)
    ) fpga_reset_n_sync (
        .clk    (pll_clk_100),
        .reset_n(~system_reset),
        .din    (1'b1),
        .dout   (sys_clk_100_reset_n)
    );

endmodule
