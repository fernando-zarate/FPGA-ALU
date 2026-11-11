`timescale 1ns / 1ps

module CONTROL_UNIT (
    input  wire [31:0] instruction,
    output reg  [1:0]  ALUOp,
    output reg         RegWrite,
    output reg         ALUSrc,
    output reg         MemtoReg
);
    always @(*) begin
        ALUOp    = 2'b00;
        RegWrite = 1'b0;
        ALUSrc   = 1'b0;
        MemtoReg = 1'b0;
        // RISC-V ADD only: opcode, funct3 and funct7 must all match.
        case ({instruction[31:25], instruction[14:12], instruction[6:0]})
            17'b0000000_000_0110011: begin
                ALUOp    = 2'b10;
                RegWrite = 1'b1;
            end
            default: begin end // Unsupported instructions and bubbles are inert.
        endcase
    end
endmodule
