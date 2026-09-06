`timescale 1ns / 1ps

module NBITS_DATA
#
(
    parameter NB_DATA = 8
)
(
    input wire i_clock,
    input wire i_enable,
    input wire i_reset,
    input wire [NB_DATA -1 : 0] i_data,

    output reg [NB_DATA -1 : 0] o_data
    // ¿porque usamos reg y no wire? por que a la variable o_data le asignamos su valor dentro de un bloque procedural 
);

    
    always @(posedge i_clock) begin
        
        if (i_reset)
            o_data = {NB_DATA{1'b0}};
        
        else if (i_enable)
            o_data <=i_data; 
    end


endmodule
