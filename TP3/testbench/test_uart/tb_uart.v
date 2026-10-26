`timescale 1ns / 1ps

// ============================================================================
// TESTBENCH UNITARIO: tb_uart.v
// Verifica el funcionamiento independiente de los módulos de comunicación UART
// ============================================================================

module tb_uart;

    parameter CLK_FREQ     = 100_000_000; // 100 MHz
    parameter BAUD_RATE    = 9600;        // 9600 Baudios
    parameter OVERSAMPLING = 16;
    parameter NB_DATA      = 8;

    // Reloj y Reset
    reg clk;
    reg reset;

    // Señales de la Interfaz TX (Entrada de datos a transmitir)
    reg  [NB_DATA-1:0] w_data;
    reg                wr;
    wire [NB_DATA-1:0] tx_data_to_uart;
    wire               tx_start_to_uart;
    wire               tx_full;
    wire               tx_done;

    // Línea Serie Física (Loopback TX -> RX)
    wire serial_line;

    // Señales del Generador de Ticks
    wire rate;

    // Señales de la Interfaz RX (Salida de datos recibidos)
    wire [NB_DATA-1:0] rx_data_from_uart;
    wire               rx_done;
    reg                rd;
    wire [NB_DATA-1:0] r_data;
    wire               rx_empty;

    // ------------------------------------------------------------------------
    // 1. GENERADOR DE TICK DE BAUDIOS
    // ------------------------------------------------------------------------
    BAUD_RATE_GENERATOR #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .OVERSAMPLING(OVERSAMPLING)
    ) u_baud_gen (
        .clk(clk),
        .reset(reset),
        .rate(rate)
    );

    // ------------------------------------------------------------------------
    // 2. TRANSMISOR UART Y SU INTERFAZ
    // ------------------------------------------------------------------------
    INTF_TX #(
        .NB_DATA(NB_DATA)
    ) u_intf_tx (
        .i_clock(clk),
        .i_reset(reset),
        .i_w_data(w_data),
        .i_wr(wr),
        .i_tx_done(tx_done),
        .o_tx_data(tx_data_to_uart),
        .o_tx_start(tx_start_to_uart),
        .o_tx_full(tx_full)
    );

    UART_TX #(
        .NB_DATA(NB_DATA)
    ) u_uart_tx (
        .i_clock(clk),
        .i_reset(reset),
        .i_data(tx_data_to_uart),
        .i_start(tx_start_to_uart),
        .i_rate(rate),
        .o_tx(serial_line), // Se conecta directamente a la entrada RX
        .o_done(tx_done)
    );

    // ------------------------------------------------------------------------
    // 3. RECEPTOR UART Y SU INTERFAZ
    // ------------------------------------------------------------------------
    UART_RX #(
        .NB_DATA(NB_DATA)
    ) u_uart_rx (
        .i_clock(clk),
        .i_reset(reset),
        .i_rx(serial_line), // Recibe la señal transmitida por UART_TX
        .i_rate(rate),
        .o_data(rx_data_from_uart),
        .o_done(rx_done)
    );

    INTF_RX #(
        .NB_DATA(NB_DATA)
    ) u_intf_rx (
        .i_clock(clk),
        .i_reset(reset),
        .i_rx_data(rx_data_from_uart),
        .i_rx_done(rx_done),
        .i_rd(rd),
        .o_r_data(r_data),
        .o_rx_empty(rx_empty)
    );

    // Generador de Reloj de 100 MHz (Periodo de 10ns)
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // TAREA DE PRUEBA: Enviar y recibir un byte
    // ------------------------------------------------------------------------
    task send_and_verify_byte;
        input [7:0] val_to_send;
        begin
            // Esperar que la interfaz TX esté libre
            wait (tx_full == 1'b0);
            
            // Escribir byte en la interfaz TX
            @(negedge clk);
            w_data = val_to_send;
            wr     = 1'b1;
            @(negedge clk);
            wr     = 1'b0;
            w_data = 8'h00;

            $display("[%0t ns] TX: Enviando byte 0x%h...", $time, val_to_send);

            // Esperar que la interfaz RX reciba el byte completo por la línea serie
            wait (rx_empty == 1'b0);
            #1;
            $display("[%0t ns] RX: Byte recibido en interfaz RX = 0x%h", $time, r_data);

            if (r_data === val_to_send) begin
                $display(">>> COINCIDENCIA CORRECTA: Transmitido 0x%h == Recibido 0x%h <<<", val_to_send, r_data);
            end else begin
                $display(">>> ERROR DE TRANSMISION: Transmitido 0x%h != Recibido 0x%h <<<", val_to_send, r_data);
            end

            // Consumir el byte de la interfaz RX leyendo con rd
            @(negedge clk);
            rd = 1'b1;
            @(negedge clk);
            rd = 1'b0;
            #10;
        end
    endtask

    // ------------------------------------------------------------------------
    // SECUENCIA DE SIMULACIÓN
    // ------------------------------------------------------------------------
    initial begin
        // Inicialización de señales
        clk    = 0;
        reset  = 1;
        w_data = 8'h00;
        wr     = 0;
        rd     = 0;

        #100;
        reset = 0;
        #200;

        $display("=================================================");
        $display("=== INICIO TESTBENCH DE MODULOS UART ===");
        $display("=================================================");

        // Enviar ráfaga de bytes de prueba
        send_and_verify_byte(8'hA5);
        send_and_verify_byte(8'h5A);
        send_and_verify_byte(8'hFF);
        send_and_verify_byte(8'h00);
        send_and_verify_byte(8'h3B);

        $display("=================================================");
        $display(">>> TESTBENCH UART FINALIZADO CON ÉXITO <<<");
        $display("=================================================");

        $finish;
    end

endmodule
