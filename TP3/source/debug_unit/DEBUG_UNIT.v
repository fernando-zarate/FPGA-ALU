`timescale 1ns / 1ps

// ============================================================================
// MÓDULO DEBUG_UNIT
// Máquina de Estados Finita (FSM) que actúa como puente de comunicación
// e inspección entre la PC (vía UART) y el procesador PIPELINE.
// ============================================================================

module DEBUG_UNIT #(
    parameter NB_DATA     = 8,
    parameter ADDR_WIDTH  = 64,
    parameter DATA_WIDTH  = 64,
    parameter INSTR_WIDTH = 32
)(
    // --- Interfaz con INTF_RX (Entrada desde la PC) ---
    input  wire [NB_DATA-1:0]     i_rx_data,        // Byte recibido por UART
    input  wire                   i_rx_empty,       // Flag de buffer vacío
    output reg                    o_rx_rd,          // Confirma lectura de byte

    // --- Interfaz con INTF_TX (Salida hacia la PC) ---
    input  wire                   i_tx_full,        // Flag de buffer lleno
    output reg  [NB_DATA-1:0]     o_tx_data,        // Byte a transmitir por UART
    output reg                    o_tx_wr,          // Habilita transmisión

    // --- Reloj y Reset de la FPGA ---
    input  wire                   i_clock,          // Reloj principal (100 MHz)
    input  wire                   i_reset,          // Reset por pulsador de placa

    // --- Control de Ejecución sobre el PIPELINE ---
    output reg                    o_pipeline_reset, // Reset de la CPU
    output reg                    o_pipeline_clk_en,// Habilitador de reloj CPU

    // --- Interfaz de Carga de Memoria IMEM ---
    output reg                    o_imem_we,        // Habilita escritura en IMEM
    output reg  [ADDR_WIDTH-1:0]  o_imem_addr,      // Dirección en IMEM
    output reg  [INSTR_WIDTH-1:0] o_imem_data,      // Instrucción a escribir

    // --- Entradas de Inspección desde el PIPELINE (Para DUMP) ---
    input  wire [ADDR_WIDTH-1:0]  i_pc_if,          // PC en etapa IF
    input  wire [ADDR_WIDTH-1:0]  i_pc_id,          // PC en etapa ID
    input  wire [ADDR_WIDTH-1:0]  i_pc_ex,          // PC en etapa EX
    input  wire [ADDR_WIDTH-1:0]  i_pc_mem,         // PC en etapa MEM
    input  wire [ADDR_WIDTH-1:0]  i_pc_wb,          // PC en etapa WB
    input  wire [INSTR_WIDTH-1:0] i_instr_id,       // Instrucción en ID
    input  wire [DATA_WIDTH-1:0]  i_rdata1_ex,      // Operando A en EX
    input  wire [DATA_WIDTH-1:0]  i_rdata2_ex,      // Operando B en EX
    input  wire [4:0]            i_rd_ex,          // rd en EX
    input  wire [DATA_WIDTH-1:0]  i_alu_res_mem,    // Resultado en MEM
    input  wire [4:0]            i_rd_mem,         // rd en MEM
    input  wire [DATA_WIDTH-1:0]  i_alu_res_wb,     // Resultado en WB
    input  wire [4:0]            i_rd_wb,          // rd en WB

    // --- Interfaz de Consulta de Registros ---
    output reg  [4:0]            o_debug_reg_addr, // Índice de registro (0-31)
    input  wire [DATA_WIDTH-1:0]  i_debug_reg_data  // Valor del registro
);

    // Opcodes de Comandos UART (1 Byte)
    localparam [7:0] CMD_HALT       = 8'h00; // Pausa la ejecución continua
    localparam [7:0] CMD_RESET      = 8'h01; // Reinicia el procesador
    localparam [7:0] CMD_WRITE_IMEM = 8'h02; // Escribe una instrucción en IMEM
    localparam [7:0] CMD_STEP       = 8'h03; // Ejecuta 1 ciclo de reloj (Step)
    localparam [7:0] CMD_RUN        = 8'h04; // Ejecuta en modo continuo
    localparam [7:0] CMD_DUMP_STATE = 8'h05; // Transmite el estado completo a la PC

    // Estados de la FSM
    localparam [4:0] STATE_IDLE         = 5'd0;
    localparam [4:0] STATE_WMEM_ADDR    = 5'd1;
    localparam [4:0] STATE_WMEM_B3      = 5'd2;
    localparam [4:0] STATE_WMEM_B2      = 5'd3;
    localparam [4:0] STATE_WMEM_B1      = 5'd4;
    localparam [4:0] STATE_WMEM_B0      = 5'd5;
    localparam [4:0] STATE_WMEM_WRITE   = 5'd6;
    localparam [4:0] STATE_RESET_PULSE  = 5'd7;
    localparam [4:0] STATE_STEP_PULSE   = 5'd8;
    localparam [4:0] STATE_DUMP_SETUP   = 5'd9;
    localparam [4:0] STATE_DUMP_SEND    = 5'd10;
    localparam [4:0] STATE_DUMP_NEXT    = 5'd11;
    localparam [4:0] STATE_SEND_ACK     = 5'd12;

    reg [4:0] state;

    // Registros auxiliares para el armado de datos
    reg [7:0]             wmem_addr_reg;
    reg [INSTR_WIDTH-1:0] wmem_data_reg;
    reg [7:0]             ack_code;

    // Contadores de DUMP
    reg [8:0] dump_idx;
    reg [7:0] byte_to_send;
    reg       run_mode;

    // Cálculos para la extracción en ráfaga del Banco de Registros (32 reg x 8 bytes)
    wire [4:0] reg_num  = (dump_idx - 9'd80) >> 3;
    wire [2:0] byte_pos = (dump_idx - 9'd80) & 3'b111;

    // Multiplexor de armado de la trama DUMP enviada por UART
    always @(*) begin
        byte_to_send = 8'h00;
        if (dump_idx == 9'd0) begin
            byte_to_send = 8'hDD; // Header de inicio de DUMP
        end
        // Envío del PC IF (8 bytes)
        else if (dump_idx >= 9'd1 && dump_idx <= 9'd8) begin
            byte_to_send = i_pc_if[(8 - (dump_idx - 9'd1))*8 - 1 -: 8];
        end
        // Envío del PC ID (8 bytes)
        else if (dump_idx >= 9'd9 && dump_idx <= 9'd16) begin
            byte_to_send = i_pc_id[(8 - (dump_idx - 9'd9))*8 - 1 -: 8];
        end
        // Envío del PC EX (8 bytes)
        else if (dump_idx >= 9'd17 && dump_idx <= 9'd24) begin
            byte_to_send = i_pc_ex[(8 - (dump_idx - 9'd17))*8 - 1 -: 8];
        end
        // Envío del PC MEM (8 bytes)
        else if (dump_idx >= 9'd25 && dump_idx <= 9'd32) begin
            byte_to_send = i_pc_mem[(8 - (dump_idx - 9'd25))*8 - 1 -: 8];
        end
        // Envío del PC WB (8 bytes)
        else if (dump_idx >= 9'd33 && dump_idx <= 9'd40) begin
            byte_to_send = i_pc_wb[(8 - (dump_idx - 9'd33))*8 - 1 -: 8];
        end
        // Envío de la Instrucción en ID (4 bytes)
        else if (dump_idx >= 9'd41 && dump_idx <= 9'd44) begin
            byte_to_send = i_instr_id[(4 - (dump_idx - 9'd41))*8 - 1 -: 8];
        end
        // Envío del Operando A en EX (8 bytes)
        else if (dump_idx >= 9'd45 && dump_idx <= 9'd52) begin
            byte_to_send = i_rdata1_ex[(8 - (dump_idx - 9'd45))*8 - 1 -: 8];
        end
        // Envío del Operando B en EX (8 bytes)
        else if (dump_idx >= 9'd53 && dump_idx <= 9'd60) begin
            byte_to_send = i_rdata2_ex[(8 - (dump_idx - 9'd53))*8 - 1 -: 8];
        end
        // Envío de rd en EX (1 byte)
        else if (dump_idx == 9'd61) begin
            byte_to_send = {3'b000, i_rd_ex};
        end
        // Envío del Resultado ALU en MEM (8 bytes)
        else if (dump_idx >= 9'd62 && dump_idx <= 9'd69) begin
            byte_to_send = i_alu_res_mem[(8 - (dump_idx - 9'd62))*8 - 1 -: 8];
        end
        // Envío de rd en MEM (1 byte)
        else if (dump_idx == 9'd70) begin
            byte_to_send = {3'b000, i_rd_mem};
        end
        // Envío del Resultado ALU en WB (8 bytes)
        else if (dump_idx >= 9'd71 && dump_idx <= 9'd78) begin
            byte_to_send = i_alu_res_wb[(8 - (dump_idx - 9'd71))*8 - 1 -: 8];
        end
        // Envío de rd en WB (1 byte)
        else if (dump_idx == 9'd79) begin
            byte_to_send = {3'b000, i_rd_wb};
        end
        // Envío secuencial de los 32 Registros (256 bytes)
        else if (dump_idx >= 9'd80 && dump_idx <= 9'd335) begin
            byte_to_send = i_debug_reg_data[(8 - byte_pos)*8 - 1 -: 8];
        end
        else if (dump_idx == 9'd336) begin
            byte_to_send = 8'hFF; // Footer de final de DUMP
        end
    end

    // Máquina de Estados
    always @(posedge i_clock) begin
        if (i_reset) begin
            state             <= STATE_IDLE;
            o_rx_rd           <= 1'b0;
            o_tx_wr           <= 1'b0;
            o_tx_data         <= 8'h00;
            o_pipeline_reset  <= 1'b1;
            o_pipeline_clk_en <= 1'b0;
            o_imem_we         <= 1'b0;
            o_imem_addr       <= {ADDR_WIDTH{1'b0}};
            o_imem_data       <= {INSTR_WIDTH{1'b0}};
            o_debug_reg_addr  <= 5'b0;
            wmem_addr_reg     <= 8'h00;
            wmem_data_reg     <= {INSTR_WIDTH{1'b0}};
            ack_code          <= 8'h00;
            dump_idx          <= 9'd0;
            run_mode          <= 1'b0;
        end else begin
            o_rx_rd          <= 1'b0;
            o_tx_wr          <= 1'b0;
            o_imem_we        <= 1'b0;
            o_pipeline_reset <= 1'b0;

            if (run_mode)
                o_pipeline_clk_en <= 1'b1;

            case (state)
                STATE_IDLE: begin
                    if (!i_rx_empty) begin
                        o_rx_rd <= 1'b1;
                        case (i_rx_data)
                            CMD_HALT: begin
                                run_mode          <= 1'b0;
                                o_pipeline_clk_en <= 1'b0;
                                ack_code          <= CMD_HALT;
                                state             <= STATE_SEND_ACK;
                            end
                            CMD_RESET: begin
                                run_mode          <= 1'b0;
                                o_pipeline_clk_en <= 1'b0;
                                o_pipeline_reset  <= 1'b1;
                                ack_code          <= CMD_RESET;
                                state             <= STATE_RESET_PULSE;
                            end
                            CMD_WRITE_IMEM: begin
                                run_mode          <= 1'b0;
                                o_pipeline_clk_en <= 1'b0;
                                state             <= STATE_WMEM_ADDR;
                            end
                            CMD_STEP: begin
                                run_mode          <= 1'b0;
                                o_pipeline_clk_en <= 1'b1;
                                ack_code          <= CMD_STEP;
                                state             <= STATE_STEP_PULSE;
                            end
                            CMD_RUN: begin
                                run_mode          <= 1'b1;
                                o_pipeline_clk_en <= 1'b1;
                                ack_code          <= CMD_RUN;
                                state             <= STATE_SEND_ACK;
                            end
                            CMD_DUMP_STATE: begin
                                dump_idx         <= 9'd0;
                                o_debug_reg_addr <= 5'b0;
                                state            <= STATE_DUMP_SETUP;
                            end
                            default: state <= STATE_IDLE;
                        endcase
                    end
                end

                // Recepción de dirección y los 4 bytes de la instrucción
                STATE_WMEM_ADDR: begin
                    if (!i_rx_empty) begin
                        o_rx_rd       <= 1'b1;
                        wmem_addr_reg <= i_rx_data;
                        state         <= STATE_WMEM_B3;
                    end
                end

                STATE_WMEM_B3: begin
                    if (!i_rx_empty) begin
                        o_rx_rd               <= 1'b1;
                        wmem_data_reg[31:24] <= i_rx_data;
                        state                 <= STATE_WMEM_B2;
                    end
                end

                STATE_WMEM_B2: begin
                    if (!i_rx_empty) begin
                        o_rx_rd               <= 1'b1;
                        wmem_data_reg[23:16] <= i_rx_data;
                        state                 <= STATE_WMEM_B1;
                    end
                end

                STATE_WMEM_B1: begin
                    if (!i_rx_empty) begin
                        o_rx_rd              <= 1'b1;
                        wmem_data_reg[15:8] <= i_rx_data;
                        state                <= STATE_WMEM_B0;
                    end
                end

                STATE_WMEM_B0: begin
                    if (!i_rx_empty) begin
                        o_rx_rd             <= 1'b1;
                        wmem_data_reg[7:0]  <= i_rx_data;
                        state               <= STATE_WMEM_WRITE;
                    end
                end

                STATE_WMEM_WRITE: begin
                    o_imem_we   <= 1'b1;
                    o_imem_addr <= { {(ADDR_WIDTH-8){1'b0}}, wmem_addr_reg };
                    o_imem_data <= wmem_data_reg;
                    ack_code    <= 8'hAA; // Confirmación de grabación exitosa
                    state       <= STATE_SEND_ACK;
                end

                STATE_RESET_PULSE: begin
                    o_pipeline_reset <= 1'b1;
                    state            <= STATE_SEND_ACK;
                end

                STATE_STEP_PULSE: begin
                    o_pipeline_clk_en <= 1'b0;
                    state             <= STATE_SEND_ACK;
                end

                STATE_DUMP_SETUP: begin
                    if (dump_idx >= 9'd80 && dump_idx <= 9'd335) begin
                        o_debug_reg_addr <= reg_num;
                    end
                    state <= STATE_DUMP_SEND;
                end

                STATE_DUMP_SEND: begin
                    if (!i_tx_full) begin
                        o_tx_data <= byte_to_send;
                        o_tx_wr   <= 1'b1;
                        state     <= STATE_DUMP_NEXT;
                    end
                end

                STATE_DUMP_NEXT: begin
                    if (dump_idx == 9'd336) begin
                        state <= STATE_IDLE;
                    end else begin
                        dump_idx <= dump_idx + 1'b1;
                        state    <= STATE_DUMP_SETUP;
                    end
                end

                STATE_SEND_ACK: begin
                    if (!i_tx_full) begin
                        o_tx_data <= ack_code;
                        o_tx_wr   <= 1'b1;
                        state     <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule

// DUMP: es el proceso de extraer y transmitir de manera masiva todo el estado 
// interno del hardware hacia un sistema externo (en nuestro caso desde UART hacia la PC).