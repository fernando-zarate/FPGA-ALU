`timescale 1ns / 1ps

module UART_TX
#
(
    parameter NB_DATA = 8
)
(
    input  wire i_clock,
    input  wire i_reset,
    input  wire [NB_DATA-1:0] i_data,
    input  wire i_start,
    input  wire i_rate,
    
    output reg  o_tx,
    output reg  o_done
);
    // Estados
    localparam IDLE  = 4'b0001;
    localparam START = 4'b0010;
    localparam DATA  = 4'b0100;
    localparam STOP  = 4'b1000;

    reg [3:0] state;
    reg [3:0] next_state;

    // Contadores
    reg [3:0] tick_counter;
    reg [$clog2(NB_DATA)-1:0] bit_counter;
    
    // Shift register
    reg [NB_DATA-1:0] shift_reg;

    // Registro de estado
    always @(posedge i_clock) begin
        if (i_reset)    state <= IDLE;
        else          state <= next_state;
    end

    // Próximo estado
    always @(*) begin

        next_state = state;

        case (state)
            IDLE: begin
                if (i_start)  //cuando se un "1" en i_start, se inicia la transmisión
                    next_state = START;
            end

            START: begin
                if (i_rate && tick_counter == 4'd15) //cuando se genera un tick, paso recibir los bits
                    next_state = DATA;
            end

            DATA: begin
                if (i_rate && tick_counter == 4'd15) begin
                    if (bit_counter == NB_DATA-1) //cuando se recibieron todos los bits, paso a stop
                        next_state = STOP;
                end
            end

            STOP: begin
                if (i_rate && tick_counter == 4'd15) //cuando se genera un tick, paso a idle
                    next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Tick Counter
    always @(posedge i_clock) begin
        if (i_reset) begin
            tick_counter <= 4'd0;
        end
        else if (state == IDLE) begin
            tick_counter <= 4'd0;
        end
        else if (i_rate) begin
            if (tick_counter == 4'd15) begin
                tick_counter <= 4'd0;
            end
            else begin
                tick_counter <= tick_counter + 1'b1;
            end
        end
    end

    // Bit Counter
    always @(posedge i_clock) begin
        if (i_reset) begin
            bit_counter <= 0;
        end
        else if (state == IDLE) begin
            bit_counter <= 0;
        end
        else if (state == DATA && i_rate && tick_counter == 4'd15) begin
            bit_counter <= bit_counter + 1'b1;
        end
    end

    // Shift Register
    always @(posedge i_clock) begin
        if (i_reset) begin
            shift_reg <= 0;
        end
        else if (state == IDLE && i_start) begin
            shift_reg <= i_data;
        end
        else if (state == DATA && i_rate && tick_counter == 4'd15) begin
            shift_reg <= {1'b0, shift_reg[NB_DATA-1:1]};
        end
    end

    // Salida 
    always @(posedge i_clock) begin
        if (i_reset) begin
            o_tx   <= 1'b1;
            o_done <= 1'b0;
        end
        else begin
            o_done <= 1'b0;
            case (state)
                IDLE: begin
                    o_tx <= 1'b1;
                end
                START: begin
                    o_tx <= 1'b0;
                end
                DATA: begin
                    o_tx <= shift_reg[0]; //se envía el bit menos significativo primero
                end
                STOP: begin
                    o_tx <= 1'b1;
                    if (i_rate && tick_counter == 4'd15)
                        o_done <= 1'b1;
                end
                default: begin
                    o_tx <= 1'b1;
                end
            endcase
        end
    end
endmodule
