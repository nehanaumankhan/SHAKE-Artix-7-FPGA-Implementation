`timescale 1ns / 1ps

module sipo_buffer #(
    parameter int WIDTH,
    parameter int DEPTH
) (
    input  logic clk,
    input  logic en ,
    input  logic [WIDTH-1:0        ] data_i,
    output logic [(DEPTH*WIDTH)-1:0] data_o
);
    logic [WIDTH-1:0] buffer [DEPTH-1:0];

    always_ff @(posedge clk) 
        if (en) begin
            for (int i=0; i<DEPTH-1; i++)
                buffer[i] <= buffer[i+1];
            buffer[DEPTH-1] <= data_i;      // First MSB is fed in which shifts to the first location of buffer(Big Endian)
        end
    
    always_comb begin
        for (int i=0; i<DEPTH; i++)
            data_o[(i+1)*WIDTH-1 -: WIDTH] = buffer[DEPTH-1-i];
    end     // LSB to LSB and MSB to MSB
    
endmodule
