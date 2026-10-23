`timescale 1ns / 1ps

module REGISTER 
#
(
    parameter DATA_WIDTH = 64
)
(
    input  wire                  clk,
    input  wire                  reg_write,  // Habilitador de escritura
    input  wire [4:0]            read_reg1,  // rs1 (bits 19:15)
    input  wire [4:0]            read_reg2,  // rs2 (bits 24:20)
    input  wire [4:0]            write_reg,  // rd (proveniente de MEM/WB)
    input  wire [DATA_WIDTH-1:0] write_data, // Dato (proveniente de MEM/WB)
    output wire [DATA_WIDTH-1:0] read_data1,
    output wire [DATA_WIDTH-1:0] read_data2
);
    reg [DATA_WIDTH-1:0] registers [0:31]; 

    // Lectura combinacional (x0 siempre retorna 0)
    assign read_data1 = (read_reg1 == 5'b0) ? {DATA_WIDTH{1'b0}} : registers[read_reg1];
    assign read_data2 = (read_reg2 == 5'b0) ? {DATA_WIDTH{1'b0}} : registers[read_reg2];

    // Escritura sincrónica en flanco de subida
    always @(posedge clk) begin
        if (reg_write && (write_reg != 5'b0)) begin
            registers[write_reg] <= write_data;
        end
    end
endmodule

// registers [0:31] -> Matriz de 32 registros de 64 bits
// las asignaciones de read_data1 y read_data2 estan en el TOP.

// Cuando agreguemos funciones de inmediato, se van a agregar más entradas y salidas a este módulo. 
// Por ahora, solo se leen los registros rs1 y rs2, y se escribe en rd.

// write_data es alu_result_out, write_reg es rd_out, que son las salidas de MEM/WB.