`timescale 1ns / 1ps

module BAUD_RATE_GENERATOR
#
(
    // los "_" se usan como separadores de miles, solamente 
    // para mejorar la legibilidad, se pueden sacar
    parameter CLK_FREQ  = 100_000_000, 
    parameter BAUD_RATE = 9_600,
    parameter OVERSAMPLING = 16
)
(
    input  wire clk,
    input  wire reset,
    output reg  rate
);
    // Frecuencia de los ticks
    localparam integer TICK_RATE = BAUD_RATE * OVERSAMPLING;

    // Cantidad de ciclos de clock por tick
    localparam integer BAUD_COUNT = CLK_FREQ / TICK_RATE;

    // Ancho del contador
    localparam integer NB_COUNT = $clog2(BAUD_COUNT);

    reg [NB_COUNT-1:0] count;

    always @(posedge clk) begin

        if (reset) begin
            count <= 0;
            rate  <= 1'b0;
        end
        else begin

            if (count == BAUD_COUNT - 1) begin
                count <= 0;
                rate  <= 1'b1;
            end
            else begin
                count <= count + 1'b1;
                rate  <= 1'b0;
            end
        end
    end
endmodule
