`timescale 1ns / 1ps

module ID_EX #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 64
)(
    input  wire                  clk,
    input  wire                  reset,
    input  wire                  clk_en,
    input  wire [DATA_WIDTH-1:0] read_data1_in, // Operando A leído de rs1
    input  wire [DATA_WIDTH-1:0] read_data2_in, // Operando B leído de rs2
    input  wire [4:0]            rd_in,         // Registro destino rd (bits [11:7])
    input  wire [ADDR_WIDTH-1:0]  pc_in,         // PC proveniente de ID
    output reg  [DATA_WIDTH-1:0] read_data1_out,// Operando A hacia la ALU
    output reg  [DATA_WIDTH-1:0] read_data2_out,// Operando B hacia la ALU
    output reg  [4:0]            rd_out,        // Registro destino rd hacia EX/MEM
    output reg  [ADDR_WIDTH-1:0]  pc_out,        // PC que viaja hacia EX
    input  wire [DATA_WIDTH-1:0] immediate_in,
    input  wire [1:0]            alu_op_in,
    input  wire                  alu_src_in,
    input  wire                  reg_write_in,
    input  wire                  mem_to_reg_in,
    output reg  [DATA_WIDTH-1:0] immediate_out,
    output reg  [1:0]            alu_op_out,
    output reg                   alu_src_out,
    output reg                   reg_write_out,
    output reg                   mem_to_reg_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            read_data1_out <= {DATA_WIDTH{1'b0}};
            read_data2_out <= {DATA_WIDTH{1'b0}};
            rd_out         <= 5'b0;
            pc_out         <= {ADDR_WIDTH{1'b0}};
            immediate_out  <= {DATA_WIDTH{1'b0}};
            alu_op_out     <= 2'b00;
            alu_src_out    <= 1'b0;
            reg_write_out  <= 1'b0;
            mem_to_reg_out <= 1'b0;
        end else if (clk_en) begin
            read_data1_out <= read_data1_in;
            read_data2_out <= read_data2_in;
            rd_out         <= rd_in;
            pc_out         <= pc_in;
            immediate_out  <= immediate_in;
            alu_op_out     <= alu_op_in;
            alu_src_out    <= alu_src_in;
            reg_write_out  <= reg_write_in;
            mem_to_reg_out <= mem_to_reg_in;
        end
    end
endmodule

// solamente un pasamanos de los datos que salen de REGISTER.v
