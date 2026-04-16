// output_buffer.sv
module output_buffer #(
    parameter DEPTH_WORDS = 131072,   // number of 64-bit words
    parameter DATA_WIDTH = 64,        // write width (must match w)
    parameter BYTE_WIDTH = 8
)(
    input  logic clk,
    input  logic rst,

    // Write interface (word-wide)
    input  logic                     we,
    input  logic [$clog2(DEPTH_WORDS)-1:0] waddr,
    input  logic [DATA_WIDTH-1:0]    din,

    // Read interface (byte-wide)
    input  logic                     re,
    input  logic [$clog2(DEPTH_WORDS * (DATA_WIDTH/BYTE_WIDTH))-1:0] raddr,  // byte address
    output logic [BYTE_WIDTH-1:0]    dout
);

    localparam BYTES_PER_WORD = DATA_WIDTH / BYTE_WIDTH;
    localparam DEPTH_BYTES = DEPTH_WORDS * BYTES_PER_WORD;

    logic [DATA_WIDTH-1:0] mem [0:DEPTH_WORDS-1];
    logic [$clog2(DEPTH_WORDS * (DATA_WIDTH/BYTE_WIDTH))-1:0] hold;
    logic [DATA_WIDTH-1:0] read_word;
    logic [$clog2(DEPTH_WORDS)-1:0] word_addr;
    logic [2:0] byte_offset;   // assuming 8 bytes per word, so 3 bits offset (0..7)

    // Write to word memory
    always_ff @(posedge clk) begin
        if (we) begin
            mem[waddr] <= {
                din[7:0],   // New Byte 7 (Old Byte 0)
                din[15:8],  // New Byte 6
                din[23:16], // New Byte 5
                din[31:24], // New Byte 4
                din[39:32], // New Byte 3
                din[47:40], // New Byte 2
                din[55:48], // New Byte 1
                din[63:56]  // New Byte 0 (Old Byte 7)
            };
         end
    end

    // Read word from memory (address = raddr / BYTES_PER_WORD)
//    assign word_addr = raddr >> $clog2(BYTES_PER_WORD);
//    assign byte_offset = raddr[$clog2(BYTES_PER_WORD)-1:0];
//    assign read_word = mem[word_addr];

    always_ff @(posedge clk) begin
        if (re) begin
            read_word <= mem[word_addr];
            word_addr <= raddr >> $clog2(BYTES_PER_WORD);
            hold <= raddr;
        end
        byte_offset <= hold[$clog2(BYTES_PER_WORD)-1:0];
        // Output the requested byte (LSB first)
        dout <= read_word[byte_offset*BYTE_WIDTH +: BYTE_WIDTH];
    end

endmodule
