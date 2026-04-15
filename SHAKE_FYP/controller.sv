// controller.sv
module controller #(
    parameter BRAM_DEPTH      = 1024,
    parameter BRAM_ADDR_WIDTH = $clog2(BRAM_DEPTH),
    parameter WORD_WIDTH      = 64
)(
    input  logic clk,
    input  logic rst,
    input  logic start,
    output logic done,

    // BRAM interface
    output logic [BRAM_ADDR_WIDTH-1:0] bram_addr,
    output logic                       bram_read_en,
    input  logic [WORD_WIDTH-1:0]      bram_rdata,

    // keccak interface
    output logic        valid_i,
    input  logic        ready_i,
    output logic [WORD_WIDTH-1:0] data_i,
    input  logic        valid_o,
    output logic        ready_o,
    input  logic [WORD_WIDTH-1:0] data_o,

    // Original output interface (for testbench compatibility)
    output logic        out_valid,
    output logic [WORD_WIDTH-1:0] out_data,

    // New output buffer interface
    output logic        buffer_we,
    output logic [31:0] buffer_addr,   // write address (0..total_output_words-1)
    output logic [WORD_WIDTH-1:0] buffer_din
);

    // State encoding
    typedef enum logic [2:0] {
        IDLE,
        READ_CONFIG,
        SEND_CONFIG,
        READ_MSG,
        SEND_MSG,
        COLLECT,
        DONE
    } state_t;
    state_t state, next_state;

    // Registers
    logic [31:0] input_size_bits;
    logic [31:0] output_size_bits;
    logic [31:0] input_bits_sent;
    logic [31:0] output_words_rcvd;
    logic [31:0] total_input_words;
    logic [31:0] total_output_words;
    logic        config_received;
    logic        bram_data_valid;

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = READ_CONFIG;
            end
            READ_CONFIG: begin
                next_state = SEND_CONFIG;
            end
            SEND_CONFIG: begin
                if (valid_i && ready_i)
                    next_state = READ_MSG;
            end
            READ_MSG: begin
                if (input_bits_sent < input_size_bits)
                    next_state = SEND_MSG;
                else
                    next_state = COLLECT;
            end
            SEND_MSG: begin
                if (valid_i && ready_i) begin
                    if (input_bits_sent + WORD_WIDTH >= input_size_bits)
                        next_state = COLLECT;
                    else
                        next_state = READ_MSG;
                end
            end
            COLLECT: begin
                if (output_words_rcvd >= total_output_words)
                    next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // State registers and outputs
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            $display("HERE!");
            state <= IDLE;
            bram_addr <= 0;
            bram_read_en <= 0;
            valid_i <= 0;
            ready_o <= 0;
            data_i <= 0;
            input_bits_sent <= 0;
            output_words_rcvd <= 0;
            input_size_bits <= 0;
            output_size_bits <= 0;
            total_input_words <= 0;
            total_output_words <= 0;
            config_received <= 0;
            done <= 0;
            out_valid <= 0;
            out_data <= 0;
            buffer_we <= 0;
            buffer_addr <= 0;
            buffer_din <= 0;
        end else begin
            // Default assignments
            bram_read_en <= 0;
            valid_i <= 0;
            ready_o <= 0;
            done <= 0;
            out_valid <= 0;
            buffer_we <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                    
                        bram_addr <= 0;
                        bram_read_en <= 1;
                        state <= READ_CONFIG;
                        input_bits_sent <= 0;
                        output_words_rcvd <= 0;
                        config_received <= 0;
                        done <= 0;
                    end
                end

                READ_CONFIG: begin
                    state <= SEND_CONFIG;
                end

                SEND_CONFIG: begin
                    valid_i <= 1;
                    data_i <= bram_rdata;
                    if (ready_i) begin
                        // Extract sizes from config word
                        input_size_bits  <= bram_rdata[31:0];
                        output_size_bits <= {4'b0, bram_rdata[59:32]};
                        total_input_words  <= (bram_rdata[31:0] + WORD_WIDTH - 1) / WORD_WIDTH;
                        total_output_words <= ({4'b0, bram_rdata[59:32]} + WORD_WIDTH - 1) / WORD_WIDTH;
                        config_received <= 1;
                        // Prepare to read first message word
                        bram_addr <= 1;
                        bram_read_en <= 1;
                        state <= READ_MSG;
                    end
                end

                READ_MSG: begin
                    if (input_bits_sent < input_size_bits) begin
                        state <= SEND_MSG;
                    end else begin
                        state <= COLLECT;
                    end
                end

                SEND_MSG: begin
                    valid_i <= 1;
                    data_i <= bram_rdata;
                    if (ready_i) begin
                        input_bits_sent <= input_bits_sent + WORD_WIDTH;
                        if (input_bits_sent + WORD_WIDTH >= input_size_bits) begin
                            state <= COLLECT;
                        end else begin
                            bram_addr <= bram_addr + 1;
                            bram_read_en <= 1;
                            state <= READ_MSG;
                        end
                    end
                end

                COLLECT: begin
                    ready_o <= 1;
                    if (valid_o) begin
                        // Pulse out_valid for testbench compatibility
                        out_valid <= 1;
                        out_data <= data_o;

                        // Write to output buffer
                        buffer_we <= 1;
                        buffer_addr <= output_words_rcvd;
                        buffer_din <= data_o;

                        output_words_rcvd <= output_words_rcvd + 1;
                        if (output_words_rcvd + 1 >= total_output_words) begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule