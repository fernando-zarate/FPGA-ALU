`timescale 1ns / 1ps

module OP_CONTROLLER_TB;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg [7:0] rx_data = 8'b0;
    reg rx_done = 1'b0;
    wire [7:0] r_data;
    wire rx_empty;
    wire rx_rd;

    wire [7:0] alu_a;
    wire [7:0] alu_b;
    wire [5:0] alu_op;
    wire [7:0] alu_result;
    wire alu_zero;
    wire alu_carry;

    wire [7:0] tx_data;
    wire tx_wr;
    wire tx_full;
    reg tx_done = 1'b0;

    always #5 clk = ~clk;

    INTF_RX rx_intf (
        .i_clock(clk), .i_reset(reset), .i_rx_data(rx_data),
        .i_rx_done(rx_done), .i_rd(rx_rd), .o_r_data(r_data),
        .o_rx_empty(rx_empty)
    );

    OP_CONTROLLER controller (
        .i_rx_data(r_data), .i_rx_empty(rx_empty), .o_rx_rd(rx_rd),
        .o_alu_a(alu_a), .o_alu_b(alu_b), .o_alu_op(alu_op),
        .i_alu_result(alu_result), .i_tx_full(tx_full),
        .o_tx_data(tx_data), .o_tx_wr(tx_wr),
        .i_clock(clk), .i_reset(reset)
    );

    ALU alu (
        ._A(alu_a), ._B(alu_b), ._OP(alu_op),
        .o_result(alu_result), .o_zero(alu_zero), .o_carry(alu_carry)
    );

    INTF_TX tx_intf (
        .i_clock(clk), .i_reset(reset), .i_w_data(tx_data),
        .i_wr(tx_wr), .i_tx_done(tx_done), .o_tx_data(),
        .o_tx_start(), .o_tx_full(tx_full)
    );

    task receive_byte;
        input [7:0] value;
        begin
            @(negedge clk);
            rx_data = value;
            rx_done = 1'b1;
            @(negedge clk);
            rx_done = 1'b0;
            rx_data = 8'b0;
        end
    endtask

    task expect_result;
        input [7:0] expected;
        begin
            wait (tx_full);
            #1;
            if (tx_intf.o_tx_data !== expected)
                $fatal(1, "Wrong result: got %h, expected %h",
                       tx_intf.o_tx_data, expected);
            @(negedge clk);
            tx_done = 1'b1;
            @(negedge clk);
            tx_done = 1'b0;
        end
    endtask

    initial begin
        #10000;
        $fatal(1, "OP_CONTROLLER_TB timeout");
    end

    initial begin
        repeat (2) @(negedge clk);
        reset = 1'b0;

        // A=5, B=3, ADD=100000 -> 8.
        receive_byte(8'd5);
        receive_byte(8'd3);
        receive_byte(8'b00100000);
        expect_result(8'd8);

        // A=3, B=5, SUB=100010 -> 8'hfe.
        receive_byte(8'd3);
        receive_byte(8'd5);
        receive_byte(8'b00100010);
        expect_result(8'hfe);

        if (alu_zero !== 1'b0 || alu_carry !== 1'b1)
            $fatal(1, "SUB flags are incorrect");

        $display("PASS OP_CONTROLLER_TB");
        $finish;
    end
endmodule
