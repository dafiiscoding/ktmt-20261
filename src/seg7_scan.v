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

    localparam G_STEP = (G_SLOT - G_BLANK) / 15;
    localparam CW = $clog2(G_SLOT);
    localparam JW = (G_DIGITS > 1) ? $clog2(G_DIGITS) : 1;

    reg [CW-1:0] c;
    reg [JW-1:0] j;
    reg [8:0]    bcnt;

    always @(posedge clk) begin
        if (rst) begin
            c    <= {CW{1'b0}};
            j    <= {JW{1'b0}};
            bcnt <= 9'd0;
        end else begin
            if (c == G_SLOT - 1) begin
                c <= {CW{1'b0}};
                j <= (j == G_DIGITS - 1) ? {JW{1'b0}} : j + 1'b1;
            end else begin
                c <= c + 1'b1;
            end

            if (blink_restart)
                bcnt <= 9'd0;
            else if (tick_ms)
                bcnt <= (bcnt == 9'd499) ? 9'd0 : bcnt + 9'd1;
        end
    end

    /* verilator lint_off UNUSEDSIGNAL */
    // giữ đoạn cũ trong khoảng tắt: anode cũ (transistor) tắt chậm vẫn hiện đúng chữ số của nó (E4′, display-spec §4)
    wire [JW-1:0] js = (c < G_BLANK) ? ((j == 0) ? G_DIGITS - 1 : j - 1'b1) : j;
    wire [7:0] cur = disp[8*js +: 8];   // [6:5] không dùng (display-spec §2)
    /* verilator lint_on UNUSEDSIGNAL */
    wire [6:0] rom_seg;
    char_rom u_rom (.code(cur[4:0]), .seg(rom_seg));

    assign blink_ph = (bcnt >= 9'd250);
    wire blink_off = blink_mask[j] && blink_ph;
    wire lit = (c >= G_BLANK) && (c < G_BLANK + bright * G_STEP) && !blink_off;

    wire [G_DIGITS-1:0] an_hi = lit ? ({{(G_DIGITS-1){1'b0}}, 1'b1} << j) : {G_DIGITS{1'b0}};

    assign an  = (G_AN_ACTIVE_LOW  != 0) ? ~an_hi   : an_hi;
    assign seg = (G_SEG_ACTIVE_LOW != 0) ? ~rom_seg : rom_seg;
    assign dp  = (G_SEG_ACTIVE_LOW != 0) ? ~cur[7]  : cur[7];
endmodule
/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */
