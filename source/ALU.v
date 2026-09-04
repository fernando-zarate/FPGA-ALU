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
    output signed [NB_DATA -1: 0 ] o_leds,
    output reg [NB_DATA-1:0] result
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

    // Lógica de la ALU
    always @(*) begin
        case (_OP)

            ADD: result = _A + _B;
            SUB: result = _A - _B;
            AND: result = _A & _B;
            OR:  result = _A | _B;
            XOR: result = _A ^ _B;
            SRA: result = $signed(_A) >>> _B;
            SRL: result = _A >> _B;
            NOR: result = ~(_A | _B);

            default: result = {NB_DATA{1'b0}};

        endcase
    end
    
    assign o_leds = result;

endmodule
