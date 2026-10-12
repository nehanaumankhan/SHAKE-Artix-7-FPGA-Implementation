import keccak_pkg::*;

module uart_controller #(
    parameter OUTPUT_BUFFER_DEPTH_WORDS = 64,
    parameter BRAM_DEPTH = 64,
    parameter CONFIG_HIGH = 32'hC0000800
) (
    input  logic clk, n_rst, done,
    input  logic tx_done,
    input  logic [7:0] buffer_data,
    output logic rd_en,
    output logic [$clog2(OUTPUT_BUFFER_DEPTH_WORDS * (w/8))-1:0] rd_addr,
    output logic tx_start,
    output logic [7:0] tx_data,
    output logic finish,
    output logic in_buffer_wdone,
    output logic in_buffer_we,   
    output logic [$clog2(BRAM_DEPTH)-1:0] in_buffer_waddr,// Byte-wide read interface for output buffer
    output logic [w-1:0] in_buffer_wdata,
    input rx_done,
    input [7:0] rx_data
);
    integer total_bytes = CONFIG_HIGH[19:3];
    logic [8:0] counter;
    
    // Message collection
    logic [31:0] message_size;
    logic [11:0] write_addr;
    logic [63:0] current_word;
    logic [3:0] byte_count;
    logic [63:0] temp_buffer [0:BRAM_DEPTH-1];  // Temporary storage during collection
    
    // Message ROMs
    logic [10:0] msg_index;
    logic [7:0] prompt_msg [0:21];
    logic [7:0] output_msg [0:15];
    logic [4:0] out_index;
    
    
    // Initialize PROMPT message: "> WRITE YOUR MESSAGE: "
    initial begin
        prompt_msg[0]  = ">";
        prompt_msg[1]  = " ";
        prompt_msg[2]  = "W";
        prompt_msg[3]  = "R";
        prompt_msg[4]  = "I";
        prompt_msg[5]  = "T";
        prompt_msg[6]  = "E";
        prompt_msg[7]  = " ";
        prompt_msg[8]  = "Y";
        prompt_msg[9]  = "O";
        prompt_msg[10] = "U";
        prompt_msg[11] = "R";
        prompt_msg[12] = " ";
        prompt_msg[13] = "M";
        prompt_msg[14] = "E";
        prompt_msg[15] = "S";
        prompt_msg[16] = "S";
        prompt_msg[17] = "A";
        prompt_msg[18] = "G";
        prompt_msg[19] = "E";
        prompt_msg[20] = ":";
        prompt_msg[21] = " ";
    end
    
    // Initialize OUTPUT message: "> OUTPUT HASH: "
    initial begin
        output_msg[0]  = 8'h0D;
        output_msg[1]  = ">";
        output_msg[2] = " ";
        output_msg[3]  = "O";
        output_msg[4]  = "U";
        output_msg[5]  = "T";
        output_msg[6]  = "P";
        output_msg[7]  = "U";
        output_msg[8]  = "T";
        output_msg[9]  = " ";
        output_msg[10] = "H";
        output_msg[11] = "A";
        output_msg[12] = "S";
        output_msg[13] = "H";
        output_msg[14] = ":";
        output_msg[15] = " ";
    end
    
    typedef enum logic [4:0] {
        IDLE,
        
        SEND_PROMPT,        // Send "WRITE YOUR MESSAGE: "
        COLLECT_MESSAGE,    // Collect input until Enter
        WRITE_CONFIG,       // Write config word at address 0
        WRITE_BUFFER,       // Write collected message to buffer
        SEND_OUTPUT,        // Send "OUTPUT HASH: "
        DONE,                // Finished
        
        READ_EN,
        GET_BUFF_DATA,
        WAIT_TX_BEF,
        WAIT_TX
    } state_t;
    

    state_t state;
    
    logic [7:0] ascii1;
    logic [7:0] ascii2;
    nibble_to_ascii nib_to_asc1 (buffer_data[3:0], ascii1);
    nibble_to_ascii nib_to_asc2 (buffer_data[7:4], ascii2);

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
//            state <= IDLE;
            tx_start <= 0;
            rd_en <= 0;
            rd_addr <= 0;
            counter <= 0;
            finish <= 0;
            tx_data <= 0;
            
            state <= SEND_PROMPT;
            msg_index <= 0;
            out_index <= 0;
            tx_data <= 0;
            
            // Collection registers
            message_size <= 0;
            write_addr <= 1;
            current_word <= 0;
            byte_count <= 0;
            in_buffer_we <= 0;
            in_buffer_waddr <= 0;
            in_buffer_wdata <= 0;
            in_buffer_wdone <= 0;
            
        end else begin
            tx_start <= 0;
            in_buffer_we <= 0;
            case (state) 
                SEND_PROMPT: begin
                    tx_data <= prompt_msg[msg_index];
                    tx_start <= 1;
                    
                    if (tx_done) begin
                        if (msg_index == 21) begin
                            state <= COLLECT_MESSAGE;
                            msg_index <= 0;
                        end else begin
                            msg_index <= msg_index + 1;
                        end
                    end
                end
            // Collect message until Enter key (0x0D)
                COLLECT_MESSAGE: begin
                    if (rx_done) begin
                        if (rx_data == 8'h0D) begin  // Enter key pressed
                            state <= WRITE_CONFIG;
                        end else begin
                            // Store byte in current word
                            if (byte_count == 7) begin
                                // Complete 64-bit word ready
                                temp_buffer[write_addr] <= {current_word[55:0], rx_data};
                                write_addr <= write_addr + 1;
                                byte_count <= 0;
                                current_word <= 0;
                            end else begin
                                current_word <= {current_word[55:0], rx_data};
                                byte_count <= byte_count + 1;
                            end
                            message_size <= message_size + 1;
                        end
                    end
                end
                
                // Write config word at address 0
                WRITE_CONFIG: begin
                    in_buffer_we <= 1;
                    in_buffer_waddr <= 0;
                    in_buffer_wdata <= {CONFIG_HIGH, message_size*8};
                    state <= WRITE_BUFFER;
                    write_addr <= 1;
                end
                
                // Write all collected data from temp_buffer to BRAM
                WRITE_BUFFER: begin
                    if (write_addr <= (message_size)/8) begin
                        in_buffer_we <= 1;
                        in_buffer_waddr <= write_addr;
                        in_buffer_wdata <= temp_buffer[write_addr];
                        write_addr <= write_addr + 1;
                    end else if(byte_count < 8) begin
                        in_buffer_we <= 1;
                        state <= SEND_OUTPUT;
                        in_buffer_waddr <= write_addr;
                        in_buffer_wdata <= current_word << (64 - (byte_count*8));
                    end
                end
                
              SEND_OUTPUT: begin
                    tx_data <= output_msg[out_index];
                    if (out_index != 15) tx_start <= 1;
                    else tx_start <= 0;
                    if (tx_done) begin
                        if (out_index == 15) begin
                            state <= IDLE;
//                            tx_start <= 0;
                            in_buffer_wdone <= 1;
                        end else begin
                            out_index <= out_index + 1;
                        end
                    end
                end
                                               
                IDLE: begin
                    in_buffer_we <= 0;
                    tx_start <= 0;
                    rd_en <= 0;
                    in_buffer_wdone <= 0;
                    
                    if (done && ~finish) begin
                        counter <= 0;
                        rd_addr <= 0;
                        finish <= 0;
                        rd_en <= 1; // new
                        state <= READ_EN;
                    end
                end
                
                READ_EN: begin
                   state <= GET_BUFF_DATA;
                end
                GET_BUFF_DATA: begin
                    tx_data <= {4'b0, ascii2};  // Read data directly
                    tx_start <= 1;
                    state <= WAIT_TX_BEF;
                end 
                
                WAIT_TX_BEF: begin
                    tx_start <= 0;
                    if (tx_done) begin
                        tx_data <= {4'b0, ascii1};
                        tx_start <= 1;
                        state <= WAIT_TX;
                    end
                end
                WAIT_TX: begin
                    tx_start <= 0;
                    if (tx_done) begin
                        if (counter < total_bytes) begin
                            counter <= counter + 1;
                            rd_addr <= rd_addr + 1;
                            state <= READ_EN;  // Send next byte immediately
                        end
                        if (counter  == total_bytes-1) begin
                            state <= IDLE;
                            finish <= 1;
                        end
                    end
                end
                
            endcase
        end
    end
endmodule

//    input logic in_buffer_wdone,
//    input logic in_buffer_we,   
//    input logic [$clog2(BRAM_DEPTH)-1:0] in_buffer_waddr,// Byte-wide read interface for output buffer
//    input logic [w-1:0] in_buffer_wdata,

