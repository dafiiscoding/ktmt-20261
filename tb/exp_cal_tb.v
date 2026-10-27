// exp_cal_tb.v — thí nghiệm báo cáo E2′ (+ E1′ khi có +e1). Chủ: TV5. Spec: timer-spec.md §2, §10.
// Code do Claude viết theo yêu cầu Long (26/10/2026); TV5 chạy lại và đọc hiểu.
//
// E2′ (luôn chạy, G_N = 50): cdtimer nạp 2000, RUN → ZERO đúng cạnh thứ 2000·G_N + floor(2000·CAL / 65536)
//      kể từ cạnh RUN, với nhiều CAL (0, ±20 ppm, ±50 ppm của board, biên ±200 ppm, số lẻ).
//      +slow: chạy thêm 1 lần ở G_N = 50 000, CAL = 65 500 (10⁸ chu kỳ, chậm).
// E1′ (+e1 +cal=<n> +k=<ms>): timebase G_N = 50 000 chạy k ms với CAL = n, in tổng số chu kỳ.
//      tools/exp_cal.py gọi chế độ này với CAL do firmware tính và đổi ra ppm.
`timescale 1ns/1ps
module exp_cal_tb;
    localparam A_VAL = 8'h28, A_CTL = 8'h2C;

    reg                clk = 0, rst = 1, bus_we = 0, clr = 0;
    reg  [7:0]         bus_addr = 0;
    reg  [31:0]        bus_wdata = 0;
    reg  signed [31:0] cal = 0;
    wire [31:0]        rd_s, rd_b;
    wire               zero_s, zero_b, beep_s, beep_b, tick_e1;
    reg                big = 0, e1 = 0;    // big: đo ZERO của cdtimer G_N = 50 000; e1: bật timebase của E1′

    cdtimer #(.G_N(50))    u_s (.clk(clk), .rst(rst), .cal(cal), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
                                .bus_we(bus_we && !big), .bus_re(1'b0), .bus_rdata(rd_s), .zero_ev(zero_s), .beep(beep_s));
    cdtimer #(.G_N(50000)) u_b (.clk(clk), .rst(rst), .cal(cal), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
                                .bus_we(bus_we && big), .bus_re(1'b0), .bus_rdata(rd_b), .zero_ev(zero_b), .beep(beep_b));
    timebase #(.G_N(50000)) u_e1 (.clk(clk), .rst(rst), .clr(clr), .en(e1), .cal(cal), .tick(tick_e1));

    always #10 clk = ~clk;

    integer n, nerr, i, k, nt;
    reg signed [63:0] cyc, c_run, c_zero, expect;
    wire zero = big ? zero_b : zero_s;

    always @(posedge clk) begin
        cyc <= cyc + 1;
        if (zero) c_zero <= cyc + 1;                 // cyc + 1 = số thứ tự cạnh này
    end

    task wr(input [7:0] a, input [31:0] d);
        begin @(negedge clk); bus_addr = a; bus_wdata = d; bus_we = 1; @(negedge clk); bus_we = 0; end
    endtask

    // nạp 2000 (xóa pha bộ chia), RUN, chờ ZERO; so số cạnh với công thức
    task e2(input signed [31:0] c, input integer gn);
        begin
            cal = c; c_zero = -1;
            wr(A_VAL, 2000);
            @(negedge clk); bus_addr = A_CTL; bus_wdata = 32'h1; bus_we = 1; c_run = cyc + 1; @(negedge clk); bus_we = 0;
            wait (c_zero >= 0);
            expect = 2000 * gn + ((2000 * $signed({{32{c[31]}}, c})) >>> 16);
            n = n + 1;
            if (c_zero - c_run != expect) nerr = nerr + 1;
            $display("E2 G_N=%0d cal=%0d chu_ky=%0d ky_vong=%0d %0s", gn, c, c_zero - c_run, expect,
                     (c_zero - c_run == expect) ? "OK" : "LECH");
            wr(A_CTL, 32'h0);
        end
    endtask

    initial begin
        n = 0; nerr = 0; cyc = 0;
        repeat (3) @(negedge clk);
        rst = 0;

        if ($test$plusargs("e1")) begin
            if (!$value$plusargs("cal=%d", cal) || !$value$plusargs("k=%d", k)) begin
                $display("FAIL exp_cal_tb can +cal= +k="); $finish;
            end
            @(negedge clk); clr = 1; @(negedge clk); clr = 0; e1 = 1;
            c_run = cyc; nt = 0;                     // cạnh kế tiếp là chu kỳ đếm số 1
            while (nt < k) begin
                @(posedge clk); #1;
                if (tick_e1) nt = nt + 1;
            end
            // tick = 1 ở chu kỳ cuối của ms, ms kết thúc ở cạnh kế → + 1
            $display("E1 cal=%0d k=%0d chu_ky=%0d", cal, k, cyc - c_run + 1);
            $finish;
        end

        // 3 277 ≈ 1 ppm; 65 500 = CAL firmware tính cho +20 ppm (timer-spec §9); 163 840 = +50 ppm; ±655 360 = biên ±200 ppm
        e2(0, 50);
        e2(65500, 50);
        e2(-65500, 50);
        e2(163840, 50);
        e2(-163840, 50);
        e2(655360, 50);
        e2(-655360, 50);
        e2(12345, 50);
        e2(-1, 50);
        if ($test$plusargs("slow")) begin
            big = 1;
            e2(65500, 50000);
        end

        if (nerr == 0) $display("PASS exp_cal_tb %0d", n);
        else           $display("FAIL exp_cal_tb %0d/%0d", nerr, n);
        $finish;
    end
endmodule
