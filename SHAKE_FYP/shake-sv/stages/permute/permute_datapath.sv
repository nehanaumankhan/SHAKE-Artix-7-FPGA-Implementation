`timescale 1ns/1ps

import keccak_pkg::*;

module permute_datapath (
    // External Inputs
    input logic clk,
    input logic rst,
    
    // Inputs from previous pipeline stage
    input logic [1:0]  operation_mode,
    input logic [31:0] output_size   ,
    input logic [RATE_SHAKE128-1:0] rate_input,

    // Control Signals
    input logic round_enable    ,
    input logic round_count_load,
    input logic state_reset  ,
    input logic copy_control_data,
    input logic output_size_count_enable,
    input logic absorb_enable,

    // Status Signals
    output logic round_start,
    output logic round_done ,
    output logic last_output_block,

    // Outputs for next pipeline stage
    output logic [1:0 ] operation_mode_out,
    output logic [31:0] output_size_out,
    output logic [RATE_SHAKE128-1:0] rate_output
);

    logic [1:0 ] operation_mode_reg;
    logic [10:0] block_size;

    logic [4:0  ] round_num; // Total 24 rounds
    logic [w-1:0] round_constant;
    logic [STATE_WIDTH-1:0] state_reg_in, state_reg_out, round_in, xor_mask; // 1600 bits state width

    // Reg for storing operation mode
    regn #(.WIDTH(2)) op_mode_reg (
        .clk   (clk),
        .rst   (rst),
        .en    (copy_control_data),
        .data_i(operation_mode),
        .data_o(operation_mode_reg)
    );

    // Round Counter (1-24)
    countern #(.WIDTH(5)) round_counter (
        .clk        (clk),
        .rst        (rst),
        .en         (round_enable),
        
        .load_max   (round_count_load), // enable
        .max_count  (5'd23),

        .count_start  (round_start),
        .counter      (round_num),
        .count_end    (round_done)
    );

    // RC Generator
    round_constant_generator rc_gen (
        .round_num      (round_num),
        .round_constant (round_constant)
    );

    // State Register (1600 bits)
    regn #(.WIDTH(STATE_WIDTH)) state_reg (
        .clk   (clk),
        .rst   (state_reset),
        .en    (round_enable),
        .data_i(state_reg_in),
        .data_o(state_reg_out)
    );

    // Keccak Round
    keccak_round round(
        .rin   (round_in),
        .rout  (state_reg_in),
        .rc    (round_constant)
    );

    // Output Size Counter
    size_counter #(
        .WIDTH(32),
        .w(w)
    ) output_size_left (
        .clk        (clk),
        .rst        (rst),
        
        .en_block   (copy_control_data),
        .en_data    (copy_control_data),
        .en_count   (output_size_count_enable),
        
        .block_size (block_size),
        .data_i     (output_size),
        .step_size  ({21'b0, block_size}), // block size is of 11 bits

        .last_block (last_output_block),
        .counter    (output_size_out)
    );

    always_comb begin : input_absorption_keccak
        if (!absorb_enable) xor_mask = '0;
        else if (operation_mode_out == SHAKE256_MODE_VEC) xor_mask = {rate_input[RATE_SHAKE256-1:0], {CAP_SHAKE256{1'b0}}}; // CAP is untouched bits by input data
        else xor_mask = {rate_input[RATE_SHAKE128-1:0], {CAP_SHAKE128{1'b0}}};
    end
    assign round_in = state_reg_out ^ xor_mask; 
    // Initially absorption is enabled but state_reg_out is reset (cleared) so xor_mask becomes round_in
    // From next cycle onwards, absorption is disabled and state_reg_out is sent to round_in
    // Xoring with 0 means value remains same each time

    always_comb begin : block_size_decider
        if (operation_mode_out == SHAKE256_MODE_VEC) block_size = RATE_SHAKE256_VEC;
        else                                         block_size = RATE_SHAKE128_VEC;
    end

    assign operation_mode_out = copy_control_data? operation_mode : operation_mode_reg; // Hack?*

    // assign rate_output = EndianSwitcher#(RATE_SHAKE128)::switch(state_reg_out[STATE_WIDTH-1 -: RATE_SHAKE128]);
    
    logic [RATE_SHAKE128-1:0] x; 
    localparam int NUM_BYTES = RATE_SHAKE128 / 8;
    always_comb begin : endian_switcher
        x = state_reg_out[STATE_WIDTH-1 -: RATE_SHAKE128]; 
        for(int i=0; i<NUM_BYTES; i++) 
            rate_output[i*8 +: 8] = x[(NUM_BYTES-1-i)*8 +: 8];                 
    end
    
endmodule

// Checks:
// Find how buffer is being controlled via buffer ready signals (active low?) Ans: 1 shows busy 0 shows idle
// Why rate output is SHAKE128 size? Even when op mode is SHAKE 256? Ans: This is a worst-case design choice, allows output port to handle maximum possible rate
// *What is the operation_mode_out hacky way? Ans: At the start of the first round, the data might still be getting copied yet the first round would begin so we need new mode instead of old one
// Why is op_mode bein stored so many times? Ans: To prevent timing delays, each stage stores the mode + other control data info
// If a signal helps the hardware decide how to treat the current data, it must be registered at every pipeline stage boundary.