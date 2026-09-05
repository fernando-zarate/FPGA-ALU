`timescale 1ns / 1ps

module TOP
#
(
    parameter NSW = 8,
    parameter NB_DATA = 8,
    parameter NB_OP = 6,
    parameter NLED = 10
)
(
    input wire       CLK,
    input wire [NSW-1:0] SW,
    input wire       BTN_A,
    input wire       BTN_B,
    input wire       BTN_OP,
    input wire       BTN_RESET,
    output wire [NLED-1:0] LED
);
    wire [NB_DATA-1:0] A_data;
    wire [NB_DATA-1:0] B_data;
    wire [NB_OP-1:0] OP_data;

    wire [NB_DATA-1:0] result;
    wire zero;
    wire carry;

    NBITS_DATA #(
        .NB_DATA(NB_DATA)
    ) data_A (
        .i_clock(CLK),
        .i_enable(BTN_A),
        .i_reset(BTN_RESET),
        .i_data(SW[NB_DATA-1:0]),
        .o_data(A_data)
    );

    NBITS_DATA #(
        .NB_DATA(NB_DATA)
    ) data_B (
        .i_clock(CLK),
        .i_enable(BTN_B),
        .i_reset(BTN_RESET),
        .i_data(SW[NB_DATA-1:0]),
        .o_data(B_data)
    );

    NBITS_DATA #(
        .NB_DATA(NB_OP)
    ) data_OP (
        .i_clock(CLK),
        .i_enable(BTN_OP),
        .i_reset(BTN_RESET),
        .i_data(SW[NB_OP-1:0]),
        .o_data(OP_data)
    );

    // Instancia de la ALU
    ALU alu_inst (
        ._A(A_data),
        ._B(B_data),
        ._OP(OP_data),
        .o_result(result),
        .o_zero(zero),
        .o_carry(carry)
    );

    assign LED[NB_DATA-1:0] = result;
    assign LED[8] = zero;
    assign LED[9] = carry;

endmodule
