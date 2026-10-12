module nibble_to_ascii (
    input  logic [3:0] nibble,
    output logic [7:0] ascii
);
    
    always_comb begin
        case (nibble)
            4'b0000: ascii = "0";  // 0x30
            4'b0001: ascii = "1";  // 0x31
            4'b0010: ascii = "2";  // 0x32
            4'b0011: ascii = "3";  // 0x33
            4'b0100: ascii = "4";  // 0x34
            4'b0101: ascii = "5";  // 0x35
            4'b0110: ascii = "6";  // 0x36
            4'b0111: ascii = "7";  // 0x37
            4'b1000: ascii = "8";  // 0x38
            4'b1001: ascii = "9";  // 0x39
            4'b1010: ascii = "A";  // 0x41
            4'b1011: ascii = "B";  // 0x42
            4'b1100: ascii = "C";  // 0x43
            4'b1101: ascii = "D";  // 0x44
            4'b1110: ascii = "E";  // 0x45
            4'b1111: ascii = "F";  // 0x46
            default: ascii = "?";  // 0x3F
        endcase
    end
endmodule