// screen_dump.v — "màn hình ảo" thay board (gói D7, display-spec / goi-viec D7).
// Chỉ nhìn CHÂN anode + đoạn (không đọc thanh ghi). Sau mỗi vòng quét 8 khe, nếu ảnh khác lần trước
// thì ghi 1 dòng vào file:   t_ms  S7 S6 … S0  LIT
//   Si  = {dp, gfedcba} của chữ số i lúc anode i sáng (hex), 00 nếu cả vòng không sáng
//   LIT = bit i = 1 nếu chữ số i có sáng trong vòng đó (0 = đang tắt do nháy / BRIGHT = 0)
// Xem ảnh: python tools/screen.py <file log>
// Code do Claude viết theo yêu cầu Long (02/10/2026).
module screen_dump #(
    parameter G_DIGITS = 8,
    parameter G_SLOT   = 40,
    parameter FILE     = "work/screen.log"
) (
    input wire                clk,
    input wire                rst,
    input wire                tick_ms,
    input wire [G_DIGITS-1:0] an,      // mức cao = sáng
    input wire [6:0]          seg,
    input wire                dp
);
    localparam ROUND = G_SLOT * G_DIGITS;

    integer fd, cyc, t_ms, i, nframes;
    reg [8*G_DIGITS-1:0] cur, frame, last;
    reg [G_DIGITS-1:0]   lit_cur, lit, lit_last;
    reg                  have_last;
    event                round;                       // mỗi vòng quét xong (frame, lit vừa cập nhật): tb so ảnh (D7)

    initial begin
        fd = $fopen(FILE, "w");
        $fdisplay(fd, "# t_ms S7..S0 LIT  | Si = {dp,gfedcba} hex, LIT bit i = chu so i co sang");
        cyc = 0; t_ms = 0; nframes = 0; have_last = 0;
        cur = 0; lit_cur = 0; frame = 0; lit = 0; last = 0; lit_last = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            cyc = 0; cur = 0; lit_cur = 0;
        end else begin
            if (tick_ms) t_ms = t_ms + 1;
            for (i = 0; i < G_DIGITS; i = i + 1)
                if (an[i]) begin
                    cur[8*i +: 8] = {dp, seg};
                    lit_cur[i]    = 1'b1;
                end
            cyc = cyc + 1;
            if (cyc % ROUND == 0) begin
                frame = cur; lit = lit_cur;
                -> round;
                if (!have_last || frame !== last || lit !== lit_last) begin
                    $fwrite(fd, "%0d", t_ms);
                    for (i = G_DIGITS - 1; i >= 0; i = i - 1) $fwrite(fd, " %h", frame[8*i +: 8]);
                    $fwrite(fd, " %h\n", lit);
                    last = frame; lit_last = lit; have_last = 1;
                    nframes = nframes + 1;
                end
                cur = 0; lit_cur = 0;
            end
        end
    end
endmodule
