`timescale 1ns / 1ps

module piso_buffer #(
    parameter int WIDTH,
    parameter int DEPTH
) (
    input  logic clk,
    input  logic write_enable,
    input  logic shift_enable,
    input  logic [(DEPTH*WIDTH)-1:0] data_i,
    output logic [WIDTH-1:0        ] data_o
);
    logic [WIDTH-1:0] buffer [DEPTH-1:0];

    always_ff @(posedge clk) begin
        if (write_enable) 
            for (int i=0; i<DEPTH; i++)
                buffer[i] <= data_i[(DEPTH-i)*WIDTH-1 -: WIDTH]; // Big-Endian (loc 0 of buffer stores MSB of data)
        
        else if (shift_enable)
            for (int i=DEPTH-1; i>0; i--)
                buffer[i] <= buffer[i-1];
    end

    assign data_o = buffer[DEPTH-1]; // LSB is shifted out first 
    // instantaneous for the first word and registered for he rest
endmodule
