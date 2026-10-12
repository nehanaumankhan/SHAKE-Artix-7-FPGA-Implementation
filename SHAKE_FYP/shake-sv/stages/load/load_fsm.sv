`timescale 1ns / 1ps

module load_fsm (
    // External i/ps
    input logic clk,
    input logic rst,
    input logic valid_i,

    // Status Signals
    input logic input_buffer_full ,
    input logic input_size_reached,
    input logic last_input_block  ,
    input logic first_incomplete_input_word,

    // Control Signals
    output logic control_regs_enable,
    output logic load_enable        ,
    output logic input_counter_en   ,
    output logic input_counter_load ,
    output logic padding_enable     ,
    output logic padding_reset      ,

    // Second Stage Handshaking
    input  logic input_buffer_ready,
    output logic input_buffer_ready_wr,
    output logic last_block_in_buffer_wr,

    // External Outputs
    output logic ready_i
);

    typedef enum logic [3:0] {
        RESET,
        WAIT_HEADER,
        WAIT_LOAD,
        LOAD,
        WAIT_BUFFER_EMPTY
    } state_t;
    state_t curr_state, next_state;

    // MEALY FSM

    always_ff @(posedge clk)  begin : sync_curr_state_controller
        if (rst) curr_state <=  RESET;
        else curr_state <= next_state;
    end

    always_comb begin : comb_next_state_and_output_controller
        padding_reset         = 0;

        control_regs_enable   = 0;
        ready_i               = 0;

        input_counter_load    = 0;

        padding_enable        = 0;
        load_enable           = 0;
        input_counter_en      = 0;

        input_buffer_ready_wr = 0; 
        

        unique case (curr_state)
            // Initial State Reset
            RESET: begin
                next_state    = WAIT_HEADER;
                padding_reset = 1;
            end
            // Waits for initial valid input to be 1, then will enable control regs to store op_mode, i/p and o/p sizes
            WAIT_HEADER: begin
                if (valid_i) begin
                    next_state          = WAIT_LOAD; 
                    control_regs_enable = 1;    // No cycle delay, data gets loaded as soon as valid signal is one
                    ready_i             = 1;
                end
                else next_state         = WAIT_HEADER;
            end 
            // Waits for SIPO buffer to be ready/available to get loaded
            WAIT_LOAD: begin
                next_state          = input_buffer_ready? WAIT_LOAD : LOAD; // i/p buffer is busy, wait else load
                input_counter_load  = 1;
            end  
            // When available, shift and load buffer
            LOAD: begin
                ready_i          =  valid_i && !input_size_reached;  // Only needs to be high to handshake and receive msg. Not needed when message is complete
                load_enable      =  valid_i ||  input_size_reached;  // tells SIPO to shift (If incoming data is valid or data has finished but padding is being loaded)
                input_counter_en =  load_enable;                     // Buffer Word counter depends on how many clocks load remains enabled
                // if final word of msg in data_i, start padding
                padding_enable   = (input_size_reached) || (first_incomplete_input_word && valid_i); // complete block was filled last time, this is for padding only / incomplete word this time so padding in same block
                
                if (!input_buffer_full || !load_enable) next_state = LOAD; // if buffer is not completely loaded or the last word in not loaded in buffer yet(both input counter and load_enable would be 0 at this point and the counter would not reset to 0 until last value is filled)
                else begin // buffer is full and final word was just loaded
                    padding_reset         = last_input_block; 
                    input_buffer_ready_wr = 1;                  // tells next state to start keccak rounding 
                    // input_counter_en      = 1;
                    next_state            = last_input_block? WAIT_BUFFER_EMPTY : WAIT_LOAD; // Now wait for buffer to be ready again: To hold header if msg is complete or to hold next chunk of data
                end
            end

            WAIT_BUFFER_EMPTY: next_state  = input_buffer_ready? WAIT_BUFFER_EMPTY: WAIT_HEADER; //  Header can only be loaded if buffer is ready
            // The stage is important because if we send to WAIT_HEADER directly then the header values will be overwritten before the final word of the prev msg is processed by the next stage 
            default: next_state = RESET;
        endcase  
    end

    assign last_block_in_buffer_wr = last_input_block;

endmodule
