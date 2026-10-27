// alarm_tb.v — gói E4 (báo thức ×4): AL-1…AL-5 (timer-spec §10) + AL-6 (goi-viec E4) + đọc lại, MINUTE ≥ 1440.
// Dùng timebase + rtc thật (G_N = 50) để có ms/dow/loading đúng như trong soc.
`timescale 1ns/1ps
module alarm_tb;
    localparam A_SET_MS = 8'h0C, A_SET_DAY = 8'h10, A_CTRL = 8'h14, A_AL0 = 8'h30, A_AL1 = 8'h34, A_AL2 = 8'h38;

    reg         clk = 0, rst = 1, bus_we = 0, bus_re = 0;
    reg  [7:0]  bus_addr = 0;
    reg  [31:0] bus_wdata = 0;
    wire [31:0] rd_rtc, rd_al;
    wire [31:0] bus_rdata = rd_rtc | rd_al;
    wire        tick_ms, tick_1s, loading, ev;
    wire [26:0] ms;
    wire [15:0] day;
    wire [2:0]  dow;

    timebase #(.G_N(50)) u_tb (.clk(clk), .rst(rst), .clr(1'b0), .en(1'b1), .cal(32'sd0), .tick(tick_ms));
    rtc u_rtc (.clk(clk), .rst(rst), .tick_ms(tick_ms), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
               .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_rtc),
               .ms(ms), .day(day), .dow(dow), .tick_1s(tick_1s), .loading(loading));
    alarm dut (.clk(clk), .rst(rst), .inc(tick_ms && !loading), .ms(ms), .dow(dow), .bus_addr(bus_addr),
               .bus_wdata(bus_wdata), .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_al), .ev(ev));

    always #10 clk = ~clk;

    integer n, nerr, nev, ninc, ev_at;
    reg [31:0] rv;

    task check(input cond, input [8*48:1] what);
        begin
            n = n + 1;
            if (!cond) begin nerr = nerr + 1; if (nerr <= 10) $display("loi %0s: ms=%0d dow=%0d nev=%0d ev_at=%0d rv=%h", what, ms, dow, nev, ev_at, rv); end
        end
    endtask
    task wr(input [7:0] a, input [31:0] d);
        begin @(negedge clk); bus_addr = a; bus_wdata = d; bus_we = 1; @(negedge clk); bus_we = 0; end
    endtask
    task rd(input [7:0] a);
        begin @(negedge clk); bus_addr = a; bus_re = 1; @(negedge clk); bus_re = 0; rv = bus_rdata; end
    endtask
    // nạp RTC, chờ nạp xong; ninc đếm số tick làm RTC tăng kể từ lúc nạp
    task set_rtc(input [26:0] t, input [2:0] d);
        begin
            wr(A_SET_MS, t); wr(A_SET_DAY, {13'd0, d, 16'd100}); wr(A_CTRL, 1);
            @(posedge loading); @(negedge clk);
            ninc = 0; nev = 0; ev_at = -1;
        end
    endtask
    function [31:0] al(input en, input [6:0] mask, input [10:0] minute);
        al = {en, mask, 13'd0, minute};
    endfunction

    always @(posedge clk) begin
        if (tick_ms && !loading) ninc = ninc + 1;
        if (ev) begin nev = nev + 1; if (ev_at < 0) ev_at = ninc; end
    end

    initial begin
        n = 0; nerr = 0; nev = 0; ninc = 0; ev_at = -1;
        repeat (3) @(negedge clk);
        rst = 0;

        // ---- AL-1: 06:59:59.990 thứ 2, ALARM0 = EN, mask thứ 2, 420 → HIT ở tick thứ 10
        wr(A_AL0, al(1, 7'b0000010, 420));
        set_rtc(25199990, 1);
        repeat (20 * 50) @(negedge clk);
        check(nev == 1 && ev_at == 10, "AL-1 su kien o tick thu 10");
        rd(A_AL0); check(rv == (al(1, 7'b0000010, 420) | 32'h0080_0000), "AL-1 doc lai: HIT = 1, cau hinh dung");

        // ---- AL-6: ghi 0 vào HIT → giữ; ghi 1 → xóa
        wr(A_AL0, al(1, 7'b0000010, 420));
        rd(A_AL0); check(rv[23] == 1, "AL-6 ghi 0 vao HIT: giu");
        wr(A_AL0, al(1, 7'b0000010, 420) | 32'h0080_0000);
        rd(A_AL0); check(rv[23] == 0, "AL-6 ghi 1 vao HIT: xoa");

        // ---- AL-2: như AL-1 nhưng mask không có thứ 2 → không kêu
        wr(A_AL0, al(1, 7'b1111101, 420) | 32'h0080_0000);
        set_rtc(25199990, 1);
        repeat (20 * 50) @(negedge clk);
        rd(A_AL0); check(nev == 0 && rv[23] == 0, "AL-2 mask khong co thu 2: khong keu");

        // ---- AL-3: MINUTE = 0, mask thứ 2, RTC 23:59:59.999 Chủ nhật → kêu ở tick qua nửa đêm (dow mới)
        wr(A_AL0, al(1, 7'b0000010, 0) | 32'h0080_0000);
        set_rtc(86399999, 0);
        repeat (5 * 50) @(negedge clk);
        check(nev == 1 && ev_at == 1 && dow == 1, "AL-3 keu o tick qua nua dem, dung dow moi");
        // mask chỉ Chủ nhật (dow cũ) → không kêu
        wr(A_AL0, al(1, 7'b0000001, 0) | 32'h0080_0000);
        set_rtc(86399999, 0);
        repeat (5 * 50) @(negedge clk);
        check(nev == 0, "AL-3 mask dow cu (CN) khong keu");

        // ---- AL-4: nạp RTC thẳng vào 07:00:00.000 → không kêu
        wr(A_AL0, al(1, 7'b0000010, 420) | 32'h0080_0000);
        set_rtc(25200000, 1);
        repeat (5 * 50) @(negedge clk);
        rd(A_AL0); check(nev == 0 && rv[23] == 0, "AL-4 nap RTC dung target: khong keu");

        // ---- AL-5: 2 báo thức cùng phút → cả hai HIT, 1 sự kiện
        wr(A_AL0, al(1, 7'b0000010, 420) | 32'h0080_0000);
        wr(A_AL1, al(1, 7'b0000010, 420));
        wr(A_AL2, al(0, 7'b0000010, 420));               // EN = 0 → không kêu
        set_rtc(25199990, 1);
        repeat (20 * 50) @(negedge clk);
        rd(A_AL0); check(rv[23] == 1, "AL-5 ALARM0 HIT");
        rd(A_AL1); check(rv[23] == 1, "AL-5 ALARM1 HIT");
        rd(A_AL2); check(rv[23] == 0, "EN = 0 khong HIT");
        check(nev == 1, "AL-5 mot su kien ngat");

        // ---- chỉ ALARM3 khớp → vẫn 1 sự kiện (sự kiện = OR cả 4)
        wr(A_AL0, al(0, 7'b0, 0) | 32'h0080_0000);
        wr(A_AL1, al(0, 7'b0, 0) | 32'h0080_0000);
        wr(8'h3C, al(1, 7'b0000010, 420));
        set_rtc(25199990, 1);
        repeat (20 * 50) @(negedge clk);
        rd(8'h3C); check(nev == 1 && rv[23] == 1, "chi ALARM3 khop -> 1 su kien, HIT3");
        wr(8'h3C, 32'h0080_0000);

        // ---- MINUTE ≥ 1440 → không bao giờ kêu (cả lúc qua nửa đêm)
        wr(A_AL0, al(1, 7'b1111111, 1440) | 32'h0080_0000);
        wr(A_AL1, al(0, 7'b0, 0) | 32'h0080_0000);
        set_rtc(86399990, 3);
        repeat (30 * 50) @(negedge clk);
        check(nev == 0, "MINUTE = 1440 khong keu");
        rd(8'h04); rd(A_AL0 + 8'h10); check(rv == 0, "dia chi khac doc 0");

        if (nerr == 0) $display("PASS alarm_tb %0d", n);
        else $display("FAIL alarm_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
