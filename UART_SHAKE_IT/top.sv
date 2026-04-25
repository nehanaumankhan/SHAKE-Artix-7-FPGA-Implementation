module top (
    input  logic clk,
    input  logic rst_n,
    output logic tx
);

    // Total message length: text (25) + CRLF (2) + "Hash: " (6) + hash (128) + CRLF (2) = 163 bytes
    localparam int MSG_LEN = 163;

    // Complete message as a byte array (synthesizable)
    logic [7:0] message [0:MSG_LEN-1] = '{
        // "SHAKE it, don't break it!"
        "S","H","A","K","E"," ","i","t",","," ","d","o","n","'","t"," ","b","r","e","a","k"," ","i","t","!",
        // CR+LF
        13,10,
        // "Hash: "
        "H","a","s","h",":"," ",
        // Hash characters (128 bytes)
        "c","5","f","4","6","3","e","7","c","3","0","8","a","0","5","8",
        "a","3","8","d","e","7","c","4","0","4","0","8","6","4","5","d",
        "d","2","b","9","f","c","7","9","2","0","8","e","8","7","f","7",
        "e","d","a","7","7","2","8","1","c","f","4","7","1","c","d","4",
        "a","a","6","d","9","f","d","e","a","3","1","1","6","f","3","5",
        "8","4","7","d","6","c","e","2","e","5","1","4","1","4","3","6",
        "f","1","1","f","4","3","7","a","4","0","5","c","1","f","5","5",
        "a","9","c","c","0","e","1","c","d","9","f","0","c","3","f","8",
        // Trailing CR+LF
        13,10
    };

    logic        tx_start;
    logic [7:0]  tx_data;
    logic        tx_done;

    transmitter u_tx (
        .clk      (clk),
        .rst      (rst_n),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx_done  (tx_done),
        .tx       (tx)
    );

    // FSM
    typedef enum logic { IDLE, BUSY } state_t;
    state_t state;
    logic [7:0] idx;  // 0..162

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx   <= 0;
            tx_start <= 0;
            tx_data  <= 0;
        end else begin
            tx_start <= 0;  // default

            case (state)
                IDLE: begin
                    if (idx < MSG_LEN) begin
                        tx_data <= message[idx];
                        tx_start <= 1;
                        state <= BUSY;
                    end
                end

                BUSY: begin
                    if (tx_done) begin
                        if (idx == MSG_LEN-1)
                            idx <= 0;          // message done, stay idle
                        else begin
                            idx <= idx + 1;
                            state <= IDLE;
                        end
                    end
                end
            endcase
        end
    end

endmodule