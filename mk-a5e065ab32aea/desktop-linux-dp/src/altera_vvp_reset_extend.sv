/* ##################################################################################
�* Copyright (C) 2025 Altera Corporation
 *
�* This software and the related documents are Altera copyrighted materials, and
 * your use of them is governed by the express license under which they were
 * provided to you ("License"). Unless the License provides otherwise, you may
 * not use, modify, copy, publish, distribute, disclose or transmit this software
 * or the related documents without Altera's prior written permission.
 *
�* This software and the related documents are provided as is, with no express
�* or implied warranties, other than those that are expressly stated in the License.
 * ##################################################################################

 * ##################################################################################
 *
 * Module: altera_vvp_reset_extend
 *
 * Description: extends reset duration
 *
 * ##################################################################################
*/

`default_nettype none

module altera_vvp_reset_extend (
    clk,
    rst_in,
    rst_out,
    rst_out_dup
);

    parameter RESYNC_RESET_IN = 1;
    parameter SYNC_LEN = 3;
    parameter RESET_MIN_LENGTH = 256;

    localparam LOCAL_ONE_CONST = 1;

    function integer local_log2;

        input [31:0] value;

        begin
            local_log2 = 1;
            while (2 ** local_log2 < value) begin
                local_log2 = local_log2 + 1;
            end
        end

    endfunction

    localparam COUNT_WIDTH = local_log2(RESET_MIN_LENGTH) + 1;

    input wire clk;
    input wire rst_in;

    output logic rst_out;
    output logic rst_out_dup;

    reg [COUNT_WIDTH - 1 : 0] reset_count;

    wire rst_internal;

    generate

        if (RESYNC_RESET_IN > 0) begin

            reg [SYNC_LEN - 1 : 0] reset_sync;

            always_ff @(posedge clk) begin
                for (int i = 0; i < SYNC_LEN; i = i + 1) begin
                    if (i == 0) begin
                        reset_sync[i] <= rst_in;
                    end else begin
                        reset_sync[i] <= reset_sync[i-1];
                    end
                end
            end

            assign rst_internal = reset_sync[SYNC_LEN-1];

        end else begin

            assign rst_internal = rst_in;

        end

    endgenerate

    always_ff @(posedge clk or posedge rst_internal) begin
        if (rst_internal) begin
            reset_count <= {1'b1, {COUNT_WIDTH - 1{1'b0}}};
        end else begin
            if (reset_count[COUNT_WIDTH-1]) begin
                reset_count <= reset_count + LOCAL_ONE_CONST[COUNT_WIDTH-1:0];
            end
            rst_out <= reset_count[COUNT_WIDTH-1];
            rst_out_dup <= reset_count[COUNT_WIDTH-1];
        end
    end

endmodule

`default_nettype wire
