`timescale 1ns / 1ps

// Interfaz IF/ID 

module IF_ID
#
( 
    parameter INSTR_WIDTH = 32 
)
( 
    input wire clk, 
    input wire reset, 
    input wire [INSTR_WIDTH-1:0] instr_width, 
    output reg [INSTR_WIDTH-1:0] instr_out 
);
    always @(posedge clk or posedge reset) begin 
        if (reset) 
            instr_out <= {INSTR_WIDTH{1'b0}}; 
        else 
            instr_out <= instr_in; 
    end 
endmodule

// Solamente un pasa mano de la instrucción.