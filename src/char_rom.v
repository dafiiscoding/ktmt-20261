// char_rom.v — mã ký tự 5 bit → đoạn gfedcba (bit 0 = a, mức cao = sáng), tổ hợp
// Gói D1 · chủ: TV4 · spec: display-spec.md §3 (bảng mã), vector tb/vectors/seg7.txt
// Code do Claude viết theo yêu cầu Long (01/10/2026); chủ gói đọc hiểu để vấn đáp.
module char_rom (
    input  wire [4:0] code,
    output reg  [6:0] seg
);
    always @* begin
        case (code)
            5'h00: seg = 7'h3F;  // 0
            5'h01: seg = 7'h06;  // 1
            5'h02: seg = 7'h5B;  // 2
            5'h03: seg = 7'h4F;  // 3
            5'h04: seg = 7'h66;  // 4
            5'h05: seg = 7'h6D;  // 5
            5'h06: seg = 7'h7D;  // 6
            5'h07: seg = 7'h07;  // 7
            5'h08: seg = 7'h7F;  // 8
            5'h09: seg = 7'h6F;  // 9
            5'h0A: seg = 7'h77;  // A
            5'h0B: seg = 7'h7C;  // b
            5'h0C: seg = 7'h39;  // C
            5'h0D: seg = 7'h5E;  // d
            5'h0E: seg = 7'h79;  // E
            5'h0F: seg = 7'h71;  // F
            5'h10: seg = 7'h76;  // H
            5'h11: seg = 7'h38;  // L
            5'h12: seg = 7'h54;  // n
            5'h13: seg = 7'h5C;  // o
            5'h14: seg = 7'h73;  // P
            5'h15: seg = 7'h50;  // r
            5'h16: seg = 7'h6D;  // S (giống 5)
            5'h17: seg = 7'h78;  // t
            5'h18: seg = 7'h3E;  // U
            5'h19: seg = 7'h40;  // -
            default: seg = 7'h00; // 0x1A–0x1F: trống
        endcase
    end
endmodule
