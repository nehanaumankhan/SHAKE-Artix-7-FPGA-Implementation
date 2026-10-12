`timescale 1ns / 1ps

module latch (
    input  logic clk,
    input  logic rst,  // sync reset
    input  logic set,  
    output logic q
);

    always_ff @(posedge clk)
        if (rst) q <= 1'b0;
        else if (set) q <= 1'b1;

endmodule