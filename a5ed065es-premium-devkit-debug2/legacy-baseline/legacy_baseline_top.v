//****************************************************************************
//
// SPDX-License-Identifier: MIT-0
// SPDX-FileCopyrightText: Copyright (C) 2025 Altera Corporation
//
//****************************************************************************
// This is a generated system top level RTL file. 

// Derive channel and width from hps_emif_topology

// Find and print each number individually


module ghrd_agilex5_top (
    //Additional refclk_bti to preserve Etile XCVR
    // Clock and Reset
    input wire fpga_clk_100,

    output wire [4-1:0] fpga_led_pio,
    input  wire [4-1:0] fpga_dipsw_pio,
    input  wire [4-1:0] fpga_button_pio,
    //HPS
    // HPS EMIF
    output wire         emif_hps_emif_mem_0_mem_ck_t,
    output wire         emif_hps_emif_mem_0_mem_ck_c,
    output wire [ 16:0] emif_hps_emif_mem_0_mem_a,
    output wire         emif_hps_emif_mem_0_mem_act_n,
    output wire [  1:0] emif_hps_emif_mem_0_mem_ba,
    output wire [  1:0] emif_hps_emif_mem_0_mem_bg,
    output wire         emif_hps_emif_mem_0_mem_cke,
    output wire         emif_hps_emif_mem_0_mem_cs_n,
    output wire         emif_hps_emif_mem_0_mem_odt,
    output wire         emif_hps_emif_mem_0_mem_reset_n,
    output wire         emif_hps_emif_mem_0_mem_par,
    input  wire         emif_hps_emif_mem_0_mem_alert_n,
    input  wire         emif_hps_emif_oct_0_oct_rzqin,
    input  wire         emif_hps_emif_ref_clk_0_clk,
    inout  wire [  3:0] emif_hps_emif_mem_0_mem_dqs_t,
    inout  wire [  3:0] emif_hps_emif_mem_0_mem_dqs_c,
    inout  wire [ 31:0] emif_hps_emif_mem_0_mem_dq,
    input  wire         hps_jtag_tck,
    input  wire         hps_jtag_tms,
    output wire         hps_jtag_tdo,
    input  wire         hps_jtag_tdi,
    output wire         hps_sdmmc_CCLK,
    inout  wire         hps_sdmmc_CMD,
    inout  wire         hps_sdmmc_D0,
    inout  wire         hps_sdmmc_D1,
    inout  wire         hps_sdmmc_D2,
    inout  wire         hps_sdmmc_D3,

    output wire hps_emac0_TX_CLK,  //TODO: may need to change RMII TX CLK to be input instead, check
    input wire hps_emac0_RX_CLK,
    output wire hps_emac0_TX_CTL,
    input wire hps_emac0_RX_CTL,
    output wire hps_emac0_TXD0,
    output wire hps_emac0_TXD1,
    input wire hps_emac0_RXD0,
    input wire hps_emac0_RXD1,
    output wire hps_emac0_PPS,
    input wire hps_emac0_PPS_TRIG,
    output wire hps_emac0_TXD2,
    output wire hps_emac0_TXD3,
    input wire hps_emac0_RXD2,
    input wire hps_emac0_RXD3,
    inout wire hps_emac0_MDIO,
    output wire hps_emac0_MDC,
    output wire hps_spim0_CLK,
    output wire hps_spim0_MOSI,
    input wire hps_spim0_MISO,
    output wire hps_spim0_SS0_N,
    input wire hps_uart0_RX,
    output wire hps_uart0_TX,
    inout wire hps_i3c1_SDA,
    inout wire hps_i3c1_SCL,
    output wire hps_trace_CLK,
    output wire hps_trace_D0,
    output wire hps_trace_D1,
    output wire hps_trace_D2,
    output wire hps_trace_D3,
    output wire hps_trace_D4,
    output wire hps_trace_D5,
    output wire hps_trace_D6,
    output wire hps_trace_D7,
    inout wire hps_gpio1_io3,
    inout wire hps_gpio1_io4,
    inout wire hps_gpio1_io12,
    inout wire hps_gpio1_io13,
    input wire hps_osc_clk,
    input wire fpga_reset_n
);

    wire system_clk_100;
    wire ninit_done;
    wire fpga_reset_n_debounced_wire;
    reg fpga_reset_n_debounced;
    wire system_reset;


    wire h2f_reset;

    assign combined_reset_n = fpga_reset_n & ~h2f_reset & ~ninit_done;

    altera_reset_synchronizer #(
        .ASYNC_RESET(1),
        .DEPTH      (2)
    ) sys_rst_inst (
        .reset_in (~combined_reset_n),
        .clk      (system_clk_100),
        .reset_out(system_reset)
    );
    assign system_clk_100 = fpga_clk_100;

    wire [4-1:0] fpga_debounced_buttons;
    wire [4-2:0] fpga_led_internal;
    wire heartbeat_led;
    reg [22:0] heartbeat_count;
    assign heartbeat_led = ~heartbeat_count[22];
    assign fpga_led_pio = {heartbeat_led, fpga_led_internal};



    wire [31:0] f2h_irq1_irq;

    assign f2h_irq1_irq = {32'b0};

    // Qsys Top module
    qsys_top soc_inst (
        .clk_100_clk                          (system_clk_100),
        .ninit_done_ninit_done                (ninit_done),
        .led_pio_external_connection_in_port  (fpga_led_internal),
        .led_pio_external_connection_out_port (fpga_led_internal),
        .dipsw_pio_external_connection_export (fpga_dipsw_pio),
        .button_pio_external_connection_export(fpga_debounced_buttons),

        .emif_hps_emif_mem_ck_0_mem_ck_t      (emif_hps_emif_mem_0_mem_ck_t),
        .emif_hps_emif_mem_ck_0_mem_ck_c      (emif_hps_emif_mem_0_mem_ck_c),
        .emif_hps_emif_mem_0_mem_a            (emif_hps_emif_mem_0_mem_a),
        .emif_hps_emif_mem_0_mem_act_n        (emif_hps_emif_mem_0_mem_act_n),
        .emif_hps_emif_mem_0_mem_ba           (emif_hps_emif_mem_0_mem_ba),
        .emif_hps_emif_mem_0_mem_bg           (emif_hps_emif_mem_0_mem_bg),
        .emif_hps_emif_mem_0_mem_cke          (emif_hps_emif_mem_0_mem_cke),
        .emif_hps_emif_mem_0_mem_cs_n         (emif_hps_emif_mem_0_mem_cs_n),
        .emif_hps_emif_mem_0_mem_odt          (emif_hps_emif_mem_0_mem_odt),
        .emif_hps_emif_mem_reset_n_mem_reset_n(emif_hps_emif_mem_0_mem_reset_n),
        .emif_hps_emif_mem_0_mem_par          (emif_hps_emif_mem_0_mem_par),
        .emif_hps_emif_mem_0_mem_alert_n      (emif_hps_emif_mem_0_mem_alert_n),
        .emif_hps_emif_mem_0_mem_dqs_t        (emif_hps_emif_mem_0_mem_dqs_t),
        .emif_hps_emif_mem_0_mem_dqs_c        (emif_hps_emif_mem_0_mem_dqs_c),
        .emif_hps_emif_mem_0_mem_dq           (emif_hps_emif_mem_0_mem_dq),
        .emif_hps_emif_oct_0_oct_rzqin        (emif_hps_emif_oct_0_oct_rzqin),
        .emif_hps_emif_ref_clk_0_clk          (emif_hps_emif_ref_clk_0_clk),
        .hps_io_jtag_tck                      (hps_jtag_tck),
        .hps_io_jtag_tms                      (hps_jtag_tms),
        .hps_io_jtag_tdo                      (hps_jtag_tdo),
        .hps_io_jtag_tdi                      (hps_jtag_tdi),
        .hps_io_emac0_tx_clk                  (hps_emac0_TX_CLK),
        .hps_io_emac0_rx_clk                  (hps_emac0_RX_CLK),
        .hps_io_emac0_tx_ctl                  (hps_emac0_TX_CTL),
        .hps_io_emac0_rx_ctl                  (hps_emac0_RX_CTL),
        .hps_io_emac0_txd0                    (hps_emac0_TXD0),
        .hps_io_emac0_txd1                    (hps_emac0_TXD1),
        .hps_io_emac0_rxd0                    (hps_emac0_RXD0),
        .hps_io_emac0_rxd1                    (hps_emac0_RXD1),
        .hps_io_emac0_pps                     (hps_emac0_PPS),
        .hps_io_emac0_pps_trig                (hps_emac0_PPS_TRIG),
        .hps_io_emac0_txd2                    (hps_emac0_TXD2),
        .hps_io_emac0_txd3                    (hps_emac0_TXD3),
        .hps_io_emac0_rxd2                    (hps_emac0_RXD2),
        .hps_io_emac0_rxd3                    (hps_emac0_RXD3),
        .hps_io_mdio0_mdio                    (hps_emac0_MDIO),
        .hps_io_mdio0_mdc                     (hps_emac0_MDC),
        .hps_io_sdmmc_cclk                    (hps_sdmmc_CCLK),
        .hps_io_sdmmc_cmd                     (hps_sdmmc_CMD),
        .hps_io_sdmmc_data0                   (hps_sdmmc_D0),
        .hps_io_sdmmc_data1                   (hps_sdmmc_D1),
        .hps_io_sdmmc_data2                   (hps_sdmmc_D2),
        .hps_io_sdmmc_data3                   (hps_sdmmc_D3),
        .hps_io_i3c1_sda                      (hps_i3c1_SDA),
        .hps_io_i3c1_scl                      (hps_i3c1_SCL),
        .hps_io_uart0_rx                      (hps_uart0_RX),
        .hps_io_uart0_tx                      (hps_uart0_TX),
        .hps_io_spim0_clk                     (hps_spim0_CLK),
        .hps_io_spim0_mosi                    (hps_spim0_MOSI),
        .hps_io_spim0_miso                    (hps_spim0_MISO),
        .hps_io_spim0_ss0_n                   (hps_spim0_SS0_N),
        .hps_io_trace_clk                     (hps_trace_CLK),
        .hps_io_trace_data0                   (hps_trace_D0),
        .hps_io_trace_data1                   (hps_trace_D1),
        .hps_io_trace_data2                   (hps_trace_D2),
        .hps_io_trace_data3                   (hps_trace_D3),
        .hps_io_trace_data4                   (hps_trace_D4),
        .hps_io_trace_data5                   (hps_trace_D5),
        .hps_io_trace_data6                   (hps_trace_D6),
        .hps_io_trace_data7                   (hps_trace_D7),
        .hps_io_gpio27                        (hps_gpio1_io3),
        .hps_io_gpio28                        (hps_gpio1_io4),
        .hps_io_gpio36                        (hps_gpio1_io12),
        .hps_io_gpio37                        (hps_gpio1_io13),
        .f2h_irq1_in_irq                      (f2h_irq1_irq),
        .hps_io_hps_osc_clk                   (hps_osc_clk),

        .h2f_reset_reset(h2f_reset),

        .reset_reset_n(combined_reset_n)
    );




    // Debounce logic to clean out glitches within 1ms
    debounce debounce_inst (
        .clk     (system_clk_100),
        .reset_n (~system_reset),
        .data_in (fpga_button_pio),
        .data_out(fpga_debounced_buttons)
    );
    defparam debounce_inst.WIDTH = 4; defparam debounce_inst.POLARITY = "LOW";
        defparam debounce_inst.TIMEOUT = 10000;  // at 100Mhz this is a debounce time of 1ms
    defparam debounce_inst.TIMEOUT_WIDTH = 32;  // ceil(log2(TIMEOUT))

    always @(posedge system_clk_100 or posedge system_reset) begin
        if (system_reset) heartbeat_count <= 23'd0;
        else heartbeat_count <= heartbeat_count + 23'd1;
    end

endmodule
