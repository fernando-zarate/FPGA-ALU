`timescale 1ns / 1ps

module PIPELINE #(
    parameter DATA_WIDTH  = 64,
    parameter INSTR_WIDTH = 32,
    parameter ADDR_WIDTH  = 64
)(
    // Reloj y Control Global provenientes de la DEBUG_UNIT
    input  wire                   clk,
    input  wire                   reset,
    input  wire                   clk_en,           // Control de paso a paso o continuo

    // Interfaz de Carga de Memoria de Instrucciones (desde DEBUG_UNIT)
    input  wire                   imem_we,          // Habilitador de escritura
    input  wire [ADDR_WIDTH-1:0]  imem_addr,        // Dirección en IMEM
    input  wire [INSTR_WIDTH-1:0] imem_data,        // Código de instrucción enviada

    // Interfaz de Lectura de Registros (para DUMP de DEBUG_UNIT)
    input  wire [4:0]            debug_reg_addr,   // Dirección de registro a consultar
    output wire [DATA_WIDTH-1:0]  debug_reg_data,   // Valor del registro consultado

    // Estado Interno Exportado hacia DEBUG_UNIT para DUMP
    output wire [ADDR_WIDTH-1:0]  o_pc_if,          // PC en etapa IF
    output wire [ADDR_WIDTH-1:0]  o_pc_id,          // PC en etapa ID
    output wire [ADDR_WIDTH-1:0]  o_pc_ex,          // PC en etapa EX
    output wire [ADDR_WIDTH-1:0]  o_pc_mem,         // PC en etapa MEM
    output wire [ADDR_WIDTH-1:0]  o_pc_wb,          // PC en etapa WB
    output wire [INSTR_WIDTH-1:0] o_instr_id,       // Instrucción en ID
    output wire [DATA_WIDTH-1:0]  o_rdata1_ex,      // Operando A en EX
    output wire [DATA_WIDTH-1:0]  o_rdata2_ex,      // Operando B en EX
    output wire [4:0]            o_rd_ex,          // rd en EX
    output wire [DATA_WIDTH-1:0]  o_alu_res_mem,    // Resultado en MEM
    output wire [4:0]            o_rd_mem,         // rd en MEM
    output wire [DATA_WIDTH-1:0]  o_alu_res_wb,     // Resultado en WB
    output wire [4:0]            o_rd_wb           // rd en WB
);

    // --- Cables Internos de Interconexión ---
    wire [ADDR_WIDTH-1:0]  pc_curr, pc_next;
    wire [INSTR_WIDTH-1:0] instr_if;
    wire [INSTR_WIDTH-1:0] instr_id;
    wire [DATA_WIDTH-1:0]  rdata1_id, rdata2_id;
    wire [DATA_WIDTH-1:0]  rdata1_ex, rdata2_ex;
    wire [4:0]            rd_ex;
    wire [DATA_WIDTH-1:0]  alu_res_ex;
    wire                  zero_ex, zero_mem;
    wire [DATA_WIDTH-1:0]  alu_res_mem;
    wire [4:0]            rd_mem;
    wire [DATA_WIDTH-1:0]  alu_res_wb;
    wire [4:0]            rd_wb;
    wire [ADDR_WIDTH-1:0]  pc_id, pc_ex, pc_mem, pc_wb;

    // Conexión de puertos de monitoreo para DEBUG_UNIT
    assign o_pc_if       = pc_curr;
    assign o_pc_id       = pc_id;
    assign o_pc_ex       = pc_ex;
    assign o_pc_mem      = pc_mem;
    assign o_pc_wb       = pc_wb;
    assign o_instr_id    = instr_id;
    assign o_rdata1_ex   = rdata1_ex;
    assign o_rdata2_ex   = rdata2_ex;
    assign o_rd_ex       = rd_ex;
    assign o_alu_res_mem = alu_res_mem;
    assign o_rd_mem      = rd_mem;
    assign o_alu_res_wb  = alu_res_wb;
    assign o_rd_wb       = rd_wb;

    // -------------------------------------------------------------
    // ETAPA 1: IF
    // -------------------------------------------------------------
    PC #(ADDR_WIDTH) u_pc (
        .clk(clk), .reset(reset), .clk_en(clk_en), .pc_in(pc_next), .pc_out(pc_curr)
    );

    ADDER_PC #(ADDR_WIDTH) u_adder_pc (
        .pc_in(pc_curr), .pc_out(pc_next)
    );

    INSTRUCTION_MEMORY #(ADDR_WIDTH, INSTR_WIDTH) u_imem (
        .clk(clk),
        .read_addr(pc_curr), .instruction(instr_if),
        .we(imem_we), .write_addr(imem_addr), .write_data(imem_data)
    );

    IF_ID #(INSTR_WIDTH, ADDR_WIDTH) u_reg_if_id (
        .clk(clk), .reset(reset), .clk_en(clk_en),
        .instr_in(instr_if), .pc_in(pc_curr),
        .instr_out(instr_id), .pc_out(pc_id)
    );

    // -------------------------------------------------------------
    // ETAPA 2: ID
    // -------------------------------------------------------------
    REGISTER #(DATA_WIDTH) u_regfile (
        .clk            (clk),
        .reset          (reset),
        .reg_write      (1'b1),               // Siempre activo para la instrucción ADD
        .read_reg1      (instr_id[19:15]),    // Extrae rs1
        .read_reg2      (instr_id[24:20]),    // Extrae rs2
        .write_reg      (rd_wb),              // rd que regresa desde WB
        .write_data     (alu_res_wb),         // Resultado que regresa desde WB
        .read_data1     (rdata1_id),
        .read_data2     (rdata2_id),
        .debug_reg_addr (debug_reg_addr),
        .debug_reg_data (debug_reg_data)
    );

    ID_EX #(DATA_WIDTH, ADDR_WIDTH) u_reg_id_ex (
        .clk(clk), .reset(reset), .clk_en(clk_en),
        .read_data1_in(rdata1_id), .read_data2_in(rdata2_id),
        .rd_in(instr_id[11:7]), .pc_in(pc_id),
        .read_data1_out(rdata1_ex), .read_data2_out(rdata2_ex),
        .rd_out(rd_ex), .pc_out(pc_ex)
    );

    // -------------------------------------------------------------
    // ETAPA 3: EX
    // -------------------------------------------------------------
    ALU #(DATA_WIDTH) u_alu (
        .a(rdata1_ex), .b(rdata2_ex),
        .alu_result(alu_res_ex), .zero(zero_ex)
    );

    EX_MEM #(DATA_WIDTH, ADDR_WIDTH) u_reg_ex_mem (
        .clk(clk), .reset(reset), .clk_en(clk_en),
        .zero_in(zero_ex), .alu_result_in(alu_res_ex),
        .rd_in(rd_ex), .pc_in(pc_ex),
        .zero_out(zero_mem), .alu_result_out(alu_res_mem),
        .rd_out(rd_mem), .pc_out(pc_mem)
    );

    // -------------------------------------------------------------
    // ETAPA 4: MEM (Paso directo para ADD)
    // -------------------------------------------------------------
    MEM_WB #(DATA_WIDTH, ADDR_WIDTH) u_reg_mem_wb (
        .clk(clk), .reset(reset), .clk_en(clk_en),
        .alu_result_in(alu_res_mem), .rd_in(rd_mem), .pc_in(pc_mem),
        .alu_result_out(alu_res_wb), .rd_out(rd_wb), .pc_out(pc_wb)
    );

endmodule
