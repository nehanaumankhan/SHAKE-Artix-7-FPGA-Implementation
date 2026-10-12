// input_buffer.sv - Now supports both read and write
module input_buffer #(
    parameter DATA_WIDTH = 64,
    parameter DEPTH      = 64,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                     clk,
    input  logic                     write_en,
    input  logic [ADDR_WIDTH-1:0]    write_addr,
    input  logic [DATA_WIDTH-1:0]    write_data,
    input  logic                     read_en,
    input  logic [ADDR_WIDTH-1:0]    read_addr,
    output logic [DATA_WIDTH-1:0]    read_data
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write to BRAM
    always_ff @(posedge clk) begin
        if (write_en)
            mem[write_addr] <= write_data;
    end

    // Synchronous read
    always_ff @(posedge clk) begin
        if (read_en)
            read_data <= mem[read_addr];
    end

endmodule