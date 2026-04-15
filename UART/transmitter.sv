module transmitter (
    input  logic clk, rst, tx_start,
    input  logic [7:0] tx_data,
    output logic tx_done, tx
);

parameter clkdiv = 3;

typedef enum logic {IDLE, TRANSMITTING} state_t;
state_t state;

logic [3:0] bit_counter;
logic [6:0] baud_counter;
logic [10:0] tx_buffer;
logic parity;

assign parity = ~^tx_data;

always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
        state <= IDLE;
        tx_done <= 0;
        tx <= 1;
        bit_counter <= 0;
        baud_counter <= 0;
    end else begin
        case (state)

        IDLE: begin
            tx <= 1;
            tx_done <= 0;
            if (tx_start) begin
                state <= TRANSMITTING;
                bit_counter <= 0;
                baud_counter <= 0;
                tx_buffer <= {1'b1, parity, tx_data, 1'b0};
            end
        end

        TRANSMITTING: begin
            tx <= tx_buffer[0];
            baud_counter <= baud_counter + 1;          // ? must increment each cycle
            if (baud_counter == clkdiv) begin
                baud_counter <= 0;
                if (bit_counter == 10) begin           // last bit (stop bit index)
                    tx_done <= 1;
                    state <= IDLE;
                end else begin
                    bit_counter <= bit_counter + 1;
                    tx_buffer <= {1'b0, tx_buffer[10:1]};
                end
            end
        end

        endcase
    end
end

endmodule