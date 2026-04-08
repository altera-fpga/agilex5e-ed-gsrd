`timescale 1 ps / 1 ps
//
`default_nettype none

module baseline_a55 (
    // Board PLL reference clock
    input  wire         pll_refclk_100,
    //
    // User switches and LEDs
    output wire [4-1:0] fpga_user_leds,
    input  wire [4-1:0] fpga_user_switches,
    input  wire [4-1:0] fpga_user_push_buttons,
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
    inout  wire [  4:0] emif_hps_emif_mem_0_mem_dbi_n,
    //
    // HPS IO48 Peripherals
    output wire         hps_sdmmc_CCLK,
    inout  wire         hps_sdmmc_CMD,
    inout  wire         hps_sdmmc_D0,
    inout  wire         hps_sdmmc_D1,
    inout  wire         hps_sdmmc_D2,
    inout  wire         hps_sdmmc_D3,
    inout  wire         hps_sdmmc_D4,
    inout  wire         hps_sdmmc_D5,
    inout  wire         hps_sdmmc_D6,
    inout  wire         hps_sdmmc_D7,
    input  wire         hps_sdmmc_WPROT,
    output wire         hps_sdmmc_PWREN,
    output wire         hps_sdmmc_PUD_DATA2,
    input  wire         hps_sdmmc_STROBE,

    output wire hps_emac0_TX_CLK,
    input  wire hps_emac0_RX_CLK,
    output wire hps_emac0_TX_CTL,
    input  wire hps_emac0_RX_CTL,
    output wire hps_emac0_TXD0,
    output wire hps_emac0_TXD1,
    input  wire hps_emac0_RXD0,
    input  wire hps_emac0_RXD1,
    output wire hps_emac0_PPS,
    input  wire hps_emac0_PPS_TRIG,
    output wire hps_emac0_TXD2,
    output wire hps_emac0_TXD3,
    input  wire hps_emac0_RXD2,
    input  wire hps_emac0_RXD3,
    inout  wire hps_emac0_MDIO,
    output wire hps_emac0_MDC,
    input  wire hps_spis1_CLK,
    input  wire hps_spis1_MOSI,
    output wire hps_spis1_MISO,
    input  wire hps_spis1_SS0_N,
    input  wire hps_uart0_RX,
    output wire hps_uart0_TX,
    inout  wire hps_i2c0_SDA,
    inout  wire hps_i2c0_SCL,
    inout  wire hps_i3c1_SDA,
    inout  wire hps_i3c1_SCL,
    inout  wire hps_gpio0_io6,
    inout  wire hps_gpio0_io7,
    inout  wire hps_gpio1_io16,
    inout  wire hps_gpio1_io19,

    //
    // HPS External Oscillator
    input wire hps_osc_clk,
    //
    // External FPGA Reset
    input wire fpga_reset_n
);
    // Constants
    localparam LED_PIO_WIDTH = 32;
    localparam DIPSW_PIO_WIDTH = 32;
    localparam BUTTONS_PIO_WIDTH = 32;

    // Clock and Reset
    wire sys_clk_100;
    wire sys_clk_100_reset_n;

    // Debounce logic to clean out push button glitches within 1ms
    wire [BUTTONS_PIO_WIDTH-1:0] fpga_debounced_buttons;
    wire [BUTTONS_PIO_WIDTH-1:0] fpga_push_buttons;
    assign fpga_push_buttons = {
        {BUTTONS_PIO_WIDTH - $size(fpga_user_push_buttons) {1'b0}}, fpga_user_push_buttons
    };

    debounce #(
        .WIDTH        (32),
        .POLARITY     ("LOW"),
        .TIMEOUT      (10000),  // at 100MHz this is a debounce time of 1ms
        .TIMEOUT_WIDTH(32)      // ceil(log2(TIMEOUT))
    ) debounce_inst (
        .clk     (sys_clk_100),
        .reset_n (sys_clk_100_reset_n),
        .data_in (fpga_push_buttons),
        .data_out(fpga_debounced_buttons)
    );

    // Assign DIPSW I/O
    wire [DIPSW_PIO_WIDTH-1:0] fpga_switches;
    assign fpga_switches = {
        {DIPSW_PIO_WIDTH - $size(fpga_user_switches) {1'b0}}, fpga_user_switches
    };

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
    wire [LED_PIO_WIDTH-1:0] fpga_leds;

    // Drive the USER PIN LEDs to be the HPS LED outputs
    // in addition to the heartbeat LED
    assign fpga_user_leds = {heartbeat_led, fpga_leds[2:0]};

    // Tie off all fabric to HPS interrupts
    wire [31:0] fpga2hps_interrupts;
    assign fpga2hps_interrupts = '0;

    // Directly loop reset request signal to the reset acknowledge signals.
    logic h2f_warm_reset_handshake_reset_ack;
    logic h2f_warm_reset_handshake_reset_req;

    assign h2f_warm_reset_handshake_reset_ack = h2f_warm_reset_handshake_reset_req;

    // Baseline-A55 system top module
    baseline_top u_baseline_top (
        // Board PLL reference clock
        .pll_refclk_100_clk                   (pll_refclk_100),
        // External FPGA reset
        .fpga_reset_n_reset_n                 (fpga_reset_n),
        // System clock and reset to FPGA
        .system_clk_clk                       (sys_clk_100),
        .system_reset_n_reset_n               (sys_clk_100_reset_n),
        //
        //HPS
        // HPS Clock
        .hps_io_hps_osc_clk                   (hps_osc_clk),
        // HPS reset to the fabric
        .h2f_warm_reset_handshake_reset_req   (h2f_warm_reset_handshake_reset_req),
        .h2f_warm_reset_handshake_reset_ack   (h2f_warm_reset_handshake_reset_ack),
        // HPS EMIF interface
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
        .emif_hps_emif_mem_0_mem_dbi_n        (emif_hps_emif_mem_0_mem_dbi_n),
        // HPS Peripherals
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
        .hps_io_sdmmc_data4                   (hps_sdmmc_D4),
        .hps_io_sdmmc_data5                   (hps_sdmmc_D5),
        .hps_io_sdmmc_data6                   (hps_sdmmc_D6),
        .hps_io_sdmmc_data7                   (hps_sdmmc_D7),
        .hps_io_sdmmc_wprot                   (hps_sdmmc_WPROT),
        .hps_io_sdmmc_pud_data2               (hps_sdmmc_PUD_DATA2),
        .hps_io_sdmmc_pwren                   (hps_sdmmc_PWREN),
        .hps_io_sdmmc_strobe                  (hps_sdmmc_STROBE),
        .hps_io_i2c0_sda                      (hps_i2c0_SDA),
        .hps_io_i2c0_scl                      (hps_i2c0_SCL),
        .hps_io_i3c1_sda                      (hps_i3c1_SDA),
        .hps_io_i3c1_scl                      (hps_i3c1_SCL),
        .hps_io_uart0_rx                      (hps_uart0_RX),
        .hps_io_uart0_tx                      (hps_uart0_TX),
        .hps_io_spis1_clk                     (hps_spis1_CLK),
        .hps_io_spis1_mosi                    (hps_spis1_MOSI),
        .hps_io_spis1_miso                    (hps_spis1_MISO),
        .hps_io_spis1_ss0_n                   (hps_spis1_SS0_N),
        .hps_io_gpio6                         (hps_gpio0_io6),
        .hps_io_gpio7                         (hps_gpio0_io7),
        .hps_io_gpio40                        (hps_gpio1_io16),
        .hps_io_gpio43                        (hps_gpio1_io19),
        //
        // Interrupts
        .f2h_interrupts_irq                   (fpga2hps_interrupts),
        //
        // LEDs, Push Buttons and DIP Switches IOs
        .user_leds_export                     (fpga_leds),
        .user_switches_export                 (fpga_switches),
        .user_push_buttons_export             (fpga_debounced_buttons),
        //
        // NiosV subsys PIO
        .niosv_pio_in_export                  ('0),
        .niosv_pio_out_export                 ()
    );

endmodule
