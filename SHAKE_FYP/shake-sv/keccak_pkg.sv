package keccak_pkg;

    // in SHAKE128/256 total state size is 5x5x64
    localparam int planes = 5;
    localparam int sheets = 5;
    localparam int w = 64; // represents lane size/slices
    localparam int w_byte_size = w/8;
    localparam int w_bit_width = $clog2(w);
    localparam int w_byte_width = w_bit_width-3;

    localparam int STATE_WIDTH = 1600;
    localparam int RATE_SHAKE256 = 1088; // number of bits processed per permutation for RATE_SHAKE256
    localparam int CAP_SHAKE256  = STATE_WIDTH - RATE_SHAKE256;  // 512 Capacity bits showing bits 1600-1088 are never touched by input data
    localparam int RATE_SHAKE128 = 1344; 
    localparam int CAP_SHAKE128  = STATE_WIDTH - RATE_SHAKE128;  // 256

    localparam logic [10:0] RATE_SHAKE256_VEC = 11'(RATE_SHAKE256);
    localparam logic [10:0] CAP_SHAKE256_VEC  = 11'(CAP_SHAKE256);
    localparam logic [10:0] RATE_SHAKE128_VEC = 11'(RATE_SHAKE128);
    localparam logic [10:0] CAP_SHAKE128_VEC  = 11'(CAP_SHAKE128);
    localparam logic [1:0]  SHAKE256_MODE_VEC = 2'b11;
    localparam logic [1:0]  SHAKE128_MODE_VEC = 2'b10;

    // For solving endian discrepancy between AXI(big-endian) and keccak(little-endian)
    class EndianSwitcher #(parameter int WIDTH = 64);
        localparam int NUM_BYTES = WIDTH/8;

        static function logic [WIDTH-1:0] switch(input logic [WIDTH-1:0] x);
            logic [WIDTH-1:0] result;

            for(int i=0; i<NUM_BYTES;i++) 
                result[i*8 +: 8] = x[(NUM_BYTES-1-i)*8 +: 8];
            return result;
        endfunction
    endclass
    // function automatic logic [63:0] switch_endian(input logic [63:0] x);
    //     logic [63:0] result;
    //     for (int i = 0; i < 8; i++)
    //         result[i*8 +: 8] = x[(7-i)*8 +: 8];
    //     return result;
    // endfunction
endpackage
