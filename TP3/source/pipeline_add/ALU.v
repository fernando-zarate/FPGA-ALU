`timescale 1ns / 1ps

module ALU #(
    parameter DATA_WIDTH = 64
)(
    input  wire [DATA_WIDTH-1:0] a,          // Operando A
    input  wire [DATA_WIDTH-1:0] b,          // Operando B
    output wire [DATA_WIDTH-1:0] alu_result, // Resultado de la suma
    output wire                  zero,       // Flag de Cero
    input  wire [1:0]            alu_op
);
    // TP3 ALUOp: 10 selects ADD; all other controls are inert.
    assign alu_result = (alu_op == 2'b10) ? a + b : {DATA_WIDTH{1'b0}};
    assign zero       = (alu_result == {DATA_WIDTH{1'b0}});
endmodule
