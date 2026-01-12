//****************************************************************************
//
// SPDX-License-Identifier: MIT-0
// SPDX-FileCopyrightText: Copyright (C) 2025 Altera Corporation
//
//****************************************************************************
//
// clocks_and_resets
//
//****************************************************************************

`timescale 1 ps / 1 ps
//
`default_nettype none

module clocks_and_resets (
    // FPGA fabric Clock
    input  wire fpga_clk_100,
    // External warm reset
    input  wire fpga_reset_n,
    // HPS to FPGA reset signal
    input  wire h2f_reset_in,
    // System clock from PLL
    output wire system_clock,
    // Synchronized system reset signal
    output wire system_reset_n
);

    // Clock and Reset
    wire pll_clk_100;
    wire system_reset;
    assign system_clock = pll_clk_100;

    // Generate n_initdone
    wire ninit_done;
    user_rst_clkgate u_ninit_done (.ninit_done(ninit_done));

    // Generate a reset signal for the PLL
    // based on the nINIT_DONE signal and the FPGA reset signal
    wire pll_reset;
    assign pll_reset = ninit_done | ~fpga_reset_n;

    // Instantiate the system clock PLL
    // Reset the PLL based on nINIT_DONE
    wire pll_locked;
    sys_pll u_sys_pll (
        .refclk  (fpga_clk_100),
        .locked  (pll_locked),
        .rst     (pll_reset),
        .outclk_0(pll_clk_100)
    );

    // Generate a system reset based on the PLL lock status
    // and the HPS to FPGA reset signal
    assign system_reset = ~pll_locked | h2f_reset_in;

    // Create a synchronized system reset signal
    // to the system clock domain
    altera_std_synchronizer #(
        .depth(3)
    ) fpga_reset_n_sync (
        .clk    (pll_clk_100),
        .reset_n(~system_reset),
        .din    (1'b1),
        .dout   (system_reset_n)
    );

endmodule
