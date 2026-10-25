`timescale 1ns / 1ps

module INTF_RX
#(
    parameter NB_DATA = 8
)
(
    input  wire i_clock,
    input  wire i_reset,
    input  wire [NB_DATA-1:0] i_rx_data,
    input  wire i_rx_done,
    input  wire i_rd,

    output reg [NB_DATA-1:0] o_r_data,
    output reg o_rx_empty
);

    // UART_RX entrega dato y done registrados. El consumidor lee cuando
    // o_rx_empty = 0 y confirma el consumo con i_rd en el flanco de reloj.
    // Si lectura y recepción coinciden, se consume el anterior y guarda el nuevo.
    // Si está lleno y no hay lectura, se descarta el byte entrante.
    always @(posedge i_clock) begin
        if (i_reset) begin
            o_r_data   <= {NB_DATA{1'b0}};
            o_rx_empty <= 1'b1;
        end
        else if (i_rx_done && (o_rx_empty || i_rd)) begin
            o_r_data   <= i_rx_data;
            o_rx_empty <= 1'b0;
        end
        else if (i_rd) begin
            o_rx_empty <= 1'b1;
        end
    end

endmodule
