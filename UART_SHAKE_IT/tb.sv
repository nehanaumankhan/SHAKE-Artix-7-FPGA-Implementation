`timescale 1ns / 1ps

module tb_top_debug();

    localparam CLK_PERIOD = 10;
    localparam CLKDIV = 868;
    localparam BIT_TIME = (CLKDIV+1) * CLK_PERIOD;  // 8690 ns

    logic clk, rst_n, tx;

    top u_top (.clk(clk), .rst_n(rst_n), .tx(tx));

    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        $display("Reset released at %0t ns", $time);
    end

    // Monitor each bit - fixed keyword issue
    initial begin
        forever begin
            @(negedge tx);  // start of a byte
            $display("\n--- New byte ---");
            for (int b = 0; b < 11; b++) begin
                #(BIT_TIME);
                $display("Bit %0d: tx = %b\n", b, tx);
            end
        end
    end

    initial begin
        #2000000;  // 2 ms
        $finish;
    end

endmodule