`timescale 1ns / 1ps

// Receives three bytes in the fixed order A, B, opcode and sends the ALU result.
module OP_CONTROLLER
#(
    parameter NB_DATA = 8,
    parameter NB_OP = 6
)
(
    input  wire [NB_DATA-1:0] i_rx_data,
    input  wire               i_rx_empty,
    output reg                o_rx_rd,

    output reg [NB_DATA-1:0]  o_alu_a,
    output reg [NB_DATA-1:0]  o_alu_b,
    output reg [NB_OP-1:0]    o_alu_op,
    input  wire [NB_DATA-1:0] i_alu_result,

    input  wire                i_tx_full,
    output reg [NB_DATA-1:0]  o_tx_data,
    output reg                o_tx_wr,

    input  wire                i_clock,
    input  wire                i_reset
);

    localparam WAIT_A      = 3'b001;
    localparam WAIT_B      = 3'b010;
    localparam WAIT_OPCODE = 3'b011;
    localparam SEND_RESULT = 3'b100;

    reg [2:0] state;

    // The interface handshakes are asserted only while the corresponding
    // state is waiting for a byte or for an available TX slot.
    always @(*) begin
        o_rx_rd   = 1'b0;
        o_tx_wr   = 1'b0;
        o_tx_data = i_alu_result;

        case (state)
            WAIT_A,
            WAIT_B,
            WAIT_OPCODE: o_rx_rd = !i_rx_empty;
            SEND_RESULT: o_tx_wr = !i_tx_full;
            default: begin
                o_rx_rd = 1'b0;
                o_tx_wr = 1'b0;
            end
        endcase
    end

    always @(posedge i_clock) begin
        if (i_reset) begin
            state    <= WAIT_A;
            o_alu_a  <= {NB_DATA{1'b0}};
            o_alu_b  <= {NB_DATA{1'b0}};
            o_alu_op <= {NB_OP{1'b0}};
        end
        else begin
            case (state)
                WAIT_A: begin
                    if (!i_rx_empty) begin
                        o_alu_a <= i_rx_data;
                        state   <= WAIT_B;
                    end
                end

                WAIT_B: begin
                    if (!i_rx_empty) begin
                        o_alu_b <= i_rx_data;
                        state   <= WAIT_OPCODE;
                    end
                end

                WAIT_OPCODE: begin
                    if (!i_rx_empty) begin
                        // UART data is one byte wide; ALU opcodes use NB_OP bits.
                        o_alu_op <= i_rx_data[NB_OP-1:0];
                        state    <= SEND_RESULT;
                    end
                end

                SEND_RESULT: begin
                    if (!i_tx_full)
                        state <= WAIT_A;
                end

                default: state <= WAIT_A;
            endcase
        end
    end

endmodule
