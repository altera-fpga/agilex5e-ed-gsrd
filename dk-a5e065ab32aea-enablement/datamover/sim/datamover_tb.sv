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
    logic fpga_reset_n;

    //==================================================================================================
    // DUT
    //==================================================================================================
    datamover dut (

        // FPGA fabric Clock
        .pll_refclk_100                 (clk100M),
        //
        //HPS
        //
        // HPS EMIF
        .emif_hps_emif_mem_0_mem_ck_t   (),
        .emif_hps_emif_mem_0_mem_ck_c   (),
        .emif_hps_emif_mem_0_mem_a      (),
        .emif_hps_emif_mem_0_mem_act_n  (),
        .emif_hps_emif_mem_0_mem_ba     (),
        .emif_hps_emif_mem_0_mem_bg     (),
        .emif_hps_emif_mem_0_mem_cke    (),
        .emif_hps_emif_mem_0_mem_cs_n   (),
        .emif_hps_emif_mem_0_mem_odt    (),
        .emif_hps_emif_mem_0_mem_reset_n(),
        .emif_hps_emif_mem_0_mem_par    (),
        .emif_hps_emif_mem_0_mem_alert_n('0),
        .emif_hps_emif_oct_0_oct_rzqin  ('0),
        .emif_hps_emif_ref_clk_0_clk    ('0),
        .emif_hps_emif_mem_0_mem_dqs_t  (),
        .emif_hps_emif_mem_0_mem_dqs_c  (),
        .emif_hps_emif_mem_0_mem_dq     (),
        //
        // HPS Peripherals
        .usb31_io_vbus_det              ('0),
        .usb31_io_flt_bar               ('0),
        .usb31_io_usb_ctrl              (),
        .usb31_io_usb31_id              ('0),
        .usb31_phy_refclk_p             ('0),
        .usb31_phy_rx_serial_n          ('1),
        .usb31_phy_rx_serial_p          ('0),
        .usb31_phy_tx_serial_n          (),
        .usb31_phy_tx_serial_p          (),
        .hps_usb1_DATA0                 (),
        .hps_usb1_DATA1                 (),
        .hps_usb1_DATA2                 (),
        .hps_usb1_DATA3                 (),
        .hps_usb1_DATA4                 (),
        .hps_usb1_DATA5                 (),
        .hps_usb1_DATA6                 (),
        .hps_usb1_DATA7                 (),
        .hps_usb1_CLK                   ('0),
        .hps_usb1_STP                   (),
        .hps_usb1_DIR                   ('0),
        .hps_usb1_NXT                   ('0),
        .hps_jtag_tck                   ('0),
        .hps_jtag_tms                   ('0),
        .hps_jtag_tdo                   (),
        .hps_jtag_tdi                   ('0),
        .hps_sdmmc_CCLK                 (),
        .hps_sdmmc_CMD                  (),
        .hps_sdmmc_D0                   (),
        .hps_sdmmc_D1                   (),
        .hps_sdmmc_D2                   (),
        .hps_sdmmc_D3                   (),
        .hps_emac2_TX_CLK               (),
        .hps_emac2_RX_CLK               ('0),
        .hps_emac2_TX_CTL               (),
        .hps_emac2_RX_CTL               ('0),
        .hps_emac2_TXD0                 (),
        .hps_emac2_TXD1                 (),
        .hps_emac2_RXD0                 ('0),
        .hps_emac2_RXD1                 ('0),
        .hps_emac2_PPS                  (),
        .hps_emac2_PPS_TRIG             ('0),
        .hps_emac2_TXD2                 (),
        .hps_emac2_TXD3                 (),
        .hps_emac2_RXD2                 ('0),
        .hps_emac2_RXD3                 ('0),
        .hps_emac2_MDIO                 (),
        .hps_emac2_MDC                  (),
        .hps_uart0_RX                   ('0),
        .hps_uart0_TX                   (),
        .hps_i3c1_SDA                   (),
        .hps_i3c1_SCL                   (),
        .hps_gpio0_io0                  (),
        .hps_gpio0_io1                  (),
        .hps_gpio0_io11                 (),
        .hps_gpio1_io3                  (),
        .hps_gpio1_io4                  (),
        //
        // HPS External Oscillator
        .hps_osc_clk                    ('0),
        //
        // External FPGA Reset
        .fpga_reset_n                   (fpga_reset_n)
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

    // Crete a simulation watchdog to avoid infinite simulation runs
    initial begin
        #40000000ns;
        $display("Test Timeout...");
        $display("Datamover Simulation Test Failed!");
        $finish;
    end

    // Reset sequence
    initial begin
        $display("Assert Reset");
        fpga_reset_n = 1'b0;

        // Hold reset for 10 clock cycles
        repeat (10) @(posedge clk100M);

        $display("De-assert Reset");
        fpga_reset_n = 1'b1;
        #10ns;

        $display("Waiting for Reset to de-assert");
        fork : wait_reset
            begin
                fork
                    begin
                        while (dut.sys_clk_250_reset_n != 1'b1) begin
                            @clk100M;
                        end
                    end
                    begin
                        while (dut.usb31_pr_reset_n != 1'b1) begin
                            @clk100M;
                        end
                    end
                join
            end
            begin
                #10000ns $fatal("INIT_DONE not asserted");
            end
        join_any
        disable wait_reset;

        $display("Reset successfully de-asserted");
        $display("Datamover Simulation Test Passed!");
        #0 $finish(1);
    end

    // For VCSMX simulator - uncomment this section to enable VPD waveform dump for debug.
    // Run dve -vpd dump.vpd to view waveforms after simulation completes.
    // initial begin
    //     $vcdplusfile("dump.vpd");
    //     $vcdpluson(0, testbench);
    //     $vcdplusmemon(0, testbench);
    // end


endmodule
