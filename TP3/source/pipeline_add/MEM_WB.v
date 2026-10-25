`timescale 1ns / 1ps

module MEM_WB #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64
)(
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  clk_en,
    input  wire [DATA_WIDTH-1:0] alu_result_in, // Resultado proveniente de EX/MEM
    input  wire [4:0]            rd_in,         // Registro destino rd
    input  wire [ADDR_WIDTH-1:0]  pc_in,         // PC proveniente de MEM
    output reg  [DATA_WIDTH-1:0] alu_result_out,// Resultado enviado a escribir en RegFile
    output reg  [4:0]            rd_out,        // Registro destino rd enviado a RegFile
    output reg  [ADDR_WIDTH-1:0]  pc_out         // PC en etapa de escritura final
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            alu_result_out <= {DATA_WIDTH{1'b0}};
            rd_out         <= 5'b0;
            pc_out         <= {ADDR_WIDTH{1'b0}};
        end else if (clk_en) begin
            alu_result_out <= alu_result_in;
            rd_out         <= rd_in;
            pc_out         <= pc_in;
        end
    end
endmodule

// solamente un pasamanos de los datos que salen de EX_MEM.v
