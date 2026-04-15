module uart_controller (
    input  logic clk, rst,
    input  logic tx_done,
    input  logic empty,
    input  logic [7:0] buffer_data,

    output logic rd_en,
    output logic tx_start,
    output logic [7:0] tx_data
);

    typedef enum logic [1:0] {
        IDLE,
        READ,
        LOAD,
        WAIT_TX
    } state_t;

    state_t state;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= IDLE;
            tx_start <= 0;
            rd_en <= 0;
        end else begin
            tx_start <= 0;
            rd_en <= 0;

            case (state)

            IDLE: begin
                if (!empty) begin
                    rd_en <= 1;
                    state <= READ;
                end
            end

            READ: begin
                state <= LOAD;
            end

            LOAD: begin
                tx_data <= buffer_data;
                tx_start <= 1;
                state <= WAIT_TX;
            end

            WAIT_TX: begin
                if (tx_done) begin
                    state <= IDLE;
                end
            end

            endcase
        end
    end

endmodule