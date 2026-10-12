import keccak_pkg::*;

module keccak (
    input logic clk,
    input logic rst,

    // Input Signals
    input logic ready_o,
    input logic valid_i,

    // Output Signals
    output logic ready_i,
    output logic valid_o,

    input logic  [w-1:0] data_i,
    output logic [w-1:0] data_o
);

    logic ready_o_internal, valid_i_internal;

    // Load Stage outputs to Permute Stage
    logic [RATE_SHAKE128-1:0] rate_input;
    logic [1:0]               operation_mode_load_stage;
    logic [31:0]              output_size_load_stage;
    
    // Permute Stage outputs to Dump Stage
    logic [RATE_SHAKE128-1:0] rate_output;
    logic [1:0]               operation_mode_permute_stage;
    logic [31:0]              output_size_permute_stage;
    logic                     output_buffer_we;
    
    // Handshaking Signals
    logic input_buffer_ready,      input_buffer_ready_clr,      input_buffer_ready_wr;
    logic last_output_block,       last_output_block_clr,       last_output_block_wr;
    logic last_block_in_buffer,    last_block_in_buffer_clr,    last_block_in_buffer_wr;
    logic output_buffer_available, output_buffer_available_clr, output_buffer_available_wr;

    // Dilithium Sends active low valid and ready signals
    // Following is to counter that
//    assign valid_i_internal = !valid_i;
//    assign ready_o_internal = !ready_o;
    assign valid_i_internal = valid_i;
    assign ready_o_internal = ready_o;

    // Stage 1
    load_stage load_pipeline_stage (
        // External inputs
        .clk                     (clk),
        .rst                     (rst),
        .valid_i                 (valid_i_internal),
        .data_i                  (data_i),
        // Second stage pipeline handshaking
        .input_buffer_ready      (input_buffer_ready && !input_buffer_ready_clr), // NOTE: passthrough of clear signal
        .input_buffer_ready_wr   (input_buffer_ready_wr),
        .last_block_in_buffer_wr (last_block_in_buffer_wr),
        // Outputs for next stage
        .operation_mode          (operation_mode_load_stage),
        .output_size             (output_size_load_stage),
        .rate_input              (rate_input),
        // External outputs
        .ready_i                 (ready_i)
    );

    latch input_buffer_ready_latch (
        .clk (clk),
        .set (input_buffer_ready_wr),
        .rst (input_buffer_ready_clr),
        .q   (input_buffer_ready)
    );

    latch last_block_in_buffer_latch (
        .clk (clk),
        .set (last_block_in_buffer_wr),
        .rst (last_block_in_buffer_clr),
        .q   (last_block_in_buffer)
    );

    // Stage 2
    permute_stage permute_pipeline_stage (
        // External inputs
        .clk                          (clk),
        .rst                          (rst),
        // Inputs from previous stage
        .operation_mode               (operation_mode_load_stage),
        .output_size                  (output_size_load_stage),
        .rate_input                   (rate_input),
        // Outputs for next stage
        .operation_mode_out           (operation_mode_permute_stage),
        .output_size_out              (output_size_permute_stage),
        .rate_output                  (rate_output),
        .output_buffer_we             (output_buffer_we),
        // First stage pipeline handshaking
        .input_buffer_ready           (input_buffer_ready),
        .last_block_in_buffer         (last_block_in_buffer),
        .input_buffer_ready_clr       (input_buffer_ready_clr),
        .last_block_in_buffer_clr     (last_block_in_buffer_clr),
        // Third stage pipeline handshaking
        .output_buffer_available      (output_buffer_available),
        .output_buffer_available_clr  (output_buffer_available_clr),
        .last_output_block_wr         (last_output_block_wr)
    );

    latch output_buffer_available_latch (
        .clk (clk),
        .set (output_buffer_available_wr),
        .rst (output_buffer_available_clr),
        .q   (output_buffer_available)
    );

    latch last_output_block_latch (
        .clk (clk),
        .set (last_output_block_wr),
        .rst (last_output_block_clr),
        .q   (last_output_block)
    );

    // Stage 3
    dump_stage dump_pipeline_stage (
        // External inputs
        .clk                         (clk),
        .rst                         (rst),
        .ready_o                     (ready_o_internal),
        // Inputs from previous stage
        .operation_mode              (operation_mode_permute_stage),
        .output_size                 (output_size_permute_stage),
        .rate_output                 (rate_output),
        .output_buffer_we            (output_buffer_we),
        // Second stage pipeline handshaking
        .last_output_block           (last_output_block),
        .last_output_block_clr       (last_output_block_clr),
        .output_buffer_available_wr  (output_buffer_available_wr),
        // External outputs
        .valid_o                     (valid_o),
        .data_o                      (data_o)
    );
    
endmodule