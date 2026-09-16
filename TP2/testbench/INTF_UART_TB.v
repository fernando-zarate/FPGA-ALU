`timescale 1ns / 1ps

module INTF_UART_TB;
    reg clk = 0;
    reg reset = 1;
    reg rate = 0;
    reg [7:0] w_data = 0;
    reg wr = 0;
    reg rd = 0;
    wire [7:0] tx_data, rx_data, r_data;
    wire tx_start, tx_full, tx_done, serial, rx_done, rx_empty;
    integer starts = 0;
    integer completions = 0;
    integer receptions = 0;
    localparam BIT_NS = 320; // 16 ticks por bit; un tick cada dos ciclos.

    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (reset) rate <= 0;
        else rate <= ~rate;
        if (!reset) begin
            if (tx_start) starts = starts + 1;
            if (tx_done) completions = completions + 1;
            if (rx_done) receptions = receptions + 1;
        end
    end

    INTF_TX tx_intf (
        .i_clock(clk), .i_reset(reset), .i_w_data(w_data), .i_wr(wr),
        .i_tx_done(tx_done), .o_tx_data(tx_data), .o_tx_start(tx_start),
        .o_tx_full(tx_full)
    );
    UART_TX tx (
        .i_clock(clk), .i_reset(reset), .i_data(tx_data), .i_start(tx_start),
        .i_rate(rate), .o_tx(serial), .o_done(tx_done)
    );
    UART_RX rx (
        .i_clock(clk), .i_reset(reset), .i_rx(serial), .i_rate(rate),
        .o_data(rx_data), .o_done(rx_done)
    );
    INTF_RX rx_intf (
        .i_clock(clk), .i_reset(reset), .i_rx_data(rx_data), .i_rx_done(rx_done),
        .i_rd(rd), .o_r_data(r_data), .o_rx_empty(rx_empty)
    );

    task transfer;
        input [7:0] value;
        integer bit_index;
        begin
            fork
                begin
                    @(negedge clk); w_data = value; wr = 1;
                    @(negedge clk); wr = 0; w_data = ~value;
                end
                // Referencia serie independiente: no basta el loopback TX -> RX.
                begin
                    @(negedge serial);
                    #(BIT_NS/2);
                    if (serial !== 0) $fatal(1, "Invalid start bit");
                    for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                        #(BIT_NS);
                        if (serial !== value[bit_index])
                            $fatal(1, "Wrong serial bit %0d for %h", bit_index, value);
                    end
                    #(BIT_NS);
                    if (serial !== 1) $fatal(1, "Invalid stop bit");
                end
                // Observar recepción desde antes del envío: done llega a mitad del stop.
                begin
                    wait (!rx_empty);
                    #1;
                    if (r_data !== value) $fatal(1, "Received %h, expected %h", r_data, value);
                end
            join
            wait (!tx_full);
            repeat (3) @(negedge clk);
            if (rx_empty || r_data !== value) $fatal(1, "RX did not retain received data");
            rd = 1;
            @(negedge clk); rd = 0;
            if (!rx_empty) $fatal(1, "RX read did not consume byte");
        end
    endtask

    initial begin
        #100000;
        $fatal(1, "INTF_UART_TB timeout");
    end

    initial begin
        repeat (3) @(negedge clk);
        reset = 0;
        transfer(8'h00);
        transfer(8'hff);
        transfer(8'h55);
        transfer(8'haa);
        transfer(8'h93);
        #(BIT_NS*12);
        if (starts != 5 || completions != 5 || receptions != 5)
            $fatal(1, "Missing/duplicate transfer: starts=%0d tx=%0d rx=%0d",
                   starts, completions, receptions);
        $display("PASS INTF_UART_TB: 5 serial transfers");
        $finish;
    end
endmodule
