module simple_buffer #(
    parameter DEPTH = 16
)(
    input  logic clk,
    input  logic rst,
    input  logic wr_en,
    input  logic rd_en,
    input  logic [7:0] wr_data,
    output logic [7:0] rd_data,
    output logic empty,
    output logic full
);

    logic [7:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH):0] wr_ptr, rd_ptr;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = ((wr_ptr + 1) == rd_ptr);

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            rd_data <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= wr_ptr + 1;
            end

            if (rd_en && !empty) begin
                rd_data <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

endmodule