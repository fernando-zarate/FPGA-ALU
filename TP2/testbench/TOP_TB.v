`timescale 1ns / 1ps

module TOP_TB;
    localparam CLK_FREQ = 100;
    localparam BAUD_RATE = 1;
    localparam OVERSAMPLING = 16;
    localparam CLK_PERIOD_NS = 10;
    localparam BAUD_COUNT = CLK_FREQ / (BAUD_RATE * OVERSAMPLING);
    localparam TICK_NS = CLK_PERIOD_NS * BAUD_COUNT;
    localparam BIT_NS = TICK_NS * OVERSAMPLING;

    reg clk = 1'b0;
    reg reset = 1'b1;
    reg uart_rx = 1'b1;
    wire uart_tx;
    integer bit_index;

    always #5 clk = ~clk;

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

    task send_byte;
        input [7:0] value;
        begin
            uart_rx = 1'b0;
            #(BIT_NS);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                uart_rx = value[bit_index];
                #(BIT_NS);
            end
            uart_rx = 1'b1;
            #(BIT_NS);
        end
    endtask

    task check_received_byte;
        input [7:0] expected;
        reg [7:0] received;
        begin
            wait (uart_tx === 1'b0);
            #(BIT_NS / 2);
            if (uart_tx !== 1'b0)
                $fatal(1, "Invalid TX start bit");

            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                #(BIT_NS);
                received[bit_index] = uart_tx;
            end

            #(BIT_NS);
            if (uart_tx !== 1'b1)
                $fatal(1, "Invalid TX stop bit");
            if (received !== expected)
                $fatal(1, "Wrong result: got %h, expected %h", received, expected);
        end
    endtask

    initial begin
        #100000;
        $fatal(1, "TOP_TB timeout");
    end

    initial begin
        repeat (3) @(negedge clk);
        reset = 1'b0;

        fork
            begin
                // A=5, B=3, ADD=100000 -> 8.
                send_byte(8'd5);
                send_byte(8'd3);
                send_byte(8'b00100000);
            end
            begin
                check_received_byte(8'd8);
            end
        join

        $display("PASS TOP_TB: UART RX -> ALU -> UART TX");
        $finish;
    end
endmodule
