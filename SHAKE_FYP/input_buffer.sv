// bram_module.sv
module input_buffer #(
    parameter DATA_WIDTH = 64,          // width of each word (must match `w` from keccak_pkg)
    parameter DEPTH      = 1024,        //is adjustable from testbench
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                     clk,
    input  logic                     read_en,
    input  logic [ADDR_WIDTH-1:0]    addr,
    output logic [DATA_WIDTH-1:0]    rdata
);

    // Memory array
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Initialize BRAM from external file
    initial begin
        $readmemh("input_data.mem", mem);
    end

    // Synchronous read (inferred as Block RAM)
    always_ff @(posedge clk) begin
        if (read_en)
            rdata <= mem[addr];
    end

endmodule
