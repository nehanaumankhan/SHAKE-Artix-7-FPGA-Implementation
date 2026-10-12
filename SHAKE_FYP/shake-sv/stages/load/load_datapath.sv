// First stage responsible to load inputs
`timescale 1ns / 1ps

import keccak_pkg::*;

module load_datapath (
    // External i/ps
    input logic clk,
    input logic rst,
    input logic [w-1:0] data_i,

    // Control Signals
    input logic control_regs_enable,
    input logic load_enable        ,
    input logic input_counter_en   ,
    input logic input_counter_load ,
    input logic padding_enable     ,
    input logic padding_reset      ,

    // Status Signals
    output logic input_buffer_full ,
    output logic input_size_reached,
    output logic last_input_block  ,
    output logic first_incomplete_input_word,

    // Outputs for next pipeline stage
    //      1. Using First Input(config_word)
    output logic [1:0]  operation_mode,
    output logic [31:0] output_size,
    //      2. Using Msg Inputs (combined to a block)
    output logic [RATE_SHAKE128-1:0] rate_input
);
    logic last_word_in_block, last_input_word;
    logic [4:0]   input_buffer_counter, max_buffer_depth;
    logic [31:0]  input_size_counter;
    logic [w-1:0] padded_data, padded_data_le;
    logic [w_byte_width:0] remaining_valid_bytes;

    // For storing operation_mode
    regn #(.WIDTH(2)) op_mode_reg (
        .clk   (clk),
        .rst   (rst),
        .en    (control_regs_enable),
        .data_i(data_i[62:61]),
        .data_o(operation_mode)
    );
    // eg C0000b4000000020 --> Op_mode = 10 (C=1100)
    
    // For storing output_size
    regn #(.WIDTH(32)) output_size_reg (
        .clk   (clk),
        .rst   (rst),
        .en    (control_regs_enable),
        .data_i({4'b0, data_i[59:32]}), // 28 bits output_size
        .data_o(output_size)
    );

    // Input Size Counter identifies where to put the padding(end of entire message)
    size_counter #(
        .WIDTH(32),
        .w(w)
    ) input_size_left (
        .clk        (clk),
        .rst        (rst),
        .data_i     (data_i[31:0]),
        .step_size  (w),
        .en_data    (control_regs_enable),
        .en_count   (load_enable),

        .last_word  (last_input_word),
        .counter_end(input_size_reached),
        .counter    (input_size_counter),
        .en_block   ('0)
    );

    // Input Buffer Counter identifies when to start the keccak_round(keeps track of the complete block being filled eg uptill 21 words or 17 words)
    countern #(.WIDTH(5)) input_counter (
        .clk        (clk),
        .rst        (rst),
        .en         (input_counter_en),
        .load_max   (input_counter_load),
        .max_count  (max_buffer_depth),

        .count_end  (input_buffer_full),
        .counter    (input_buffer_counter)
    );

    // Padding Generator
    assign remaining_valid_bytes = input_size_counter[w_bit_width:3]; // sees size of last 8 bits(as size of one segment is 64 bits, :3 is for converting 64 bits to 8 bytes)
    // Above is only useful when padding is enabled and last word of msg is seen
    assign first_incomplete_input_word = last_input_word && (remaining_valid_bytes != w_byte_size); 
    // For second condition above, if remaining valid bytes is 8 then the whole 64 bits will be filled and no space for mask is left
    // assign last_word_in_block = (input_buffer_counter == {max_buffer_depth[4:1], 1'b0}); // subtracts 1
    // assign last_word_in_block = input_buffer_counter == max_buffer_depth; // since max_buffer_depth is even
    assign last_word_in_block = input_buffer_full; // check if all three equivalent
    
    padding_generator padding_gen (
        .clk                    (clk),
        .data_i                 (data_i),
        .remaining_valid_bytes  (remaining_valid_bytes),
        .padding_enable         (padding_enable),
        .last_word_in_block     (last_word_in_block),
        .padding_reset          (padding_reset),

        .last_block             (last_input_block), // if current block being filled is last block (only if msg has ended)
        .data_o                 (padded_data)
    );

    // SIPO Input Buffer
    sipo_buffer #(
        .WIDTH(w),
        .DEPTH(RATE_SHAKE128/w) // Because this rate is greater than of 256 - allows uniformity
    ) input_buffer (
        .clk    (clk),
        .en     (load_enable),     
        .data_i (padded_data_le),  // must be little endian for keccak
        .data_o (rate_input)
    );

    // Decision regarding block size 
    always_comb 
        unique case (operation_mode)
            SHAKE256_MODE_VEC: max_buffer_depth = 5'd16;
            SHAKE128_MODE_VEC: max_buffer_depth = 5'd20;
            default:           max_buffer_depth = 5'd20;
        endcase
    
    // assign padded_data_le = EndianSwitcher#(w)::switch(padded_data); // padding is big endian (terminator applies to 0th index so we need to reverse it)
    logic [w-1:0] x; 
    localparam int NUM_BYTES = w / 8;
    always_comb begin : endian_switcher
        x = padded_data; 
        for(int i=0; i<NUM_BYTES; i++) 
            padded_data_le[i*8 +: 8] = x[(NUM_BYTES-1-i)*8 +: 8];                 
    end
endmodule

// Question: see when external controller sends padding_enable signal
// probably when input_size reached is high

// Padded Output:
//       1f represents domain seperator byte   ....................................................................................................................................................................................................................................................................................8000000000000000  represents terminator segment (80)                                              
// 0000001fa36eecd800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000

// d8 ec 6e a3 1f -> 1f a3 6e ec d8
// Big Endian     -> Little Endian
// Small Index    -> Big Index
// Bigger Val     -> Bigger Val

// xx xx xx xx xx xx xx 80 -> 80 xx xx xx xx xx xx xx
// Big Endian              -> Little Endian
// Small Index             -> Big Index
// Bigger Val              -> Bigger Val