module top #(
    parameter clkdiv = 868,
    parameter BRAM_DEPTH = 256,
    parameter OUTPUT_BUFFER_DEPTH_WORDS = 256
)(
    input  logic clk,
    input  logic rst_n,
    output logic tr_start,
    output logic tr_end,
    output logic tx
);

    logic rd_en;
    logic [7:0] rd_data;
    logic empty;

    logic tx_start, tx_done;
    logic [7:0] tx_data;
    logic [$clog2(OUTPUT_BUFFER_DEPTH_WORDS * (w/8))-1:0] rd_addr;

 shake_top #(.OUTPUT_BUFFER_DEPTH_WORDS(OUTPUT_BUFFER_DEPTH_WORDS), .BRAM_DEPTH(BRAM_DEPTH))
    shake (
    .clk(clk),
    .rst_n(rst_n),
    .done(tr_start),
    .buffer_dout_byte(rd_data),
    .buffer_read_en(rd_en),
    .buffer_read_addr(rd_addr)
);

    // Controller
    uart_controller  #(.OUTPUT_BUFFER_DEPTH_WORDS(OUTPUT_BUFFER_DEPTH_WORDS))
        ctrl (
        .clk(clk),
        .n_rst(rst_n),
        .done(tr_start),
        .buffer_data(rd_data),
        .rd_addr(rd_addr),
        .rd_en(rd_en),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_done(tx_done),
        .finish(tr_end)
    );

    // Transmitter
    transmitter #(.clkdiv(clkdiv)) tx_inst (
        .clk(clk),
        .rst(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_done(tx_done),
        .tx(tx)
    );

endmodule
