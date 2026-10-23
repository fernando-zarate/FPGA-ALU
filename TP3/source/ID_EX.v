`timescale 1ns / 1ps

module ID_EX
#
(
    parameter DATA_WIDTH = 64
)
(
    input  wire                  clk,
    input  wire                  reset,
    input  wire [DATA_WIDTH-1:0] read_data1_in,
    input  wire [DATA_WIDTH-1:0] read_data2_in,
    input  wire [4:0]            rd_in,
    output reg  [DATA_WIDTH-1:0] read_data1_out,
    output reg  [DATA_WIDTH-1:0] read_data2_out,
    output reg  [4:0]            rd_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            read_data1_out <= {DATA_WIDTH{1'b0}};
            read_data2_out <= {DATA_WIDTH{1'b0}};
            rd_out         <= 5'b0;
        end else begin
            read_data1_out <= read_data1_in;
            read_data2_out <= read_data2_in;
            rd_out         <= rd_in;
        end
    end
endmodule

// solamente un pasamanos de los datos que salen de REGISTER.v