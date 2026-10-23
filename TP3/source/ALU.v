module ALU
#
(
    parameter DATA_WIDTH = 64
)
(
    input  wire [DATA_WIDTH-1:0] a,
    input  wire [DATA_WIDTH-1:0] b,
    output wire [DATA_WIDTH-1:0] alu_result,
    output wire                  zero
);
    assign alu_result = a + b; // Suma de la instrucción ADD
    assign zero       = (alu_result == {DATA_WIDTH{1'b0}});
endmodule

// solo ADD, no usamos la ALU anterior, tampoco desglosamos el opcode.