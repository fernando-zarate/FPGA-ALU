`timescale 1ns / 1ps

// Interfaz IF/ID 

module IF_ID #(
    parameter INSTR_WIDTH = 32,
    parameter ADDR_WIDTH  = 64
)(
    input  wire                   clk,
    input  wire                   reset,
    input  wire                   clk_en,
    input  wire [INSTR_WIDTH-1:0] instr_in, // Instrucción leída de la IMEM
    input  wire [ADDR_WIDTH-1:0]  pc_in,     // PC actual de la etapa IF
    output reg  [INSTR_WIDTH-1:0] instr_out,// Instrucción hacia la etapa ID
    output reg  [ADDR_WIDTH-1:0]  pc_out     // PC que viaja hacia la etapa ID
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            instr_out <= {INSTR_WIDTH{1'b0}};
            pc_out    <= {ADDR_WIDTH{1'b0}};
        end else if (clk_en) begin
            instr_out <= instr_in;
            pc_out    <= pc_in;
        end
    end
endmodule

// Solamente un pasa mano de la instrucción.
