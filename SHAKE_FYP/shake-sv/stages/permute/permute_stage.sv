import keccak_pkg::*;

module permute_stage (
    // External Inputs
    input logic clk,
    input logic rst,

    // Inputs from Load Stage
    input logic [1:0]  operation_mode,
    input logic [31:0] output_size,
    input logic [RATE_SHAKE128-1:0] rate_input,

    // Outputs for Dump Stage
    output logic [1:0 ] operation_mode_out,
    output logic [31:0] output_size_out,
    output logic [RATE_SHAKE128-1:0] rate_output,
    output logic output_buffer_we,

    // First Stage input handshaking
    input  logic input_buffer_ready,
    input  logic last_block_in_buffer,
    output logic input_buffer_ready_clr,
    output logic last_block_in_buffer_clr,

    // Second Stage Output handshaking
    input  logic output_buffer_available,
    output logic output_buffer_available_clr,
    output logic last_output_block_wr
);

    // Control signals
    logic round_enable;    
    logic round_count_load;
    logic state_reset;  
    logic copy_control_data;
    logic output_size_count_enable;
    logic absorb_enable;

    // Status signals
    logic round_start;
    logic round_done;
    logic last_output_block;


    permute_fsm permute_stage_fsm (
        // External inputs
        .clk                          (clk),
        .rst                          (rst),
        // Status signals
        .round_start                  (round_start),
        .round_done                   (round_done),
        .last_output_block            (last_output_block),
        // Control signals
        .round_enable                 (round_enable),
        .round_count_load             (round_count_load),
        .state_reset                  (state_reset),
        .copy_control_data            (copy_control_data),
        .output_size_count_enable     (output_size_count_enable),
        .absorb_enable                (absorb_enable),
        // First stage pipeline handshaking
        .input_buffer_ready           (input_buffer_ready),
        .input_buffer_ready_clr       (input_buffer_ready_clr),
        .last_block_in_input_buffer   (last_block_in_buffer),
        .last_block_in_input_buffer_clr     (last_block_in_buffer_clr),
        // Second stage pipeline handshaking
        .output_buffer_available      (output_buffer_available),
        .output_buffer_available_clr  (output_buffer_available_clr),
        .last_output_block_wr         (last_output_block_wr),
        .output_buffer_we             (output_buffer_we)
    );


    permute_datapath permute_stage_datapath (
        // External inputs
        .clk                     (clk),
        .rst                     (rst),
        // Inputs from previous pipeline stage
        .operation_mode          (operation_mode),
        .output_size             (output_size),
        .rate_input              (rate_input),
        // Control signals
        .round_enable            (round_enable),
        .round_count_load        (round_count_load),
        .state_reset             (state_reset),
        .copy_control_data       (copy_control_data),
        .output_size_count_enable(output_size_count_enable),
        .absorb_enable           (absorb_enable),
        // Status signals
        .round_start             (round_start),
        .round_done              (round_done),
        .last_output_block       (last_output_block),
        // Outputs for next pipeline stage
        .operation_mode_out      (operation_mode_out),
        .output_size_out         (output_size_out),
        .rate_output             (rate_output)
    );
    
endmodule