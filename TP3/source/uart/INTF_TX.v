`timescale 1ns / 1ps

module INTF_TX
#(
    parameter NB_DATA = 8
)
(
    input  wire i_clock,
    input  wire i_reset,
    input  wire [NB_DATA-1:0] i_w_data,
    input  wire i_wr,
    input  wire i_tx_done,

    output reg [NB_DATA-1:0] o_tx_data,
    output reg o_tx_start,
    output reg o_tx_full
);

    // Una transferencia pendiente o en curso: no hay cola adicional.
    // Se acepta i_wr solamente con o_tx_full = 0 antes del flanco.
    // Una escritura mientras está lleno se ignora, incluso si coincide con done.
    // Compartir reloj y reset con UART_TX; esta interfaz debe controlar su start.
    always @(posedge i_clock) begin
        if (i_reset) begin
            o_tx_data  <= {NB_DATA{1'b0}};
            o_tx_start <= 1'b0;
            o_tx_full  <= 1'b0;
        end
        else begin
            o_tx_start <= 1'b0;

            if (!o_tx_full) begin
                if (i_wr) begin
                    o_tx_data  <= i_w_data;
                    // UART_TX captura el dato en el siguiente flanco.
                    o_tx_start <= 1'b1;
                    o_tx_full  <= 1'b1;
                end
            end
            else if (i_tx_done) begin
                o_tx_full <= 1'b0;
            end
        end
    end

endmodule
