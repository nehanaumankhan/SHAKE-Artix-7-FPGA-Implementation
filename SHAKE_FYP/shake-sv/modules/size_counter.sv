`timescale 1ns / 1ps

// Manager of message length and block boundaries
module size_counter #(
    parameter int WIDTH = 32,
    parameter int w     = 64
) (
    input logic clk,
    input logic rst,                    // sync rst
    input logic [WIDTH-1:0] data_i    , // carries total bit_length of the message (input_size)
    input logic [WIDTH-1:0] step_size , // usually equal to w
    input logic [10:0]      block_size, // depends on SHAKE128 or 256
    input logic en_data ,
    input logic en_count,
    input logic en_block,

    output logic last_word ,
    output logic last_block,
    output logic counter_end ,
    output logic [WIDTH-1:0] counter
);
    logic [WIDTH-1:0] _counter, _block;

    always_ff @(posedge clk) begin
        if (rst) begin
            _counter <= '1;
            _block   <= '0;
        end
        else begin
            if      (en_block) _block   <= block_size;
            if      (en_data ) _counter <= data_i    ;
            else if (en_count)
                if  (_counter < step_size) _counter <= 0;
                else                       _counter <= _counter - step_size;
        end
    end

    assign last_word    = (_counter <= w     );
    assign last_block   = (_counter <= _block);
    assign counter_end    = (_counter == '0    );
    assign counter      =  _counter;

endmodule
