// seg7_scan.v — quét LED 7 đoạn: khe từng chữ số, khoảng tắt chống bóng ma, PWM độ sáng, nháy 2 Hz
// Gói D1 · chủ: TV4 · spec: display-spec.md §2 (Display RAM), §4 (quét)
// Code do Claude viết theo yêu cầu Long (01/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// Khe j dài G_SLOT chu kỳ, đếm c = 0 .. G_SLOT-1:
//   c <  G_BLANK                       : mọi anode tắt, chân đoạn vẫn giữ chữ số j−1 (đổi sang j ở c = G_BLANK)
//   c <  G_BLANK + BRIGHT × G_STEP     : anode j bật (trừ khi chữ số j đang ở nửa "tắt" của nháy)
//   còn lại                            : tắt (PWM)
// Nháy: bcnt đếm tick_ms 0..499, tắt khi bcnt >= 250; ghi BLINK_MASK (blink_restart) → bcnt = 0.
// Chỉ làm G_MUX = 1 (các chữ số dùng chung chân đoạn); G_MUX = 0 cần chân đoạn riêng mỗi chữ số,
// đồ án không dùng (display-spec.md §4) nên mô phỏng báo lỗi nếu đặt 0.
// So bộ đếm hẹp (c, j) với hằng parameter 32 bit là cố ý → tắt cảnh báo độ rộng của Verilator.
//
// ĐỌC NHANH: 8 chữ số LED dùng CHUNG 7 chân đoạn (để tiết kiệm chân). Nên mỗi lúc chỉ bật được 1 chữ số:
// chân đoạn hiện hình chữ số j, anode j bật, các anode khác tắt. Rồi chuyển sang chữ số kế, đủ nhanh
// (mỗi chữ số được bật lại 125 lần/giây) thì mắt thấy cả 8 sáng cùng lúc, đó là "lưu ảnh võng mạc".
// Mỗi khe (slot) của 1 chữ số chia làm 3 đoạn theo bộ đếm c:
//   [0, G_BLANK)        khoảng tắt hết, để anode cũ kịp tắt (chống bóng ma, xem dòng js bên dưới)
//   [G_BLANK, ...)      anode bật một lúc, dài bao nhiêu tùy độ sáng bright (PWM: bật lâu = sáng, ngắn = mờ)
//   phần còn lại        tắt
// Nháy: ô nào có bit trong blink_mask thì tắt trong nửa sau của chu kỳ 500 ms (nháy 2 lần mỗi giây).
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module seg7_scan #(
    parameter G_DIGITS         = 8,
    parameter G_MUX            = 1,
    parameter G_SLOT           = 50000,   // 1 ms ở 50 MHz
    parameter G_BLANK          = 100,     // 2 µs
    parameter G_AN_ACTIVE_LOW  = 0,
    parameter G_SEG_ACTIVE_LOW = 0
) (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    tick_ms,
    input  wire [8*G_DIGITS-1:0]   disp,          // DISPi ở [8i+7:8i]: [4:0] mã, [7] chấm
    input  wire [G_DIGITS-1:0]     blink_mask,
    input  wire                    blink_restart, // xung khi CPU ghi BLINK_MASK
    input  wire [3:0]              bright,
    output wire [G_DIGITS-1:0]     an,
    output wire [6:0]              seg,           // gfedcba
    output wire                    dp,
    output wire                    blink_ph       // 1 = nửa "tắt" của nháy (VGA dùng chung pha, D5)
);
`ifndef SYNTHESIS
    initial if (G_MUX != 1) $display("ERROR seg7_scan: chi ho tro G_MUX = 1");
`endif

    localparam G_STEP = (G_SLOT - G_BLANK) / 15;     // độ dài bật ứng với 1 mức sáng (có 15 mức)
    localparam CW = $clog2(G_SLOT);                  // số bit của bộ đếm c
    localparam JW = (G_DIGITS > 1) ? $clog2(G_DIGITS) : 1;   // số bit của chỉ số chữ số j

    reg [CW-1:0] c;       // vị trí trong khe hiện tại
    reg [JW-1:0] j;       // đang quét chữ số thứ mấy (0..7)
    reg [8:0]    bcnt;    // đếm ms cho nháy: 0..499

    always @(posedge clk) begin
        if (rst) begin
            c    <= {CW{1'b0}};
            j    <= {JW{1'b0}};
            bcnt <= 9'd0;
        end else begin
            if (c == G_SLOT - 1) begin
                // hết khe: sang chữ số kế, vòng về 0 sau chữ số cuối
                c <= {CW{1'b0}};
                j <= (j == G_DIGITS - 1) ? {JW{1'b0}} : j + 1'b1;
            end else begin
                c <= c + 1'b1;
            end

            if (blink_restart)
                bcnt <= 9'd0;      // vừa ghi mặt nạ nháy: bắt đầu nháy lại từ pha "sáng"
            else if (tick_ms)
                bcnt <= (bcnt == 9'd499) ? 9'd0 : bcnt + 9'd1;
        end
    end

    /* verilator lint_off UNUSEDSIGNAL */
    // giữ đoạn cũ trong khoảng tắt: anode cũ (transistor) tắt chậm vẫn hiện đúng chữ số của nó (E4′, display-spec §4)
    // Giải thích "bóng ma": transistor điều khiển anode tắt không tức thì. Nếu vừa chuyển sang chữ số mới
    // mà chân đoạn đã đổi hình ngay, anode cũ còn sáng mờ sẽ hiện luôn hình MỚI (hình ma của chữ số bên cạnh).
    // Cách chữa: trong khoảng tắt (c < G_BLANK) vẫn xuất hình của chữ số TRƯỚC (j - 1), tới khi hết khoảng tắt
    // mới đổi hình, đúng lúc anode mới bật. Cụ thể ở đây: js = chữ số dùng để lấy hình.
    wire [JW-1:0] js = (c < G_BLANK) ? ((j == 0) ? G_DIGITS - 1 : j - 1'b1) : j;
    wire [7:0] cur = disp[8*js +: 8];   // [6:5] không dùng (display-spec §2)
    /* verilator lint_on UNUSEDSIGNAL */
    wire [6:0] rom_seg;
    char_rom u_rom (.code(cur[4:0]), .seg(rom_seg));     // đổi mã ký tự thành 7 đoạn

    assign blink_ph = (bcnt >= 9'd250);                  // nửa sau của 500 ms = pha "tắt"
    wire blink_off = blink_mask[j] && blink_ph;          // chữ số j đang cần nháy và đang ở pha tắt
    wire lit = (c >= G_BLANK) && (c < G_BLANK + bright * G_STEP) && !blink_off;   // anode j có được bật lúc này không

    // one-hot: chỉ bit j = 1 khi lit (mỗi lúc chỉ 1 chữ số được bật)
    wire [G_DIGITS-1:0] an_hi = lit ? ({{(G_DIGITS-1){1'b0}}, 1'b1} << j) : {G_DIGITS{1'b0}};

    // nếu mạch LED thật bật bằng mức thấp thì đảo lại; mô phỏng mặc định mức cao = sáng
    assign an  = (G_AN_ACTIVE_LOW  != 0) ? ~an_hi   : an_hi;
    assign seg = (G_SEG_ACTIVE_LOW != 0) ? ~rom_seg : rom_seg;
    assign dp  = (G_SEG_ACTIVE_LOW != 0) ? ~cur[7]  : cur[7];     // bit 7 của ô là dấu chấm thập phân
endmodule
/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */
