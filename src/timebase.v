// timebase.v — bộ chia phân số có hiệu chỉnh CAL: sinh tick mỗi ms
// Gói E1 · chủ: TV5 · spec: timer-spec.md §2 (công thức len_k, quy ước dấu, clr/en)
// Code do Claude viết theo yêu cầu Long (01/10/2026); chủ gói đọc hiểu để vấn đáp.
//
//   s_k      = frac_k + CAL              (CAL lấy mẫu ở chu kỳ đầu của ms thứ k)
//   len_k    = G_N + (s_k >>> 16)        (dịch số học = floor)
//   frac_k+1 = s_k[15:0]
// tick = 1 đúng 1 chu kỳ: chu kỳ cuối (cnt = len_k - 1) của mỗi ms, chỉ khi en = 1.
// CAL > 0 → ms dài hơn → đồng hồ chậm lại. 1 ppm = 3 276,8 đơn vị CAL.
//
// ĐỌC NHANH: khối này đếm chu kỳ clock 50 MHz để "gõ nhịp" mỗi 1 ms (50 000 chu kỳ).
// Vấn đề: thạch anh thật hơi nhanh/chậm vài chục phần triệu (ppm). Nếu cứ đếm đúng 50 000 thì
// đồng hồ lệch dần. Cách sửa: thỉnh thoảng cho 1 ms dài thêm 1 chu kỳ (hoặc ngắn bớt 1).
// Ta giữ một "phần lẻ" frac (16 bit, đơn vị 1/65 536 chu kỳ). Mỗi ms cộng CAL vào frac;
// phần nguyên tràn ra (s_k >>> 16) chính là số chu kỳ cần thêm cho ms đó. Giống cách trả
// tiền lẻ: mỗi lần dư 0,3 xu thì cộng dồn, đủ 1 xu mới trả thêm 1 xu.
// Ví dụ +50 ppm nghĩa là CAL = 163 840 = 2,5 chu kỳ mỗi ms: các ms dài 50 002 và 50 003 xen kẽ.
module timebase #(
    parameter G_N = 50000              // chu kỳ / ms (mô phỏng: 50)
) (
    input  wire               clk,
    input  wire               rst,
    input  wire               clr,     // cnt ← 0, frac ← 0
    input  wire               en,      // 0 = tạm dừng, giữ nguyên cnt và frac
    input  wire signed [31:0] cal,     // số hiệu chỉnh, có dấu (âm = ms ngắn lại = đồng hồ nhanh lên)
    output wire               tick     // xung 1 chu kỳ ở cuối mỗi ms
);
    reg        [31:0] cnt;             // đang ở chu kỳ thứ mấy của ms hiện tại
    reg        [15:0] frac;            // phần lẻ tích lũy, đơn vị 1/65 536 chu kỳ
    reg signed [33:0] s_q;             // s_k đã chốt của ms đang chạy

    // ở chu kỳ đầu ms (cnt = 0) dùng s_k tính từ CAL hiện tại, các chu kỳ sau dùng bản đã chốt
    // (chốt để đổi CAL giữa chừng một ms không làm ms đó bị tính hai kiểu).
    wire signed [33:0] s_now = $signed({18'd0, frac}) + $signed({{2{cal[31]}}, cal});
    wire signed [33:0] s_cur = (cnt == 32'd0) ? s_now : s_q;
    // ">>>" là dịch số học (giữ dấu): CAL âm thì phần nguyên âm, ms ngắn hơn G_N. Dịch logic ">>" sẽ SAI ở đây.
    wire signed [33:0] len   = G_N + (s_cur >>> 16);

    // tick bật đúng ở chu kỳ cuối của ms (cnt đếm từ 0 nên cuối là len - 1)
    assign tick = en && ($signed({2'b00, cnt}) == len - 1);

    always @(posedge clk) begin
        if (rst || clr) begin
            cnt  <= 32'd0;
            frac <= 16'd0;
            s_q  <= 34'sd0;
        end else if (en) begin
            if (cnt == 32'd0)
                s_q <= s_now;          // chốt CAL ở đầu ms: đổi CAL giữa ms chỉ có tác dụng từ ms sau
            if (tick) begin
                cnt  <= 32'd0;         // hết ms: quay về đếm lại từ 0
                frac <= s_cur[15:0];   // giữ lại phần lẻ cho ms sau
            end else begin
                cnt  <= cnt + 32'd1;
            end
        end
    end
endmodule
