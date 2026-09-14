module UART_RX
#(
    parameter NB_DATA = 8
)
(
    input  wire i_clock,
    input  wire i_reset,
    input  wire i_rx,

    output reg [NB_DATA-1:0] o_data,
    output reg               o_done
);

    // Estados
    localparam IDLE  = 4'b0001; // estado de reposo en "1"
    localparam START = 4'b0010; // cuando cae a "0" el i_rx, se entra en este estado
    localparam DATA  = 4'b0100; // estado de recepción de datos
    localparam STOP  = 4'b1000; // estado de recepción de bit stop

    reg [3:0] state;
    reg [3:0] next_state;

    // Contadores
    reg [3:0] tick_counter;
    reg [3:0] bit_counter;

    // Shift register
    reg [NB_DATA-1:0] shift_reg;

    // Registro de estado
    always @(posedge i_clock) begin

        if (i_reset)    state <= IDLE;
        else            state <= next_state;
    end

    // Próximo estado
    always @(*) begin

        next_state = state;

        case (state)
            IDLE: begin
                if (i_rx == 1'b0)  //cae a "0" el i_rx, inicia la recepción de datos
                    next_state = START;
            end

            START: begin
                if (tick_counter == 4'd7) begin //controlo a la mitad del bit de start para asegurarme que es un "0" y no un ruido
                    if (i_rx == 1'b0)
                        next_state = DATA;
                    else
                        next_state = IDLE;
                end
            end

            DATA: begin
                if (tick_counter == 4'd15) begin
                    if (bit_counter == NB_DATA-1) //cuando se recibieron todos los bits de datos, paso al estado de stop
                        next_state = STOP;
                end
            end

            STOP: begin
                if (tick_counter == 4'd15)
                    next_state = IDLE;
            end

            default:
                next_state = IDLE;
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
        else if (tick_counter == 4'd15) begin
            tick_counter <= 4'd0;
        end
        else begin
            tick_counter <= tick_counter + 1'b1;
        end
    end

    // Bit Counter
    always @(posedge i_clock) begin
        if (i_reset) begin
            bit_counter <= 4'd0;
        end
        else if (state == IDLE || state == START) begin
            bit_counter <= 4'd0;
        end
        else if (state == DATA && tick_counter == 4'd15) begin
            bit_counter <= bit_counter + 1'b1;
        end
    end

    // Shift Register
    always @(posedge i_clock) begin
        if (i_reset) begin
            shift_reg <= {NB_DATA{1'b0}};
        end
        else if (state == DATA && tick_counter == 4'd15) begin
            shift_reg <= {i_rx, shift_reg[NB_DATA-1:1]};
            // i_rx entra por la izquierda y todos los demás bits se desplazan 
            //una posición hacia la derecha.
        end
    end

    // Salida
    always @(posedge i_clock) begin
        if (i_reset) begin
            o_data <= {NB_DATA{1'b0}};
            o_done <= 1'b0;
        end
        else begin
            o_done <= 1'b0;
            //controlo que el bit de stop se haya recibido correctamente, 
            //y que haya pasado un tick completo
            if (state == STOP && tick_counter == 4'd15) begin 
                o_data <= shift_reg; //seteo el dato recibido en la salida
                o_done <= 1'b1; //indico que se recibió un dato completo
            end
        end
    end
endmodule
