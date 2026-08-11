//****************************************************************************
//
// SPDX-License-Identifier: MIT-0
// SPDX-FileCopyrightText: Copyright (C) 2026 Altera Corporation
//
//****************************************************************************
//
// fpga2hps_msgdma2axi4
//
//****************************************************************************

`timescale 1 ps / 1 ps
//
`default_nettype none

module fpga2hps_msgdma2axi4 (
    // Clock and Reset
    input wire clk,   //      clk.clk
    input wire reset, //    reset.reset

    // Avalon MM read agent
    input  wire [ 31:0] s0_read_address,        //  s0_read.address
    input  wire         s0_read_read,           //         .read
    input  wire [ 31:0] s0_read_byteenable,     //         .byteenable	// data width related
    output wire [255:0] s0_read_readdata,       //         .readdata		// data width related
    output wire         s0_read_waitrequest,    //         .waitrequest
    output wire         s0_read_readdatavalid,  //         .readdatavalid
    input  wire [  7:0] s0_read_burstcount,     //         .burstcount	// data width related

    // Avalon MM read agent
    input  wire [ 31:0] s1_write_address,      // s1_write.address
    input  wire         s1_write_write,        //         .write
    input  wire [ 31:0] s1_write_byteenable,   //         .byteenable	// data width related
    input  wire [255:0] s1_write_writedata,    //         .writedata	// data width related
    output wire         s1_write_waitrequest,  //         .waitrequest
    input  wire [  7:0] s1_write_burstcount,   //         .burstcount	// data width related

    // AXI4 manager
    output wire [ 37:0] m0_araddr,   //       m0.araddr
    output wire [  1:0] m0_arburst,  //         .arburst
    output wire [  3:0] m0_arcache,  //         .arcache
    output wire         m0_arid,     //         .arid
    output wire [  7:0] m0_arlen,    //         .arlen
    output wire         m0_arlock,   //         .arlock
    output wire [  2:0] m0_arprot,   //         .arprot
    input  wire         m0_arready,  //         .arready
    output wire [  2:0] m0_arsize,   //         .arsize
    output wire         m0_arvalid,  //         .arvalid
    output wire [ 37:0] m0_awaddr,   //         .awaddr
    output wire [  1:0] m0_awburst,  //         .awburst
    output wire [  3:0] m0_awcache,  //         .awcache
    output wire         m0_awid,     //         .awid
    output wire [  7:0] m0_awlen,    //         .awlen
    output wire         m0_awlock,   //         .awlock
    output wire [  2:0] m0_awprot,   //         .awprot
    input  wire         m0_awready,  //         .awready
    output wire [  2:0] m0_awsize,   //         .awsize
    output wire         m0_awvalid,  //         .awvalid
    input  wire         m0_bid,      //         .bid
    output wire         m0_bready,   //         .bready
    input  wire [  1:0] m0_bresp,    //         .bresp
    input  wire         m0_bvalid,   //         .bvalid
    input  wire [255:0] m0_rdata,    //         .rdata		// data width related
    input  wire         m0_rid,      //         .rid
    input  wire         m0_rlast,    //         .rlast
    output wire         m0_rready,   //         .rready
    input  wire [  1:0] m0_rresp,    //         .rresp
    input  wire         m0_rvalid,   //         .rvalid
    output wire [255:0] m0_wdata,    //         .wdata		// data width related
    output wire         m0_wlast,    //         .wlast
    input  wire         m0_wready,   //         .wready
    output wire [ 31:0] m0_wstrb,    //         .wstrb		// data width related
    output wire         m0_wvalid    //         .wvalid
);

    localparam integer AVMM_ADDR_WIDTH = 32;
    localparam integer AXI_ADDR_WIDTH = 38;
    localparam integer ADDR_PAD_BITS = AXI_ADDR_WIDTH - AVMM_ADDR_WIDTH;
    localparam integer AXI_BURST_WIDTH = 2;
    localparam integer AXI_CACHE_WIDTH = 4;
    localparam integer AXI_ID_WIDTH = 1;
    localparam integer AXI_PROT_WIDTH = 3;
    localparam integer AXI_SIZE_WIDTH = 3;

    // AXI constants
    localparam [AXI_BURST_WIDTH-1:0] AXI_BURST_INCR = 2'b01;
    localparam [AXI_CACHE_WIDTH-1:0] AXI_CACHE = 4'b0000;
    localparam [AXI_ID_WIDTH-1:0] AXI_ID = 1'b0;
    localparam [AXI_PROT_WIDTH-1:0] AXI_PROT = 3'b011;
    localparam [AXI_SIZE_WIDTH-1:0] AXI_SIZE = 3'b101;

    // ===============================
    // Registers
    // ===============================
    logic wr_command_phase;
    logic [7:0] wr_burstcount;  // data width related

    always_ff @(posedge clk) begin
        if (reset) begin
            wr_command_phase <= 1'b1;
            wr_burstcount <= 8'h00;  // data width related
        end else begin
            if (m0_awvalid & m0_awready) begin
                wr_command_phase <= 1'b0;
                wr_burstcount <= s1_write_burstcount;
            end

            if (m0_wvalid & m0_wready) begin
                if (wr_burstcount == 8'd1) begin  // data width related
                    wr_command_phase <= 1'b1;
                end
                wr_burstcount <= wr_burstcount - 8'd1;  // data width related
            end
        end
    end

    assign s0_read_readdata = m0_rdata;
    assign s0_read_readdatavalid = m0_rvalid;
    assign s0_read_waitrequest = ~m0_arready;

    assign s1_write_waitrequest = wr_command_phase | ~m0_wready | (wr_burstcount == 8'h00);	// data width related

    assign m0_araddr = {{ADDR_PAD_BITS{1'b0}}, s0_read_address};
    assign m0_arburst = AXI_BURST_INCR;
    assign m0_arcache = AXI_CACHE;
    assign m0_arid = AXI_ID;
    assign m0_arlen = s0_read_burstcount - 8'd1;
    assign m0_arlock = 1'b0;
    assign m0_arprot = AXI_PROT;
    assign m0_arsize = AXI_SIZE;
    assign m0_arvalid = s0_read_read;

    assign m0_awaddr = {{ADDR_PAD_BITS{1'b0}}, s1_write_address};
    assign m0_awburst = AXI_BURST_INCR;
    assign m0_awcache = AXI_CACHE;
    assign m0_awid = AXI_ID;
    assign m0_awlen = s1_write_burstcount - 8'd1;
    assign m0_awlock = 1'b0;
    assign m0_awprot = AXI_PROT;
    assign m0_awsize = AXI_SIZE;
    assign m0_awvalid = s1_write_write & wr_command_phase;

    assign m0_bready = 1'b1;  // ALWAYS READY

    assign m0_rready = 1'b1;  // ALWAYS READY

    assign m0_wstrb = s1_write_byteenable;
    assign m0_wdata = s1_write_writedata;
    assign m0_wlast = (wr_burstcount == 8'h01) ? 1'b1 : 1'b0;  // data width related
    assign m0_wvalid = s1_write_write & ~wr_command_phase & (wr_burstcount > 8'h00);	// data width related

endmodule
