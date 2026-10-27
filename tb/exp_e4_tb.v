// exp_e4_tb.v — thí nghiệm E4′ (chủ TV4): bóng ma LED 7 đoạn quanh ranh giới khe, 3 G_SLOT × có/không G_BLANK.
// Code do Claude viết theo yêu cầu Long (26/10/2026); TV4 chạy lại và đọc hiểu.
//
// RTL đổi anode và đoạn ở CÙNG cạnh clock → mô phỏng thuần không có bóng ma. Bóng ma thật do transistor kéo anode
// tắt chậm: anode cũ còn dẫn T_OFF chu kỳ sau khi tín hiệu về 0, lúc đó chân đoạn đã mang mẫu của chữ số mới.
// Mô hình: anode_vl[i] = 1 khi an[i] = 1 hoặc an[i] vừa tắt < T_OFF chu kỳ (giả định, không đo từ board).
// Đo 200 000 chu kỳ (+slow: 800 000 = 2 khung của G_SLOT = 50 000): on = số (chu kỳ × chữ số) anode vật lý dẫn; ghost = số chu kỳ trong đó có đoạn
// sáng mà chữ số đang dẫn không có (seg & ~mẫu đúng ≠ 0). Tỉ lệ ghost / on ≈ độ sáng bóng ma so với đoạn thật.
// KẾT QUẢ 26/10 (RTL cũ, đoạn đổi ở c = 0): bóng ma mỗi ranh giới = T_OFF − gap, gap = G_SLOT − G_BLANK − 15·G_STEP
// (phần dư PWM cuối khe, 5–10 chu kỳ) → G_BLANK KHÔNG chống được, vì khoảng tắt chỉ làm anode MỚI bật muộn.
// SỬA 27/10 (Long chọn A): đoạn đổi ở c = G_BLANK → bóng ma = max(0, T_OFF − gap − G_BLANK). tb kiểm công thức này.
// +csv=<file>: ghi dạng sóng quanh ranh giới khe 0 → 1 của G_SLOT = 3 125, T_OFF = 50 (vẽ bằng tools/exp_e4.py).
`timescale 1ns/1ps
module ghost_meter #(parameter G_SLOT = 50000, parameter G_BLANK = 0, parameter T_OFF = 50) (
    input  wire clk,
    input  wire rst
);
    // 8 chữ số khác nhau: 1 2 3 4 5 6 7 8 (mã = giá trị, char_rom)
    wire [63:0] disp = {8'h08, 8'h07, 8'h06, 8'h05, 8'h04, 8'h03, 8'h02, 8'h01};
    wire [7:0]  an;
    wire [6:0]  seg;
    wire        dp, bph;
    seg7_scan #(.G_DIGITS(8), .G_SLOT(G_SLOT), .G_BLANK(G_BLANK)) u (.clk(clk), .rst(rst), .tick_ms(1'b0), .disp(disp),
        .blink_mask(8'd0), .blink_restart(1'b0), .bright(4'd15), .an(an), .seg(seg), .dp(dp), .blink_ph(bph));

    wire [6:0] pat [0:7];               // mẫu đúng của chữ số i (lấy từ char_rom, không chép tay)
    genvar g;
    generate for (g = 0; g < 8; g = g + 1) begin : rom
        char_rom r (.code(disp[8*g +: 5]), .seg(pat[g]));
    end endgenerate

    localparam GAP = G_SLOT - G_BLANK - 15 * ((G_SLOT - G_BLANK) / 15);
    integer i, left [0:7];
    integer on, ghost;
    reg [7:0] avl;
    always @(*) for (i = 0; i < 8; i = i + 1) avl[i] = an[i] || left[i] > 0;
    initial begin on = 0; ghost = 0; for (i = 0; i < 8; i = i + 1) left[i] = 0; end
    always @(posedge clk) if (!rst) begin
        for (i = 0; i < 8; i = i + 1) begin
            if (avl[i]) begin
                on = on + 1;
                if ((seg & ~pat[i]) != 7'd0) ghost = ghost + 1;
            end
            left[i] = an[i] ? T_OFF : (left[i] > 0 ? left[i] - 1 : 0);
        end
    end
endmodule

module exp_e4_tb;
    reg clk = 0, rst = 1;
    always #10 clk = ~clk;

    ghost_meter #(50000, 0,   50)  m0 (clk, rst);
    ghost_meter #(50000, 100, 50)  m1 (clk, rst);
    ghost_meter #(12500, 0,   50)  m2 (clk, rst);
    ghost_meter #(12500, 100, 50)  m3 (clk, rst);
    ghost_meter #(3125,  0,   50)  m4 (clk, rst);
    ghost_meter #(3125,  100, 50)  m5 (clk, rst);
    ghost_meter #(3125,  0,   150) m6 (clk, rst);
    ghost_meter #(3125,  100, 150) m7 (clk, rst);

    integer n, nerr, cyc, fd, ncyc;
    reg [8*256:1] fcsv;

    // số ranh giới khe k·G_SLOT (1 ≤ k < ncyc / G_SLOT) có bóng ma: trừ ranh giới chữ số 8 → 1 (k chia hết 8),
    // vì 8 sáng đủ 7 đoạn nên mẫu của 1 không có đoạn nào thừa
    task show(input integer s, input integer b, input integer t, input integer gap, input integer on, input integer gh);
        integer nb, e;
        begin
            nb = (ncyc / s - 1) - (ncyc / s - 1) / 8;
            e = (t > gap + b ? t - gap - b : 0) * nb;
            n = n + 1;
            if (gh != e) begin nerr = nerr + 1; $display("loi G_SLOT=%0d G_BLANK=%0d: ghost %0d, cong thuc %0d", s, b, gh, e); end
            $display("E4 G_SLOT=%0d G_BLANK=%0d T_OFF=%0d gap=%0d on=%0d ghost=%0d ti_le=%0.3f%%", s, b, t, gap, on, gh,
                     100.0 * gh / on);
        end
    endtask
    task check(input cond, input [8*64:1] what);
        begin n = n + 1; if (!cond) begin nerr = nerr + 1; $display("loi %0s", what); end end
    endtask

    initial begin
        n = 0; nerr = 0; cyc = 0; fd = 0;
        if ($value$plusargs("csv=%s", fcsv)) begin
            fd = $fopen(fcsv, "w");
            $fwrite(fd, "cyc,blank,an0,an1,vl0,vl1,ghost0\n");
        end
        repeat (2) @(negedge clk);
        rst = 0;
        ncyc = $test$plusargs("slow") ? 800000 : 200000;
        repeat (ncyc) begin
            @(negedge clk);
            cyc = cyc + 1;
            if (fd != 0 && cyc > 3125 - 20 && cyc <= 3125 + 180) begin
                $fwrite(fd, "%0d,0,%0d,%0d,%0d,%0d,%0d\n", cyc, m4.an[0], m4.an[1], m4.avl[0], m4.avl[1],
                        m4.avl[0] && (m4.seg & ~m4.pat[0]) != 0);
                $fwrite(fd, "%0d,1,%0d,%0d,%0d,%0d,%0d\n", cyc, m5.an[0], m5.an[1], m5.avl[0], m5.avl[1],
                        m5.avl[0] && (m5.seg & ~m5.pat[0]) != 0);
            end
        end
        if (fd != 0) $fclose(fd);
        show(50000, 0, 50, m0.GAP, m0.on, m0.ghost);   show(50000, 100, 50, m1.GAP, m1.on, m1.ghost);
        show(12500, 0, 50, m2.GAP, m2.on, m2.ghost);   show(12500, 100, 50, m3.GAP, m3.on, m3.ghost);
        show(3125, 0, 50, m4.GAP, m4.on, m4.ghost);    show(3125, 100, 50, m5.GAP, m5.on, m5.ghost);
        show(3125, 0, 150, m6.GAP, m6.on, m6.ghost);   show(3125, 100, 150, m7.GAP, m7.on, m7.ghost);
        check(m1.ghost == 0 && m3.ghost == 0 && m5.ghost == 0 && m4.ghost > 0, "G_BLANK = 100 >= T_OFF = 50 phai het bong ma");
        if (nerr == 0) $display("PASS exp_e4_tb %0d", n);
        else           $display("FAIL exp_e4_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
