`timescale 1ns / 1ps

module PC #
( 
    parameter ADDR_WIDTH = 64 
)
( 
    input wire clk, 
    input wire reset, 
    input wire [ADDR_WIDTH-1:0] pc_in, 
    output reg [ADDR_WIDTH-1:0] pc_out 
);

    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_out <= {ADDR_WIDTH{1'b0}};
        else
            pc_out <= pc_in;
    end
endmodule

// pc_out alimenta a INSTRCTION_MEMORY (address) y a ADDER_PC (pc_in).
// la inicialización de la PC a 0 se hace en el reset.