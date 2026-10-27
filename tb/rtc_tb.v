// rtc_tb.v — gói E2: RTC-1…7 (timer-spec.md §10, goi-viec.md E2) qua bus MMIO. tick_ms do tb phát.
`timescale 1ns/1ps
module rtc_tb;
    localparam A_MS = 8'h04, A_SHADOW = 8'h08, A_SET_MS = 8'h0C, A_SET_DAY = 8'h10, A_CTRL = 8'h14;
    localparam MS_DAY = 86400000;

    reg         clk = 0, rst = 1, tick_ms = 0, bus_we = 0, bus_re = 0;
    reg  [7:0]  bus_addr = 0;
    reg  [31:0] bus_wdata = 0;
    wire [31:0] bus_rdata;
    wire [26:0] ms;
    wire [15:0] day;
    wire [2:0]  dow;
    wire        tick_1s, loading;

    rtc dut (.clk(clk), .rst(rst), .tick_ms(tick_ms), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
             .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(bus_rdata),
             .ms(ms), .day(day), .dow(dow), .tick_1s(tick_1s), .loading(loading));

    always #10 clk = ~clk;

    integer n, nerr, k, n1s, at1s;
    reg [31:0] r, r2, r_ms_a, r_sh_a, r_ms_b, r_sh_b;

    task check(input cond, input [8*40:1] what);
        begin
            n = n + 1;
            if (!cond) begin
                nerr = nerr + 1;
                if (nerr <= 10) $display("loi %0s: ms=%0d day=%0d dow=%0d r=%h", what, ms, day, dow, r);
            end
        end
    endtask

    // mỗi task bắt đầu và kết thúc ở negedge; 1 thao tác = 1 chu kỳ
    task wr(input [7:0] a, input [31:0] d);
        begin bus_addr = a; bus_wdata = d; bus_we = 1; @(negedge clk); bus_we = 0; end
    endtask
    task rd(input [7:0] a, output [31:0] d);
        begin bus_addr = a; bus_re = 1; @(negedge clk); bus_re = 0; d = bus_rdata; end
    endtask
    task tick;                     // 1 tick_ms, đếm tick_1s
        begin
            tick_ms = 1; #1;
            if (tick_1s) n1s = n1s + 1;
            @(negedge clk); tick_ms = 0;
        end
    endtask
    task set_rtc(input [31:0] set_ms, input [2:0] set_dow, input [15:0] set_day);
        begin
            wr(A_SET_MS, set_ms); wr(A_SET_DAY, {13'd0, set_dow, set_day}); wr(A_CTRL, 1);
            tick;                  // nạp ở tick này
        end
    endtask

    initial begin
        n = 0; nerr = 0; n1s = 0;
        repeat (2) @(negedge clk);
        rst = 0;

        // ---- RTC-7: reset
        rd(A_MS, r); check(r == 0, "RTC-7 ms reset");
        rd(A_SHADOW, r); check(r == {13'd0, 3'd6, 16'd0}, "RTC-7 dow=6 day=0");
        rd(A_CTRL, r); check(r == 0, "RTC-7 ARM=0");
        tick; tick; check(ms == 2, "dem ms");

        // ---- RTC-4 + RTC-1: ghi SET_*, ARM; trước tick: ARM = 1, ms chưa đổi
        wr(A_SET_MS, 86399990); wr(A_SET_DAY, {13'd0, 3'd6, 16'd100}); wr(A_CTRL, 1);
        rd(A_CTRL, r); check(r == 1, "RTC-4 ARM=1 truoc tick");
        check(ms == 2 && day == 0, "RTC-4 ms chua doi");
        tick; check(loading == 0, "loading chi 1 chu ky");
        rd(A_CTRL, r); check(r == 0, "RTC-4 ARM=0 sau tick");
        check(ms == 86399990 && day == 100 && dow == 6, "RTC-4 nap dung");
        repeat (10) tick;
        check(ms == 0 && day == 101 && dow == 0, "RTC-1 qua nua dem");

        // ---- RTC-2: day = 65 535 qua nửa đêm → 0
        set_rtc(MS_DAY - 1, 3, 65535);
        check(ms == MS_DAY - 1 && day == 65535, "RTC-2 nap");
        tick; check(ms == 0 && day == 0 && dow == 4, "RTC-2 day quay vong");

        // ---- RTC-3: đọc MS_OF_DAY đúng chu kỳ tick qua nửa đêm, và chu kỳ ngay sau
        set_rtc(MS_DAY - 1, 2, 500);
        bus_addr = A_MS; bus_re = 1; tick_ms = 1; @(negedge clk); bus_re = 0; tick_ms = 0; r_ms_a = bus_rdata;
        rd(A_SHADOW, r_sh_a);
        rd(A_MS, r_ms_b); rd(A_SHADOW, r_sh_b);
        check(r_ms_a == MS_DAY - 1 && r_sh_a == {13'd0, 3'd2, 16'd500}, "RTC-3 cung truoc tick");
        check(r_ms_b == 0 && r_sh_b == {13'd0, 3'd3, 16'd501}, "RTC-3 cung sau tick");
        // shadow chỉ đổi khi đọc MS_OF_DAY
        repeat (3) tick; rd(A_SHADOW, r); check(r == r_sh_b, "shadow giu den lan doc ms sau");

        // ---- RTC-5: SET_MS ≥ 86 400 000 → nạp 0; [26:0] toàn 1 cũng vậy
        set_rtc(MS_DAY, 1, 7); check(ms == 0 && day == 7 && dow == 1, "RTC-5 86400000 -> 0");
        set_rtc(32'hFFFFFFFF, 1, 7); check(ms == 0, "RTC-5 0xFFFFFFFF -> 0");
        // SET_DAY dow = 7 → 0
        set_rtc(5, 7, 9); check(ms == 5 && dow == 0 && day == 9, "SET_DAY dow 7 -> 0");

        // ghi ARM = 0 hủy lệnh nạp đang chờ
        wr(A_SET_MS, 123); wr(A_CTRL, 1); wr(A_CTRL, 0);
        r = ms; tick; check(ms == r + 1, "ARM=0 huy nap");

        // thanh ghi chỉ-ghi và địa chỉ lạ đọc ra 0
        rd(A_SET_MS, r); check(r == 0, "SET_MS doc 0");
        rd(8'h5C, r); check(r == 0, "dia chi khac doc 0");

        // ---- RTC-6: TICK_1S sau đúng 1 000 tick kể từ lần nạp; nạp giữa chừng xóa bộ đếm
        set_rtc(0, 0, 0);
        n1s = 0;
        repeat (500) tick;
        set_rtc(0, 0, 0);                      // tick nạp này không tính, bộ đếm về 0
        n1s = 0; at1s = 0;
        for (k = 1; k <= 2500; k = k + 1) begin
            tick_ms = 1; #1;
            if (tick_1s) begin
                n1s = n1s + 1;
                if (at1s == 0) at1s = k;
            end
            @(negedge clk); tick_ms = 0;
        end
        check(at1s == 1000 && n1s == 2, "RTC-6 tick_1s o tick 1000, 2000");

        if (nerr == 0) $display("PASS rtc_tb %0d", n);
        else $display("FAIL rtc_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
