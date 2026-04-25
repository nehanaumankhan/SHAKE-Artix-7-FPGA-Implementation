`timescale 1ns / 1ps

module tb_top();

    localparam CLK_PERIOD = 10;
    integer j = 0;
    localparam CLKDIV = 868;
    localparam BIT_TIME = (CLKDIV+1) * CLK_PERIOD;  // 8690 ns
    logic [7:0] received_byte;
    logic clk, rst_n, tx, start, done, tr_end;

    localparam integer P = 10;
    localparam MAX_TV_SIZE = 2;
    localparam MAX_DIGEST_SIZE = 8 * 1024 * 1024;
    localparam MAX_MESSAGE_SIZE = 8 * 1024 * 1024;
    localparam BRAM_DEPTH = 256;
    localparam OUTPUT_BUFFER_DEPTH_WORDS = 256;  // must match shake_top parameter

    localparam string TV_PATH = "C://Users//LENOVO//SHAKE-Artix-7-FPGA-Implementation//SHAKE_FYP//shake-sv//tb//kat//";
    localparam string RESULTS_DIR = "C://Users//LENOVO//SHAKE-Artix-7-FPGA-Implementation//SHAKE_FYP//shake-sv//tb//results//";
    localparam TV = 0;

    string file_name;
    integer csv_fd;
    logic failed = 0;
    logic [63:0] curr;
    logic [7:0] out_last;

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
    top #(
        .clkdiv(CLKDIV),
        .OUTPUT_BUFFER_DEPTH_WORDS(OUTPUT_BUFFER_DEPTH_WORDS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tr_start(done),
        .tr_end(tr_end),
        .tx(tx)
    );

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

        for (int i =  0; i < total_expected_bytes; i++) begin
            expected_bytes[i] = digests[TV][MAX_DIGEST_SIZE - total_expected_bytes*8 + i*8 +: 8];        
        end

        // Open CSV
        file_name = "keccak.csv";
        csv_fd = $fopen({RESULTS_DIR, file_name}, "w");
        if (!csv_fd) $fatal(1, "Failed to open CSV file");
        $fwrite(csv_fd, "total_cycles,success\n");

        repeat(1) begin
            rst_n = 0;
            start = 0;
            mismatch = 0;
            repeat(5) @(posedge clk);
            rst_n = 1;
            repeat(2) @(posedge clk);
            $display("INFO: Asserting start pulse");
            // Wait for done with timeout
            $display("INFO: Waiting for done...");
            fork
                begin
                    wait(done == 1);
                    $display("INFO: done asserted at time %0t", $time);
                end
    
            join_any
            disable fork;
            j = 0;
            while(j!=output_size/8) begin
                $display("--- Byte %d ---", j);
                
                @(negedge tx);      
                #(BIT_TIME);
                for (int b = 0; b < 8; b++) begin
                    #(BIT_TIME);
                    received_byte[b] = tx;
                end
                
                #(BIT_TIME);
                #(BIT_TIME);
    //            if (received_byte !== 8'hxx) begin
                    if (received_byte == expected_bytes[j]) begin
                        $display("MATCH: %h == %h", received_byte, expected_bytes[j]);
                    end else begin
                        $display("MISMATCH: %h != %h", received_byte, expected_bytes[j]);
                        mismatch = 1;
                    end
                    j = j + 1;
    //            end
                
            end
            $display("\n");
    
            if (mismatch) $display("FAILURE: Digest mismatch");
            else          $display("SUCCESS: All %0d bytes match", total_expected_bytes);
    
            $display("Completed in %0d clock cycles", cycle_ctr);
            $fwrite(csv_fd, "%0d,%0d\n", cycle_ctr, !mismatch);
        end
        wait(tr_end);
        $finish;
    end
    

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

endmodule
