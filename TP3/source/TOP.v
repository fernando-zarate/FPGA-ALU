`timescale 1ns / 1ps

// ============================================================================
// MÓDULO TOP PRINCIPAL 
// Conecta los periféricos físicos UART, la DEBUG_UNIT y el procesador PIPELINE.
// ============================================================================

module TOP #(
    parameter CLK_FREQ     = 100_000_000, // Reloj de 100 MHz de la placa Basys3
    parameter BAUD_RATE    = 9_600,       // Velocidad en baudios
    parameter OVERSAMPLING = 16,          // Muestreo de la UART
    parameter NB_DATA      = 8,           // Trama de 8 bits
    parameter DATA_WIDTH   = 64,          // Datos de 64 bits del procesador
    parameter INSTR_WIDTH  = 32,          // Instrucciones de 32 bits
    parameter ADDR_WIDTH   = 64           // Direcciones de 64 bits
)(
    input  wire i_clock,   // Mapeado a la W5 de la Basys3
    input  wire i_reset,   // Mapeado al pulsador T18 de la Basys3
    input  wire i_uart_rx, // Mapeado al pin B18 (Recepción UART)
    output wire o_uart_tx  // Mapeado al pin A18 (Transmisión UART)
);

    // --- Interconexiones de Reloj e Interfaces UART ---
    wire rate;

    wire [NB_DATA-1:0] uart_rx_data;
    wire               uart_rx_done;

    wire [NB_DATA-1:0] rx_data;
    wire               rx_empty;
    wire               rx_rd;

    wire [NB_DATA-1:0] debug_tx_data;
    wire               debug_tx_wr;
    wire               tx_full;

    wire [NB_DATA-1:0] uart_tx_data;
    wire               uart_tx_start;
    wire               uart_tx_done;

    // --- Interconexiones entre DEBUG_UNIT y PIPELINE ---
    wire                  pipeline_reset;
    wire                  pipeline_clk_en;

    wire                  imem_we;
    wire [ADDR_WIDTH-1:0] imem_addr;
    wire [INSTR_WIDTH-1:0]imem_data;

    wire [4:0]            debug_reg_addr;
    wire [DATA_WIDTH-1:0] debug_reg_data;

    wire [ADDR_WIDTH-1:0] pc_if, pc_id, pc_ex, pc_mem, pc_wb;
    wire [INSTR_WIDTH-1:0]instr_id;
    wire [DATA_WIDTH-1:0] rdata1_ex, rdata2_ex;
    wire [4:0]            rd_ex;
    wire [DATA_WIDTH-1:0] alu_res_mem;
    wire [4:0]            rd_mem;
    wire [DATA_WIDTH-1:0] alu_res_wb;
    wire [4:0]            rd_wb;

    // ------------------------------------------------------------------------
    // 1. GENERADOR DE TICK DE BAUDIOS
    // ------------------------------------------------------------------------
    BAUD_RATE_GENERATOR #(
        .CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE), .OVERSAMPLING(OVERSAMPLING)
    ) u_baud_generator (
        .clk(i_clock), .reset(i_reset), .rate(rate)
    );

    // ------------------------------------------------------------------------
    // 2. RECEPTOR UART Y SU INTERFAZ
    // ------------------------------------------------------------------------
    UART_RX #(.NB_DATA(NB_DATA)) u_uart_rx (
        .i_clock(i_clock), .i_reset(i_reset), .i_rx(i_uart_rx), .i_rate(rate),
        .o_data(uart_rx_data), .o_done(uart_rx_done)
    );

    INTF_RX #(.NB_DATA(NB_DATA)) u_rx_intf (
        .i_clock(i_clock), .i_reset(i_reset),
        .i_rx_data(uart_rx_data), .i_rx_done(uart_rx_done),
        .i_rd(rx_rd), .o_r_data(rx_data), .o_rx_empty(rx_empty)
    );

    // ------------------------------------------------------------------------
    // 3. UNIDAD DE DEPURACIÓN (DEBUG_UNIT)
    // ------------------------------------------------------------------------
    DEBUG_UNIT #(
        .NB_DATA(NB_DATA), .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH), .INSTR_WIDTH(INSTR_WIDTH)
    ) u_debug_unit (
        .i_clock(i_clock), .i_reset(i_reset),
        // Entrada desde UART RX
        .i_rx_data(rx_data), .i_rx_empty(rx_empty), .o_rx_rd(rx_rd),
        // Salida hacia UART TX
        .i_tx_full(tx_full), .o_tx_data(debug_tx_data), .o_tx_wr(debug_tx_wr),
        // Control hacia PIPELINE
        .o_pipeline_reset(pipeline_reset), .o_pipeline_clk_en(pipeline_clk_en),
        // Carga de programa a IMEM
        .o_imem_we(imem_we), .o_imem_addr(imem_addr), .o_imem_data(imem_data),
        // Entrada de estado del PIPELINE para DUMP
        .i_pc_if(pc_if), .i_pc_id(pc_id), .i_pc_ex(pc_ex), .i_pc_mem(pc_mem), .i_pc_wb(pc_wb),
        .i_instr_id(instr_id), .i_rdata1_ex(rdata1_ex), .i_rdata2_ex(rdata2_ex),
        .i_rd_ex(rd_ex), .i_alu_res_mem(alu_res_mem), .i_rd_mem(rd_mem),
        .i_alu_res_wb(alu_res_wb), .i_rd_wb(rd_wb),
        // Consulta del Banco de Registros
        .o_debug_reg_addr(debug_reg_addr), .i_debug_reg_data(debug_reg_data)
    );

    // ------------------------------------------------------------------------
    // 4. PROCESADOR (PIPELINE)
    // ------------------------------------------------------------------------
    PIPELINE #(
        .DATA_WIDTH(DATA_WIDTH), .INSTR_WIDTH(INSTR_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) u_pipeline (
        .clk(i_clock), .reset(pipeline_reset), .clk_en(pipeline_clk_en),
        .imem_we(imem_we), .imem_addr(imem_addr), .imem_data(imem_data),
        .debug_reg_addr(debug_reg_addr), .debug_reg_data(debug_reg_data),
        .o_pc_if(pc_if), .o_pc_id(pc_id), .o_pc_ex(pc_ex), .o_pc_mem(pc_mem), .o_pc_wb(pc_wb),
        .o_instr_id(instr_id), .o_rdata1_ex(rdata1_ex), .o_rdata2_ex(rdata2_ex),
        .o_rd_ex(rd_ex), .o_alu_res_mem(alu_res_mem), .o_rd_mem(rd_mem),
        .o_alu_res_wb(alu_res_wb), .o_rd_wb(rd_wb)
    );

    // ------------------------------------------------------------------------
    // 5. TRANSMISOR UART Y SU INTERFAZ
    // ------------------------------------------------------------------------
    INTF_TX #(.NB_DATA(NB_DATA)) u_tx_intf (
        .i_clock(i_clock), .i_reset(i_reset),
        .i_w_data(debug_tx_data), .i_wr(debug_tx_wr),
        .i_tx_done(uart_tx_done), .o_tx_data(uart_tx_data),
        .o_tx_start(uart_tx_start), .o_tx_full(tx_full)
    );

    UART_TX #(.NB_DATA(NB_DATA)) u_uart_tx (
        .i_clock(i_clock), .i_reset(i_reset),
        .i_data(uart_tx_data), .i_start(uart_tx_start), .i_rate(rate),
        .o_tx(o_uart_tx), .o_done(uart_tx_done)
    );

endmodule
