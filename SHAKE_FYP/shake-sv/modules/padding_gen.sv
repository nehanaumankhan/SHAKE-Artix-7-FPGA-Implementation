`timescale 1ns / 1ps

import keccak_pkg::*;

module padding_generator (
    input clk,
    input logic [w-1:0] data_i, // 8 bytes input

    // Control signals
    input logic [w_byte_width:0] remaining_valid_bytes, // Number of valid input bytes(out of total 8)
    input logic padding_enable,                         // if message has ended, pad
    input logic last_word_in_block,                     // Flag if current word is last of block
    input logic padding_reset,                          // Flag to reset padding latches

    output logic last_block,
    output logic [w-1:0] data_o
);

    localparam logic [7:0] DOMAIN_SEPARATOR_BYTE = 8'h1F;   // appended right after message
    localparam logic [7:0] TERMINATOR_PADDING_BYTE = 8'h80; // appended in the last byte of block
    // Used in edge case when the last byte has both the domain separator, and the 10*1(Terminator) padding
    localparam logic [7:0] COMPLETE_PADDING_BYTE = 8'h9F;   // Or first two

    logic [w_byte_size-1:0] first_pad_word_sel;
    logic [w_byte_size-1:0] padding_mask_sel;
    logic [7:0]    byte_pad [w_byte_size-1:0];
    logic first_pad_used;

    // sticky bit to remember msg has ended
    latch first_pad_used_latch(
        .clk (clk),
        .set (padding_enable),
        .rst (padding_reset),
        .q   (first_pad_used)
    );

    // Which byte to attach DOMAIN_SEPARATOR to (mask the rest)
    assign first_pad_word_sel = (padding_enable && !first_pad_used)? (8'h80 >> remaining_valid_bytes):'0;
    // What bytes to apply padding to?
    assign padding_mask_sel   =  padding_enable?                     (8'hFF >> remaining_valid_bytes):'0;
    // very first block of padding or the ones after domain seperator padding
    assign last_block = padding_enable || first_pad_used; 

    always_comb begin
        for(int i = 1; i < w_byte_size; i++)
            byte_pad[i] = first_pad_word_sel[i]? DOMAIN_SEPARATOR_BYTE:'0;
        
        case ({last_word_in_block, first_pad_word_sel[0]})
            2'b00:  byte_pad[0] = 8'b0;
            2'b01:  byte_pad[0] = DOMAIN_SEPARATOR_BYTE;
            2'b10:  byte_pad[0] = TERMINATOR_PADDING_BYTE;
            2'b11:  byte_pad[0] = COMPLETE_PADDING_BYTE;
        endcase
        
        for (int i = 0; i<w_byte_size; i++)
            data_o[(i+1)*8-1 -: 8] = padding_mask_sel[i]? byte_pad[i] : data_i[(i+1)*8-1 -: 8];
    end
endmodule

// Eg: The AXI allows only 64 bit input
// We send the first 64 bits from the MSB first like:
// Message = "5418998384844123_9887721232177373"
// First segment  = 5418998384844123
// Second segment = 9887721232177373
// Hence the domain separator will be appended at the 0th position(end)
