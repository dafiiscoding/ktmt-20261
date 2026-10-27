// rtc_bcd_tb.v — gói E7 (RTC BCD): 3 ca biên của goi-viec E7 + so với mô hình ms nhị phân → BCD ở mọi ranh giới giây
// trong ngày (86 400 lần nạp, mỗi lần 2 tick qua ranh giới) và 1 000 000 tick liền từ 23:43:20.000 (qua nửa đêm).
// (goi-viec ghi "so với RTC nhị phân 1 ngày, G_N = 50" = 4,3·10⁹ chu kỳ, quá lâu cho Icarus → đổi thành 2 phần trên,
// vẫn phủ mọi lần nhớ của mọi hàng.) Thêm: ghi thắng tick cùng chu kỳ, chữ số sai tự về 0, địa chỉ khác đọc 0.
`timescale 1ns/1ps
module rtc_bcd_tb;
    localparam A_BCD = 8'h98;

    reg         clk = 0, rst = 1, tick = 0, bus_we = 0, bus_re = 0;
    reg  [7:0]  bus_addr = 0;
    reg  [31:0] bus_wdata = 0;
    wire [31:0] bus_rdata;

    rtc_bcd dut (.clk(clk), .rst(rst), .tick_ms(tick), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
                 .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(bus_rdata));

    always #10 clk = ~clk;

    integer n, nerr, nbad, i, t;
    reg [31:0] d;

    // ms trong ngày → RTC_BCD (timer-spec §8)
    function [31:0] pack(input integer ms);
        integer h, m, s, r;
        begin
            h = ms / 3600000;  m = (ms / 60000) % 60;  s = (ms / 1000) % 60;  r = ms % 1000;
            pack = 32'd0;
            pack[31:30] = h / 10;  pack[29:26] = h % 10;  pack[25:23] = m / 10;  pack[22:19] = m % 10;
            pack[18:16] = s / 10;  pack[15:12] = s % 10;  pack[11:8] = r / 100;  pack[7:4] = (r / 10) % 10;
            pack[3:0] = r % 10;
        end
    endfunction

    task check(input cond, input [8*48:1] what);
        begin
            n = n + 1;
            if (!cond) begin nerr = nerr + 1; if (nerr <= 10) $display("loi %0s: d=%h v=%h", what, d, dut.v); end
        end
    endtask
    task wr(input [7:0] a, input [31:0] v);
        begin @(negedge clk); bus_addr = a; bus_wdata = v; bus_we = 1; @(negedge clk); bus_we = 0; end
    endtask
    task rd(input [7:0] a);
        begin @(negedge clk); bus_addr = a; bus_re = 1; @(negedge clk); bus_re = 0; d = bus_rdata; end
    endtask
    task tk;                            // 1 tick_ms
        begin @(negedge clk); tick = 1; @(negedge clk); tick = 0; end
    endtask

    initial begin
        n = 0; nerr = 0;
        repeat (3) @(negedge clk);
        rst = 0;
        rd(A_BCD);
        check(d == 0, "reset: 00:00:00.000");

        // ---- 3 ca biên của E7
        wr(A_BCD, pack(86399999));  tk;  rd(A_BCD);
        check(d == pack(0), "23:59:59.999 -> 00:00:00.000");
        wr(A_BCD, pack(35999999));  tk;  rd(A_BCD);
        check(d == pack(36000000), "09:59:59.999 -> 10:00:00.000");
        wr(A_BCD, pack(71999999));  tk;  rd(A_BCD);
        check(d == pack(72000000), "19:59:59.999 -> 20:00:00.000");

        // ---- mọi ranh giới giây: nạp x.998, 2 tick → (x+1).000
        nbad = 0;
        for (i = 1; i <= 86400; i = i + 1) begin
            t = i * 1000 - 2;
            @(negedge clk); bus_addr = A_BCD; bus_wdata = pack(t); bus_we = 1;
            @(negedge clk); bus_we = 0; tick = 1;
            @(negedge clk); if (dut.v !== pack(t + 1)) nbad = nbad + 1;
            @(negedge clk); tick = 0;
            @(negedge clk); if (dut.v !== pack((t + 2) % 86400000)) nbad = nbad + 1;
        end
        check(nbad == 0, "86 400 ranh gioi giay dung");

        // ---- 1 000 000 tick liền qua nửa đêm (tick mỗi chu kỳ)
        wr(A_BCD, pack(85400000));
        nbad = 0;  t = 85400000;
        @(negedge clk); tick = 1;
        for (i = 0; i < 1000000; i = i + 1) begin
            @(negedge clk);
            t = (t + 1) % 86400000;
            if (dut.v !== pack(t)) nbad = nbad + 1;
        end
        tick = 0;
        check(nbad == 0, "1 000 000 tick lien qua nua dem");

        // ---- ghi và tick cùng chu kỳ → ghi thắng
        @(negedge clk); bus_addr = A_BCD; bus_wdata = pack(1234); bus_we = 1; tick = 1;
        @(negedge clk); bus_we = 0; tick = 0;
        check(dut.v == pack(1234), "ghi + tick cung chu ky -> ghi thang");

        // ---- chữ số sai tự về 0 và nhớ lên; hàng giờ 3x
        wr(A_BCD, 32'h0000_000F);  tk;
        check(dut.v == 32'h0000_0010, "don vi ms = F -> 0, nho len chuc");
        wr(A_BCD, {2'd3, 4'd0, 26'd0} | pack(3599999));  tk;           // 30:59:59.999 (sai) → 31:00:00.000
        check(dut.v == {2'd3, 4'd1, 26'd0}, "gio 3x tang tiep, khong ket");
        wr(A_BCD, {2'd3, 4'd3, 26'd0} | pack(3599999));  tk;           // 33:59:59.999 → 00:00:00.000
        check(dut.v == 32'd0, "gio 33 -> 00");
        wr(A_BCD, pack(45296789));
        rd(8'h94);
        check(d == 0, "dia chi khac doc 0 (RTC_BCD dang khac 0)");

        if (nerr == 0) $display("PASS rtc_bcd_tb %0d", n);
        else           $display("FAIL rtc_bcd_tb %0d/%0d", nerr, n);
        $finish;
    end
endmodule
