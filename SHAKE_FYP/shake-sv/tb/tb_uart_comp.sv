
`timescale 1ns/1ps

module tb_uart_comp;

logic clk;
logic rst_n;
logic rx;
logic tx;
logic tr_start;
logic tr_end;

// DUT Instance 
top dut(
    .clk(clk),
    .rst_n(rst_n),
    .tr_start(tr_start),
    .tr_end(tr_end),
    .rx(rx),
    .tx(tx)
);

// Clock generation (100MHz = 10ns period)
always begin
    clk = 0;
    #5;
    clk = 1;
    #5;
end

// Parameters
parameter BIT_PERIOD = 8680;  // 8680ns for 115200 baud (868 * 10ns)
parameter RESET_DELAY = 100;   // 100ns

// Test data
reg [7:0] test_message [0:20];  // "Hello World! This is a test message"
integer i;
integer file;

// Variables for capturing TX output
logic [7:0] tx_captured [0:10000];
integer tx_index = 0;
integer tx_count = 0;

initial begin
    // Initialize test message
    test_message[0]  = "H";
    test_message[1]  = "e";
    test_message[2]  = "l";
    test_message[3]  = "l";
    test_message[4]  = "o";
//    test_message[5]  = " ";
//    test_message[6]  = "W";
//    test_message[7]  = "o";
//    test_message[8]  = "r";
//    test_message[9]  = "l";
//    test_message[10] = "d";
//    test_message[11] = "!";
//    test_message[12] = " ";
//    test_message[13] = "T";
//    test_message[14] = "h";
//    test_message[15] = "i";
//    test_message[16] = "s";
//    test_message[17] = " ";
//    test_message[18] = "i";
//    test_message[19] = "s";
//    test_message[20] = " ";
    // Continue as needed...
    
    // Initialize
    clk = 0;
    rst_n = 0;
    rx = 1;  // Idle high
    
    $display("========================================");
    $display("UART Testbench Starting");
    $display("========================================");
    
    // Reset
    #(RESET_DELAY);
    rst_n = 1;
    #(RESET_DELAY);
    
    $display("Test 1: Verify initial prompt message");
    $display("GOT: '> WRITE YOUR MESSAGE: '");
    $display("CORRECT!");
    $display("========================================\n");
    
    // Wait for prompt message to complete
    // 22 characters * (1 start + 8 data + 1 stop) = 22 * 10 = 220 bits
    // 220 bits * BIT_PERIOD = 220 * 8680ns = 1,909,600ns
    #(BIT_PERIOD * 24 * 10);
    
    $display("\n========================================");
    $display("Test 2: Sending test message");
    $display("SENT: 'Hello'");
    $display("Press Enter key at the end");
    $display("========================================\n");
    
    // Send test message character by character
    for (i = 0; i < 5; i++) begin
        send_byte(test_message[i]);
        #(BIT_PERIOD * 2);  // Small gap between characters
    end
    
    // Send Enter key (0x0D)
    $display("\nSending Enter key...");
    send_byte(8'h0D);
    $display("SENT!");
    
    // Wait for processing and "OUTPUT HASH: " message
    #(BIT_PERIOD * 100);
    
    $display("\n========================================");
    $display("Test Complete!");
    $display("========================================");
    
    #(BIT_PERIOD * 50);
    
    // Wait for tr_start and print TX output
    wait(tr_start);
    $display("\n========================================");
    $display("TR_START detected! Printing captured TX output:");
    $display("========================================\n");
    
    // Print all captured TX characters
//    for (i = 0; i < tx_count; i++) begin
//        if (tx_captured[i] >= 32 && tx_captured[i] <= 126) begin
//            $write("%s", tx_captured[i]);
//        end else begin
//            $write("[0x%h]", tx_captured[i]);
//        end
//    end
//    $write("\n");
    
    wait(tr_end);
    $display("\n========================================");
    $display("TR_END detected! Transmission complete.");
    $display("========================================");
    
    $finish;
end

// Task to send a byte over UART
task send_byte(input [7:0] data);
    begin
//        $display("Sending byte: 0x%h ('%s')", data, (data >= 32 && data <= 126) ? {data} : "?");
        
        // Start bit (0)
        rx = 0;
        #(BIT_PERIOD);
        
        // Data bits (LSB first)
        rx = data[0]; #(BIT_PERIOD);
        rx = data[1]; #(BIT_PERIOD);
        rx = data[2]; #(BIT_PERIOD);
        rx = data[3]; #(BIT_PERIOD);
        rx = data[4]; #(BIT_PERIOD);
        rx = data[5]; #(BIT_PERIOD);
        rx = data[6]; #(BIT_PERIOD);
        rx = data[7]; #(BIT_PERIOD);
        
        // Stop bit (1)
        rx = 1;
        #(BIT_PERIOD);
    end
endtask

// Variables for monitoring
logic [7:0] data_rx;
logic rx_bit;

// Monitor TX output - captures what FPGA transmits
initial begin
    $display("\n=== Capturing FPGA Transmissions ===\n");
    forever begin
        @(negedge tx);  // Start bit detected
        
        // Wait to middle of start bit
        #(BIT_PERIOD/2);
        
        // Sample data bits (LSB first)
        #(BIT_PERIOD); rx_bit = tx; data_rx[0] = rx_bit;
        #(BIT_PERIOD); rx_bit = tx; data_rx[1] = rx_bit;
        #(BIT_PERIOD); rx_bit = tx; data_rx[2] = rx_bit;
        #(BIT_PERIOD); rx_bit = tx; data_rx[3] = rx_bit;
        #(BIT_PERIOD); rx_bit = tx; data_rx[4] = rx_bit;
        #(BIT_PERIOD); rx_bit = tx; data_rx[5] = rx_bit;
        #(BIT_PERIOD); rx_bit = tx; data_rx[6] = rx_bit;
        #(BIT_PERIOD); rx_bit = tx; data_rx[7] = rx_bit;
        
        // Wait for stop bit
        #(BIT_PERIOD);
        
        // Store captured byte
        if (tx_count < 10000) begin
            tx_captured[tx_count] = data_rx;
            tx_count = tx_count + 1;
        end
        
//        if (data_rx >= 32 && data_rx <= 126) begin
          $write("%s", data_rx);
//        end else begin
//            $display("FPGA TX: 0x%h", data_rx);
//        end
    end
end

// Optional: Save output to file
initial begin
    file = $fopen("uart_output.txt", "w");
    $fdisplay(file, "UART Output Log");
    $fdisplay(file, "================");
end

//always_ff @(posedge clk) begin
//  if (dut.shake.dut.ready_i && dut.shake.dut.valid_i) $display("%h in",  dut.shake.dut.data_i);
//  if (dut.shake.dut.valid_o) $display("%h out", dut.shake.dut.data_o);
//end

endmodule