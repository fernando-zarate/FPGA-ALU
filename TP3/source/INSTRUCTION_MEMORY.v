`timescale 1ns / 1ps

module INSTRUCTION_MEMORY
#
(
    parameter ADDR_WIDTH = 64,
    parameter INSTR_WIDTH = 32
)
(
    input  wire [ADDR_WIDTH-1:0]  address,
    output wire [INSTR_WIDTH-1:0] instruction
);
    reg [INSTR_WIDTH-1:0] mem [0:63]; // Memoria simplificada de 64 palabras

    assign instruction = mem[address[7:2]]; // Alineación a palabra (4 bytes)
endmodule


// address[7:2] -> equivalente a dividir por 4.
// De todas formas el ADDER_PC se encarga de sumar 4 a la PC en cada ciclo, 
// por lo que la dirección de memoria siempre será múltiplo de 4.
// Otra cosa, cuando el PC pase a 