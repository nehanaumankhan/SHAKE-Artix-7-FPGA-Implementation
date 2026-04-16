import keccak_pkg::*;

module shake_top_tb;
    // Constants
    localparam integer P = 10;
    localparam MAX_TV_SIZE = 2;
    localparam MAX_DIGEST_SIZE = 8 * 1024 * 1024;
    localparam MAX_MESSAGE_SIZE = 8 * 1024 * 1024;
    localparam BRAM_DEPTH = 1024;
    localparam OUTPUT_BUFFER_DEPTH_WORDS = 131072;  // must match shake_top parameter

    localparam string TV_PATH = "C://FYP//SHAKE//shake-sv//tb//kat//";
    localparam string RESULTS_DIR = "C://FYP//SHAKE//shake-sv//tb//results";
    localparam TV = 1;
    
    string file_name;
    integer csv_fd;
    logic failed = 0;
    logic [63:0] curr;

    logic clk = 1;
    logic rst_n;
    logic start;
    logic done;

    // Output buffer read interface (byte-wide)
    logic [7:0] buffer_dout_byte;
    logic       buffer_read_en;
    logic [$clog2(OUTPUT_BUFFER_DEPTH_WORDS * (w/8))-1:0] buffer_read_addr;

    // Test vector arrays
    logic [w-1:0] config_words [0:MAX_TV_SIZE-1];
    logic [MAX_MESSAGE_SIZE-1:0] messages [0:MAX_TV_SIZE-1];
    logic [0:MAX_DIGEST_SIZE-1] digests [0:MAX_TV_SIZE-1];
    logic [31:0] input_size;
    logic [31:0] output_size;

    // Expected digest bytes
    logic [7:0] expected_bytes [0:MAX_DIGEST_SIZE/8 - 1];
    int total_expected_bytes;
    int total_words;
    logic mismatch;

    // Cycle counter
    longint unsigned cycle_ctr = 0;
    logic started = 0;

    // Instantiate shake_top
    shake_top #(
        .BRAM_DEPTH(BRAM_DEPTH),
        .OUTPUT_BUFFER_DEPTH_WORDS(OUTPUT_BUFFER_DEPTH_WORDS)
    ) dut (
        .clk,
        .rst_n,
        .start,
        .done,
        .buffer_dout_byte,
        .buffer_read_en,
        .buffer_read_addr
    );

    // Clock
    always #(P/2) clk = ~clk;

    // Cycle counter
    always_ff @(posedge clk) begin
        if (rst_n == 0) begin
            cycle_ctr <= 0;
            started <= 0;
        end else if (start) begin
            started <= 1;
        end else if (done) begin
            started <= 0;
        end else if (started) begin
            cycle_ctr <= cycle_ctr + 1;
        end
    end

    // Main initial block
    initial begin
        // Read test vectors
        $readmemh({TV_PATH, "config_word.txt"}, config_words);
        $readmemh({TV_PATH, "message.txt"}, messages);
        $readmemh({TV_PATH, "digest.txt"}, digests);

        input_size  = config_words[TV][31:0];
        output_size = {4'b0, config_words[TV][59:32]};
        total_expected_bytes = output_size / 8;
        total_words = output_size / 64;
        $display("INFO: input_size = %0d bits, output_size = %0d bits", input_size, output_size);
        $display("INFO: total_expected_bytes = %0d", total_expected_bytes);

//        // Convert packed digest vector to byte array (LSB first)
//        for (int i = 0; i < total_words; i++) begin
//            curr = digests[TV][i*64 +: 64];
//            for (int j = 0; j < 8; j++)
//                expected_bytes[8*i + j] = curr[j*8 +: 8 ];
//            $display("curr : %h, eb %h",curr, expected_bytes[8*i +: 8]);
                
//        end
        for (int i = 0; i < total_expected_bytes; i++) begin
//            curr = digests[TV][i*64 +: 64];
            expected_bytes[i] = digests[TV][i*8 +: 8];
//            $display("curr : %h, eb %h",curr, expected_bytes[8*i +: 8]);           
        end

        // Open CSV
        file_name = "keccak.csv";
        csv_fd = $fopen({RESULTS_DIR, file_name}, "w");
        if (!csv_fd) $fatal(1, "Failed to open CSV file");
        $fwrite(csv_fd, "total_cycles,success\n");

        // Initialize input buffer (hierarchical path)
        $display("INFO: Initializing input buffer...");
        for (int i = 0; i < BRAM_DEPTH; i++) dut.bram_inst.mem[i] = '0;
        dut.bram_inst.mem[0] = config_words[TV];
        for (int i = 0; i < (input_size + w - 1) / w; i++) begin
            dut.bram_inst.mem[1 + i] = messages[TV][i*w +: w];
        end
        $display("INFO: Input buffer initialized with config and %0d message words", (input_size + w - 1) / w);

        // Reset and start
        rst_n = 0;
        start = 0;
        buffer_read_en = 0;
        buffer_read_addr = 0;
        mismatch = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        $display("INFO: Asserting start pulse");
        start = 1;
        @(posedge clk);
        start = 0;

        // Wait for done with timeout
        $display("INFO: Waiting for done...");
        fork
            begin
                wait(done == 1);
                $display("INFO: done asserted at time %0t", $time);
            end
//            begin
//                repeat(2000000) @(posedge clk);
//                $display("ERROR: Timeout waiting for done");
//                $finish;
//            end
        join_any
        disable fork;

        // Read output buffer byte by byte and compare
//        buffer_read_addr = 0;
//        buffer_read_en = 1;
        @(posedge clk);
        $display("INFO: Reading output buffer...");
        for (int i = 0; i <= total_expected_bytes; i++) begin
            buffer_read_addr = i;
            buffer_read_en = 1;
            @(posedge clk);
            buffer_read_en = 0;
            @(posedge clk);
            if (buffer_dout_byte !== expected_bytes[i-1]) begin
                $display("ERROR: Byte %0d: expected %h, got %h", i, expected_bytes[i-1], buffer_dout_byte);
                mismatch = 1;
            end else begin
                $write("%h ", buffer_dout_byte);
                if ((i+1) % 16 == 0) $write("\n");
            end
        end
        $display("\n");
endmodule
