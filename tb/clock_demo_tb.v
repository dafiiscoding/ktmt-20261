// clock_demo_tb.v — đồng hồ phần cứng thuần, CHƯA có CPU (bước đệm trước tầng 1).
// timebase (G_N = 50) → rtc → [tb đóng vai firmware qua bus MMIO] → display_ctrl → screen_dump (màn ảo).
// Kịch bản: đặt 23:59:55 ngày 02/10/2026 (day 9771, Thứ Sáu) → nháy giờ 1,2 s như chế độ SET → chạy qua
// nửa đêm tới 00:00:05 ngày 03/10 (Thứ Bảy). Xem ảnh: python tools/screen.py work/screen_clock.log
// Phần "firmware" ở đây là mã tb tạm; khi có CPU G1 thì fw/main.s làm việc này (B7).
`timescale 1ns/1ps
module clock_demo_tb;
    localparam A_MS = 8'h04, A_SHADOW = 8'h08, A_SET_MS = 8'h0C, A_SET_DAY = 8'h10, A_CTRL = 8'h14;
    localparam A_DISP0 = 8'h5C, A_BLINK = 8'h7C;

    reg         clk = 0, rst = 1, bus_we = 0, bus_re = 0;
    reg  [7:0]  bus_addr = 0;
    reg  [31:0] bus_wdata = 0;
    wire [31:0] rd_rtc, rd_disp;
    wire [31:0] bus_rdata = rd_rtc | rd_disp;     // tạm thay bộ giải mã C4
    wire        tick_ms, tick_1s, loading;
    wire [26:0] ms;
    wire [15:0] day;
    wire [2:0]  dow;
    wire [7:0]  an;
    wire [6:0]  seg;
    wire        dp;

    timebase #(.G_N(50)) u_tb (.clk(clk), .rst(rst), .clr(1'b0), .en(1'b1), .cal(32'sd0), .tick(tick_ms));
    rtc u_rtc (.clk(clk), .rst(rst), .tick_ms(tick_ms), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
               .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_rtc),
               .ms(ms), .day(day), .dow(dow), .tick_1s(tick_1s), .loading(loading));
    display_ctrl #(.G_SLOT(40), .G_BLANK(4)) u_disp (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_disp), .an(an), .seg(seg), .dp(dp));
    screen_dump #(.G_DIGITS(8), .G_SLOT(40), .FILE("work/screen_clock.log")) u_dump (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .an(an), .seg(seg), .dp(dp));

    always #10 clk = ~clk;

    integer fd, c, r, i, n, nerr, nline, nsec, last_s;
    reg [8*200:1] rest;
    reg [31:0] f_ms, g [0:7], rv, rsh, now_ms;
    reg [63:0] shown, want;
    reg [6:0]  golden [0:31];
    reg [31:0] e_code, e_seg;
    reg        saw_blink_off, blinking;

    task check(input cond, input [8*40:1] what);
        begin
            n = n + 1;
            if (!cond) begin
                nerr = nerr + 1;
                if (nerr <= 10) $display("loi %0s: ms=%0d day=%0d dow=%0d", what, ms, day, dow);
            end
        end
    endtask

    // TIME 24 h  `__HH.MM.SS` (display-spec §8) → {DISP7, …, DISP0}
    function [63:0] fmt24(input [31:0] t);
        reg [31:0] h, m, s;
        reg [7:0]  h1, h0, m1, m0, s1, s0;   // ép 8 bit trước khi ghép
        begin
            h = t / 3600000; m = (t / 60000) % 60; s = (t / 1000) % 60;
            h1 = h / 10; h0 = h % 10; m1 = m / 10; m0 = m % 10; s1 = s / 10; s0 = s % 10;
            fmt24 = {8'h1A, 8'h1A, h1, h0 | 8'h80, m1, m0 | 8'h80, s1, s0};
        end
    endfunction

    task wr(input [7:0] a, input [31:0] d);
        begin @(negedge clk); bus_addr = a; bus_wdata = d; bus_we = 1; @(negedge clk); bus_we = 0; end
    endtask
    task rd(input [7:0] a, output [31:0] d);
        begin @(negedge clk); bus_addr = a; bus_re = 1; @(negedge clk); bus_re = 0; d = bus_rdata; end
    endtask
    task wait_ms(input integer k);
        begin repeat (k) @(posedge tick_ms); end
    endtask

    // "firmware" 1 lượt: đọc giờ, nếu khác màn đang hiện thì ghi 8 ô
    task fw_update;
        begin
            rd(A_MS, now_ms); rd(A_SHADOW, rsh);
            want = fmt24(now_ms);
            if (want !== shown) begin
                for (i = 0; i < 8; i = i + 1) wr(A_DISP0 + 4 * i, want[8*i +: 8]);
                shown = want;
            end
        end
    endtask

    // ảnh màn ảo: theo dõi mỗi lần screen_dump ghi ảnh mới
    always @(u_dump.nframes) if (u_dump.lit == 8'hCF) saw_blink_off = 1;   // 2 chữ số giờ tắt

    initial begin
        n = 0; nerr = 0; saw_blink_off = 0; shown = {8{8'h1A}};

        // ---- hàm định dạng của tb khớp golden fmt_time.txt (cột TIME24)
        fd = $fopen("tb/vectors/fmt_time.txt", "r");
        nline = 0;
        while (!$feof(fd)) begin
            c = $fgetc(fd);
            if (c == "#" || c == "\n") r = $fgets(rest, fd);
            else if (c != -1) begin
                r = $ungetc(c, fd);
                r = $fscanf(fd, "%d | %h %h %h %h %h %h %h %h", f_ms, g[7], g[6], g[5], g[4], g[3], g[2], g[1], g[0]);
                r = $fgets(rest, fd);
                check(fmt24(f_ms) == {g[7][7:0], g[6][7:0], g[5][7:0], g[4][7:0], g[3][7:0], g[2][7:0], g[1][7:0], g[0][7:0]},
                      "fmt24 vs fmt_time.txt");
                nline = nline + 1;
            end
        end
        $fclose(fd);
        check(nline > 0, "doc duoc fmt_time.txt");
        fd = $fopen("tb/vectors/seg7.txt", "r");
        while (!$feof(fd)) begin
            c = $fgetc(fd);
            if (c == "#" || c == "\n") r = $fgets(rest, fd);
            else if (c != -1) begin
                r = $ungetc(c, fd);
                r = $fscanf(fd, "%h %h\n", e_code, e_seg);
                golden[e_code[4:0]] = e_seg[6:0];
            end
        end
        $fclose(fd);

        repeat (3) @(negedge clk);
        rst = 0;
        wait_ms(300);                                  // 0,3 s màn trống sau reset

        // ---- đặt giờ 23:59:55.000, 02/10/2026 (day 9771), Thứ Sáu (dow 5)
        wr(A_SET_MS, 23 * 3600000 + 59 * 60000 + 55 * 1000);
        wr(A_SET_DAY, {13'd0, 3'd5, 16'd9771});
        wr(A_CTRL, 1);
        rv = 1;
        while (rv[0]) rd(A_CTRL, rv);                  // chờ nạp xong
        fw_update;
        wr(A_BLINK, 8'h30);                            // chế độ SET: nháy 2 chữ số giờ
        blinking = 1;

        // ---- chạy: mỗi 20 ms "firmware" cập nhật màn; sau 1,2 s thôi nháy
        nsec = 0; last_s = -1;
        while (!(rsh[15:0] == 9772 && now_ms >= 5000)) begin
            fw_update;
            if ((now_ms / 1000) != last_s) begin nsec = nsec + 1; last_s = now_ms / 1000; end
            if (blinking && now_ms >= 86396200) begin wr(A_BLINK, 8'h00); blinking = 0; end   // 23:59:56.2
            wait_ms(20);
        end
        wait_ms(20);

        // ---- kiểm
        check(nsec == 11, "thay du 11 giay 55..59, 00..05");
        check(rsh == {13'd0, 3'd6, 16'd9772}, "qua nua dem: 03/10 Thu Bay");
        check(saw_blink_off, "man ao thay gio nhay");
        for (i = 0; i < 8; i = i + 1)
            check(u_dump.last[8*i +: 8] == {shown[8*i + 7], golden[shown[8*i +: 5]]}, "man ao khop DISP");
        check(u_dump.lit_last == 8'hFF, "het nhay: 8 chu so sang");
        $display("man ao: %0d anh, ket thuc o ms_of_day = %0d", u_dump.nframes, now_ms);

        if (nerr == 0) $display("PASS clock_demo_tb %0d", n);
        else $display("FAIL clock_demo_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
