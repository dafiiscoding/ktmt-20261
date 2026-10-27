// rtc_bcd.v — RTC đếm thẳng bằng chữ số BCD (ms → giây → phút → giờ), để đo fmt_hw (CPU khỏi chia)
// Gói E7 · chủ: TV5 · spec: timer-spec.md §8, mmio-map.md §3 (RTC_BCD −104), plan §8.1 hàng 4
// Code do Claude viết theo yêu cầu Long (26/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// RTC_BCD [31:30] chục giờ · [29:26] đơn vị giờ · [25:23] chục phút · [22:19] đơn vị phút · [18:16] chục giây
//         [15:12] đơn vị giây · [11:8] trăm ms · [7:4] chục ms · [3:0] đơn vị ms. Ghi: nạp ngay (thắng tick cùng chu kỳ).
// Độc lập với RTC nhị phân (không theo ARM). Mỗi chữ số so "≥ giá trị cuối" thay vì "=": ghi giá trị sai (vd. 0xF)
// thì lần tăng kế tiếp tự về 0 và nhớ sang hàng trên, không kẹt.
//
// ĐỌC NHANH: đồng hồ kiểu cơ học: mỗi chữ số là 1 bánh xe nhỏ. Bánh đơn vị ms quay 0..9, quay hết thì
// đẩy bánh chục ms nhích 1, cứ thế lên giây, phút, giờ (giống đồng hồ cơ có nhiều bánh răng).
// Khối này là bản "so sánh cách làm": giờ được đếm sẵn bằng chữ số thập phân, nên CPU không phải chia
// cho 10 nhiều lần mới có số để hiện (chia tốn 32 chu kỳ mỗi lần). Báo cáo mục 3.4 đo xem cách này đáng bao nhiêu.
module rtc_bcd (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick_ms,         // mỗi xung = trôi qua 1 ms
    input  wire [7:0]  bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output reg  [31:0] bus_rdata
);
    localparam A_BCD = 8'h98;           // −104

    reg [1:0] h10;  reg [3:0] h1;       // chục giờ (0..2), đơn vị giờ
    reg [2:0] m10;  reg [3:0] m1;       // chục phút (0..5), đơn vị phút
    reg [2:0] s10;  reg [3:0] s1;       // chục giây (0..5), đơn vị giây
    reg [3:0] c, d, u;                  // trăm, chục, đơn vị ms
    wire [31:0] v = {h10, h1, m10, m1, s10, s1, c, d, u};   // ghép tất cả thành 1 số để CPU đọc

    // nhớ: hàng i tràn khi chính nó ở giá trị cuối và mọi hàng thấp hơn cũng tràn
    // (ví dụ giây đơn vị tràn khi nó = 9 VÀ ms đã tràn hết 999 → 000)
    wire cu  = u  >= 4'd9;
    wire cd  = cu  && d  >= 4'd9;
    wire cc  = cd  && c  >= 4'd9;
    wire cs1 = cc  && s1 >= 4'd9;
    wire cs10 = cs1 && s10 >= 3'd5;     // chục giây chỉ tới 5 (59 giây → 0)
    wire cm1 = cs10 && m1 >= 4'd9;
    wire cm10 = cm1 && m10 >= 3'd5;     // chục phút chỉ tới 5
    wire h_end = (h10 >= 2'd2 && h1 >= 4'd3) || h1 >= 4'd9;      // 23 → 00, x9 → (x+1)0

    always @(posedge clk) begin
        if (rst) begin
            {h10, h1, m10, m1, s10, s1, c, d, u} <= 32'd0;
            bus_rdata <= 32'd0;
        end else begin
            if (bus_we && bus_addr == A_BCD) begin
                {h10, h1, m10, m1, s10, s1, c, d, u} <= bus_wdata;     // CPU đặt giờ: nạp ngay
            end else if (tick_ms) begin
                // mỗi hàng chỉ nhích khi hàng thấp hơn vừa tràn; tràn thì về 0
                u <= cu ? 4'd0 : u + 4'd1;
                if (cu)   d  <= cd  ? 4'd0 : d + 4'd1;
                if (cd)   c  <= cc  ? 4'd0 : c + 4'd1;
                if (cc)   s1 <= cs1 ? 4'd0 : s1 + 4'd1;
                if (cs1)  s10 <= cs10 ? 3'd0 : s10 + 3'd1;
                if (cs10) m1 <= cm1 ? 4'd0 : m1 + 4'd1;
                if (cm1)  m10 <= cm10 ? 3'd0 : m10 + 3'd1;
                if (cm10) begin
                    // giờ có 2 chữ số nên xử lý riêng: 23 → 00; x9 → (x+1)0; còn lại cộng 1 vào đơn vị giờ
                    if (h10 >= 2'd2 && h1 >= 4'd3) begin h10 <= 2'd0;  h1 <= 4'd0; end
                    else if (h_end)               begin h10 <= h10 + 2'd1;  h1 <= 4'd0; end
                    else                          h1 <= h1 + 4'd1;
                end
            end
            if (bus_re) bus_rdata <= (bus_addr == A_BCD) ? v : 32'd0;
        end
    end
endmodule
