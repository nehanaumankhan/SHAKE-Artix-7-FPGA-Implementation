`timescale 1ns/1ps

import keccak_pkg::*;

module load_stage (
    
    // External i/ps
    input logic clk,
    input logic rst,
    input logic valid_i,
    input logic [w-1:0] data_i,

    // Second Stage Handshaking
    input  logic input_buffer_ready,
    output logic input_buffer_ready_wr,
    output logic last_block_in_buffer_wr,

    // Inputs to Second Stage
    output logic [1:0]  operation_mode,
    output logic [31:0] output_size,
    output logic [RATE_SHAKE128-1:0] rate_input,

    // External Outputs
    output logic ready_i
);

    // Control Signals
    logic control_regs_enable;
    logic load_enable;        
    logic input_counter_en, input_counter_load;
    logic padding_enable, padding_reset;

    // Status Signals
    logic input_buffer_full ;
    logic input_size_reached;
    logic last_input_block  ;
    logic first_incomplete_input_word; // may or may not be one throughout, depends on the size of message

    load_fsm load_stage_fsm(
        // External inputs
        .clk                           (clk),
        .rst                           (rst),
        .valid_i                       (valid_i),
        // Status signals
        .input_buffer_full             (input_buffer_full),
        .input_size_reached            (input_size_reached),
        .last_input_block              (last_input_block),
        .first_incomplete_input_word   (first_incomplete_input_word),
        // Control signals
        .control_regs_enable           (control_regs_enable),
        .load_enable                   (load_enable),
        .input_counter_en              (input_counter_en),
        .input_counter_load            (input_counter_load),
        .padding_enable                (padding_enable),
        .padding_reset                 (padding_reset),
        // Second stage pipeline handshaking
        .input_buffer_ready            (input_buffer_ready),
        .input_buffer_ready_wr         (input_buffer_ready_wr),
        .last_block_in_buffer_wr       (last_block_in_buffer_wr),
        // External outputs
        .ready_i                       (ready_i)
    );

    load_datapath load_stage_datapath (
        // External inputs
        .clk                           (clk),
        .rst                           (rst),
        .data_i                        (data_i),
        // Control signals
        .control_regs_enable           (control_regs_enable),
        .load_enable                   (load_enable),
        .input_counter_en              (input_counter_en),
        .input_counter_load            (input_counter_load),
        .padding_enable                (padding_enable),
        .padding_reset                 (padding_reset),
        // Status signals
        .input_buffer_full             (input_buffer_full),
        .input_size_reached            (input_size_reached),
        .last_input_block              (last_input_block),
        .first_incomplete_input_word   (first_incomplete_input_word),
        // Outputs for next pipeline stage
        .operation_mode                (operation_mode),
        .output_size                   (output_size),
        .rate_input                    (rate_input)
    );

endmodule

