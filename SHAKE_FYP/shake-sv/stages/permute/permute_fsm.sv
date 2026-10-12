`timescale 1ns/1ps

module permute_fsm(
    // External Inputs
    input logic clk,
    input logic rst,

    // Status Signals
    input logic round_start,
    input logic round_done ,
    input logic last_output_block,

    // Control Signals
    output logic round_enable    ,
    output logic round_count_load,
    output logic state_reset  ,
    output logic copy_control_data,
    output logic output_size_count_enable,
    output logic absorb_enable,

    // First Stage Handshaking
    input  logic input_buffer_ready,
    output logic input_buffer_ready_clr,
    input  logic last_block_in_input_buffer,
    output logic last_block_in_input_buffer_clr,

    // Third Stage Handshaking
    input  logic output_buffer_available,
    output logic output_buffer_available_clr,
    output logic last_output_block_wr,
    output logic output_buffer_we
);
    typedef enum logic [3:0] { 
        RESET,
        WAIT_FIRST_ABSORB,
        ABSORB,
        WAIT_NEXT_ABSORB,
        ABSORB_LAST,
        DUMP,
        SQUEEZE,
        WAIT_DUMP
     } state_t;
     state_t curr_state, next_state;

    always_ff @(posedge clk)  begin : sync_curr_state_controller
        if (rst) curr_state <=  RESET;
        else curr_state <= next_state;
    end

    always_comb begin : comb_next_state_and_output_controller
        
        round_count_load                = 0;
        state_reset                     = 0;
        input_buffer_ready_clr          = 0;
        last_block_in_input_buffer_clr  = 0;
        copy_control_data               = 0;
        absorb_enable                   = 0;
        round_enable                    = 0;
        output_buffer_we                = 0;

        unique case (curr_state)    // Mealy FSM sets output combinationally when in the current state wrt inputs and curr_state
            RESET: begin
                next_state                      = WAIT_FIRST_ABSORB;
                round_count_load                = 1; // enable
                state_reset                     = 1; // 1600-bit state register reset
                input_buffer_ready_clr          = 1; // set input_buffer_ready to 0 (Not busy)
                last_block_in_input_buffer_clr  = 1; // last_block_in_input_buffer in now 0 means last block isn't there.
            end 

            WAIT_FIRST_ABSORB: begin
                if (!input_buffer_ready) next_state = WAIT_FIRST_ABSORB; // if input_buffer_ready is 0 (Empty), wait for it to fill up
                else begin
                    copy_control_data               = 1;
                    absorb_enable                   = 1;
                    round_enable                    = 1;
                    input_buffer_ready_clr          = 1; // input_buffer_ready is now 0 (Empty), acknowledge the consumption
                    next_state                      = last_block_in_input_buffer? ABSORB_LAST : ABSORB;
                    last_block_in_input_buffer_clr  = last_block_in_input_buffer; // If there is last block in input buffer, now you can clear this signal 
                end
            end

            ABSORB: begin
                // Either round is underway or it is done and next non-last block is ready to be absorbed
                if ((!round_done) || (input_buffer_ready && !last_block_in_input_buffer)) begin
                    next_state              = ABSORB;
                    round_enable            = 1;                     // round_counter enable
                    absorb_enable           = round_start;           // enabled just once in the start
                    input_buffer_ready_clr  = round_done;            // when last round is reached, input buffer is empty
                end
                // Round is done and last block ready to be absorbed
                else if (round_done && input_buffer_ready && last_block_in_input_buffer) begin
                    next_state                     = ABSORB_LAST;
                    last_block_in_input_buffer_clr = 1;
                    input_buffer_ready_clr         = 1;
                    round_enable                   = 1; // For counter to reset
                end
                // Round is done and for next block, we're waiting for it to come in buffer for absorption
                else begin 
                    next_state   = WAIT_NEXT_ABSORB;
                    round_enable = 1; // For counter to reset, in the next cycle enable is again 0 in the comb block
                end
            end

            WAIT_NEXT_ABSORB: begin
                if (!input_buffer_ready) next_state = WAIT_NEXT_ABSORB;
                else begin
                    absorb_enable                  = 1;
                    round_enable                   = 1;
                    input_buffer_ready_clr         = 1;
                    next_state                     = last_block_in_input_buffer? ABSORB_LAST : ABSORB;
                    last_block_in_input_buffer_clr = last_block_in_input_buffer;
                end
            end
            // No more data left after this (runs 24 rounds of keccak over last block)
            // At the end, the 1600 bit state has my hash
            ABSORB_LAST: begin
                next_state    = round_done? DUMP : ABSORB_LAST;
                round_enable  = 1;
                absorb_enable = round_start;
            end
            // Hands over data to next stage 
            DUMP: begin
                output_buffer_we = output_buffer_available; // Only writes data if the next stage is ready to receive it
                if (!last_output_block) next_state = SQUEEZE; // Means user wants a very large output block which is longer than one block(1344 bits for SHAKE128)
                else begin
                    next_state          = output_buffer_available? WAIT_FIRST_ABSORB : DUMP;
                    state_reset         = output_buffer_available; // clear the 160 bit state for next user/msg
                    copy_control_data   = output_buffer_available;
                end
            end

            // Squeezes out more bits than the block size by enabling the 24 rounds again without adding more data
            SQUEEZE: begin
                round_enable = 1;
                next_state   = round_done? WAIT_DUMP : SQUEEZE;
            end

            // Waits for the previous dumping to complete and for buffer to be available again
            WAIT_DUMP: begin
                next_state = output_buffer_available? DUMP : WAIT_DUMP;
            end

            default: next_state = RESET;
        endcase
    end
    assign last_output_block_wr         = last_output_block;
    assign output_size_count_enable     = output_buffer_we; // only enables count when data successfully leaves keccak core
    assign output_buffer_available_clr  = output_buffer_we || rst;
    // output_buffer_we depends on output_buffer_available so the clear is to ack it
    // These latch stored signals only apply in the next cycle
endmodule
