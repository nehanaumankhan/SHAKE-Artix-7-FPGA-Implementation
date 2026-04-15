// uart_rx.sv
// Simple UART receiver, 8N1, with configurable baud rate.
// done pulses high for one clock cycle when a byte is received.
// data_o is valid when done is asserted.

module uart_rx #(
    parameter CLK_FREQ = 100_000_000, //Clock Frequency of Artix-7 FPGA -> 100MHz
    parameter BAUD_RATE = 115200
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic       done,
    output logic [7:0] data_o
);

    localparam CLKS_PER_BIT     = CLK_FREQ / BAUD_RATE;
    localparam CLKS_PER_HALF_BIT = CLKS_PER_BIT / 2;

    // State encoding
    localparam WAIT_START = 2'b00;
    localparam SAMPLE     = 2'b01;
    localparam STOP_BIT   = 2'b10;

    logic [1:0] state;
    logic [12:0] clk_cnt;
    logic [3:0]  bit_cnt;
    logic        rx_sync, rx_prev;
    logic [7:0]  shift_reg;

    // Synchronize rx to clock domain
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_sync <= 1;
            rx_prev <= 1;
        end else begin
            rx_sync <= rx;
            rx_prev <= rx_sync;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= WAIT_START;
            clk_cnt  <= 0;
            bit_cnt  <= 0;
            shift_reg <= 0;
            done     <= 0;
            data_o   <= 0;
        end else begin
            done <= 0;

            case (state)
                WAIT_START: begin
                    // Detect falling edge on rx (start bit)
                    if (rx_prev == 1 && rx_sync == 0) begin
                        state   <= SAMPLE;
                        clk_cnt <= CLKS_PER_HALF_BIT; // middle of start bit
                        bit_cnt <= 0;
                    end
                end

                SAMPLE: begin
                    if (clk_cnt == 0) begin
                        if (bit_cnt == 0) begin
                            // Verify start bit is still low
                            if (rx_sync != 0) state <= WAIT_START;
                        end else if (bit_cnt >= 1 && bit_cnt <= 8) begin
                            // Sample data bits (LSB first)
                            shift_reg[bit_cnt-1] <= rx_sync;
                        end else if (bit_cnt == 9) begin
                            // Stop bit - should be high
                            if (rx_sync == 1) begin
                                data_o <= shift_reg;
                                done   <= 1;
                            end
                            state <= WAIT_START;
                        end
                        clk_cnt <= CLKS_PER_BIT;
                        bit_cnt <= bit_cnt + 1;
                    end else begin
                        clk_cnt <= clk_cnt - 1;
                    end
                end

                default: state <= WAIT_START;
            endcase
        end
    end
endmodule