`timescale 1ns / 1ps

module TOP
#(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 9_600,
    parameter OVERSAMPLING = 16,
    parameter NB_DATA = 8,
    parameter NB_OP = 6
)
(
    input  wire i_clock,
    input  wire i_reset,
    input  wire i_uart_rx,
    output wire o_uart_tx
);

    wire rate;

    wire [NB_DATA-1:0] uart_rx_data;
    wire uart_rx_done;

    wire [NB_DATA-1:0] rx_data;
    wire rx_empty;
    wire rx_rd;

    wire [NB_DATA-1:0] alu_a;
    wire [NB_DATA-1:0] alu_b;
    wire [NB_OP-1:0] alu_op;
    wire [NB_DATA-1:0] alu_result;
    wire alu_zero;
    wire alu_carry;

    wire [NB_DATA-1:0] controller_tx_data;
    wire controller_tx_wr;
    wire tx_full;

    wire [NB_DATA-1:0] uart_tx_data;
    wire uart_tx_start;
    wire uart_tx_done;

    BAUD_RATE_GENERATOR #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .OVERSAMPLING(OVERSAMPLING)
    ) baud_generator (
        .clk(i_clock),
        .reset(i_reset),
        .rate(rate)
    );

    UART_RX #(
        .NB_DATA(NB_DATA)
    ) uart_rx (
        .i_clock(i_clock),
        .i_reset(i_reset),
        .i_rx(i_uart_rx),
        .i_rate(rate),
        .o_data(uart_rx_data),
        .o_done(uart_rx_done)
    );

    INTF_RX #(
        .NB_DATA(NB_DATA)
    ) rx_interface (
        .i_clock(i_clock),
        .i_reset(i_reset),
        .i_rx_data(uart_rx_data),
        .i_rx_done(uart_rx_done),
        .i_rd(rx_rd),
        .o_r_data(rx_data),
        .o_rx_empty(rx_empty)
    );

    OP_CONTROLLER #(
        .NB_DATA(NB_DATA),
        .NB_OP(NB_OP)
    ) operation_controller (
        .i_rx_data(rx_data),
        .i_rx_empty(rx_empty),
        .o_rx_rd(rx_rd),
        .o_alu_a(alu_a),
        .o_alu_b(alu_b),
        .o_alu_op(alu_op),
        .i_alu_result(alu_result),
        .i_tx_full(tx_full),
        .o_tx_data(controller_tx_data),
        .o_tx_wr(controller_tx_wr),
        .i_clock(i_clock),
        .i_reset(i_reset)
    );

    ALU #(
        .NB_DATA(NB_DATA),
        .NB_OP(NB_OP)
    ) alu (
        ._A(alu_a),
        ._B(alu_b),
        ._OP(alu_op),
        .o_result(alu_result),
        .o_zero(alu_zero),
        .o_carry(alu_carry)
    );

    INTF_TX #(
        .NB_DATA(NB_DATA)
    ) tx_interface (
        .i_clock(i_clock),
        .i_reset(i_reset),
        .i_w_data(controller_tx_data),
        .i_wr(controller_tx_wr),
        .i_tx_done(uart_tx_done),
        .o_tx_data(uart_tx_data),
        .o_tx_start(uart_tx_start),
        .o_tx_full(tx_full)
    );

    UART_TX #(
        .NB_DATA(NB_DATA)
    ) uart_tx (
        .i_clock(i_clock),
        .i_reset(i_reset),
        .i_data(uart_tx_data),
        .i_start(uart_tx_start),
        .i_rate(rate),
        .o_tx(o_uart_tx),
        .o_done(uart_tx_done)
    );

endmodule
