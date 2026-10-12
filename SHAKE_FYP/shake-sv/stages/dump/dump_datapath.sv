`timescale 1ns/1ps

import keccak_pkg::*;

module dump_datapath (
    input logic clk,
    input logic rst,

    // Outputs from Permute Stage
    input logic [1:0 ] operation_mode,
    input logic [31:0] output_size,
    input logic [RATE_SHAKE128-1:0] rate_output,
    
    // Control Signals
    input logic output_buffer_we,
    input logic last_output_block,
    input logic output_buffer_shift_en,
    input logic output_counter_load,
    input logic output_counter_rst,
    input logic valid_bytes_enable,
    input logic valid_bytes_reset,
    
    // Status Signals
    output logic last_word_from_block,

    // External Outputs
    output logic [w-1:0] data_o
);
    logic [4:0] max_buffer_depth;
    logic [4:0] remaining_valid_words;
    logic [4:0] extra_valid_word;

    logic [w_byte_width-1:0] remaining_valid_bytes, remaining_valid_bytes_reg;
    logic [w-1:0]            buffer_output;
    logic [w_byte_size-1:0]  zero_mask_sel;

    // Counter for output buffer
    // Module needs to know how many output words to provide, if we're not on last block, then all words should be sent else size of output
    countern #(.WIDTH(5)) output_counter (
        .clk         (clk),
        .rst         (output_counter_rst),
        .en          (output_buffer_shift_en),
        
        .load_max    (output_counter_load), // enable
        .max_count   (max_buffer_depth),

        .count_last  (last_word_from_block)
    );

    // Reg for output masking (Maybe user wants number of bytes not equal to a multiple of 64 so rest of the unused bits must be zeroed out -> prevents internal state leakage)
    assign remaining_valid_bytes = output_size[w_bit_width-1:3]; // Number of valid bytes in the last word
    // assign remaining_valid_bytes = output_size[3+:w_byte_width];
    regn #(w_byte_width) output_bytes_reg (
        .clk   (clk),
        .rst   (valid_bytes_reset),
        .en    (valid_bytes_enable),
        .data_i(remaining_valid_bytes),
        .data_o(remaining_valid_bytes_reg)
    );

    // Stores full 1344 bits and outputs 64 bits each clk
    piso_buffer #(
        .WIDTH(w),
        .DEPTH(RATE_SHAKE128/w) // Because this rate is greater than of 256 - allows uniformity
    ) output_buffer (
        .clk          (clk),
        .write_enable (output_buffer_we), 
        .shift_enable (output_buffer_shift_en),    
        .data_i       (rate_output),  
        .data_o       (buffer_output)
    );

    assign extra_valid_word      = remaining_valid_bytes? 5'd1 : 5'd0; 
    assign remaining_valid_words = output_size[w_bit_width+5:w_bit_width] + extra_valid_word;
    // assign  remaining_valid_words = output_size[w_bit_width+:6] + extra_valid_word;

    always_comb begin : output_words_to_send_for_this_block
        if (last_output_block)                        max_buffer_depth = remaining_valid_words[4:0];
        else if (operation_mode == SHAKE256_MODE_VEC) max_buffer_depth = 5'd17;
        else                                          max_buffer_depth = 5'd21;
    end

    assign zero_mask_sel = (last_word_from_block && remaining_valid_bytes_reg)? (8'hFF >> remaining_valid_bytes_reg) : '0; //*
    always_comb begin : masker_to_prevent_leakage
        for (int i=0; i < w_byte_size; i++)
            data_o[(i+1)*8-1-:8] = zero_mask_sel[i]? 8'h00 : buffer_output[(i+1)*8-1-:8];
    end
endmodule

// Lets say we want 100 bits
// d'100 = b'0000000001100100 // remaining_valid_words = 1, remaining_valid_bytes = 4
// remaining_valid_words tell us a partial word is still remianing
// First block 64 bits -> pass
// *Second block = b'100100 = 32+4 = 36 valid bits = b'100 or 4 valid bytes (when we ignored last three bits to calculate byte, we missed a partial byte, actually the data was of 5 bytes)
// so total 96 bits sent out = 12 bytes (8 + 4) -> We ignore the partial byte calculation
// Otherwise we would have sent 13 bytes = 104 bits (more info than less)
// TODO: However we can manipulate bit-wise for exact calculation -> will work on this