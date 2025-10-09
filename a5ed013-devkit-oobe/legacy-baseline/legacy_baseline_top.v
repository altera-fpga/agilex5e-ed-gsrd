//****************************************************************************
//
// SPDX-License-Identifier: MIT-0
// Copyright(c) 2019-2021 Intel Corporation.
//
//****************************************************************************
// This is a generated system top level RTL file.

// Derive channel and width from hps_emif_topology

// Find and print each number individually


module legacy_baseline_top (
    // Clock and Reset
    input  wire        fpga_reset_n,
    input  wire        fpga_clk_100,
    // HPS
    // HPS_EMIF
    output wire        emif_hps_emif_mem_0_mem_ck_t,
    output wire        emif_hps_emif_mem_0_mem_ck_c,
    output wire        emif_hps_emif_mem_0_mem_cke,
    output wire        emif_hps_emif_mem_0_mem_reset_n,
    input  wire        emif_hps_emif_oct_0_oct_rzqin,
    input  wire        emif_hps_emif_ref_clk_0_clk,
    inout  wire [ 3:0] emif_hps_emif_mem_0_mem_dqs_t,
    inout  wire [ 3:0] emif_hps_emif_mem_0_mem_dqs_c,
    inout  wire [31:0] emif_hps_emif_mem_0_mem_dq,
    output wire        emif_hps_emif_mem_0_mem_cs,
    output wire [ 5:0] emif_hps_emif_mem_0_mem_ca,
    inout  wire [ 3:0] emif_hps_emif_mem_0_mem_dmi,
    // HPS_IO48
    input  wire        hps_jtag_tck,
    input  wire        hps_jtag_tms,
    output wire        hps_jtag_tdo,
    input  wire        hps_jtag_tdi,
    output wire        hps_sdmmc_CCLK,
    inout  wire        hps_sdmmc_CMD,
    inout  wire        hps_sdmmc_D0,
    inout  wire        hps_sdmmc_D1,
    inout  wire        hps_sdmmc_D2,
    inout  wire        hps_sdmmc_D3,
    inout  wire        hps_usb1_DATA0,
    inout  wire        hps_usb1_DATA1,
    inout  wire        hps_usb1_DATA2,
    inout  wire        hps_usb1_DATA3,
    inout  wire        hps_usb1_DATA4,
    inout  wire        hps_usb1_DATA5,
    inout  wire        hps_usb1_DATA6,
    inout  wire        hps_usb1_DATA7,
    input  wire        hps_usb1_CLK,
    output wire        hps_usb1_STP,
    input  wire        hps_usb1_DIR,
    input  wire        hps_usb1_NXT,
    output wire        hps_emac2_TX_CLK,
    input  wire        hps_emac2_RX_CLK,
    output wire        hps_emac2_TX_CTL,
    input  wire        hps_emac2_RX_CTL,
    output wire        hps_emac2_TXD0,
    output wire        hps_emac2_TXD1,
    input  wire        hps_emac2_RXD0,
    input  wire        hps_emac2_RXD1,
    output wire        hps_emac2_TXD2,
    output wire        hps_emac2_TXD3,
    input  wire        hps_emac2_RXD2,
    input  wire        hps_emac2_RXD3,
    inout  wire        hps_emac2_MDIO,
    output wire        hps_emac2_MDC,
    input  wire        hps_uart0_RX,
    output wire        hps_uart0_TX,
    inout  wire        hps_i2c0_SDA,
    inout  wire        hps_i2c0_SCL,
    inout  wire        hps_i3c1_SDA,
    inout  wire        hps_i3c1_SCL,
    inout  wire        hps_gpio0_io0,
    inout  wire        hps_gpio0_io1,
    inout  wire        hps_gpio0_io11,
    inout  wire        hps_gpio1_io3,
    inout  wire        hps_gpio1_io4,
    input  wire        hps_osc_clk,

    // output   wire          hps_emac2_PPS,
    // input    wire          hps_emac2_PPS_TRIG,
    // input    wire          usb31_io_vbus_det,
    // input    wire          usb31_io_flt_bar,
    // output   wire [1:0]    usb31_io_usb_ctrl,
    // input    wire          usb31_io_usb31_id,
    // input    wire          usb31_phy_refclk_p_clk,
    // input    wire          usb31_phy_refclk_p_clk(n),
    // input    wire          usb31_phy_rx_serial_n_i_rx_serial_n,
    // input    wire          usb31_phy_rx_serial_p_i_rx_serial_p,
    // output   wire          usb31_phy_tx_serial_n_o_tx_serial_n,
    // output   wire          usb31_phy_tx_serial_p_o_tx_serial_p,

    // General purpose I/O
    output wire [1:0] fpga_led_pio,
    input  wire       fpga_button_pio
);

    wire system_clk_100;
    wire ninit_done;
    wire fpga_reset_n_debounced_wire;
    reg fpga_reset_n_debounced;
    wire system_reset_n;
    wire h2f_reset;

    assign combined_reset_n = fpga_reset_n & ~h2f_reset & ~ninit_done;

    altera_std_synchronizer #(
        .depth(3)
    ) fpga_reset_n_sync (
        .clk    (system_clk_100),
        .reset_n(combined_reset_n),
        .din    (1'b1),
        .dout   (system_reset_n)
    );

    assign system_clk_100 = fpga_clk_100;

    // Debounce logic to clean out glitches within 1ms
    wire fpga_debounced_buttons;
    debounce debounce_inst (
        .clk     (system_clk_100),
        .reset_n (system_reset_n),
        .data_in (fpga_button_pio),
        .data_out(fpga_debounced_buttons)
    );
    defparam debounce_inst.WIDTH = 1; defparam debounce_inst.POLARITY = "LOW";
        defparam debounce_inst.TIMEOUT = 10000;  // at 100Mhz this is a debounce time of 1ms
    defparam debounce_inst.TIMEOUT_WIDTH = 32;  // ceil(log2(TIMEOUT))

    // Loopback the LED PIO
    //wire [1:0] fpga_led_pio;
    wire fpga_led_pio_out;
    wire fpga_led_pio_in;
    assign fpga_led_pio_in = fpga_led_pio[0];

    // Tie off all fabric to HPS interrupts
    wire [30:0] f2h_irq1_irq;
    assign f2h_irq1_irq = {31'b0};

    //
    wire usb31_phy_pma_cpu_clk_clk;
    wire o_pma_cpu_clk;
    assign usb31_phy_pma_cpu_clk_clk = o_pma_cpu_clk;

    // Create a heartbeat counter
    reg [22:0] heartbeat_count;
    always @(posedge system_clk_100 or negedge system_reset_n) begin
        if (!system_reset_n) begin
            heartbeat_count <= 23'd0;
        end else begin
            heartbeat_count <= heartbeat_count + 23'd1;
        end
    end

    // Create a heartbeat LED
    wire heartbeat_led;
    assign heartbeat_led = ~heartbeat_count[22];

    // Drive the PIN LEDs to be the HPS PIO outputs
    // in addition to the heartbeat LED
    assign fpga_led_pio = {heartbeat_led, fpga_led_pio_out};

    // Loopback the reset request and ack signals
    wire h2f_warm_reset_handshake_reset_ack;
    wire h2f_warm_reset_handshake_reset_req;
    assign h2f_warm_reset_handshake_reset_ack = h2f_warm_reset_handshake_reset_req;

    // Qsys Top module
    qsys_top soc_inst (
        .clk_100_clk                          (system_clk_100),
        .reset_reset_n                        (system_reset_n),
        .ninit_done_ninit_done                (ninit_done),
        //
        // HPS Clock
        .hps_io_hps_osc_clk                   (hps_osc_clk),
        // HPS reset to the fabric
        .h2f_reset_reset                      (h2f_reset),
        //
        .h2f_warm_reset_handshake_reset_req   (h2f_warm_reset_handshake_reset_req),
        .h2f_warm_reset_handshake_reset_ack   (h2f_warm_reset_handshake_reset_ack),
        //
        .led_pio_external_connection_in_port  (fpga_led_pio_in),
        .led_pio_external_connection_out_port (fpga_led_pio_out),
        .button_pio_external_connection_export(fpga_debounced_buttons),
        //
        .emif_hps_emif_mem_ck_0_mem_ck_t      (emif_hps_emif_mem_0_mem_ck_t),
        .emif_hps_emif_mem_ck_0_mem_ck_c      (emif_hps_emif_mem_0_mem_ck_c),
        .emif_hps_emif_mem_0_mem_cke          (emif_hps_emif_mem_0_mem_cke),
        .emif_hps_emif_mem_reset_n_mem_reset_n(emif_hps_emif_mem_0_mem_reset_n),
        .emif_hps_emif_mem_0_mem_dqs_t        (emif_hps_emif_mem_0_mem_dqs_t),
        .emif_hps_emif_mem_0_mem_dqs_c        (emif_hps_emif_mem_0_mem_dqs_c),
        .emif_hps_emif_mem_0_mem_dq           (emif_hps_emif_mem_0_mem_dq),
        .emif_hps_emif_oct_0_oct_rzqin        (emif_hps_emif_oct_0_oct_rzqin),
        .emif_hps_emif_ref_clk_0_clk          (emif_hps_emif_ref_clk_0_clk),
        .emif_hps_emif_mem_0_mem_cs           (emif_hps_emif_mem_0_mem_cs),
        .emif_hps_emif_mem_0_mem_ca           (emif_hps_emif_mem_0_mem_ca),
        .emif_hps_emif_mem_0_mem_dmi          (emif_hps_emif_mem_0_mem_dmi),
        //
        .hps_io_jtag_tck                      (hps_jtag_tck),
        .hps_io_jtag_tms                      (hps_jtag_tms),
        .hps_io_jtag_tdo                      (hps_jtag_tdo),
        .hps_io_jtag_tdi                      (hps_jtag_tdi),
        .hps_io_emac2_tx_clk                  (hps_emac2_TX_CLK),
        .hps_io_emac2_rx_clk                  (hps_emac2_RX_CLK),
        .hps_io_emac2_tx_ctl                  (hps_emac2_TX_CTL),
        .hps_io_emac2_rx_ctl                  (hps_emac2_RX_CTL),
        .hps_io_emac2_txd0                    (hps_emac2_TXD0),
        .hps_io_emac2_txd1                    (hps_emac2_TXD1),
        .hps_io_emac2_rxd0                    (hps_emac2_RXD0),
        .hps_io_emac2_rxd1                    (hps_emac2_RXD1),
        .hps_io_emac2_txd2                    (hps_emac2_TXD2),
        .hps_io_emac2_txd3                    (hps_emac2_TXD3),
        .hps_io_emac2_rxd2                    (hps_emac2_RXD2),
        .hps_io_emac2_rxd3                    (hps_emac2_RXD3),
        .hps_io_mdio2_mdio                    (hps_emac2_MDIO),
        .hps_io_mdio2_mdc                     (hps_emac2_MDC),
        .hps_io_sdmmc_cclk                    (hps_sdmmc_CCLK),
        .hps_io_sdmmc_cmd                     (hps_sdmmc_CMD),
        .hps_io_sdmmc_data0                   (hps_sdmmc_D0),
        .hps_io_sdmmc_data1                   (hps_sdmmc_D1),
        .hps_io_sdmmc_data2                   (hps_sdmmc_D2),
        .hps_io_sdmmc_data3                   (hps_sdmmc_D3),
        .hps_io_i2c0_sda                      (hps_i2c0_SDA),
        .hps_io_i2c0_scl                      (hps_i2c0_SCL),
        .hps_io_i3c1_sda                      (hps_i3c1_SDA),
        .hps_io_i3c1_scl                      (hps_i3c1_SCL),
        .hps_io_uart0_rx                      (hps_uart0_RX),
        .hps_io_uart0_tx                      (hps_uart0_TX),
        .usb31_io_vbus_det                    (1'b0),
        .usb31_io_flt_bar                     (1'b0),
        .usb31_io_usb_ctrl                    (),
        .usb31_io_usb31_id                    (1'b0),
        .usb31_phy_refclk_p_clk               (1'b0),
        //.usb31_phy_refclk_n_clk               (usb31_phy_refclk_p_clk(n)),
        .usb31_phy_rx_serial_n_i_rx_serial_n  (1'b0),
        .usb31_phy_rx_serial_p_i_rx_serial_p  (1'b0),
        .usb31_phy_tx_serial_n_o_tx_serial_n  (),
        .usb31_phy_tx_serial_p_o_tx_serial_p  (),
        .usb31_phy_pma_cpu_clk_clk            (usb31_phy_pma_cpu_clk_clk),
        .o_pma_cu_clk_clk                     (o_pma_cpu_clk),
        .hps_io_usb1_clk                      (hps_usb1_CLK),
        .hps_io_usb1_stp                      (hps_usb1_STP),
        .hps_io_usb1_dir                      (hps_usb1_DIR),
        .hps_io_usb1_nxt                      (hps_usb1_NXT),
        .hps_io_usb1_data0                    (hps_usb1_DATA0),
        .hps_io_usb1_data1                    (hps_usb1_DATA1),
        .hps_io_usb1_data2                    (hps_usb1_DATA2),
        .hps_io_usb1_data3                    (hps_usb1_DATA3),
        .hps_io_usb1_data4                    (hps_usb1_DATA4),
        .hps_io_usb1_data5                    (hps_usb1_DATA5),
        .hps_io_usb1_data6                    (hps_usb1_DATA6),
        .hps_io_usb1_data7                    (hps_usb1_DATA7),
        .hps_io_gpio0                         (hps_gpio0_io0),
        .hps_io_gpio1                         (hps_gpio0_io1),
        .hps_io_gpio11                        (hps_gpio0_io11),
        .hps_io_gpio27                        (hps_gpio1_io3),
        .hps_io_gpio28                        (hps_gpio1_io4),
        .f2h_irq1_in_irq                      (f2h_irq1_irq)
    );

endmodule
