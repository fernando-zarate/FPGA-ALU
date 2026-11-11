`timescale 1ns / 1ps

module INSTRUCTION_MEMORY #(
    parameter ADDR_WIDTH  = 64,
    parameter INSTR_WIDTH = 32
)(
    input  wire                  clk,        // Reloj para escritura
    // Puerto de Lectura (Etapa IF)
    input  wire [ADDR_WIDTH-1:0]  read_addr,  // Dirección enviada por el PC
    output wire [INSTR_WIDTH-1:0] instruction,// Instrucción de 32 bits leída
    // Puerto de Escritura (Carga desde DEBUG_UNIT)
    input  wire                  we,         // Write Enable
    input  wire [ADDR_WIDTH-1:0]  write_addr, // Dirección de memoria a escribir
    input  wire [INSTR_WIDTH-1:0] write_data  // Instrucción enviada por UART
);
    reg [INSTR_WIDTH-1:0] mem [0:63]; // Memoria de 64 palabras de 32 bits

    // Lectura combinacional alineada a palabra (descarte de bits [1:0] -> división por 4)
    assign instruction = mem[read_addr[7:2]];

    // Escritura sincrónica comandada por la DEBUG_UNIT
    always @(posedge clk) begin
        if (we) begin
            mem[write_addr[7:2]] <= write_data;
        end
    end
endmodule


// address[7:2] -> equivalente a dividir por 4.
// De todas formas el ADDER_PC se encarga de sumar 4 a la PC en cada ciclo, 
// por lo que la dirección de memoria siempre será múltiplo de 4.
