`timescale 1ns/1ps

import keccak_pkg::*;

module dump_fsm (
    input logic clk,
    input logic rst,
    input logic ready_o,

    // Status Signals
    input logic last_word_from_block,
    
    // Control Signals
    output logic output_buffer_we_out,
    output logic last_output_block_out,
    output logic output_buffer_shift_en,
    output logic output_counter_load,
    output logic output_counter_rst,
    output logic valid_bytes_enable,
    output logic valid_bytes_reset,

    // permute-dump Handshaking
    input  logic output_buffer_we_in,
    input  logic last_output_block_in,
    output logic last_output_block_clr,
    output logic output_buffer_available_wr,

    //External outputs
    output logic valid_o
);
    typedef enum logic [3:0] { 
        IDLE,
        WRITING
    } state_t;
    state_t curr_state, next_state;

    always_ff @( posedge clk ) begin : sync_curr_state_setter
        if (rst) curr_state <= IDLE;
        else     curr_state <= next_state;
    end

    always_comb begin : mealy_comb_next_state_and_output_setter
        output_counter_load         = 0;
        valid_bytes_enable          = 0;
        output_buffer_shift_en      = 0;
        valid_o                     = 0;
        output_buffer_available_wr  = 0;
        valid_bytes_reset             = rst;
        output_counter_rst          = rst;
        last_output_block_clr       = rst;

        unique case (curr_state)
            IDLE: begin
              if (output_buffer_we_in) begin
                output_counter_load = 1; // maxi load enable
                valid_bytes_enable  =  last_output_block_in;
                valid_bytes_reset     = !last_output_block_in;
                next_state          = WRITING;
              end  
              else begin
                output_buffer_available_wr = 1; // ready to receive new data
                output_counter_rst         = 1; 
                next_state                 = IDLE;
              end
            end 
            WRITING: begin
                valid_o = ready_o; 

                if (last_word_from_block && ready_o) begin
                    output_buffer_available_wr = 1; // ready to receive new data
                    last_output_block_clr      = 1;
                    output_buffer_shift_en     = 1;
                    next_state                 = IDLE;
                end
                else begin
                    output_buffer_shift_en     = ready_o;
                    next_state                 = WRITING;
                end
            end
            default: next_state                = IDLE;
        endcase
    end

    assign output_buffer_we_out  = output_buffer_we_in;
    assign last_output_block_out = last_output_block_in;

endmodule