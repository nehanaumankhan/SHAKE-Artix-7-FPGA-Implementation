// shake_top.sv
import keccak_pkg::*;

module shake_top #(
    parameter BRAM_DEPTH = 64,
    parameter OUTPUT_BUFFER_DEPTH_WORDS = 64 //131072   // number of 64-bit words
)(
    input  logic clk,
    input  logic rst_n,
//    input  logic start,
    output logic done,
    input logic in_buffer_wdone,
    input logic in_buffer_we,   
    input logic [$clog2(BRAM_DEPTH)-1:0] in_buffer_waddr,// Byte-wide read interface for output buffer
    input logic [w-1:0] in_buffer_wdata,
    output logic [7:0] buffer_dout_byte,
    input  logic       buffer_read_en,
    input  logic [$clog2(OUTPUT_BUFFER_DEPTH_WORDS * (w/8))-1:0] buffer_read_addr
);

    localparam BRAM_ADDR_WIDTH = $clog2(BRAM_DEPTH);
    logic rst;
//    logic rst = ~rst_n;
    assign rst = ~rst_n;
    // Input BRAM signals
    logic [BRAM_ADDR_WIDTH-1:0] bram_addr;
    logic bram_read_en;
    logic [w-1:0] bram_rdata;

    // Keccak signals
    logic valid_i, ready_i, valid_o, ready_o;
    logic [w-1:0] data_i, data_o;

    // Controller signals (including output buffer write)
    logic        ctrl_out_valid;
    logic [w-1:0] ctrl_out_data;
    logic        buffer_we;
    logic [31:0] buffer_waddr;          // word address for write
    logic [w-1:0] buffer_din;

    // ------------------------------------------------------------------
    // Output buffer (byte read, word write)
    // ------------------------------------------------------------------
    output_buffer #(
        .DEPTH_WORDS(OUTPUT_BUFFER_DEPTH_WORDS),
        .DATA_WIDTH(w),
        .BYTE_WIDTH(8)
    ) out_buf (
        .clk   (clk),
        .rst   (rst),
        .we    (buffer_we),
        .waddr (buffer_waddr[$clog2(OUTPUT_BUFFER_DEPTH_WORDS)-1:0]),
        .din   (buffer_din),
        .re    (buffer_read_en),
        .raddr (buffer_read_addr),
        .dout  (buffer_dout_byte)
    );

    // ------------------------------------------------------------------
    // Input buffer (config + message) - renamed from bram_module
    // ------------------------------------------------------------------
    input_buffer #(
        .DATA_WIDTH(w),
        .DEPTH(BRAM_DEPTH)
    ) bram_inst (
        .clk(clk),
        .write_en(in_buffer_we),
        .write_addr(in_buffer_waddr),
        .write_data(in_buffer_wdata),
        .read_en(bram_read_en),
        .read_addr(bram_addr),
        .read_data(bram_rdata)
    );

    // ------------------------------------------------------------------
    // Keccak core (explicit named connections)
    // ------------------------------------------------------------------
    keccak dut (
        .clk     (clk),
        .rst     (rst),
        .ready_o (ready_o),
        .valid_i (valid_i),
        .ready_i (ready_i),
        .valid_o (valid_o),
        .data_i  (data_i),
        .data_o  (data_o)
    );

    // ------------------------------------------------------------------
    // Controller (with output buffer write ports)
    // ------------------------------------------------------------------
    controller #(
        .BRAM_DEPTH      (BRAM_DEPTH),
        .BRAM_ADDR_WIDTH (BRAM_ADDR_WIDTH),
        .WORD_WIDTH      (w)
    ) ctrl_inst (
        .clk          (clk),
        .rst          (rst),
        .write_done(in_buffer_wdone),
        
//        .start        (start),
        .done         (done),
        .bram_addr    (bram_addr),
        .bram_read_en (bram_read_en),
        .bram_rdata   (bram_rdata),
        .valid_i      (valid_i),
        .ready_i      (ready_i),
        .data_i       (data_i),
        .valid_o      (valid_o),
        .ready_o      (ready_o),
        .data_o       (data_o),
        .out_valid    (ctrl_out_valid),
        .out_data     (ctrl_out_data),
        .buffer_we    (buffer_we),
        .buffer_addr  (buffer_waddr),
        .buffer_din   (buffer_din)
    );

endmodule