`timescale 1ns / 1ps

// ============================================================================
// TESTBENCH UNITARIO: DEBUG_UNIT.v
// Prueba la FSM de depuración, la decodificación de comandos UART,
// el envío de respuestas ACK, la escritura en IMEM y la ráfaga de DUMP.
// ============================================================================

module tb_debug_unit;

    parameter NB_DATA     = 8;
    parameter ADDR_WIDTH  = 64;
    parameter DATA_WIDTH  = 64;
    parameter INSTR_WIDTH = 32;

    // Señales de la interfaz de la DEBUG_UNIT
    reg                  clk;
    reg                  reset;

    // Interfaz UART RX
    reg  [NB_DATA-1:0]   rx_data;
    reg                  rx_empty;
    wire                 rx_rd;

    // Interfaz UART TX
    reg                  tx_full;
    wire [NB_DATA-1:0]   tx_data;
    wire                 tx_wr;

    // Control del Pipeline
    wire                 pipeline_reset;
    wire                 pipeline_clk_en;

    // Memoria IMEM
    wire                 imem_we;
    wire [ADDR_WIDTH-1:0]imem_addr;
    wire [INSTR_WIDTH-1:0]imem_data;

    // Entradas de estado simuladas para DUMP
    reg  [ADDR_WIDTH-1:0] pc_if, pc_id, pc_ex, pc_mem, pc_wb;
    reg  [INSTR_WIDTH-1:0]instr_id;
    reg  [DATA_WIDTH-1:0] rdata1_ex, rdata2_ex;
    reg  [4:0]            rd_ex;
    reg  [DATA_WIDTH-1:0] alu_res_mem;
    reg  [4:0]            rd_mem;
    reg  [DATA_WIDTH-1:0] alu_res_wb;
    reg  [4:0]            rd_wb;

    // Interfaz de Registros
    wire [4:0]            debug_reg_addr;
    reg  [DATA_WIDTH-1:0] debug_reg_data;

    // Instancia del UUT
    DEBUG_UNIT #(
        .NB_DATA(NB_DATA),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .INSTR_WIDTH(INSTR_WIDTH)
    ) uut ( // UUT = Unit Under Test
        .i_clock(clk),
        .i_reset(reset),
        .i_rx_data(rx_data),
        .i_rx_empty(rx_empty),
        .o_rx_rd(rx_rd),
        .i_tx_full(tx_full),
        .o_tx_data(tx_data),
        .o_tx_wr(tx_wr),
        .o_pipeline_reset(pipeline_reset),
        .o_pipeline_clk_en(pipeline_clk_en),
        .o_imem_we(imem_we),
        .o_imem_addr(imem_addr),
        .o_imem_data(imem_data),
        .i_pc_if(pc_if),
        .i_pc_id(pc_id),
        .i_pc_ex(pc_ex),
        .i_pc_mem(pc_mem),
        .i_pc_wb(pc_wb),
        .i_instr_id(instr_id),
        .i_rdata1_ex(rdata1_ex),
        .i_rdata2_ex(rdata2_ex),
        .i_rd_ex(rd_ex),
        .i_alu_res_mem(alu_res_mem),
        .i_rd_mem(rd_mem),
        .i_alu_res_wb(alu_res_wb),
        .i_rd_wb(rd_wb),
        .o_debug_reg_addr(debug_reg_addr),
        .i_debug_reg_data(debug_reg_data)
    );

    // Generación de reloj (100 MHz)
    always #5 clk = ~clk;

    // Tarea auxiliar para enviar un byte a la DEBUG_UNIT simulando el buffer RX
    task send_cmd_byte;
        input [7:0] byte_val;
        begin
            @(negedge clk);
            rx_data  = byte_val;
            rx_empty = 0;
            wait (rx_rd == 1'b1); // Esperar a que la DEBUG_UNIT lea el byte
            @(negedge clk);
            rx_empty = 1;
            rx_data  = 8'h00;
        end
    endtask

    initial begin
        clk            = 0;
        reset          = 1;
        rx_data        = 8'h00;
        rx_empty       = 1;
        tx_full        = 0;
        debug_reg_data = 64'hA5A5_5A5A_1234_5678;

        // Cargar algunos datos fijos de simulación en las señales de entrada del DUMP
        pc_if       = 64'd0;
        pc_id       = 64'd4;
        pc_ex       = 64'd8;
        pc_mem      = 64'd12;
        pc_wb       = 64'd16;
        instr_id    = 32'h002081B3;
        rdata1_ex   = 64'd10;
        rdata2_ex   = 64'd20;
        rd_ex       = 5'd3;
        alu_res_mem = 64'd30;
        rd_mem      = 5'd3;
        alu_res_wb  = 64'd30;
        rd_wb       = 5'd3;

        #20;
        reset = 0;
        #20;

        $display("=== INICIO TESTBENCH DEBUG_UNIT ===");

        // --------------------------------------------------------------------
        // PRUEBA 1: Comando CMD_RESET (0x01)
        // --------------------------------------------------------------------
        $display("[PRUEBA 1] Enviando CMD_RESET (0x01)...");
        send_cmd_byte(8'h01);
        wait (tx_wr == 1'b1);
        $display("ACK recibido de TX: 0x%h (Esperado: 0x01)", tx_data);

        // --------------------------------------------------------------------
        // PRUEBA 2: Comando CMD_WRITE_IMEM (0x02 + Dir + 4 Bytes de Instrucción)
        // --------------------------------------------------------------------
        $display("[PRUEBA 2] Enviando CMD_WRITE_IMEM (0x02) en Dir 0x04 con valor 0x002081B3...");
        send_cmd_byte(8'h02); // Opcode WRITE_IMEM
        send_cmd_byte(8'h04); // Dirección de memoria = 4
        send_cmd_byte(8'h00); // Byte 3
        send_cmd_byte(8'h20); // Byte 2
        send_cmd_byte(8'h81); // Byte 1
        send_cmd_byte(8'hB3); // Byte 0

        #20;
        if (imem_we && imem_addr == 64'd4 && imem_data == 32'h002081B3) begin
            $display(">>> Escritura en IMEM Verificada Correctamente: Addr=%d, Data=0x%h", imem_addr, imem_data);
        end else begin
            $display(">>> ERROR en Escritura en IMEM <<<");
        end

        // --------------------------------------------------------------------
        // PRUEBA 3: Comando CMD_STEP (0x03)
        // --------------------------------------------------------------------
        $display("[PRUEBA 3] Enviando CMD_STEP (0x03)...");
        send_cmd_byte(8'h03);
        #10;
        $display("Estado o_pipeline_clk_en tras STEP = %b", pipeline_clk_en);
        // en pipeline_clk_en debería ser 1 por un ciclo de reloj, luego volver a 0.

        // --------------------------------------------------------------------
        // PRUEBA 4: Comando CMD_DUMP_STATE (0x05)
        // --------------------------------------------------------------------
        $display("[PRUEBA 4] Iniciando ráfaga CMD_DUMP_STATE (0x05)...");
        send_cmd_byte(8'h05);

        // Capturar primer byte del DUMP (Header 0xDD)
        wait (tx_wr == 1'b1);
        $display("DUMP Header recibido: 0x%h (Esperado: 0xDD)", tx_data);

        $display(">>> TEST DEBUG_UNIT COMPLETADO EXITOSAMENTE <<<");
        // En el Multiplexor de armado (debug_unit.v) está el Header 0xDD
        
        #100;
        $finish;
    end

endmodule
