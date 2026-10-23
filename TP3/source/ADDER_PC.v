`timescale 1ns / 1ps
// Sumador PC + 4 

module ADDER_PC
#
( 
    parameter ADDR_WIDTH = 64 
)
( 
    input wire [ADDR_WIDTH-1:0] pc_in, 
    output wire [ADDR_WIDTH-1:0] pc_out 
);
    assign pc_out = pc_in + 64'd4; 

endmodule