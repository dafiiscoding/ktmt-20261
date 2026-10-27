// fmt_bench_tb.v — (fw: fw/fmt.s) B7 fmt_div / fmt_bcd / fmt_hw trên soc_top (G_BCD_RTC = 1) + số đo plan §8.1.
// tb chụp 7 khung (mỗi lần firmware ghi DISP7): div/bcd ở 0, 12:34:56.789, 23:59:59.999 rồi hw (RTC_BCD nạp 12:34:56.789)
// và so với bố cục TIME 24 h; in ΔCYCLE_COUNT (chu kỳ hệ thống 50 MHz) từng hàm, đã trừ chi phí gọi hàm rỗng.
// G_N = 50 000 (thật): cả bench < 1 ms nên RTC_BCD không kịp sang giây kế (nạp ở .789).
// Biến thể (chạy tay, ghi evidence): -DG2 (lõi pipeline), -DBCD_COMB (bcd tổ hợp 1 chu kỳ, G_BCD_COMB = 1),
// -DSLOW (firmware đặt CPU_CLK_DIV = 1526 ≈ 32,77 kHz trước khi đo; bench ≈ 50 ms nên RTC_BCD vẫn chưa sang giây).
`timescale 1ns/1ps
module fmt_bench_tb;
    reg  clk = 0, rst_in = 1;
    wire [7:0] an;
    wire [6:0] seg;
    wire       dp;

`ifdef BCD_COMB
    localparam COMB = 1;
`else
    localparam COMB = 0;
`endif
    soc_top #(.G_N(50000), .G_SLOT(40), .G_BLANK(4), .G_BCD_RTC(1), .G_BCD_COMB(COMB)) dut (
        .clk(clk), .rst_in(rst_in), .btn(4'b0), .an(an), .seg(seg), .dp(dp), .beep(), .uart_rx(1'b1), .uart_tx());

    always #10 clk = ~clk;

    integer n, nerr, nbad, cyc, i, nfr;
    reg [8*256:1] fimem, ftrace;
    reg [63:0] fr [0:7];
    reg [63:0] exp [0:6];
    reg [31:0] base, c [1:7];

    task check(input cond, input [8*48:1] what);
        begin
            n = n + 1;
            if (!cond) begin nerr = nerr + 1; $display("loi %0s", what); end
        end
    endtask

    always @(posedge clk) if (!dut.rst) begin
        cyc <= cyc + 1;
        if (dut.u_cpu.retire && !dut.u_cpu.valid) nbad <= nbad + 1;
        if (dut.bus_we && dut.bus_addr == 8'h78 && nfr < 8) begin       // DISP7 = khung xong
            #1 fr[nfr] = dut.u_disp.disp;
            nfr = nfr + 1;
        end
    end

    initial begin
        n = 0; nerr = 0; nbad = 0; cyc = 0; nfr = 0;
        exp[0] = 64'h1A1A_0080_0080_0000;  exp[1] = exp[0];                // 00:00:00
        exp[2] = 64'h1A1A_0182_0384_0506;  exp[3] = exp[2];                // 12:34:56
        exp[4] = 64'h1A1A_0283_0589_0509;  exp[5] = exp[4];                // 23:59:59
        exp[6] = exp[2];                                                   // hw: RTC_BCD 12:34:56.789
        if (!$value$plusargs("imem=%s", fimem)) begin $display("FAIL fmt_bench_tb thieu +imem="); $finish; end
        #1;
        $readmemh(fimem, dut.u_cpu.imem);
`ifdef SLOW
        dut.u_cpu.dmem[12'h7f0 >> 2] = 1526;
`endif
        if ($value$plusargs("trace=%s", ftrace)) dut.u_cpu.tf = $fopen(ftrace, "w");
        repeat (6) @(negedge clk);
        rst_in = 0;
        while (!(dut.bus_we && dut.bus_addr == 8'h94) && cyc < 10000000) @(negedge clk);  // sw dấu xong (−108)
        repeat (20) @(negedge clk);
        check(cyc < 10000000, "chay toi dau xong truoc 10^7 chu ky");
        check(nfr == 7, "dung 7 khung");
        for (i = 0; i < 7; i = i + 1)
            if (fr[i] !== exp[i]) begin
                check(0, "khung sai");
                $display("  khung %0d: %h, mong %h", i, fr[i], exp[i]);
            end else n = n + 1;
        check(nbad == 0, "khong lenh la");
        base = dut.u_cpu.dmem[64];
        for (i = 1; i <= 7; i = i + 1) c[i] = dut.u_cpu.dmem[64 + i] - base;
        $display("core G%0d, D = %0d, bcd %s: nen (jal+jr+lw) %0d chu ky he thong", dut.G_CORE, dut.u_regs.d, COMB ? "to hop" : "tuan tu", base);
        $display("  fmt_div  %0d %0d %0d   fmt_bcd  %0d %0d %0d   fmt_hw  %0d   (0 / 12:34:56.789 / 23:59:59.999)",
                 c[1], c[3], c[5], c[2], c[4], c[6], c[7]);
        check(c[1] == c[3] && c[3] == c[5] && c[2] == c[4] && c[4] == c[6], "chi phi khong phu thuoc gia tri");
        if (nerr == 0) $display("PASS fmt_bench_tb %0d", n);
        else $display("FAIL fmt_bench_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
