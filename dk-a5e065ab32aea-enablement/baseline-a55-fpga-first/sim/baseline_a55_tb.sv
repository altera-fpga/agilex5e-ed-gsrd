`timescale 1 ps / 1 ps
//
`default_nettype none

// import libraries
import altera_axi_bfm_pkg::*;
import host_memory_class_pkg::*;
import hps_h2f_pkg::*;
import hps_h2f_lw_pkg::*;

// Define a helper macro for easier access to the HPS2FPGA BFM instance
`define h2f_bfm_m dut.u_baseline_top.u_shell_subsys.u_hps_subsys.u_agilex_hps.intel_agilex_5_soc_inst.sm_hps.sundancemesa_hps_inst.h2f_bfm_gen.h2f_axi4_master_inst
`define lwh2f_bfm_m dut.u_baseline_top.u_shell_subsys.u_hps_subsys.u_agilex_hps.intel_agilex_5_soc_inst.sm_hps.sundancemesa_hps_inst.lwh2f_bfm_gen.lwh2f_axi4_master_inst
`define f2sdram_test_s dut.u_baseline_top.u_shell_subsys.u_hps_subsys.u_agilex_hps.intel_agilex_5_soc_inst.sm_mpfe.sundancemesa_mpfe_inst.f2sdram_bfm_gen.f2sdram_axi4_slave_inst
`define f2h_sub_bfm dut.u_baseline_top.u_shell_subsys.u_hps_subsys.u_agilex_hps.intel_agilex_5_soc_inst.sm_mpfe.sundancemesa_mpfe_inst.f2soc_bfm_gen.f2h_ace5lite_slave_inst


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
    wire [3:0] fpga_led_pio;
    wire [3:0] fpga_dipsw_pio = '0;
    wire [3:0] fpga_button_pio = '0;

    // Test flag
    bit h2f_pass = 1;
    bit lwh2f_pass = 1;
    bit f2sdram_pass = 1;
    bit f2h_pass = 1;
    int f2h_txn_count = 0;
    int f2h_r_count = 0;
    logic [255:0] f2h_rd_data[2];
    bit test_pass = 1;
    bit reset_done;

    // hps2fpga test flag
    bit h2f_f1 = 0;
    bit h2f_f2 = 0;
    bit h2f_f3 = 0;
    bit h2f_f4 = 0;
    bit h2f_f5 = 0;
    bit h2f_f6 = 0;

    string h2f_messageQueue[$];
    task automatic h2f_storeMessage(input string msg);
        string formattedMsg = $sformatf("[%0t] %s", $time, msg);
        h2f_messageQueue.push_back(formattedMsg);
    endtask

    // lwhps2fpga test flag
    bit lwh2f_f1 = 0;
    bit lwh2f_f2 = 0;
    bit lwh2f_f3 = 0;
    bit lwh2f_f4 = 0;
    bit lwh2f_f5 = 0;
    bit lwh2f_f6 = 0;

    string lwh2f_messageQueue[$];
    task automatic lwh2f_storeMessage(input string msg);
        string formattedMsg = $sformatf("[%0t] %s", $time, msg);
        lwh2f_messageQueue.push_back(formattedMsg);
    endtask
    // F2SDRAM
    string f2sdram_messageQueue[$];
    task automatic f2sdram_storeMessage(input string msg);
        string formattedMsg = $sformatf("[%0t] %s", $time, msg);
        f2sdram_messageQueue.push_back(formattedMsg);
    endtask

    // F2H
    string f2h_messageQueue[$];
    task automatic f2h_storeMessage(input string msg);
        string formattedMsg = $sformatf("[%0t] %s", $time, msg);
        f2h_messageQueue.push_back(formattedMsg);
    endtask

    //==================================================================================================
    // DUT
    //==================================================================================================
    baseline_a55 dut (

        // FPGA fabric Clock
        .pll_refclk_100                 (clk100M),
        //
        // Switches and LEDs
        .fpga_user_leds                 (fpga_led_pio),
        .fpga_user_switches             (fpga_dipsw_pio),
        .fpga_user_push_buttons         (fpga_button_pio),
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
    // HPS2FPGA AXI4 Object handles.
    //==================================================================================================
    AlteraAxiTransaction h2f_wr_tr, h2f_rd_tr;

    //---------------------------------------------------------
    // LWHPS2FPGA AXI4 Object handles.
    //---------------------------------------------------------
    AlteraAxiTransaction lwh2f_wr_tr, lwh2f_rd_tr;

    // Enable BFM debug mode
    //assign `h2f_bfm_m.dbg = 1;

    // Print initialization of the BFMs
    initial begin
        `h2f_bfm_m.AXI4MAN.bfm.hello();
        `lwh2f_bfm_m.AXI4MAN.bfm.hello();
    end

    // Check if the nios_mem.hex file exists, and error out if it doesn't.
    initial begin
        if ($fopen("nios_mem.hex", "r") == 0) begin
            $fatal(
                1,
                "Missing nios_mem.hex in simulation working directory. Generate/copy it before running simulation.");
        end
    end

    //==================================================================================================
    // Testbench tasks
    //==================================================================================================
    task wait_for_nios_done();
        //print(VERBOSITY_INFO, "Waiting for Nios Done");
        fork : wait_watched
            begin
                while (dut.nios_done != 1'b1) begin
                    @clk100M;
                end
            end
            begin
                #100ms;
                //print(VERBOSITY_FAILURE, "Nios Done not received");
                $fatal;
            end
        join_any
        disable wait_watched;
        //print(VERBOSITY_INFO, "Nios Done received");
    endtask

    task wait_for_nios_start();
        //print(VERBOSITY_INFO, "Waiting for Nios Start");
        fork : wait_watched
            begin
                while (dut.nios_start != 1'b1) begin
                    @clk100M;
                end
            end
            begin
                #10ms;
                //print(VERBOSITY_FAILURE, "Nios Start not received");
                $fatal;
            end
        join_any
        disable wait_watched;
        //print(VERBOSITY_INFO, "Nios Start received");
    endtask

    //==================================================================================================
    // Simulation Overrides
    //==================================================================================================

    // Override the behavior of the HPS IP generated reset. Use the input bridge
    // reset to hold the simulation model BFM in reset until the PLL clock is stable.
    initial begin
        force dut.u_baseline_top.u_shell_subsys.u_hps_subsys.u_agilex_hps.intel_agilex_5_soc_inst.sm_hps.sundancemesa_hps_inst.h2f_bfm_gen.h2f_axi4_master_inst.rstn = !dut.u_baseline_top.u_shell_subsys.u_hps_subsys.u_agilex_hps.intel_agilex_5_soc_inst.sm_hps.hps2fpga_rst;
        force dut.u_baseline_top.u_shell_subsys.u_hps_subsys.u_agilex_hps.intel_agilex_5_soc_inst.sm_hps.sundancemesa_hps_inst.lwh2f_bfm_gen.lwh2f_axi4_master_inst.rstn = !dut.u_baseline_top.u_shell_subsys.u_hps_subsys.u_agilex_hps.intel_agilex_5_soc_inst.sm_hps.hps2fpga_rst;
        //force dut.u_baseline_top.u_shell_subsys.u_hps_subsys.u_agilex_hps.intel_agilex_5_soc_inst.sm_mpfe.sundancemesa_mpfe_inst.f2sdram_bfm_gen.f2sdram_axi4_slave_inst.rstn = !dut.u_baseline_top.u_shell_subsys.u_hps_subsys.u_agilex_hps.intel_agilex_5_soc_inst.sm_mpfe.f2sdram_rst;
        #2001ns;
        force dut.u_baseline_top.u_shell_subsys.u_hps_subsys.u_agilex_hps.intel_agilex_5_soc_inst.sm_mpfe.sundancemesa_mpfe_inst.f2sdram_bfm_gen.f2sdram_axi4_slave_inst.rstn = !dut.u_baseline_top.u_shell_subsys.u_hps_subsys.u_agilex_hps.intel_agilex_5_soc_inst.sm_mpfe.f2sdram_rst;
    end

    //==================================================================================================
    // Simulation Main
    //==================================================================================================

    // Crete a simulation watchdog to avoid infinite simulation runs
    initial begin
        #40000000ns;
        $display("Test Timeout...");
        $display("Baseline Simulation Test Failed!");
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
                #10000ns;
                if (!reset_done) $fatal("INIT_DONE not asserted");
            end
        join_none

        fork
            begin
                while (dut.sys_clk_100_reset_n != 1'b1) begin
                    @clk100M;
                end
            end
            `h2f_bfm_m.AXI4MAN.bfm.m_reset();
            `lwh2f_bfm_m.AXI4MAN.bfm.m_reset();
            `f2sdram_test_s.AXI4SUB.bfm.s_reset();
        join

        `h2f_bfm_m.AXI4MAN.bfm.do_collect_responses();
        `lwh2f_bfm_m.AXI4MAN.bfm.do_collect_responses();
        reset_done = 1;

        // Post reset cycles
        repeat (10) @(posedge clk100M);

        // Begin HPS to FPGA Bridge Test
        fork : bridge_test
            // Enable NiosV traffic generator for F2SDRAM and F2H test.
            begin
                force dut.nios_enable = 1'b1;
            end

            begin
                // Sync this thread to the BFM clock
                repeat (5) @(`h2f_bfm_m.m_cb);
                `h2f_bfm_m.AXI4MAN.bfm.set_config(AXI_CONFIG_MAX_HANDSHAKE_TIMEOUT, 1000);

                h2f_storeMessage("*******************************************************");
                h2f_storeMessage("**************** Test HPS2FPGA Bridge *****************");
                h2f_storeMessage("*******************************************************");
                h2f_storeMessage("[TESTINFO]: Test Sequence for Write Started");

                h2f_storeMessage("*************** START OF First Write TEST ***************\n");
                h2f_storeMessage(
                    "HPS2FPGA Write #1 - Write data (128'haaaaaaaa_11111111_a1a1a1a1_0a100a10) at OCRAM_BASE_ADDR");
                $display("\n@%0t, ************ HPS2FPGA - START OF WRITE TEST **********\n", $time);

                // Create write transaction
                // manager_bfm_wr_tx(<id>, <addr>, <data>, <burst_len>, <burst_size>, <burst_type>, <awvalid>, <wvalid>, <bready>, <wlast>);
                h2f_wr_tr = `h2f_bfm_m.AXI4MAN.bfm.manager_bfm_wr_tx(1, H2F_OCRAM_BASE_ADDR);
                // Configure write transaction
                h2f_wr_tr.set_burst_length(0);
                h2f_wr_tr.set_size(AXI4_BYTES_16);
                h2f_wr_tr.set_burst_type(BURST_TYPE_FIXED);
                h2f_wr_tr.set_data_words(128'haaaaaaaa_11111111_a1a1a1a1_0a100a10, 0);
                h2f_wr_tr.set_write_strobes(16'hffff, 0);
                // Execute write transaction
                `h2f_bfm_m.AXI4MAN.bfm.put_transaction(h2f_wr_tr);
                `h2f_bfm_m.AXI4MAN.bfm.drive_transaction();
                h2f_storeMessage("*************** END OF First Write TEST ***************\n");

                /////////////////////////////////////////////////////////////////////////////////

                h2f_storeMessage("[TESTINFO]: Test for Second Write Started");
                h2f_storeMessage("*************** START OF SECOND Write TEST ***************\n");
                h2f_storeMessage(
                    "HPS2FPGA Write #2 - Write data (128'hbbbbbbbb_22222222_b2b2b2b2_0b200b20) at OCRAM_BASE_ADDR + 32");

                h2f_wr_tr = `h2f_bfm_m.AXI4MAN.bfm.manager_bfm_wr_tx(
                    2, H2F_OCRAM_BASE_ADDR + 32, 0, 0, AXI4_BYTES_16, BURST_TYPE_FIXED);
                h2f_wr_tr.set_data_words(128'hbbbbbbbb_22222222_b2b2b2b2_0b200b20, 0);
                `h2f_bfm_m.AXI4MAN.bfm.put_transaction(h2f_wr_tr);
                `h2f_bfm_m.AXI4MAN.bfm.drive_transaction();
                h2f_storeMessage("*************** END OF Second Write TEST ***************\n");

                /////////////////////////////////////////////////////////////////////////////////

                h2f_storeMessage("[TESTINFO]: Test Sequence for Read Started");
                h2f_storeMessage("*************** START OF FIRST Read TEST ***************\n");
                $display("\n@%0t, ************ HPS2FPGA - START OF READ TEST **********\n", $time);

                // Create read transaction
                // manager_bfm_rd_tx(<id>, <addr>, <burst_len>, <burst_size>, <burst_type>, <arvalid>, <rready>);
                h2f_rd_tr = `h2f_bfm_m.AXI4MAN.bfm.manager_bfm_rd_tx(1, H2F_OCRAM_BASE_ADDR);
                // Configure read transaction
                h2f_rd_tr.set_size(AXI4_BYTES_16);
                // Execute read transaction
                `h2f_bfm_m.AXI4MAN.bfm.put_transaction(h2f_rd_tr);
                `h2f_bfm_m.AXI4MAN.bfm.drive_transaction();
                // Verify read data
                if (h2f_rd_tr.get_data_words(0) == 128'haaaaaaaa_11111111_a1a1a1a1_0a100a10) begin
                    h2f_f1 = 1'b1;  // Set flag to indicate success
                    h2f_storeMessage($sformatf("value of h2f_f1 is %b", h2f_f1));
                    h2f_storeMessage(
                        "manager sanity test: Read correct data (128'haaaaaaaa_11111111_a1a1a1a1_0a100a10) at address (0)");
                end else begin
                    h2f_storeMessage($sformatf(
                                     "manager sanity test: Error: Expected data (128'haaaaaaaa_11111111_a1a1a1a1_0a100a10) at address 0, but got %h",
                                     h2f_rd_tr.get_data_words(
                                         0
                                     )
                                     ));
                end
                h2f_storeMessage("*************** END OF First Read TEST ***************\n");

                ////////////////////////////////////////////////////////////////////////////////

                h2f_storeMessage("*************** START OF SECOND Read TEST ***************\n");

                // Create read transaction
                h2f_rd_tr = `h2f_bfm_m.AXI4MAN.bfm.manager_bfm_rd_tx(2, H2F_OCRAM_BASE_ADDR + 32);
                h2f_rd_tr.set_size(AXI4_BYTES_16);
                // Execute read transaction
                `h2f_bfm_m.AXI4MAN.bfm.put_transaction(h2f_rd_tr);
                `h2f_bfm_m.AXI4MAN.bfm.drive_transaction();
                // Verify read data
                if (h2f_rd_tr.get_data_words(0) == 128'hbbbbbbbb_22222222_b2b2b2b2_0b200b20) begin
                    h2f_f2 = 1'b1;  // Set flag to indicate success
                    h2f_storeMessage($sformatf("value of h2f_f2 is %b", h2f_f2));
                    h2f_storeMessage(
                        "manager sanity test: Read correct data (128'hbbbbbbbb_22222222_b2b2b2b2_0b200b20) at address (32)");
                end else begin
                    h2f_storeMessage($sformatf(
                                     "manager sanity test: Error: Expected data (128'hbbbbbbbb_22222222_b2b2b2b2_0b200b20) at address 32, but got %h",
                                     h2f_rd_tr.get_data_words(
                                         0
                                     )
                                     ));
                end
                h2f_storeMessage("*************** END OF Second Read TEST ***************\n");

                /////////////////////////////////////////////////////////////////////////////////

                h2f_storeMessage("[TESTINFO]: Test Sequence for Burst Transaction Started");
                $display("\n@%0t, **** HPS2FPGA - START OF Burst Transaction TEST ****\n", $time);

                // Create burst write transactions
                // manager_bfm_wr_tx(<id>, <addr>, <data>, <burst_len>, <burst_size>, <burst_type>, <awvalid>, <wvalid>, <bready>, <wlast>);
                h2f_wr_tr = `h2f_bfm_m.AXI4MAN.bfm.manager_bfm_wr_tx(4, H2F_OCRAM_BASE_ADDR + 16);
                h2f_wr_tr.set_burst_length(3);
                h2f_wr_tr.set_size(AXI4_BYTES_16);
                h2f_wr_tr.set_burst_type(BURST_TYPE_INCR);
                h2f_wr_tr.set_data_words('hfab0fab1, 0);
                h2f_wr_tr.set_data_words('hfab2fab3, 1);
                h2f_wr_tr.set_data_words('hfab4fab5, 2);
                h2f_wr_tr.set_data_words('hfab6fab7, 3);
                h2f_wr_tr.set_write_strobes(16'hffff, 0);
                h2f_wr_tr.set_write_strobes(16'hffff, 1);
                h2f_wr_tr.set_write_strobes(16'hffff, 2);
                h2f_wr_tr.set_write_strobes(16'hffff, 3);
                `h2f_bfm_m.AXI4MAN.bfm.put_transaction(h2f_wr_tr);
                `h2f_bfm_m.AXI4MAN.bfm.drive_transaction();

                // Create burst read transactions
                h2f_rd_tr = `h2f_bfm_m.AXI4MAN.bfm.manager_bfm_rd_tx(4, H2F_OCRAM_BASE_ADDR + 16);
                h2f_rd_tr.set_burst_length(3);
                h2f_rd_tr.set_size(AXI4_BYTES_16);
                h2f_rd_tr.set_burst_type(BURST_TYPE_INCR);
                `h2f_bfm_m.AXI4MAN.bfm.put_transaction(h2f_rd_tr);
                `h2f_bfm_m.AXI4MAN.bfm.drive_transaction();

                if (h2f_rd_tr.get_data_words(0) == 'hfab0fab1) begin
                    h2f_f3 = 1'b1;
                    h2f_storeMessage(
                        "master_test_program: Read correct data (hfab0fab1) at H2F_OCRAM_BASE_ADDR+16");
                end else begin
                    h2f_storeMessage($sformatf(
                                     "master_test_program: Error: Expected data (hfab0fab1) at H2F_OCRAM_BASE_ADDR+16, but got %h",
                                     h2f_rd_tr.get_data_words(
                                         0
                                     )
                                     ));
                end

                if (h2f_rd_tr.get_data_words(1) == 'hfab2fab3) begin
                    h2f_f4 = 1'b1;
                    h2f_storeMessage(
                        "master_test_program: Read correct data (hfab2fab3) at H2F_OCRAM_BASE_ADDR+32");
                end else begin
                    h2f_storeMessage($sformatf(
                                     "master_test_program: Error: Expected data (hfab2fab3) at H2F_OCRAM_BASE_ADDR+32, but got %h",
                                     h2f_rd_tr.get_data_words(
                                         1
                                     )
                                     ));
                end

                if (h2f_rd_tr.get_data_words(2) == 'hfab4fab5) begin
                    h2f_f5 = 1'b1;
                    h2f_storeMessage(
                        "master_test_program: Read correct data (hfab4fab5) at H2F_OCRAM_BASE_ADDR+48");
                end else begin
                    h2f_storeMessage($sformatf(
                                     "master_test_program: Error: Expected data (hfab4fab5) at H2F_OCRAM_BASE_ADDR+48, but got %h",
                                     h2f_rd_tr.get_data_words(
                                         2
                                     )
                                     ));
                end

                if (h2f_rd_tr.get_data_words(3) == 'hfab6fab7) begin
                    h2f_f6 = 1'b1;
                    h2f_storeMessage(
                        "master_test_program: Read correct data (hfab6fab7) at H2F_OCRAM_BASE_ADDR+64");
                end else begin
                    h2f_storeMessage($sformatf(
                                     "master_test_program: Error: Expected data (hfab6fab7) at H2F_OCRAM_BASE_ADDR+64, but got %h",
                                     h2f_rd_tr.get_data_words(
                                         3
                                     )
                                     ));
                end

                if(h2f_f1==1'b1 && h2f_f2==1'b1 && h2f_f3==1'b1 && h2f_f4==1'b1 && h2f_f5==1'b1 && h2f_f6==1'b1) begin
                    h2f_storeMessage("HPS2FPGA Test Pass!\n");
                    h2f_pass = 1;
                end else begin
                    h2f_storeMessage("HPS2FPGA Test Fail!\n");
                    h2f_pass = 0;
                end
            end

            begin
                // Sync this thread to the BFM clock
                @(`lwh2f_bfm_m.m_cb);

                lwh2f_storeMessage("*******************************************************");
                lwh2f_storeMessage("*************** Test LWHPS2FPGA Bridge *****************");
                lwh2f_storeMessage("*******************************************************");
                lwh2f_storeMessage("[TESTINFO]: Test Sequence for Write Started");

                lwh2f_storeMessage("*************** START OF First Write TEST ***************\n");
                lwh2f_storeMessage(
                    "LWHPS2FPGA Write #1 - Write data (32'haaaaaaaa) at LWH2F_LED_PIO_BASE_ADDR");
                $display("\n@%0t, ************ LWHPS2FPGA - START OF WRITE TEST **********\n",
                         $time);

                lwh2f_wr_tr =
                    `lwh2f_bfm_m.AXI4MAN.bfm.manager_bfm_wr_tx(2, LWH2F_LED_PIO_BASE_ADDR);
                lwh2f_wr_tr.set_size(AXI4_BYTES_4);
                lwh2f_wr_tr.set_burst_length(0);
                lwh2f_wr_tr.set_burst_type(BURST_TYPE_FIXED);
                lwh2f_wr_tr.set_data_words(32'haaaaaaaa, 0);
                lwh2f_wr_tr.set_write_strobes(4'hf, 0);
                `lwh2f_bfm_m.AXI4MAN.bfm.put_transaction(lwh2f_wr_tr);
                `lwh2f_bfm_m.AXI4MAN.bfm.drive_transaction();
                lwh2f_storeMessage("*************** END OF First Write TEST ***************\n");

                /////////////////////////////////////////////////////////////////////////////////

                lwh2f_storeMessage("[TESTINFO]: Test Sequence for Read Started");

                lwh2f_storeMessage("*************** START OF FIRST Read TEST ***************\n");
                lwh2f_storeMessage("LWHPS2FPGA Read #1 at LWH2F_SYSID_BASE_ADDR");
                lwh2f_rd_tr = `lwh2f_bfm_m.AXI4MAN.bfm.manager_bfm_rd_tx(1, LWH2F_SYSID_BASE_ADDR);
                lwh2f_rd_tr.set_size(AXI4_BYTES_4);
                lwh2f_rd_tr.set_burst_length(0);
                lwh2f_rd_tr.set_burst_type(BURST_TYPE_FIXED);
                `lwh2f_bfm_m.AXI4MAN.bfm.put_transaction(lwh2f_rd_tr);
                `lwh2f_bfm_m.AXI4MAN.bfm.drive_transaction();
                if (lwh2f_rd_tr.get_data_words(0) == LWH2F_SYSID_VALUE) begin
                    lwh2f_f1 = 1'b1;
                    lwh2f_storeMessage($sformatf("value of lwh2f_f1 is %b", lwh2f_f1));
                    lwh2f_storeMessage($sformatf(
                                       "manager sanity test: Read correct data %h at LWH2F_SYSID_BASE_ADDR",
                                       LWH2F_SYSID_VALUE
                                       ));
                end else begin
                    lwh2f_storeMessage($sformatf(
                                       "manager sanity test: Error: Expected data %h at LWH2F_SYSID_BASE_ADDR, but got %h",
                                       LWH2F_SYSID_VALUE,
                                       lwh2f_rd_tr.get_data_words(
                                           0
                                       )
                                       ));
                end
                lwh2f_storeMessage("*************** END OF First Read TEST ***************\n");

                ////////////////////////////////////////////////////////////////////////////////

                lwh2f_storeMessage("*************** START OF SECOND Read TEST ***************\n");
                lwh2f_storeMessage("LWHPS2FPGA Read #2 at LWH2F_LED_PIO_BASE_ADDR");
                lwh2f_rd_tr =
                    `lwh2f_bfm_m.AXI4MAN.bfm.manager_bfm_rd_tx(2, LWH2F_LED_PIO_BASE_ADDR);
                lwh2f_rd_tr.set_size(AXI4_BYTES_4);
                lwh2f_rd_tr.set_burst_length(0);
                lwh2f_rd_tr.set_burst_type(BURST_TYPE_FIXED);
                `lwh2f_bfm_m.AXI4MAN.bfm.put_transaction(lwh2f_rd_tr);
                `lwh2f_bfm_m.AXI4MAN.bfm.drive_transaction();
                if (lwh2f_rd_tr.get_data_words(0) == 32'haaaaaaaa) begin
                    lwh2f_f2 = 1'b1;
                    lwh2f_storeMessage($sformatf("value of lwh2f_f2 is %b", lwh2f_f2));
                    lwh2f_storeMessage(
                        "manager sanity test: Read correct data (32'haaaaaaaa) at LWH2F_LED_PIO_BASE_ADDR");
                end else begin
                    lwh2f_storeMessage($sformatf(
                                       "manager sanity test: Error: Expected data (32'haaaaaaaa) at LWH2F_LED_PIO_BASE_ADDR, but got %h",
                                       lwh2f_rd_tr.get_data_words(
                                           0
                                       )
                                       ));
                end
                lwh2f_storeMessage("*************** END OF Second Read TEST ***************\n");

                /////////////////////////////////////////////////////////////////////////////////


                if (lwh2f_f1 == 1'b1 && lwh2f_f2 == 1'b1) begin
                    lwh2f_storeMessage("LWH2F Test Pass!");
                    lwh2f_pass = 1;
                end else begin
                    lwh2f_storeMessage("LWH2F Test Fail!");
                    lwh2f_pass = 0;
                end
            end

            begin
                // Sync this thread to the BFM clock
                @(`f2sdram_test_s.s_cb);

                f2sdram_storeMessage("*******************************************************");
                f2sdram_storeMessage("*************** Test F2SDRAM Bridge *****************");
                f2sdram_storeMessage("*******************************************************");

                wait_for_nios_start();
                f2sdram_storeMessage("[TESTINFO]: Test Sequence for F2SDRAM Started");

                wait_for_nios_done();
                // Wait some additional cycles for the Nios test program to complete
                repeat (1000) @clk100M;
                f2sdram_storeMessage("*************** END OF F2SDRAM TEST ***************\n");

                /////////////////////////////////////////////////////////////////////////////////

                if (dut.nios_f2sdram_pass == 1'b1) begin
                    f2sdram_storeMessage("F2SDRAM Test Pass!");
                    f2sdram_pass = 1;
                end else begin
                    f2sdram_storeMessage("F2SDRAM Test Fail!");
                    f2sdram_pass = 0;
                end
            end

            begin
                f2h_storeMessage("*******************************************************");
                f2h_storeMessage("**************** Test FPGA2HPS Bridge *****************");
                f2h_storeMessage("*******************************************************");

                // Wait for F2H subordinate reset to fully deassert before running check,
                // keep NiosV as the only manager generating F2H traffic.
                if (`f2h_sub_bfm.ace5_lite_bus.rst_n === 1'b0) begin
                    wait (`f2h_sub_bfm.ace5_lite_bus.rst_n === 1'b1);
                end else begin
                    f2h_storeMessage("[TESTINFO]: F2H subordinate reset already deasserted");
                end
                repeat (100) @clk100M;

                wait_for_nios_start();
                f2h_storeMessage("[TESTINFO]: Test Sequence for F2H Started (NiosV manager)");

                // Monitor F2H ACE5-Lite subordinate for traffic while waiting for NiosV done.
                // If no R handshakes are seen, no F2H read data was returned.
                begin : f2h_nios_done_with_monitor
                    f2h_txn_count = 0;
                    f2h_r_count = 0;
                    fork
                        begin
                            wait_for_nios_done();
                        end
                        begin : f2h_traffic_mon
                            while (dut.nios_done !== 1'b1) begin
                                @(posedge clk100M);
                                if (`f2h_sub_bfm.ace5_lite_bus.awvalid === 1'b1 &&
                                     `f2h_sub_bfm.ace5_lite_bus.awready === 1'b1)
                                    f2h_txn_count++;
                                if (`f2h_sub_bfm.ace5_lite_bus.arvalid === 1'b1 &&
                                     `f2h_sub_bfm.ace5_lite_bus.arready === 1'b1)
                                    f2h_txn_count++;
                                if (`f2h_sub_bfm.ace5_lite_bus.rvalid === 1'b1 &&
                                     `f2h_sub_bfm.ace5_lite_bus.rready === 1'b1) begin
                                    f2h_r_count++;
                                    if (f2h_r_count <= 2)
                                        f2h_rd_data[f2h_r_count-1] = `f2h_sub_bfm.ace5_lite_bus.rdata;
                                    if (f2h_r_count <= 8)
                                        f2h_storeMessage($sformatf(
                                                         "[READDATA]: F2H [%0d] = 0x%h",
                                                         f2h_r_count,
                                                         `f2h_sub_bfm.ace5_lite_bus.rdata
                                                         ));
                                end
                            end
                        end : f2h_traffic_mon
                    join
                    if (f2h_txn_count == 0)
                        f2h_storeMessage("[WARNING]: NiosV F2H traffic not observed");
                    else
                        f2h_storeMessage($sformatf(
                                         "[TESTINFO]: NiosV F2H traffic observed: %0d transaction(s)",
                                         f2h_txn_count
                                         ));
                    if (f2h_r_count == 0)
                        f2h_storeMessage("[WARNING]: No F2H read data beat observed");
                    else
                        f2h_storeMessage(
                            $sformatf("[TESTINFO]: F2H read data beats observed: %0d", f2h_r_count
                            ));
                end : f2h_nios_done_with_monitor
                // Wait some additional cycles for the NiosV test program to complete
                repeat (1000) @clk100M;

                // Display captured F2H read data (pass/fail determined by NiosV firmware via nios_f2h_pass PIO).
                if (f2h_r_count >= 1)
                    f2h_storeMessage($sformatf(
                                     "[READDATA]: F2H captured beat [1] = 0x%h", f2h_rd_data[0]));
                if (f2h_r_count >= 2)
                    f2h_storeMessage($sformatf(
                                     "[READDATA]: F2H captured beat [2] = 0x%h", f2h_rd_data[1]));

                f2h_storeMessage("*************** END OF F2H TEST ***************\n");

                /////////////////////////////////////////////////////////////////////////////////

                if (dut.nios_f2h_pass == 1'b1) begin
                    f2h_storeMessage("FPGA2HPS Test Pass!");
                    f2h_pass = 1;
                end else begin
                    f2h_storeMessage("FPGA2HPS Test Fail!");
                    f2h_pass = 0;
                end
            end
        join

        foreach (h2f_messageQueue[i]) begin
            $display("%s", h2f_messageQueue[i]);
        end
        foreach (lwh2f_messageQueue[i]) begin
            $display("%s", lwh2f_messageQueue[i]);
        end
        foreach (f2sdram_messageQueue[i]) begin
            $display("%s", f2sdram_messageQueue[i]);
        end
        foreach (f2h_messageQueue[i]) begin
            $display("%s", f2h_messageQueue[i]);
        end

        $display("@%0t*********************************************", $time);
        $display("@%0t************** TEST SUMMARY *****************", $time);
        $display("@%0t*********************************************", $time);
        if (h2f_pass) begin
            $display("HPS2FPGA Test -- PASS");
        end else begin
            $display("HPS2FPGA Test -- FAIL");
            test_pass = 0;
        end
        if (lwh2f_pass) begin
            $display("LWHPS2FPGA Test -- PASS");
        end else begin
            $display("LWHPS2FPGA Test -- FAIL");
            test_pass = 0;
        end
        if (f2sdram_pass) begin
            $display("F2SDRAM Test -- PASS");
        end else begin
            $display("F2SDRAM Test -- FAIL");
            test_pass = 0;
        end
        if (f2h_pass) begin
            $display("F2H Test -- PASS");
        end else begin
            $display("F2H Test -- FAIL");
            test_pass = 0;
        end

        if (test_pass == 0) begin
            $fatal("Baseline Simulation Test Failed!");
        end else begin
            $display("\n@%0t**************** END OF TEST ****************\n", $time);
            $display("\n@%0t************ Simulation complete ************\n", $time);
            #0 $finish(1);
        end
    end

    // f2sdram subordinate
    initial begin

        // Sync this thread to the BFM clock
        @(`f2sdram_test_s.s_cb);

        // NiosV test program takes some time to initialize after reset,
        // so wait for the NiosV to indicate it has started before starting the BFM transactions.
        wait_for_nios_start();

        $display("\n@%0t, [TESTINFO]: Test Sequence for F2SDRAM Started\n", $time);
        `f2sdram_test_s.AXI4SUB.bfm.set_config(AXI_CONFIG_MAX_OUTSTANDING_WR, 2);
        `f2sdram_test_s.AXI4SUB.bfm.run();
    end

    // For VCSMX simulator - uncomment this section to enable VPD waveform dump for debug.
    // Run dve -vpd dump.vpd to view waveforms after simulation completes.
    // initial begin
    //     $vcdplusfile("dump.vpd");
    //     $vcdpluson(0, testbench);
    //     $vcdplusmemon(0, testbench);
    // end


endmodule
