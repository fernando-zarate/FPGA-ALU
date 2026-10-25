`timescale 1ns / 1ps

module EX_MEM #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64
)(
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  clk_en,
    input  wire                  zero_in,
    input  wire [DATA_WIDTH-1:0] alu_result_in, // Resultado calculado por la ALU
    input  wire [4:0]            rd_in,         // Registro destino rd
    input  wire [ADDR_WIDTH-1:0]  pc_in,         // PC proveniente de EX
    output reg                   zero_out,
    output reg  [DATA_WIDTH-1:0] alu_result_out,// Resultado ALU hacia MEM/WB
    output reg  [4:0]            rd_out,        // Registro destino rd hacia MEM/WB
    output reg  [ADDR_WIDTH-1:0]  pc_out         // PC que viaja hacia MEM
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            zero_out       <= 1'b0;
            alu_result_out <= {DATA_WIDTH{1'b0}};
            rd_out         <= 5'b0;
            pc_out         <= {ADDR_WIDTH{1'b0}};
        end else if (clk_en) begin
            zero_out       <= zero_in;
            alu_result_out <= alu_result_in;
            rd_out         <= rd_in;
            pc_out         <= pc_in;
        end
    end
endmodule

// solamente un pasamanos de los datos que salen de ALU.v
