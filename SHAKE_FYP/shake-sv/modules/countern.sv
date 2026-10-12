`timescale 1ns / 1ps //delay /  resolution

module countern #(
   parameter int WIDTH = 32  
) (
    input  logic clk,
    input  logic rst,       // sync reset
    input  logic en ,
    input  logic load_max,
    input  logic [WIDTH-1:0] max_count,

    output logic [WIDTH-1:0] counter,
    output logic count_end  ,
    output logic count_last , // pre-warning
    output logic count_start
);
    logic [WIDTH-1:0] store_max, _counter;

    always_ff @(posedge clk) begin
        if (rst) begin
            store_max <= '1;
            _counter  <= '0;
        end
        else
            if (load_max) store_max <= max_count;
            else if (en) _counter <= (_counter < store_max)? (_counter + 1) : '0;
    end

    assign counter     = _counter;
    assign count_end   = _counter == store_max;
    assign count_last  = _counter == (store_max - 1);
    assign count_start = _counter == '0;

endmodule