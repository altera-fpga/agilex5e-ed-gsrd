`timescale 1 ps / 1 ps
//
`default_nettype none

module desktop_linux_dp (
    // Board PLL reference clock
    input  wire         pll_refclk_100,
    //
    // Switches and LEDs
    output wire [1-1:0] fpga_user_leds,
    input  wire [2-1:0] fpga_user_switches,
    input  wire [1-1:0] fpga_user_push_buttons,
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
    inout  wire         hps_i2c_emac1_SDA,
    inout  wire         hps_i2c_emac1_SCL,
    inout  wire         hps_gpio0_io0,
    inout  wire         hps_gpio0_io10,
    inout  wire         hps_gpio1_io3,
    inout  wire         hps_gpio1_io4,
    //
    // HPS USB1 (3.1) IO interface
    input  wire         usb31_io_vbus_det,
    input  wire         usb31_io_flt_bar,
    output wire         usb31_io_usb_ctrl,
    input  wire         usb31_io_usb31_id,
    input  wire         usb31_phy_refclk_p,
    input  wire         usb31_phy_rx_serial_n,
    input  wire         usb31_phy_rx_serial_p,
    output wire         usb31_phy_tx_serial_n,
    output wire         usb31_phy_tx_serial_p,
    //
    // HPS External Oscillator
    input  wire         hps_osc_clk,
    //
    // External FPGA Reset
    input  wire         fpga_reset_n,
    //
    // DisplayPort GTS 150MHz reference clock
    input  wire         dp_gts_refclk_150_clk,
    output wire [  3:0] dp_tx_p,
    output wire [  3:0] dp_tx_n,
    //
    // DisplayPort Redriver I2C interface
    // inout  wire    board_i2c_scl,
    // inout  wire    board_i2c_sda,
    //
    // DisplayPort Auxiliary I/O
    // output wire    dp_tx_cad; // cable detect, not used in this design
    input  wire         dp_tx_hpd_n,
    input  wire         dp_tx_aux_in,
    output wire         dp_tx_aux_out,
    output wire         dp_tx_aux_oe
);
    // Constants
    localparam LED_PIO_WIDTH = 32;
    localparam DIPSW_PIO_WIDTH = 32;
    localparam BUTTONS_PIO_WIDTH = 32;

    // Clock and Reset
    wire sys_clk_148_5;
    wire sys_reset_n;

    // NiosV PIO
    wire [31:0] niosv_pio_in;
    // Set this bit to enable the NiosV firmware. Disabled by default.
    wire nios_enable = 1'b0;
    assign niosv_pio_in = {31'b0, nios_enable};

    wire [31:0] niosv_pio_out;
    wire nios_start;
    wire nios_done;
    wire nios_f2h_pass;
    assign nios_start = niosv_pio_out[0];
    assign nios_f2h_pass = niosv_pio_out[2];
    assign nios_done = niosv_pio_out[3];

    // Debounce logic to clean out glitches within 1ms
    wire [BUTTONS_PIO_WIDTH-1:0] fpga_debounced_buttons;
    wire [BUTTONS_PIO_WIDTH-1:0] fpga_push_buttons;

    assign fpga_push_buttons = {
        {(BUTTONS_PIO_WIDTH - $bits(fpga_user_push_buttons)) {1'b0}}, fpga_user_push_buttons
    };

    debounce #(
        .WIDTH        (BUTTONS_PIO_WIDTH),
        .POLARITY     ("LOW"),
        .TIMEOUT      (14850),              // at 148.5MHz this is a debounce time of 1ms
        .TIMEOUT_WIDTH(16)                  // ceil(log2(TIMEOUT))
    ) debounce_inst (
        .clk     (sys_clk_148_5),
        .reset_n (sys_reset_n),
        .data_in (fpga_push_buttons),
        .data_out(fpga_debounced_buttons)
    );

    // Assign DIPSW I/O
    wire [DIPSW_PIO_WIDTH-1:0] fpga_switches;
    assign fpga_switches = {
        {DIPSW_PIO_WIDTH - $size(fpga_user_switches) {1'b0}}, fpga_user_switches
    };

    // LED PIO
    wire [LED_PIO_WIDTH-1:0] fpga_leds;
    assign fpga_user_leds = fpga_leds[0];

    // Tie off all fabric to HPS interrupts
    wire [30:0] fpga2hps_interrupts;
    assign fpga2hps_interrupts = '0;

    // Directly loop reset request signal to the reset acknowledge signals.
    logic h2f_warm_reset_handshake_reset_ack;
    logic h2f_warm_reset_handshake_reset_req;

    assign h2f_warm_reset_handshake_reset_ack = h2f_warm_reset_handshake_reset_req;

    wire [1:0] usb31_io_usb_ctrl_int;
    assign usb31_io_usb_ctrl = usb31_io_usb_ctrl_int[1];

    // PMA control unit clock output from GTS Reset Sequencer IP.
    // This signal connects to the usb3.1 transceiver PMA clock input.
    wire gts_pma_cpu_clk;
    wire usb31_phy_pma_cpu_clk;
    assign usb31_phy_pma_cpu_clk = gts_pma_cpu_clk;

    // DisplayPort: fabric nets between dp_source, GTS, and XCVR interfaces
    wire dp_tx_hpd;
    wire [159:0] dp_tx_parallel_data;
    wire dp_txpll_locked;
    wire [0:0] dp_tx_std_clkout;
    wire dp_tx_analog_rcfg_req;
    wire dp_tx_analog_rcfg_ack;
    wire [7:0] dp_tx_analog_rcfg_vod;
    wire [7:0] dp_tx_analog_rcfg_emp;
    wire [7:0] dp_tx_link_rate;
    wire dp_tx_rate_rcfg_req;
    wire dp_tx_rate_rcfg_ack;
    wire dp_tx_rate_rcfg_busy;

    // DP Redriver I2C interface
    // assign board_i2c_scl_in = board_i2c_scl;
    // assign board_i2c_sda_in = board_i2c_sda;
    // assign board_i2c_scl = board_i2c_scl_oe ? 1'b0 : 1'bz;
    // assign board_i2c_sda = board_i2c_sda_oe ? 1'b0 : 1'bz;

    // DP cable detect, not used in this design
    // assign dp_tx_cad = 1'b0;

    // Hot Plug Detect signal
    assign dp_tx_hpd = ~dp_tx_hpd_n;

    wire [31:0] dp_source_pio_board;
    wire dp_tx_vid_clk;
    // Tx Pixel Clock Gen
    logic [7:0] clk_148_cnt;
    wire [7:0] clk_148_set;
    logic clk_148_en;

    assign clk_148_set = dp_source_pio_board[7:0];

    // altera_std_synchronizer_bundle #(
    //     .depth(3),
    //     .width(8)
    // ) u_clk_sync (
    //     .clk    (sys_clk_148_5),
    //     .reset_n(1'b1),
    //     .din    (dp_source_pio_board[7:0]),
    //     .dout   (clk_148_set)
    // );

    always_ff @(negedge sys_reset_n or posedge sys_clk_148_5) begin
        if (!sys_reset_n) begin
            clk_148_cnt <= '0;
            clk_148_en <= 1'b0;
        end else begin
            if (!clk_148_cnt) begin
                clk_148_cnt <= clk_148_set;
                clk_148_en <= 1'b1;
            end else begin
                clk_148_en <= 1'b0;
                clk_148_cnt <= clk_148_cnt - 1'b1;
            end
        end
    end

    // Clock Gate control for video clock
    dp_clk_ctrl u_dp_clk_ctrl (
        .ena   (clk_148_en),
        .inclk (sys_clk_148_5),
        .outclk(dp_tx_vid_clk)
    );

    // Desktop Linux DP system top module
    desktop_linux_dp_top u_desktop_linux_dp_top (
        // Board PLL reference clock
        .fpga_clk_100_clk                                    (pll_refclk_100),
        // External FPGA reset
        .fpga_reset_n_reset_n                                (fpga_reset_n),
        // System clock and reset to FPGA
        .system_clock_clk                                    (sys_clk_148_5),
        .system_reset_n_reset_n                              (sys_reset_n),
        //
        //HPS
        // HPS Clock
        .hps_io_hps_osc_clk                                  (hps_osc_clk),
        // HPS reset to the fabric
        .h2f_warm_reset_handshake_reset_req                  (h2f_warm_reset_handshake_reset_req),
        .h2f_warm_reset_handshake_reset_ack                  (h2f_warm_reset_handshake_reset_ack),
        // HPS EMIF interface
        .emif_hps_emif_mem_ck_0_mem_ck_t                     (emif_hps_emif_mem_0_mem_ck_t),
        .emif_hps_emif_mem_ck_0_mem_ck_c                     (emif_hps_emif_mem_0_mem_ck_c),
        .emif_hps_emif_mem_0_mem_a                           (emif_hps_emif_mem_0_mem_a),
        .emif_hps_emif_mem_0_mem_act_n                       (emif_hps_emif_mem_0_mem_act_n),
        .emif_hps_emif_mem_0_mem_ba                          (emif_hps_emif_mem_0_mem_ba),
        .emif_hps_emif_mem_0_mem_bg                          (emif_hps_emif_mem_0_mem_bg),
        .emif_hps_emif_mem_0_mem_cke                         (emif_hps_emif_mem_0_mem_cke),
        .emif_hps_emif_mem_0_mem_cs_n                        (emif_hps_emif_mem_0_mem_cs_n),
        .emif_hps_emif_mem_0_mem_odt                         (emif_hps_emif_mem_0_mem_odt),
        .emif_hps_emif_mem_reset_n_mem_reset_n               (emif_hps_emif_mem_0_mem_reset_n),
        .emif_hps_emif_mem_0_mem_par                         (emif_hps_emif_mem_0_mem_par),
        .emif_hps_emif_mem_0_mem_alert_n                     (emif_hps_emif_mem_0_mem_alert_n),
        .emif_hps_emif_mem_0_mem_dqs_t                       (emif_hps_emif_mem_0_mem_dqs_t),
        .emif_hps_emif_mem_0_mem_dqs_c                       (emif_hps_emif_mem_0_mem_dqs_c),
        .emif_hps_emif_mem_0_mem_dq                          (emif_hps_emif_mem_0_mem_dq),
        .emif_hps_emif_oct_0_oct_rzqin                       (emif_hps_emif_oct_0_oct_rzqin),
        .emif_hps_emif_ref_clk_0_clk                         (emif_hps_emif_ref_clk_0_clk),
        .emif_hps_emif_mem_0_mem_dbi_n                       (emif_hps_emif_mem_0_mem_dbi_n),
        // HPS Peripherals
        .hps_io_jtag_tck                                     (hps_jtag_tck),
        .hps_io_jtag_tms                                     (hps_jtag_tms),
        .hps_io_jtag_tdo                                     (hps_jtag_tdo),
        .hps_io_jtag_tdi                                     (hps_jtag_tdi),
        .hps_io_emac2_tx_clk                                 (hps_emac2_TX_CLK),
        .hps_io_emac2_rx_clk                                 (hps_emac2_RX_CLK),
        .hps_io_emac2_tx_ctl                                 (hps_emac2_TX_CTL),
        .hps_io_emac2_rx_ctl                                 (hps_emac2_RX_CTL),
        .hps_io_emac2_txd0                                   (hps_emac2_TXD0),
        .hps_io_emac2_txd1                                   (hps_emac2_TXD1),
        .hps_io_emac2_rxd0                                   (hps_emac2_RXD0),
        .hps_io_emac2_rxd1                                   (hps_emac2_RXD1),
        .hps_io_emac2_pps                                    (hps_emac2_PPS),
        .hps_io_emac2_pps_trig                               (hps_emac2_PPS_TRIG),
        .hps_io_emac2_txd2                                   (hps_emac2_TXD2),
        .hps_io_emac2_txd3                                   (hps_emac2_TXD3),
        .hps_io_emac2_rxd2                                   (hps_emac2_RXD2),
        .hps_io_emac2_rxd3                                   (hps_emac2_RXD3),
        .hps_io_mdio2_mdio                                   (hps_emac2_MDIO),
        .hps_io_mdio2_mdc                                    (hps_emac2_MDC),
        .hps_io_sdmmc_cclk                                   (hps_sdmmc_CCLK),
        .hps_io_sdmmc_cmd                                    (hps_sdmmc_CMD),
        .hps_io_sdmmc_data0                                  (hps_sdmmc_D0),
        .hps_io_sdmmc_data1                                  (hps_sdmmc_D1),
        .hps_io_sdmmc_data2                                  (hps_sdmmc_D2),
        .hps_io_sdmmc_data3                                  (hps_sdmmc_D3),
        .hps_io_i2c_emac1_sda                                (hps_i2c_emac1_SDA),
        .hps_io_i2c_emac1_scl                                (hps_i2c_emac1_SCL),
        .hps_io_uart0_rx                                     (hps_uart0_RX),
        .hps_io_uart0_tx                                     (hps_uart0_TX),
        .hps_io_usb1_clk                                     (hps_usb1_CLK),
        .hps_io_usb1_stp                                     (hps_usb1_STP),
        .hps_io_usb1_dir                                     (hps_usb1_DIR),
        .hps_io_usb1_nxt                                     (hps_usb1_NXT),
        .hps_io_usb1_data0                                   (hps_usb1_DATA0),
        .hps_io_usb1_data1                                   (hps_usb1_DATA1),
        .hps_io_usb1_data2                                   (hps_usb1_DATA2),
        .hps_io_usb1_data3                                   (hps_usb1_DATA3),
        .hps_io_usb1_data4                                   (hps_usb1_DATA4),
        .hps_io_usb1_data5                                   (hps_usb1_DATA5),
        .hps_io_usb1_data6                                   (hps_usb1_DATA6),
        .hps_io_usb1_data7                                   (hps_usb1_DATA7),
        .hps_io_gpio0                                        (hps_gpio0_io0),
        .hps_io_gpio10                                       (hps_gpio0_io10),
        .hps_io_gpio27                                       (hps_gpio1_io3),
        .hps_io_gpio28                                       (hps_gpio1_io4),
        // HPS USB1 (3.1) interface
        .usb31_io_vbus_det                                   (usb31_io_vbus_det),
        .usb31_io_flt_bar                                    (usb31_io_flt_bar),
        .usb31_io_usb_ctrl                                   (usb31_io_usb_ctrl_int),
        .usb31_io_usb31_id                                   (usb31_io_usb31_id),
        .usb31_phy_refclk_p_clk                              (usb31_phy_refclk_p),
        .usb31_phy_rx_serial_n_i_rx_serial_n                 (usb31_phy_rx_serial_n),
        .usb31_phy_rx_serial_p_i_rx_serial_p                 (usb31_phy_rx_serial_p),
        .usb31_phy_tx_serial_n_o_tx_serial_n                 (usb31_phy_tx_serial_n),
        .usb31_phy_tx_serial_p_o_tx_serial_p                 (usb31_phy_tx_serial_p),
        .usb31_phy_pma_cpu_clk_clk                           (usb31_phy_pma_cpu_clk),
        //
        // GTS Reset Sequencer IP PMA clock output
        .o_pma_cu_clk_clk                                    (gts_pma_cpu_clk),
        //
        // Interrupts
        .f2h_interrupts_irq                                  (fpga2hps_interrupts),
        //
        // LEDs, Push Buttons and DIP Switches IOs
        .user_leds_export                                    (fpga_leds),
        .user_switches_export                                (fpga_switches),
        .user_push_buttons_export                            (fpga_debounced_buttons),
        //
        // NiosV subsys PIO
        .niosv_pio_in_export                                 (niosv_pio_in),
        .niosv_pio_out_export                                (niosv_pio_out),
        //
        // Display Port Subsystem
        .vfr_fsync_in_read                                   (1'b0),
        .dp_source_tx_xcvr_interface_tx_parallel_data        (dp_tx_parallel_data),
        .dp_source_tx_xcvr_interface_tx_pll_powerdown        (),
        .dp_source_tx_xcvr_interface_tx_analogreset          (),
        .dp_source_tx_xcvr_interface_tx_digitalreset         (),
        .dp_source_tx_xcvr_interface_tx_cal_busy             ('0),
        .dp_source_tx_xcvr_interface_tx_std_clkout           (dp_tx_std_clkout),
        .dp_source_tx_xcvr_interface_tx_pll_locked           (dp_txpll_locked),
        .dp_source_tx_aux_tx_aux_in                          (dp_tx_aux_in),
        .dp_source_tx_aux_tx_aux_out                         (dp_tx_aux_out),
        .dp_source_tx_aux_tx_aux_oe                          (dp_tx_aux_oe),
        .dp_source_tx_aux_tx_hpd                             (dp_tx_hpd),
        .dp_source_tx_analog_reconfig_tx_analog_reconfig_req (dp_tx_analog_rcfg_req),
        .dp_source_tx_analog_reconfig_tx_analog_reconfig_ack (dp_tx_analog_rcfg_ack),
        .dp_source_tx_analog_reconfig_tx_analog_reconfig_busy(),
        .dp_source_tx_analog_reconfig_tx_vod                 (dp_tx_analog_rcfg_vod),
        .dp_source_tx_analog_reconfig_tx_emp                 (dp_tx_analog_rcfg_emp),
        .dp_source_tx_reconfig_tx_link_rate                  (),
        .dp_source_tx_reconfig_tx_link_rate_8bits            (dp_tx_link_rate),
        .dp_source_tx_reconfig_tx_reconfig_req               (dp_tx_rate_rcfg_req),
        .dp_source_tx_reconfig_tx_reconfig_ack               (dp_tx_rate_rcfg_ack),
        .dp_source_tx_reconfig_tx_reconfig_busy              (dp_tx_rate_rcfg_busy),
        .dp_source_tx_vid_clk_clk                            (dp_tx_vid_clk),
        .dp_source_pio_board_out_export                      (dp_source_pio_board),
        .dp_gts_refclk_150_clk                               (dp_gts_refclk_150_clk),
        .dp_gts_tx_clk_clk                                   (dp_tx_std_clkout),
        .dp_gts_dp_tx_serial_tx_p                            (dp_tx_p),
        .dp_gts_dp_tx_serial_tx_n                            (dp_tx_n),
        .dp_gts_dp_tx_tx_link_rate                           (dp_tx_link_rate),
        .dp_gts_dp_tx_tx_rate_rcfg_req                       (dp_tx_rate_rcfg_req),
        .dp_gts_dp_tx_tx_rate_rcfg_ack                       (dp_tx_rate_rcfg_ack),
        .dp_gts_dp_tx_tx_rate_rcfg_busy                      (dp_tx_rate_rcfg_busy),
        .dp_gts_dp_tx_tx_reconfig_en                         (1'b1),
        .dp_gts_dp_tx_tx_analog_rcfg_req                     (dp_tx_analog_rcfg_req),
        .dp_gts_dp_tx_tx_analog_rcfg_ack                     (dp_tx_analog_rcfg_ack),
        .dp_gts_dp_tx_tx_analog_rcfg_vod                     (dp_tx_analog_rcfg_vod),
        .dp_gts_dp_tx_tx_analog_rcfg_emp                     (dp_tx_analog_rcfg_emp),
        .dp_gts_dp_tx_tx_analog_rcfg_ffe                     ('0),
        .dp_gts_dp_tx_tx_parallel_data                       (dp_tx_parallel_data),
        .dp_gts_dp_tx_tx_pll_locked                          (dp_txpll_locked),
        .dp_srcss_gts_i_src_rs_priority_src_rs_priority      ('0),
        .dp_srcss_gts_o_refclk_fail_status_refclk_fail_status(),
        .dp_srcss_gts_o_refclk_on_ack_refclk_on_ack          (),
        .dp_srcss_gts_i_refclk_on_refclk_on                  ('0)
    );

endmodule
