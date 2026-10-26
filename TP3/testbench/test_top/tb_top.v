`timescale 1ns / 1ps

// ============================================================================
// TESTBENCH INTEGRAL: tb_top.v
// Verificación completa de la comunicación UART con la DEBUG_UNIT y PIPELINE.
// ============================================================================

module tb_top;

    // Parámetros de comunicación (9600 Baudios a 100 MHz)
    localparam CLK_FREQ     = 100_000_000; // 100 MHz
    localparam BAUD_RATE    = 9_600;       // 9600 Baudios
    localparam OVERSAMPLING = 16;
    localparam CLK_PERIOD   = 10;          // Periodo de reloj = 10 ns

    localparam BAUD_COUNT   = CLK_FREQ / (BAUD_RATE * OVERSAMPLING); //BAUD_COUNT = 651
    localparam TICK_NS      = CLK_PERIOD * BAUD_COUNT; // TICK_NS = 6510 ns
    localparam BIT_NS       = TICK_NS * OVERSAMPLING; // BIT_NS = 104.160 ns

    // Señales físicas para el TOP
    reg  clk;
    reg  reset;
    reg  uart_rx;
    wire uart_tx;

    reg [7:0] response_byte;

    // Instancia del sistema completo TOP
    TOP #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .OVERSAMPLING(OVERSAMPLING)
    ) dut (
        .i_clock(clk),
        .i_reset(reset),
        .i_uart_rx(uart_rx),
        .o_uart_tx(uart_tx)
    );

    // Generador de Reloj de 100 MHz
    always #(CLK_PERIOD/2) clk = ~clk;

    // Tarea para enviar un byte serie por i_uart_rx (LSB primero)
    task send_uart_byte;
        input [7:0] data_byte;
        integer i;
        begin
            // Bit de Start (0)
            uart_rx = 1'b0;
            #(BIT_NS); // Mantener el bit de Start durante un período de bit completo

            // 8 Bits de Datos
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = data_byte[i];
                #(BIT_NS);
            end

            // Bit de Stop (1)
            uart_rx = 1'b1;
            #(BIT_NS);
        end
    endtask

    // Tarea para recibir un byte serie por o_uart_tx (LSB primero)
    task receive_uart_byte;
        output [7:0] received_byte;
        integer i;
        begin
            received_byte = 8'h00;

            // Esperar el bit de Start (0 en la línea de transmisión de la FPGA)
            wait (uart_tx === 1'b0);

            // Posicionarse en el centro del bit de Start
            #(BIT_NS / 2);

            // Muestrear los 8 bits de datos (i = 0 es LSB)
            for (i = 0; i < 8; i = i + 1) begin
                #(BIT_NS);
                received_byte[7-i] = uart_tx;
            end

            // Esperar el bit de Stop
            #(BIT_NS);
        end
    endtask

    // Secuencia de Simulación
    initial begin
        clk     = 0;
        reset   = 1;
        uart_rx = 1; // Línea serie en reposo (1)

        #1000; // son sleeps, no colores 
        reset   = 0;
        #2000;

        $display("=================================================");
        $display("=== INICIO SIMULACION INTEGRAL DEL SISTEMA TOP ===");
        $display("=== Velocidad: 9600 Baudios | Reloj: 100 MHz   ===");
        $display("=================================================");

        // PASO 1: Enviar Comando CMD_RESET (0x01) por la línea serie
        $display("[%0t ns] [TX PC] Enviando comando CMD_RESET (0x01)...", $time);
        send_uart_byte(8'h01);
        $display("[%0t ns] [TX PC] Comando enviado. Esperando respuesta ACK de la FPGA...", $time);

        // PASO 2: Recibir Respuesta ACK (0x01) enviada por la FPGA
        receive_uart_byte(response_byte);

        $display("[%0t ns] [RX PC] Respuesta recibida de la FPGA: 0x%h", $time, response_byte);

        if (response_byte === 8'h01) begin
            $display("=================================================");
            $display(">>> CONEXION Y COMUNICACION UART INTEGRA VERIFICADA CON ÉXITO! <<<");
            $display(">>> Respuesta confirmada: 0x01 == 0x01 <<<");
            $display("=================================================");
        end else begin
            $display(">>> ERROR: Respuesta incorrecta (Esperado 0x01, Recibido 0x%h) <<<", response_byte);
        end

        #10000;
        $finish;
    end

endmodule
