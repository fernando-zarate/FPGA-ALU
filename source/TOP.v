`timescale 1ns / 1ps

module TOP
#
(
    parameter NSW = 8,
    parameter NB_DATA = 8,
    parameter NB_OP = 6,
    parameter NLED = 8
)
(
    input wire       CLK,
    input wire [NSW-1:0] SW,
    input wire       BTN_A,
    input wire       BTN_B,
    input wire       BTN_OP,
    output signed [NLED-1:0] LED
);
    // Registros para almacenar A, B y OP
    reg [NB_DATA-1:0] A_reg;
    reg [NB_DATA-1:0] B_reg;
    reg [NB_DATA-1:0] OP_reg;

    // Resultado de la ALU
    wire [NB_DATA-1:0] result;

    // Instancia de la ALU
    ALU alu_inst (
        ._A(A_reg),
        ._B(B_reg),
        ._OP(OP_reg),
        .result(LED)
    );

    // Registro de A, B y OP
    always @(posedge CLK) begin

        // Guardar A
        if (BTN_A) begin
            A_reg <= SW;
        end

        // Guardar B
        if (BTN_B) begin
            B_reg <= SW;
        end

        // Guardar opcode
        if (BTN_OP) begin
            OP_reg <= SW[NB_OP-1:0];
        end
    end

    // Mostrar resultado en los LEDs
    assign LED = result;

endmodule
