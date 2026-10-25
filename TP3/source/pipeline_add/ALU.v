`timescale 1ns / 1ps

module ALU #(
    parameter DATA_WIDTH = 64
)(
    input  wire [DATA_WIDTH-1:0] a,          // Operando A
    input  wire [DATA_WIDTH-1:0] b,          // Operando B
    output wire [DATA_WIDTH-1:0] alu_result, // Resultado de la suma
    output wire                  zero        // Flag de Cero
);
    assign alu_result = a + b;
    assign zero       = (alu_result == {DATA_WIDTH{1'b0}});
endmodule

// solo ADD, no usamos la ALU anterior, tampoco desglosamos el opcode.
