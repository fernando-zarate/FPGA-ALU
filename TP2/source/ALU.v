`timescale 1ns / 1ps

module ALU
#
(
    parameter NB_DATA = 8,
    parameter NB_OP = 6
)
(
    input wire [NB_DATA-1:0] _A,
    input wire [NB_DATA-1:0] _B,
    input wire [NB_OP-1:0] _OP,

    output reg [NB_DATA -1: 0 ] o_result,
    output reg o_zero,
    output reg o_carry

);

    // Opcodes
    localparam ADD = 6'b100000;
    localparam SUB = 6'b100010;
    localparam AND = 6'b100100;
    localparam OR  = 6'b100101;
    localparam XOR = 6'b100110;
    localparam SRA = 6'b000011;
    localparam SRL = 6'b000010;
    localparam NOR = 6'b100111;

    reg [NB_DATA:0] extended_result;

    // Lógica de la ALU
    always @(*) begin
        o_result = {NB_DATA{1'b0}};
        o_carry = 1'b0;
        extended_result = {(NB_DATA + 1){1'b0}};

        case (_OP)

            ADD: begin
                extended_result = {1'b0, _A} + {1'b0, _B};
                o_result = extended_result[NB_DATA-1:0];
                o_carry = extended_result[NB_DATA];
            end

            SUB: begin
                o_result = _A - _B;
                // In SUB, o_carry represents borrow.
                o_carry = (_A < _B);
            end

            AND: o_result = _A & _B;
            OR:  o_result = _A | _B;
            XOR: o_result = _A ^ _B;
            SRA: o_result = $signed(_A) >>> _B;
            SRL: o_result = _A >> _B;
            NOR: o_result = ~(_A | _B);

            default: o_result = {NB_DATA{1'b0}};

        endcase

        o_zero = (o_result == {NB_DATA{1'b0}});
    end
    
    //assign o_leds = result;

endmodule
