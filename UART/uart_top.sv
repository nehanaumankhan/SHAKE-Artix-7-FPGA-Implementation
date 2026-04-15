module uart_top #(
    parameter CLKDIV = 3,
    parameter DEPTH  = 16
)(
    input  logic clk,
    input  logic rst,

    input  logic wr_en,
    input  logic [7:0] wr_data,
    output logic full,

    output logic tx
);

    logic rd_en;
    logic [7:0] rd_data;
    logic empty;

    logic tx_start, tx_done;
    logic [7:0] tx_data;

    // Buffer
    simple_buffer #(DEPTH) buffer (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .empty(empty),
        .full(full)
    );

    // Controller
    uart_controller ctrl (
        .clk(clk),
        .rst(rst),
        .tx_done(tx_done),
        .empty(empty),
        .buffer_data(rd_data),
        .rd_en(rd_en),
        .tx_start(tx_start),
        .tx_data(tx_data)
    );

    // Transmitter
    transmitter #(.clkdiv(CLKDIV)) tx_inst (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_done(tx_done),
        .tx(tx)
    );

endmodule