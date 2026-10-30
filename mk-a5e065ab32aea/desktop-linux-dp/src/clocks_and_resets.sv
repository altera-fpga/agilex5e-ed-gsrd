`timescale 1 ps / 1 ps
//
`default_nettype none

module clocks_and_resets (
    // FPGA fabric Clock
    input  wire fpga_clk_100,
    // External FPGA reset
    input  wire fpga_reset_n,
    // HPS to FPGA reset signal
    input  wire h2f_reset_in,
    // Generated clocks from PLL
    output wire sys_clk_148_5,
    output wire mgmt_clk_50,
    output wire aux_clk_16,
    // Synchronized system reset signal
    output wire sys_reset_n,
    output wire mgmt_reset_n,
    output wire aux_reset_n
);

    // PLL generated clocks
    wire pll_clk_148_5;
    wire pll_clk_50;
    wire pll_clk_16;

    // Output clocks assignments
    assign sys_clk_148_5 = pll_clk_148_5;
    assign mgmt_clk_50 = pll_clk_50;
    assign aux_clk_16 = pll_clk_16;

    // Generate n_initdone
    wire ninit_done;
    user_rst_clkgate u_ninit_done (.ninit_done(ninit_done));

    // Generate a reset signal for the PLL
    // based on the nINIT_DONE signal and the FPGA reset signal
    wire pll_reset;
    assign pll_reset = ninit_done | ~fpga_reset_n;

    // Instantiate the system clock PLL
    wire pll_locked;
    sys_pll u_sys_pll (
        .refclk  (fpga_clk_100),
        .locked  (pll_locked),
        .rst     (pll_reset),
        .outclk_0(pll_clk_148_5),
        .outclk_1(pll_clk_50),
        .outclk_2(pll_clk_16)
    );

    // Generate a system reset based on the PLL lock status
    // and the HPS to FPGA reset signal
    wire system_reset;
    assign system_reset = ~pll_locked | h2f_reset_in;

    wire system_reset_extended;
    wire system_reset_extended_dup;
    altera_vvp_reset_extend #(
        .RESYNC_RESET_IN (1),
        .SYNC_LEN        (3),
        .RESET_MIN_LENGTH(1024)
    ) system_reset_extend_inst (
        .clk        (fpga_clk_100),
        .rst_in     (system_reset),
        .rst_out    (system_reset_extended),
        .rst_out_dup(system_reset_extended_dup)
    );

    // Create a synchronized system reset signal
    // to the system clock domain
    altera_std_synchronizer #(
        .depth(3)
    ) sys_reset_sync_inst (
        .clk    (pll_clk_148_5),
        .reset_n(~system_reset_extended_dup),
        .din    (1'b1),
        .dout   (sys_reset_n)
    );

    altera_std_synchronizer #(
        .depth(3)
    ) mgmt_reset_sync_inst (
        .clk    (pll_clk_50),
        .reset_n(~system_reset_extended_dup),
        .din    (1'b1),
        .dout   (mgmt_reset_n)
    );

    // Create a synchronized auxiliary reset signal
    // to the auxiliary clock domain
    altera_std_synchronizer #(
        .depth(3)
    ) aux_reset_sync_inst (
        .clk    (pll_clk_16),
        .reset_n(~system_reset_extended_dup),
        .din    (1'b1),
        .dout   (aux_reset_n)
    );

endmodule
