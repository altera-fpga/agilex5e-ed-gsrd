`timescale 1 ps / 1 ps `default_nettype none

module testbench ();

    //==================================================================================================
    // Local Signals
    //==================================================================================================

    // Clock and reset
    logic clk100M;
    wire system_clock;
    wire system_reset;

    // DUT signals
    wire [3:0] fpga_led_pio;
    logic [3:0] fpga_dipsw_pio;
    logic [3:0] fpga_button_pio;

    // Tie off inputs to HPS
    assign fpga_button_pio = '0;
    assign fpga_dipsw_pio = '0;

    //==================================================================================================
    // DUT
    //==================================================================================================
    baseline dut (

        // FPGA fabric Clock
        .fpga_clk_100                       (clk100M),
        //
        // Switches and LEDs
        .fpga_led                           (fpga_led_pio),
        .fpga_dipsw                         (fpga_dipsw_pio),
        .fpga_buttons                       (fpga_button_pio),
        //
        //HPS
        //
        // HPS EMIF
        .emif_hps_emif_mem_0_mem_ck_t       (),
        .emif_hps_emif_mem_0_mem_ck_c       (),
        .emif_hps_emif_mem_0_mem_a          (),
        .emif_hps_emif_mem_0_mem_act_n      (),
        .emif_hps_emif_mem_0_mem_ba         (),
        .emif_hps_emif_mem_0_mem_bg         (),
        .emif_hps_emif_mem_0_mem_cke        (),
        .emif_hps_emif_mem_0_mem_cs_n       (),
        .emif_hps_emif_mem_0_mem_odt        (),
        .emif_hps_emif_mem_0_mem_reset_n    (),
        .emif_hps_emif_mem_0_mem_par        (),
        .emif_hps_emif_mem_0_mem_alert_n    ('0),
        .emif_hps_emif_oct_0_oct_rzqin      ('0),
        .emif_hps_emif_ref_clk_0_clk        ('0),
        .emif_hps_emif_mem_0_mem_dqs_t      (),
        .emif_hps_emif_mem_0_mem_dqs_c      (),
        .emif_hps_emif_mem_0_mem_dq         (),
        //
        // HPS Peripherals
        .usb31_io_vbus_det                  ('0),
        .usb31_io_flt_bar                   ('0),
        .usb31_io_usb_ctrl                  (),
        .usb31_io_usb31_id                  ('0),
        .usb31_phy_refclk_p_clk             ('0),
        .usb31_phy_rx_serial_n_i_rx_serial_n('1),
        .usb31_phy_rx_serial_p_i_rx_serial_p('0),
        .usb31_phy_tx_serial_n_o_tx_serial_n(),
        .usb31_phy_tx_serial_p_o_tx_serial_p(),
        .hps_usb1_DATA0                     (),
        .hps_usb1_DATA1                     (),
        .hps_usb1_DATA2                     (),
        .hps_usb1_DATA3                     (),
        .hps_usb1_DATA4                     (),
        .hps_usb1_DATA5                     (),
        .hps_usb1_DATA6                     (),
        .hps_usb1_DATA7                     (),
        .hps_usb1_CLK                       ('0),
        .hps_usb1_STP                       (),
        .hps_usb1_DIR                       ('0),
        .hps_usb1_NXT                       ('0),
        .hps_jtag_tck                       ('0),
        .hps_jtag_tms                       ('0),
        .hps_jtag_tdo                       (),
        .hps_jtag_tdi                       ('0),
        .hps_sdmmc_CCLK                     (),
        .hps_sdmmc_CMD                      (),
        .hps_sdmmc_D0                       (),
        .hps_sdmmc_D1                       (),
        .hps_sdmmc_D2                       (),
        .hps_sdmmc_D3                       (),
        .hps_emac2_TX_CLK                   (),
        .hps_emac2_RX_CLK                   ('0),
        .hps_emac2_TX_CTL                   (),
        .hps_emac2_RX_CTL                   ('0),
        .hps_emac2_TXD0                     (),
        .hps_emac2_TXD1                     (),
        .hps_emac2_RXD0                     ('0),
        .hps_emac2_RXD1                     ('0),
        .hps_emac2_PPS                      (),
        .hps_emac2_PPS_TRIG                 ('0),
        .hps_emac2_TXD2                     (),
        .hps_emac2_TXD3                     (),
        .hps_emac2_RXD2                     ('0),
        .hps_emac2_RXD3                     ('0),
        .hps_emac2_MDIO                     (),
        .hps_emac2_MDC                      (),
        .hps_uart0_RX                       ('0),
        .hps_uart0_TX                       (),
        .hps_i3c1_SDA                       (),
        .hps_i3c1_SCL                       (),
        .hps_gpio0_io0                      (),
        .hps_gpio0_io1                      (),
        .hps_gpio0_io11                     (),
        .hps_gpio1_io3                      (),
        .hps_gpio1_io4                      (),
        //
        // HPS External Oscillator
        .hps_osc_clk                        ('0),
        //
        // External warm reset
        // TODO: Kalen to confirm if this is a button
        .fpga_reset_n                       ('1)
    );

    //==================================================================================================
    // clk and reset
    //==================================================================================================

    // Clock generators
    initial begin
        clk100M <= 1'b0;
        forever begin
            #5ns clk100M <= ~clk100M;  // 100MHz
        end
    end

    //==================================================================================================
    // Simulation Main
    //==================================================================================================
    initial begin
        #10ns;

        $display("Waiting for Reset to de-assert");
        fork : wait_reset
            begin
                while (dut.sys_clk_100_reset_n != 1'b1) begin
                    @clk100M;
                end
            end
            begin
                #10000ns $fatal("INIT_DONE not asserted");
            end
        join_any
        disable wait_reset;
        $display("Reset de-asserted");

        // Post reset cycles
        repeat (10) @clk100M;

        $display("Simulation complete");
        #0 $finish(1);

    end

endmodule
