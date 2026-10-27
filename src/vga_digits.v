// vga_digits.v — VGA 640×480@60 "đuổi tia": vẽ 8 chữ số 7 đoạn khổng lồ thẳng từ Display RAM, không framebuffer
// Gói D5 · chủ: TV4 · spec: display-spec.md §7
// Code do Claude viết theo yêu cầu Long (26/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// Xung pixel = clock enable mỗi 2 chu kỳ clk (25 MHz từ 50 MHz), cùng miền clock với CPU → không CDC.
// Mỗi pixel: (x, y) → (ô, đoạn) bằng vga_map (tổ hợp) → mã ô → char_rom → đoạn sáng/tắt → màu.
// hsync, vsync, rgb chốt cùng một cạnh pixel (cả ba trễ đúng 1 pixel so với bộ đếm x, y → vẫn thẳng hàng).

// vga_map: (x, y) → ô (0 = DISP0, phải nhất) và đoạn 0…6 = a…g, 7 = dp; hit = 0 là nền. Bảng display-spec §7.
// Tách module riêng để tb so thẳng với vga_points.txt (V-2). So bộ đếm hẹp với hằng 32 bit là cố ý → tắt cảnh báo độ rộng.
/* verilator lint_off DECLFILENAME */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module vga_map (
    input  wire [9:0] x,
    input  wire [9:0] y,
    output wire [2:0] ci,
    output reg  [2:0] sg,
    output reg        hit
);
    wire [2:0] col = x[9:4] / 3'd5;         // x / 80 = (x / 16) / 5 với x < 640 (col ≤ 7)
    wire [6:0] u   = x - {col, 6'd0} - {col, 4'd0};   // x − 80·col
    wire [9:0] v   = y - 10'd160;
    wire       in  = (x < 10'd640) && (y >= 10'd160) && (y < 10'd320);
    assign ci = 3'd7 - col;

    always @* begin
        sg  = 3'd0;
        hit = 1'b0;
        if (in) begin
            if      (u >= 20 && u < 60 && v >= 8   && v < 16)  begin sg = 3'd0; hit = 1'b1; end   // a
            else if (u >= 60 && u < 68 && v >= 16  && v < 76)  begin sg = 3'd1; hit = 1'b1; end   // b
            else if (u >= 60 && u < 68 && v >= 84  && v < 144) begin sg = 3'd2; hit = 1'b1; end   // c
            else if (u >= 20 && u < 60 && v >= 144 && v < 152) begin sg = 3'd3; hit = 1'b1; end   // d
            else if (u >= 12 && u < 20 && v >= 84  && v < 144) begin sg = 3'd4; hit = 1'b1; end   // e
            else if (u >= 12 && u < 20 && v >= 16  && v < 76)  begin sg = 3'd5; hit = 1'b1; end   // f
            else if (u >= 20 && u < 60 && v >= 76  && v < 84)  begin sg = 3'd6; hit = 1'b1; end   // g
            else if (u >= 70 && u < 78 && v >= 144 && v < 152) begin sg = 3'd7; hit = 1'b1; end   // dp
        end
    end
endmodule
/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */
/* verilator lint_on DECLFILENAME */

module vga_digits (
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] disp,                // DISPi ở [8i+7:8i]: [4:0] mã, [7] chấm (display-spec §2)
    input  wire [7:0]  dim,                 // bit i = 1: chữ số i đang ở nửa "tắt" của nháy → chỉ vết mờ
    output reg         hsync,               // tích cực thấp
    output reg         vsync,
    output reg  [11:0] rgb                  // R[11:8] G[7:4] B[3:0]
);
    reg        pe;                          // clock enable pixel
    reg  [9:0] hc, vc;

    always @(posedge clk) begin
        if (rst) begin
            pe <= 1'b0;
            hc <= 10'd0;
            vc <= 10'd0;
        end else begin
            pe <= ~pe;
            if (pe) begin
                if (hc == 10'd799) begin
                    hc <= 10'd0;
                    vc <= (vc == 10'd524) ? 10'd0 : vc + 10'd1;
                end else begin
                    hc <= hc + 10'd1;
                end
            end
        end
    end

    wire [2:0] ci, sg;
    wire       hit;
    vga_map u_map (.x(hc), .y(vc), .ci(ci), .sg(sg), .hit(hit));

    wire [7:0] cur = disp[8*ci +: 8];
    wire [6:0] segs;                        // gfedcba
    char_rom u_rom (.code(cur[4:0]), .seg(segs));
    wire on = (sg == 3'd7 ? cur[7] : segs[sg]) && !dim[ci];

    always @(posedge clk) begin
        if (rst) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
            rgb   <= 12'h000;
        end else if (pe) begin
            hsync <= !(hc >= 10'd656 && hc < 10'd752);
            vsync <= !(vc >= 10'd490 && vc < 10'd492);
            rgb   <= !hit ? 12'h000 : on ? 12'hFFF : 12'h222;   // hit chỉ có trong vùng hiện (y < 320, x < 640)
        end
    end
    wire unused_ok = &{1'b0, cur[6:5]};
endmodule
