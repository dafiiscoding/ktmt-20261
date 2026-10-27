// seg7_tb.v — gói D1: D-1 (char_rom vs seg7.txt), D-2 (thứ tự anode + khoảng tắt), D-3 (BRIGHT 0/1/15),
// D-6 (đảo mức active-low); thêm nháy (D-4/D-5 ở mức module, bản đầy đủ thuộc D2).
// Mô phỏng: G_SLOT = 40, G_BLANK = 4 → G_STEP = 2. Chạy từ thư mục gốc project.
`timescale 1ns/1ps
module seg7_tb;
    localparam SLOT = 40, BLANK = 4, STEP = 2, ND = 8;

    reg          clk = 0, rst = 1, tick_ms = 0, blink_restart = 0;
    reg  [63:0]  disp;
    reg  [7:0]   blink_mask = 0;
    reg  [3:0]   bright = 15;
    wire [7:0]   an, an_l;
    wire [6:0]   seg, seg_l;
    wire         dp, dp_l;

    // D-1: ROM riêng để duyệt mọi mã
    reg  [4:0] code;
    wire [6:0] rom_seg;
    char_rom u_rom (.code(code), .seg(rom_seg));

    seg7_scan #(.G_DIGITS(ND), .G_SLOT(SLOT), .G_BLANK(BLANK)) u_hi (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .disp(disp), .blink_mask(blink_mask),
        .blink_restart(blink_restart), .bright(bright), .an(an), .seg(seg), .dp(dp));
    seg7_scan #(.G_DIGITS(ND), .G_SLOT(SLOT), .G_BLANK(BLANK),
                .G_AN_ACTIVE_LOW(1), .G_SEG_ACTIVE_LOW(1)) u_lo (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .disp(disp), .blink_mask(blink_mask),
        .blink_restart(blink_restart), .bright(bright), .an(an_l), .seg(seg_l), .dp(dp_l));

    always #10 clk = ~clk;

    reg [6:0] golden [0:31];
    integer fd, c, r, i, n, nerr, cyc, ticks, slot, cc, on_cnt, k;
    reg [8*200:1] rest;
    reg [31:0] e_code, e_seg;
    reg [7:0]  e_an, cur;
    reg        boff;
    integer    lit_per_digit [0:7];

    task check(input cond, input [8*32:1] what);
        begin
            n = n + 1;
            if (!cond) begin
                nerr = nerr + 1;
                if (nerr <= 10) $display("loi %0s: cyc=%0d slot=%0d c=%0d an=%b (can %b) seg=%h bright=%0d ticks=%0d",
                                         what, cyc, slot, cc, an, e_an, seg, bright, ticks);
            end
        end
    endtask

    // 1 chu kỳ: kiểm đầu ra theo đúng công thức display-spec §4, rồi sang chu kỳ sau.
    // cyc = số sườn lên đã qua kể từ hết reset; ticks = số tick_ms đã đếm kể từ lần restart nháy.
    task step;
        begin
            #1;
            slot = (cyc / SLOT) % ND;
            cc   = cyc % SLOT;
            cur  = disp[8*((cc < BLANK) ? (slot + ND - 1) % ND : slot) +: 8];   // đoạn đổi ở c = BLANK
            boff = blink_mask[slot] && ((ticks % 500) >= 250);
            e_an = (cc >= BLANK && cc < BLANK + bright * STEP && !boff) ? (8'd1 << slot) : 8'd0;
            check(an === e_an, "anode");
            check(seg === golden[cur[4:0]] && dp === cur[7], "doan");
            check(an_l === ~an && seg_l === ~seg && dp_l === ~dp, "active-low");
            if (an !== 0) lit_per_digit[slot] = lit_per_digit[slot] + 1;
            @(posedge clk);
            cyc = cyc + 1;
            if (blink_restart) ticks = 0;
            else if (tick_ms) ticks = ticks + 1;
            @(negedge clk);
        end
    endtask

    // chạy đúng 1 vòng 8 khe, trả số chu kỳ bật của từng chữ số
    task one_round;
        begin
            for (k = 0; k < ND; k = k + 1) lit_per_digit[k] = 0;
            repeat (SLOT * ND) step;
        end
    endtask

    initial begin
        n = 0; nerr = 0;

        // ---- D-1
        fd = $fopen("tb/vectors/seg7.txt", "r");
        if (fd == 0) begin $display("FAIL seg7_tb khong mo duoc seg7.txt"); $finish; end
        i = 0;
        while (!$feof(fd)) begin
            c = $fgetc(fd);
            if (c == "#" || c == "\n") r = $fgets(rest, fd);
            else if (c != -1) begin
                r = $ungetc(c, fd);
                r = $fscanf(fd, "%h %h\n", e_code, e_seg);
                golden[e_code[4:0]] = e_seg[6:0];
                code = e_code[4:0]; #1;
                check(rom_seg === e_seg[6:0], "D-1 char_rom");
                i = i + 1;
            end
        end
        $fclose(fd);
        check(i == 32, "D-1 du 32 ma");

        // Display RAM: 8 ký tự khác nhau, chấm ở chữ số lẻ
        for (k = 0; k < ND; k = k + 1) disp[8*k +: 8] = {k[0], 2'b00, k[4:0] + 5'd3};

        repeat (2) @(negedge clk);
        rst = 0; cyc = 0; ticks = 0;

        // ---- D-2 + D-3: BRIGHT 15 / 1 / 0 (đổi đúng ở đầu vòng)
        one_round;
        for (k = 0; k < ND; k = k + 1) check(lit_per_digit[k] == 30, "D-3 bright 15 = 30 chu ky");
        bright = 1;
        one_round;
        for (k = 0; k < ND; k = k + 1) check(lit_per_digit[k] == 2, "D-3 bright 1 = 2 chu ky");
        bright = 0;
        one_round;
        for (k = 0; k < ND; k = k + 1) check(lit_per_digit[k] == 0, "D-3 bright 0 = 0 chu ky");
        bright = 15;

        // ---- nháy: BLINK_MASK = 0x01, tick_ms mỗi 4 chu kỳ, 1 200 tick
        blink_mask = 8'h01;
        blink_restart = 1; step; blink_restart = 0;
        for (i = 0; i < 1200 * 4; i = i + 1) begin
            tick_ms = (i % 4 == 3);
            step;
        end
        tick_ms = 0;

        // D-4 biên: dừng đúng ở tick 249 / 250 / 499 / 500 rồi quét trọn 1 vòng
        blink_restart = 1; step; blink_restart = 0;
        while (ticks < 249) begin tick_ms = 1; step; end
        tick_ms = 0; one_round;
        check(lit_per_digit[0] == 30, "D-4 tick 249 con sang");
        tick_ms = 1; step; tick_ms = 0; one_round;
        check(lit_per_digit[0] == 0 && lit_per_digit[1] == 30, "D-4 tick 250 tat");
        while (ticks < 499) begin tick_ms = 1; step; end
        tick_ms = 0; one_round;
        check(lit_per_digit[0] == 0, "D-4 tick 499 van tat");
        tick_ms = 1; step; tick_ms = 0; one_round;
        check(lit_per_digit[0] == 30, "D-4 tick 500 sang lai");

        // D-5: đưa vào nửa "tắt" rồi ghi lại BLINK_MASK → sáng ngay
        while ((ticks % 500) < 250) begin tick_ms = 1; step; end
        tick_ms = 0;
        one_round;
        check(lit_per_digit[0] == 0 && lit_per_digit[1] == 30, "nua tat: chu so 0 tat, chu so 1 sang");
        blink_restart = 1; step; blink_restart = 0;
        one_round;
        check(lit_per_digit[0] == 30, "D-5 ghi BLINK_MASK -> sang lai ngay");

        if (nerr == 0) $display("PASS seg7_tb %0d", n);
        else $display("FAIL seg7_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
