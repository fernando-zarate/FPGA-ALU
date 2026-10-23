`timescale 1ns / 1ps

module TOP
#
(
    parameter DATA_WIDTH  = 64,
    parameter INSTR_WIDTH = 32
)
(
    input wire clk,
    input wire reset
);
    // Señales de interconexión IF
    wire [DATA_WIDTH-1:0]  pc_curr, pc_next;
    wire [INSTR_WIDTH-1:0] instr_if;

    // Señales de interconexión ID
    wire [INSTR_WIDTH-1:0] instr_id;
    wire [DATA_WIDTH-1:0]  rdata1_id, rdata2_id;

    // Señales de interconexión EX
    wire [DATA_WIDTH-1:0]  rdata1_ex, rdata2_ex;
    wire [4:0]            rd_ex;
    wire [DATA_WIDTH-1:0]  alu_res_ex;
    wire                  zero_ex;

    // Señales de interconexión MEM
    wire                  zero_mem;
    wire [DATA_WIDTH-1:0]  alu_res_mem;
    wire [4:0]            rd_mem;

    // Señales de interconexión WB
    wire [DATA_WIDTH-1:0]  alu_res_wb;
    wire [4:0]            rd_wb;

    // IF
    PC #(DATA_WIDTH) u_pc (
        .clk(clk), .reset(reset), .pc_in(pc_next), .pc_out(pc_curr)
    );

    ADDER_PC #(DATA_WIDTH) u_adder_pc (
        .pc_in(pc_curr), .pc_out(pc_next)
    );

    INSTRUCTION_MEMORY #(DATA_WIDTH, INSTR_WIDTH) u_imem (
        .address(pc_curr), .instruction(instr_if)
    );

    IF_ID #(INSTR_WIDTH) u_reg_if_id (
        .clk(clk), .reset(reset), .instr_in(instr_if), .instr_out(instr_id)
    );

    // ID

    REGISTER #(DATA_WIDTH) u_regfile (
        .clk        (clk),
        .reg_write  (1'b1),               // Habilitado para la instrucción ADD
        .read_reg1  (instr_id[19:15]),    // rs1
        .read_reg2  (instr_id[24:20]),    // rs2
        .write_reg  (rd_wb),              // rd proveniente de MEM/WB
        .write_data (alu_res_wb),         // Dato proveniente de MEM/WB
        .read_data1 (rdata1_id),
        .read_data2 (rdata2_id)
    );

    ID_EX #(DATA_WIDTH) u_reg_id_ex (
        .clk(clk), .reset(reset),
        .read_data1_in(rdata1_id), .read_data2_in(rdata2_id),
        .rd_in(instr_id[11:7]),            // rd (bits 11:7)
        .read_data1_out(rdata1_ex), .read_data2_out(rdata2_ex),
        .rd_out(rd_ex)
    );

    // EX

    ALU #(DATA_WIDTH) u_alu (
        .a(rdata1_ex), .b(rdata2_ex),
        .alu_result(alu_res_ex), .zero(zero_ex)
    );

    EX_MEM #(DATA_WIDTH) u_reg_ex_mem (
        .clk(clk), .reset(reset),
        .zero_in(zero_ex), .alu_result_in(alu_res_ex), .rd_in(rd_ex),
        .zero_out(zero_mem), .alu_result_out(alu_res_mem), .rd_out(rd_mem)
    );

    // MEM 

    MEM_WB #(DATA_WIDTH) u_reg_mem_wb (
        .clk(clk), .reset(reset),
        .alu_result_in(alu_res_mem), .rd_in(rd_mem),
        .alu_result_out(alu_res_wb), .rd_out(rd_wb)
    );

    // WB 
    // No se usa por ahora.

endmodule
