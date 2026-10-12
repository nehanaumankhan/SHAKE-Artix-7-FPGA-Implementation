`timescale 1ns / 1ps

import keccak_pkg::*;

module tb_top;
    localparam integer P       = 10;
    localparam MAX_TV_SIZE     = 12 ;
    localparam MAX_DIGEST_SIZE = 8*1024*1024;   
    localparam MAX_MSG_SIZE    = 8*1024*1024;

    localparam string TV_PATH  = "C://Users//LENOVO//SHAKE//SHAKE.srcs//sim_1//new//kat//";
    integer TV              = 0 ;

    string f;
    integer csv_fd;
    logic done   = 0;
    logic failed = 0;
    logic clk    = 1;
    logic rst;
    logic valid_i, ready_o;
    logic valid_o, ready_i;
    logic [w-1:0] data_i, data_o;

    logic [w-1:0] config_words [0:MAX_TV_SIZE-1];
    logic [MAX_MSG_SIZE-1:0] messages [0:MAX_TV_SIZE-1]; // message comes in MSB first
    logic [MAX_MSG_SIZE-1:0] digests  [0:MAX_TV_SIZE-1]; 
    logic [31:0] input_size;
    logic [31:0] output_size;

    typedef enum logic [3:0] {
        S_INIT, S_EXECUTE, S_STOP, S_RST
    } state_t;
    state_t state = S_RST;


    initial begin
        // Read test vectors
        $readmemh({TV_PATH, "config_word.txt"}, config_words);
        $readmemh({TV_PATH, "message.txt"}, messages);
        $readmemh({TV_PATH, "digest.txt"}, digests);

    end

    // Clock definition
    always #(P/2) clk = ~clk;

    // Some constant signals
    assign output_size = {4'b0, config_words[TV][59:32]};
    assign input_size = config_words[TV][31:0];

    // Cycle counter
    longint unsigned cycle_ctr;
    always_ff @(posedge clk) begin
        if (rst)
            cycle_ctr <= 0;
        else if (state != S_STOP)
            cycle_ctr <= cycle_ctr + 1;
    end

    // Input word counter
    longint unsigned input_ctr;
    always_ff @(posedge clk) begin
        if (rst)
            input_ctr <= (input_size >> 6) + (input_size[5:0] != 0);
        else if ((state == S_EXECUTE) && valid_i && ready_i)
            if (input_ctr > 1) input_ctr <= input_ctr - 1;
//            else input_ctr <= 1;
    end

    // Output word counter
    longint unsigned output_ctr;
    always_ff @(posedge clk) begin
        if (rst) begin
            output_ctr <= output_size;
//            $display("Output Counter: %d", output_ctr);
        end
        else if ((state == S_EXECUTE) && valid_o && ready_o)
            output_ctr <= output_ctr - 64;
    end

    // Device under stress
    keccak dut (
        .clk (clk),
        .rst (rst),
        .ready_o (ready_o),
        .valid_i (valid_i),
        .ready_i (ready_i),
        .valid_o (valid_o),
        .data_i (data_i),
        .data_o (data_o)
    );

//    initial begin
//        $display("Testbench started");
//        rst = 1;
//        #(2*P);
//        rst = 0;
//    end

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_i             <= 0;
            ready_o             <= 0;
            data_i              <= 0;
            failed              <= 0;
            state               <= S_INIT;
            rst <= 0;
        end
   
        else begin
//            valid_i <= 0;
            ready_o <= 0;
            data_i  <= 0;
//            rst <= 0;

            unique case (state)
                S_RST:  begin
                    rst <= 1;
                end
                S_INIT: begin
                    valid_i <= 1;
                    data_i  <= config_words[TV][w-1:0];
//                    rst <= 0;
                    if (ready_i) begin
                        valid_i <= 1;
                        state  <= S_EXECUTE;
                        data_i <= messages[TV][(input_ctr-1)*w +: w];
                    end
                end

                S_EXECUTE: begin               
                    ready_o <= 1;
                    data_i  <= messages[TV][(input_ctr-1)*w +: w];
//                    $display("valid_i = %d, ready_i = %d output_ctr = %d", valid_i, ready_i, output_ctr);

                    if (ready_i && valid_i) begin
                        if (input_ctr == 1) begin
                            valid_i <= 0;
                        end
//                        $display("valid_i = %d, ready_i = %d, data_i = %h, input_ctr = %d, msg = %h", valid_i, ready_i, data_i, input_ctr, messages[TV][(input_ctr-1)*w +: w]);
//                        $display("output_size = %d, input_size = %d, data_i = %h, input_ctr = %d", output_size, input_size, data_i, input_ctr);
                        data_i <= messages[TV][(input_ctr-2)*w +: w];
                    end

                    if (valid_o && (data_o != digests[TV][(output_ctr-64)+:w])) begin
                        $display("Error in word %d: Expected %h, received %h", output_ctr, digests[TV][(output_ctr-64)+:w], data_o);
                        $display("digest: %h", digests[0][31:0]);
                        state <= S_STOP;
//                         $display("output_ctr: %d", digests[TV]);
                        failed <= 1;
                    end

                    if (output_ctr <= 64) begin
                        state  <= S_STOP;
                    end
                end

                S_STOP: begin
                    if (failed) begin
                        $display("Test case %d: FAILURE", TV);
                    end else begin
                        $display("Test case %d: SUCCESS", TV);
                    end
                    if (TV + 1 < MAX_TV_SIZE) begin
                        TV <= TV + 1;
                        state <= S_RST;
                        $display("Completed in %d clock cycles", cycle_ctr);
                    end
                    else begin
                        $display("Completed in %d clock cycles", cycle_ctr);
                        $finish;
                       
                    end  
              
                    
                end
            
                default: begin
                    $fatal(1, "Invalid state reached: %0d", state);
                end
            endcase
        end
    end

endmodule


//1. 40000b4000000020 - SHAKE128 with a 32-bit input and a 2880-bit output (plus bit 63 set).
//2. 4080000000000020 - SHAKE128 with a 32-bit input and an extremely large 8,388,608-bit (8 Mb) output.
//3. 4000100000000040 - SHAKE128 with a 64-bit input and a 4096-bit (512-byte) output.
//4. 40000AF0000007D0 - SHAKE128 with a 2000-bit input and a 2800-bit output.
//5. 60000AF0000007D0 - SHAKE256 with a 2000-bit input and a 2800-bit output (same lengths as above, switched to SHAKE256).
//6. 60000AF000000800 - SHAKE256 with a 2048-bit (exact 256-byte) input and a 2800-bit output.
//7. 4000010000000024 - SHAKE128 with a 36-bit input and a 256-bit (32-byte) output.
//8. 4000020000000080 - SHAKE128 with a 128-bit (16-byte) seed/input and a 512-bit (64-byte) output.
//9. 6000040000000100 - SHAKE256 with a 256-bit (32-byte) key/input and a 1024-bit (128-byte) output.
//10. 4000080000000200 - SHAKE128 with a 512-bit (64-byte) block input and a 2048-bit (256-byte) output.
//11. 60000C0000000400 - SHAKE256 with a 1024-bit (128-byte) message input and a 3072-bit (384-byte) output.
//12. 4000020000001000 - SHAKE128 with a large 4096-bit (512-byte) message input and a compact 512-bit (64-byte) output.
// message stored in memory or sent as multiple of 64 (padded with 0s) let's say msg size is 72 so it will be stored in 
// memory as {first 64 bits, 8 bits, 56 0s} message_size 72
