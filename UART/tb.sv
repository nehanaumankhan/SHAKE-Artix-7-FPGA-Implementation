`timescale 1ns/1ps

module tb_uart_top;

    localparam CLK_PERIOD = 10;

    logic clk, rst;
    logic wr_en;
    logic [7:0] wr_data;
    logic full;
    logic tx;

    uart_top dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .full(full),
        .tx(tx)
    );

    // Clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Write task
    task write_byte(input [7:0] data);
        begin
            @(posedge clk);
            while (full) @(posedge clk);

            wr_data = data;
            wr_en   = 1;

            @(posedge clk);
            wr_en   = 0;
        end
    endtask
    
    //UART monitor task
task automatic uart_monitor;
        int i;
        reg [7:0] rx_byte;
    
        forever begin
            @(posedge clk);
    
            // Detect start bit
            if (tx == 0) begin
    
                // Wait HALF bit time ? 2 cycles (since bit = 4 cycles)
                repeat (2) @(posedge clk);
    
                // Now sample in middle of each bit
                for (i = 0; i < 8; i++) begin
                    repeat (4) @(posedge clk); // full bit duration
                    rx_byte[i] = tx;
                end
    
                // Skip parity
                repeat (4) @(posedge clk);
    
                // Stop bit
                repeat (4) @(posedge clk);
    
                $display("Received Byte = %c (0x%h)", rx_byte, rx_byte);
            end
        end
    endtask

    // Test
    initial begin
        rst = 0;
        wr_en = 0;
        wr_data = 0;

        repeat(5) @(posedge clk);
        rst = 1;

        $display("Writing message...");

        write_byte("H");
        write_byte("e");
        write_byte("l");
        write_byte("l");
        write_byte("o");
        write_byte(13);
        write_byte(10);

        repeat(1000) @(posedge clk);
        $finish;
    end

    // Monitor
    initial begin
        $monitor("T=%0t | wr_en=%b data=%h | tx=%b",
                 $time, wr_en, wr_data, tx);
    end
    initial begin
        uart_monitor();
    end

endmodule