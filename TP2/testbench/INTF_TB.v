`timescale 1ns / 1ps

module INTF_TB;
    parameter NB_DATA = 8;
    reg clk = 0;
    reg reset = 1;
    reg [NB_DATA-1:0] rx_data = 0;
    reg rx_done = 0;
    reg rd = 0;
    wire [NB_DATA-1:0] r_data;
    wire rx_empty;
    reg [NB_DATA-1:0] w_data = 0;
    reg wr = 0;
    reg tx_done = 0;
    wire [NB_DATA-1:0] tx_data;
    wire tx_start, tx_full;
    localparam [NB_DATA-1:0] FIRST = {NB_DATA{1'b1}};
    localparam [NB_DATA-1:0] SECOND = 5;

    always #5 clk = ~clk;

    INTF_RX #(.NB_DATA(NB_DATA)) rx_intf (
        .i_clock(clk), .i_reset(reset), .i_rx_data(rx_data),
        .i_rx_done(rx_done), .i_rd(rd), .o_r_data(r_data),
        .o_rx_empty(rx_empty)
    );
    INTF_TX #(.NB_DATA(NB_DATA)) tx_intf (
        .i_clock(clk), .i_reset(reset), .i_w_data(w_data),
        .i_wr(wr), .i_tx_done(tx_done), .o_tx_data(tx_data),
        .o_tx_start(tx_start), .o_tx_full(tx_full)
    );

    // Estímulos en flanco negativo; comprobaciones después de actualizar registros.
    task step;
        begin @(posedge clk); #1; end
    endtask

    task check;
        input condition;
        input [8*100-1:0] message;
        begin
            if (condition !== 1'b1) $fatal(1, "%0s", message);
        end
    endtask

    initial begin
        #10000;
        $fatal(1, "INTF_TB timeout");
    end

    initial begin
        step;
        check(rx_empty && !tx_full && !tx_start && r_data == 0 && tx_data == 0,
              "Reset must clear data and mark interfaces available");
        @(negedge clk); reset = 0; rd = 1;
        step;
        check(rx_empty, "Reading empty RX must leave it empty");

        @(negedge clk); rd = 0; rx_data = FIRST; rx_done = 1;
        step;
        check(!rx_empty && r_data == FIRST, "RX must capture completed byte");
        @(negedge clk); rx_done = 0; rx_data = SECOND;
        repeat (3) step;
        check(!rx_empty && r_data == FIRST, "RX must retain pending byte");
        @(negedge clk); rx_done = 1;
        step;
        check(!rx_empty && r_data == FIRST, "RX overflow must preserve unread byte");
        @(negedge clk); rd = 1;
        step;
        check(!rx_empty && r_data == SECOND, "RX simultaneous read/write must replace byte");
        @(negedge clk); rx_done = 0;
        step;
        check(rx_empty, "RX read must consume byte");
        @(negedge clk); rx_done = 1; rx_data = FIRST;
        step;
        check(!rx_empty && r_data == FIRST, "RX read while empty must not consume new arrival");
        @(negedge clk); rd = 0; rx_done = 0; wr = 1; w_data = FIRST;
        step;
        check(tx_full && tx_start && tx_data == FIRST, "TX must accept write and start");
        @(negedge clk); w_data = SECOND;
        repeat (3) begin
            step;
            check(tx_full && !tx_start && tx_data == FIRST,
                  "TX must ignore writes while full and pulse start only once");
        end
        @(negedge clk); tx_done = 1;
        step;
        check(!tx_full && !tx_start && tx_data == FIRST,
              "TX completion must release interface without accepting a full write");
        @(negedge clk); tx_done = 0;
        step;
        check(tx_full && tx_start && tx_data == SECOND,
              "TX held write may be accepted on next available edge");
        @(negedge clk); wr = 0;
        step;
        check(tx_full && !tx_start, "TX stays full until completion");
        @(negedge clk); reset = 1; rx_done = 1; rd = 1; wr = 1; tx_done = 1;
        step;
        check(rx_empty && !tx_full && !tx_start && r_data == 0 && tx_data == 0,
              "Reset must override pending data and all handshake inputs");
        @(negedge clk); reset = 0; rx_done = 0; rd = 0; wr = 0; tx_done = 0;
        repeat (3) step;
        check(rx_empty && !tx_full && !tx_start, "Reset must cancel pending transfer");
        $display("PASS INTF_TB NB_DATA=%0d", NB_DATA);
        $finish;
    end
endmodule
