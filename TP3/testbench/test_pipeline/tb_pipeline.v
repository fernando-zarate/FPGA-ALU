`timescale 1ns / 1ps

// ============================================================================
// TESTBENCH UNITARIO: PIPELINE.v
// Prueba el funcionamiento del datapath del procesador para la instrucción ADD.
// ============================================================================

module tb_pipeline;

    parameter DATA_WIDTH  = 64;
    parameter INSTR_WIDTH = 32;
    parameter ADDR_WIDTH  = 64;

    // Entradas del UUT
    reg                  clk;
    reg                  reset;
    reg                  clk_en;
    reg                  imem_we;
    reg [ADDR_WIDTH-1:0] imem_addr;
    reg [INSTR_WIDTH-1:0]imem_data;
    reg [4:0]            debug_reg_addr;

    // Salidas del UUT
    wire [DATA_WIDTH-1:0] debug_reg_data;
    wire [ADDR_WIDTH-1:0] pc_if, pc_id, pc_ex, pc_mem, pc_wb;
    wire [INSTR_WIDTH-1:0]instr_id;
    wire [DATA_WIDTH-1:0] rdata1_ex, rdata2_ex;
    wire [4:0]            rd_ex;
    wire [DATA_WIDTH-1:0] alu_res_mem;
    wire [4:0]            rd_mem;
    wire [DATA_WIDTH-1:0] alu_res_wb;
    wire [4:0]            rd_wb;

    // Instancia del procesador PIPELINE
    PIPELINE #(
        .DATA_WIDTH(DATA_WIDTH),
        .INSTR_WIDTH(INSTR_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut ( //UUT = Unit Under Test
        .clk(clk),
        .reset(reset),
        .clk_en(clk_en),
        .imem_we(imem_we),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .debug_reg_addr(debug_reg_addr),
        .debug_reg_data(debug_reg_data),
        .o_pc_if(pc_if),
        .o_pc_id(pc_id),
        .o_pc_ex(pc_ex),
        .o_pc_mem(pc_mem),
        .o_pc_wb(pc_wb),
        .o_instr_id(instr_id),
        .o_rdata1_ex(rdata1_ex),
        .o_rdata2_ex(rdata2_ex),
        .o_rd_ex(rd_ex),
        .o_alu_res_mem(alu_res_mem),
        .o_rd_mem(rd_mem),
        .o_alu_res_wb(alu_res_wb),
        .o_rd_wb(rd_wb)
    );

    // Generación de Reloj (100 MHz -> Periodo = 10ns)
    always #5 clk = ~clk;

    initial begin
        // 1. Inicialización de señales
        clk            = 0;
        reset          = 1;
        clk_en         = 0;
        imem_we        = 0;
        imem_addr      = 0;
        imem_data      = 0;
        debug_reg_addr = 0;

        #20;
        reset = 0;
        #10;

        // 2. Carga de Instrucciones en IMEM
        // Instrucción: ADD x3, x1, x2  (opcode R-type = 0x33, funct3=0, funct7=0, rs1=1, rs2=2, rd=3)
        // Binario: 0000000_00010_00001_000_00011_0110011 -> Hex: 32'h002081B3
        imem_we   = 1;
        imem_addr = 64'h0;
        imem_data = 32'h002081B3;
        #10;
        imem_we   = 0;

        // 3. Pre-cargar valores en los registros x1 y x2 para verificar la suma
        uut.u_regfile.registers[1] = 64'd15; // x1 = 15
        uut.u_regfile.registers[2] = 64'd25; // x2 = 25

        $display("=== INICIO SIMULACION PIPELINE ===");
        $display("Valores iniciales: x1 = %d, x2 = %d", uut.u_regfile.registers[1], uut.u_regfile.registers[2]);

        // 4. Avance del Pipeline ciclo a ciclo
        clk_en = 1;

        // Ciclo 1: Fetch
        #10;
        $display("[Ciclo 1 - IF]  PC=%d", pc_if);

        // Ciclo 2: Decode
        #10;
        $display("[Ciclo 2 - ID]  PC=%d | Instr_ID=0x%h", pc_id, instr_id);

        // Ciclo 3: Execute
        #10;
        $display("[Ciclo 3 - EX]  PC=%d | OpA=%d, OpB=%d, rd_ex=%d", pc_ex, rdata1_ex, rdata2_ex, rd_ex);

        // Ciclo 4: Memory
        #10;
        $display("[Ciclo 4 - MEM] PC=%d | ALU_Res=%d, rd_mem=%d", pc_mem, alu_res_mem, rd_mem);

        // Ciclo 5: Write-Back
        #10;
        $display("[Ciclo 5 - WB]  PC=%d | ALU_Res=%d, rd_wb=%d", pc_wb, alu_res_wb, rd_wb);

        // Esperar un ciclo extra para que se complete la escritura en x3
        #10;
        clk_en = 0;

        // 5. Verificación de resultado
        debug_reg_addr = 5'd3; // Consultar x3
        #5;
        $display("=== RESULTADO FINAL ===");
        $display("Registro x3 = %d (Esperado: 40)", debug_reg_data);

        if (debug_reg_data === 64'd40) begin
            $display(">>> TEST PASSED: La instruccion ADD funciono correctamente en el pipeline! <<<");
        end else begin
            $display(">>> TEST FAILED: Resultado incorrecto en x3 <<<");
        end

        $finish;
    end

endmodule
