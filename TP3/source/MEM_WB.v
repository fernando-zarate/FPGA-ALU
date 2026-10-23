`timescale 1ns / 1ps

module MEM_WB
#
(
    parameter DATA_WIDTH = 64
)
(
    input  wire                  clk,
    input  wire                  reset,
    input  wire [DATA_WIDTH-1:0] alu_result_in,
    input  wire [4:0]            rd_in,
    output reg  [DATA_WIDTH-1:0] alu_result_out,
    output reg  [4:0]            rd_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            alu_result_out <= {DATA_WIDTH{1'b0}};
            rd_out         <= 5'b0;
        end else begin
            alu_result_out <= alu_result_in;
            rd_out         <= rd_in;
        end
    end
endmodule

// solamente un pasamanos de los datos que salen de EX_MEM.v