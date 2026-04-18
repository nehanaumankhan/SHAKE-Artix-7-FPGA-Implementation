import keccak_pkg::*;

module uart_controller #(
    parameter OUTPUT_BUFFER_DEPTH_WORDS = 131072
) (
    input  logic clk, n_rst, done,
    input  logic tx_done,
    input  logic [7:0] buffer_data,
    output logic rd_en,
    output logic [$clog2(OUTPUT_BUFFER_DEPTH_WORDS * (w/8))-1:0] rd_addr,
    output logic tx_start,
    output logic [7:0] tx_data,
    output logic finish,
    output logic tx_begin
);
    integer total_bytes = 360;
    logic [8:0] counter;
    
    typedef enum logic [2:0] {
        IDLE,
        READ_EN,
        GET_BUFF_DATA,
        SEND_BYTE,
        WAIT_TX
    } state_t;
    
    state_t state;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            state <= IDLE;
            tx_start <= 0;
            rd_en <= 0;
            rd_addr <= 0;
            counter <= 0;
            finish <= 0;
            tx_data <= 0;
            tx_begin <= 0;
            
        end else begin
            case (state)
                
                IDLE: begin
                    tx_start <= 0;
                    rd_en <= 0;
                    tx_begin <= 0;
                    finish <= 0;
                    
                    if (done) begin
                        counter <= 0;
                        rd_addr <= 0;
//                        rd_en <= 1; // new
                        state <= READ_EN;
                    end
                end
                
                READ_EN: begin
                    // Read data and start transmission in same cycle
                        rd_en <= 1;
//                        tx_data <= buffer_data;  // Read data directly
//                        tx_start <= 1;
//                        tx_begin <= 1;
                        state <= GET_BUFF_DATA;
                end
                GET_BUFF_DATA: begin
                    rd_en <= 0;
//                    tx_data <= buffer_data;  // Read data directly
//                    tx_start <= 1;
//                    tx_begin <= 1;
                    state <= SEND_BYTE;
                end 
                
                SEND_BYTE: begin
                    rd_en <= 1;
                    tx_data <= buffer_data;  // Read data directly
                    tx_start <= 1;
                    tx_begin <= 1;
                    state <= WAIT_TX;
                end 
                
                WAIT_TX: begin
                    tx_start <= 0;
                    tx_begin <= 0;
                    rd_en <= 0;
                    
                    if (tx_done) begin
                        if (counter < total_bytes) begin
                            counter <= counter + 1;
                            rd_addr <= rd_addr + 1;
                            state <= READ_EN;  // Send next byte immediately
//                            rd_en <= 1; // new
                        end
                        else if (counter == total_bytes) begin
                            // Last byte finished
                            state <= IDLE;
                            finish <= 1;
                        end
                    end
                end
                
            endcase
        end
    end
endmodule
