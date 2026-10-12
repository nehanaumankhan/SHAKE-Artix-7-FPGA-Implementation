module top #(
    parameter clkdiv = 868,
    parameter BRAM_DEPTH = 64,
    parameter OUTPUT_BUFFER_DEPTH_WORDS = 64
)(
    input  logic clk,
    input  logic rst_n,
    output logic tr_start,
    output logic tr_end,
    output logic tx,
    input  logic rx
);

    logic rd_en;
    logic [7:0] rd_data;
    logic empty;
    logic in_buffer_wdone;
    logic in_buffer_we; 
    logic [$clog2(BRAM_DEPTH)-1:0] in_buffer_waddr;// Byte-wide read interface for output buffer
    logic [w-1:0] in_buffer_wdata;
    
    logic rx_done;
    logic [7:0] rx_data;
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
    .buffer_read_addr(rd_addr),
    .in_buffer_we(in_buffer_we),
    .in_buffer_wdone(in_buffer_wdone),
    .in_buffer_waddr(in_buffer_waddr),
    .in_buffer_wdata(in_buffer_wdata)
);


    // Controller
    uart_controller  #(.OUTPUT_BUFFER_DEPTH_WORDS(OUTPUT_BUFFER_DEPTH_WORDS), .BRAM_DEPTH(BRAM_DEPTH))
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
        .finish(tr_end),
        .in_buffer_we(in_buffer_we),
        .in_buffer_wdone(in_buffer_wdone),
        .in_buffer_waddr(in_buffer_waddr),
        .in_buffer_wdata(in_buffer_wdata),
        .rx_done(rx_done),
        .rx_data(rx_data)
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
    
    receiver rx_inst(
        .clk(clk), 
        .rx(rx),
        .rx_val(rx_done),
        .rx_byte(rx_data)
    );


endmodule
