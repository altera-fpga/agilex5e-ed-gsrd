`timescale 1 ps / 1 ps
//
`default_nettype none

module baseline (
    // FPGA fabric Clock
    input  wire         fpga_clk_100,
    //
    // Switches and LEDs
    output wire [4-1:0] fpga_led,
    input  wire [4-1:0] fpga_dipsw,
    input  wire [4-1:0] fpga_buttons,
    //
    //HPS
    //
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
    inout  wire [  4:0] emif_hps_emif_mem_0_mem_dqs_t,
    inout  wire [  4:0] emif_hps_emif_mem_0_mem_dqs_c,
    inout  wire [ 39:0] emif_hps_emif_mem_0_mem_dq,
    //
    // HPS Peripherals
    input  wire         usb31_io_vbus_det,
    input  wire         usb31_io_flt_bar,
    output wire         usb31_io_usb_ctrl,
    input  wire         usb31_io_usb31_id,
    input  wire         usb31_phy_refclk_p_clk,
    input  wire         usb31_phy_rx_serial_n_i_rx_serial_n,
    input  wire         usb31_phy_rx_serial_p_i_rx_serial_p,
    output wire         usb31_phy_tx_serial_n_o_tx_serial_n,
    output wire         usb31_phy_tx_serial_p_o_tx_serial_p,
    inout  wire         hps_usb1_DATA0,
    inout  wire         hps_usb1_DATA1,
    inout  wire         hps_usb1_DATA2,
    inout  wire         hps_usb1_DATA3,
    inout  wire         hps_usb1_DATA4,
    inout  wire         hps_usb1_DATA5,
    inout  wire         hps_usb1_DATA6,
    inout  wire         hps_usb1_DATA7,
    input  wire         hps_usb1_CLK,
    output wire         hps_usb1_STP,
    input  wire         hps_usb1_DIR,
    input  wire         hps_usb1_NXT,
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
    output wire         hps_emac2_TX_CLK,
    input  wire         hps_emac2_RX_CLK,
    output wire         hps_emac2_TX_CTL,
    input  wire         hps_emac2_RX_CTL,
    output wire         hps_emac2_TXD0,
    output wire         hps_emac2_TXD1,
    input  wire         hps_emac2_RXD0,
    input  wire         hps_emac2_RXD1,
    output wire         hps_emac2_PPS,
    input  wire         hps_emac2_PPS_TRIG,
    output wire         hps_emac2_TXD2,
    output wire         hps_emac2_TXD3,
    input  wire         hps_emac2_RXD2,
    input  wire         hps_emac2_RXD3,
    inout  wire         hps_emac2_MDIO,
    output wire         hps_emac2_MDC,
    input  wire         hps_uart0_RX,
    output wire         hps_uart0_TX,
    inout  wire         hps_i3c1_SDA,
    inout  wire         hps_i3c1_SCL,
    inout  wire         hps_gpio0_io0,
    inout  wire         hps_gpio0_io1,
    inout  wire         hps_gpio0_io11,
    inout  wire         hps_gpio1_io3,
    inout  wire         hps_gpio1_io4,
    //
    // HPS External Oscillator
    input  wire         hps_osc_clk,
    //
    // External warm reset
    // TODO: Kalen to confirm if this is a button
    input  wire         fpga_reset_n
);
    // Constants
    localparam LED_PIO_WIDTH = 32;
    localparam DIPSW_PIO_WIDTH = 32;
    localparam BUTTONS_PIO_WIDTH = 32;

    // Clock and Reset
    wire sys_clk_100;
    wire sys_clk_100_reset_n;

    // Debounce logic to clean out glitches within 1ms
    wire [BUTTONS_PIO_WIDTH-1:0] fpga_debounced_buttons;
    wire [BUTTONS_PIO_WIDTH-1:0] fpga_buttons_pio;
    assign fpga_buttons_pio = {{BUTTONS_PIO_WIDTH - $size(fpga_buttons) {1'b0}}, fpga_buttons};

    debounce #(
        .WIDTH        (32),
        .POLARITY     ("LOW"),
        .TIMEOUT      (10000),  // at 100MHz this is a debounce time of 1ms
        .TIMEOUT_WIDTH(32)      // ceil(log2(TIMEOUT))
    ) debounce_inst (
        .clk     (sys_clk_100),
        .reset_n (sys_clk_100_reset_n),
        .data_in (fpga_buttons_pio),
        .data_out(fpga_debounced_buttons)
    );

    // Assign DIPSW I/O
    wire [DIPSW_PIO_WIDTH-1:0] fpga_dipsw_pio;
    assign fpga_dipsw_pio = {{DIPSW_PIO_WIDTH - $size(fpga_dipsw) {1'b0}}, fpga_dipsw};

    // Create a heartbeat counter
    reg [22:0] heartbeat_count;
    always @(posedge sys_clk_100) begin
        if (!sys_clk_100_reset_n) begin
            heartbeat_count <= '0;
        end else begin
            heartbeat_count <= heartbeat_count + 23'd1;
        end
    end

    // Create a heartbeat LED
    wire heartbeat_led;
    assign heartbeat_led = heartbeat_count[22];

    // LED PIO
    wire [LED_PIO_WIDTH-1:0] fpga_led_pio;

    // Drive the PIN LEDs to be the HPS PIO outputs
    // in addition to the heartbeat LED
    assign fpga_led = {heartbeat_led, fpga_led_pio[2:0]};

    // Tie off all fabric to HPS interrupts
    wire [30:0] f2h_irq1_irq;
    assign f2h_irq1_irq = '0;

    // Synchronize the reset request signal to system clock domain
    // and loopback to the ack signals.
    logic h2f_warm_reset_handshake_reset_ack;
    logic h2f_warm_reset_handshake_reset_req;
    altera_std_synchronizer #(
        .depth(2)
    ) h2f_warm_reset_handshake_reset_req_sync (
        .clk    (sys_clk_100),
        .reset_n(sys_clk_100_reset_n),
        .din    (h2f_warm_reset_handshake_reset_req),
        .dout   (h2f_warm_reset_handshake_reset_ack)
    );

    wire [1:0] usb31_io_usb_ctrl_int;
    assign usb31_io_usb_ctrl = usb31_io_usb_ctrl_int[1];

    // GTS Reset Sequencer IP for transceivers
    wire o_pma_cpu_clk;

    // Baseline system top module
    baseline_top u_baseline_top (
        // FPGA External Clock and Reset
        .fpga_clk_100_clk                               (fpga_clk_100),
        .fpga_reset_n_reset_n                           (fpga_reset_n),
        // 100MHz PLL Clock and Reset to the fabric
        .system_clk_clk                                 (sys_clk_100),
        .system_reset_n_reset_n                         (sys_clk_100_reset_n),
        //
        // HPS Clock
        .hps_io_hps_osc_clk                             (hps_osc_clk),
        // HPS reset to the fabric
        .h2f_warm_reset_handshake_reset_req             (h2f_warm_reset_handshake_reset_req),
        .h2f_warm_reset_handshake_reset_ack             (h2f_warm_reset_handshake_reset_ack),
        //
        .emif_hps_emif_mem_ck_0_mem_ck_t                (emif_hps_emif_mem_0_mem_ck_t),
        .emif_hps_emif_mem_ck_0_mem_ck_c                (emif_hps_emif_mem_0_mem_ck_c),
        .emif_hps_emif_mem_0_mem_a                      (emif_hps_emif_mem_0_mem_a),
        .emif_hps_emif_mem_0_mem_act_n                  (emif_hps_emif_mem_0_mem_act_n),
        .emif_hps_emif_mem_0_mem_ba                     (emif_hps_emif_mem_0_mem_ba),
        .emif_hps_emif_mem_0_mem_bg                     (emif_hps_emif_mem_0_mem_bg),
        .emif_hps_emif_mem_0_mem_cke                    (emif_hps_emif_mem_0_mem_cke),
        .emif_hps_emif_mem_0_mem_cs_n                   (emif_hps_emif_mem_0_mem_cs_n),
        .emif_hps_emif_mem_0_mem_odt                    (emif_hps_emif_mem_0_mem_odt),
        .emif_hps_emif_mem_reset_n_mem_reset_n          (emif_hps_emif_mem_0_mem_reset_n),
        .emif_hps_emif_mem_0_mem_par                    (emif_hps_emif_mem_0_mem_par),
        .emif_hps_emif_mem_0_mem_alert_n                (emif_hps_emif_mem_0_mem_alert_n),
        .emif_hps_emif_mem_0_mem_dqs_t                  (emif_hps_emif_mem_0_mem_dqs_t),
        .emif_hps_emif_mem_0_mem_dqs_c                  (emif_hps_emif_mem_0_mem_dqs_c),
        .emif_hps_emif_mem_0_mem_dq                     (emif_hps_emif_mem_0_mem_dq),
        .emif_hps_emif_oct_0_oct_rzqin                  (emif_hps_emif_oct_0_oct_rzqin),
        .emif_hps_emif_ref_clk_0_clk                    (emif_hps_emif_ref_clk_0_clk),
        //
        .hps_io_jtag_tck                                (hps_jtag_tck),
        .hps_io_jtag_tms                                (hps_jtag_tms),
        .hps_io_jtag_tdo                                (hps_jtag_tdo),
        .hps_io_jtag_tdi                                (hps_jtag_tdi),
        .hps_io_emac2_tx_clk                            (hps_emac2_TX_CLK),
        .hps_io_emac2_rx_clk                            (hps_emac2_RX_CLK),
        .hps_io_emac2_tx_ctl                            (hps_emac2_TX_CTL),
        .hps_io_emac2_rx_ctl                            (hps_emac2_RX_CTL),
        .hps_io_emac2_txd0                              (hps_emac2_TXD0),
        .hps_io_emac2_txd1                              (hps_emac2_TXD1),
        .hps_io_emac2_rxd0                              (hps_emac2_RXD0),
        .hps_io_emac2_rxd1                              (hps_emac2_RXD1),
        .hps_io_emac2_pps                               (hps_emac2_PPS),
        .hps_io_emac2_pps_trig                          (hps_emac2_PPS_TRIG),
        .hps_io_emac2_txd2                              (hps_emac2_TXD2),
        .hps_io_emac2_txd3                              (hps_emac2_TXD3),
        .hps_io_emac2_rxd2                              (hps_emac2_RXD2),
        .hps_io_emac2_rxd3                              (hps_emac2_RXD3),
        .hps_io_mdio2_mdio                              (hps_emac2_MDIO),
        .hps_io_mdio2_mdc                               (hps_emac2_MDC),
        .hps_io_sdmmc_cclk                              (hps_sdmmc_CCLK),
        .hps_io_sdmmc_cmd                               (hps_sdmmc_CMD),
        .hps_io_sdmmc_data0                             (hps_sdmmc_D0),
        .hps_io_sdmmc_data1                             (hps_sdmmc_D1),
        .hps_io_sdmmc_data2                             (hps_sdmmc_D2),
        .hps_io_sdmmc_data3                             (hps_sdmmc_D3),
        .hps_io_i3c1_sda                                (hps_i3c1_SDA),
        .hps_io_i3c1_scl                                (hps_i3c1_SCL),
        .hps_io_uart0_rx                                (hps_uart0_RX),
        .hps_io_uart0_tx                                (hps_uart0_TX),
        .hps_io_usb1_clk                                (hps_usb1_CLK),
        .hps_io_usb1_stp                                (hps_usb1_STP),
        .hps_io_usb1_dir                                (hps_usb1_DIR),
        .hps_io_usb1_nxt                                (hps_usb1_NXT),
        .hps_io_usb1_data0                              (hps_usb1_DATA0),
        .hps_io_usb1_data1                              (hps_usb1_DATA1),
        .hps_io_usb1_data2                              (hps_usb1_DATA2),
        .hps_io_usb1_data3                              (hps_usb1_DATA3),
        .hps_io_usb1_data4                              (hps_usb1_DATA4),
        .hps_io_usb1_data5                              (hps_usb1_DATA5),
        .hps_io_usb1_data6                              (hps_usb1_DATA6),
        .hps_io_usb1_data7                              (hps_usb1_DATA7),
        .hps_io_gpio0                                   (hps_gpio0_io0),
        .hps_io_gpio1                                   (hps_gpio0_io1),
        .hps_io_gpio11                                  (hps_gpio0_io11),
        .hps_io_gpio27                                  (hps_gpio1_io3),
        .hps_io_gpio28                                  (hps_gpio1_io4),
        //
        .usb31_io_vbus_det                              (usb31_io_vbus_det),
        .usb31_io_flt_bar                               (usb31_io_flt_bar),
        .usb31_io_usb_ctrl                              (usb31_io_usb_ctrl_int),
        .usb31_io_usb31_id                              (usb31_io_usb31_id),
        .usb31_phy_refclk_p_clk                         (usb31_phy_refclk_p_clk),
        .usb31_phy_rx_serial_n_i_rx_serial_n            (usb31_phy_rx_serial_n_i_rx_serial_n),
        .usb31_phy_rx_serial_p_i_rx_serial_p            (usb31_phy_rx_serial_p_i_rx_serial_p),
        .usb31_phy_tx_serial_n_o_tx_serial_n            (usb31_phy_tx_serial_n_o_tx_serial_n),
        .usb31_phy_tx_serial_p_o_tx_serial_p            (usb31_phy_tx_serial_p_o_tx_serial_p),
        .usb31_phy_pma_cpu_clk_clk                      (o_pma_cpu_clk),
        // GTS Reset Sequencer
        .o_pma_cu_clk_clk                               (o_pma_cpu_clk),
        // Interrupts
        .f2h_irq1_in_irq                                (f2h_irq1_irq),
        // LEDs, Push Buttons and DIP Switches IOs
        .led_pio_external_connection_export             (fpga_led_pio),
        .dipsw_pio_external_connection_export           (fpga_dipsw_pio),
        .button_pio_external_connection_export          (fpga_debounced_buttons),
        // NiosV subsys PIO
        .niosv_subsys_pio_in_external_connection_export ('0),
        .niosv_subsys_pio_out_external_connection_export()
    );

endmodule
