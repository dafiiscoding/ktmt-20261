// exp_e3_tb.v — (fw: fw/exp/e3_irq.s) thí nghiệm E3 (chủ TV3 + TV2): lấy thời điểm bấm nút B bằng 4 cách trên soc_top G1.
// Code do Claude viết theo yêu cầu Long (26/10/2026); TV3 + TV2 chạy lại và đọc hiểu.
//   1 polling / 2 ngắt: firmware đọc MS_OF_DAY (e3_poll.s / e3_irq.s) → độ trễ = chu kỳ lệnh lw đó retire − chu kỳ xung nhấn
//   3 capture: lap stopwatch (SRC = 1) chụp ngay chu kỳ xung nhấn → sai số so với giá trị stopwatch lúc nhấn
//   4 dấu thời gian trong BTN_EVENT → sai số so với MS_OF_DAY lúc nhấn
// Mốc "lúc nhấn" = chu kỳ xung press[2] (sau đồng bộ 2 FF, như nhau cho cả 4 cách).
// G_N = 50 (1 ms mô phỏng = 50 chu kỳ). Độ trễ tính bằng chu kỳ 50 MHz nên đổi thẳng ra µs ở board (÷ 50).
// Tham số: +imem= (bắt buộc) +d=<CPU_CLK_DIV khớp firmware, mặc định 2> +n=<số lần bấm, mặc định 30> +csv=<file>
// Chạy cả bảng: python tools/exp_e3.py
`timescale 1ns/1ps
module exp_e3_tb;
    localparam NMAX = 2000;
    reg        clk = 0, rst_in = 1;
    reg  [3:0] btn = 4'b0;
    wire [7:0] an;
    wire [6:0] seg;
    wire       dp, beep;

    soc_top #(.G_N(50), .G_SLOT(40), .G_BLANK(4)) dut (.clk(clk), .rst_in(rst_in), .btn(btn), .an(an), .seg(seg),
                                                     .dp(dp), .beep(beep), .uart_rx(1'b1), .uart_tx());

    always #10 clk = ~clk;

    integer n, nerr, cyc, d, np, i, k, fd, kp, kf, kl, kb, gap, seed;
    integer t_p [0:NMAX-1], ms_p [0:NMAX-1], sw_p [0:NMAX-1];
    integer t_f [0:NMAX-1], v_f [0:NMAX-1], v_l [0:NMAX-1], v_b [0:NMAX-1];
    integer lat, lmin, lmax, nlap_bad, nstamp_bad, nms_neg;
    real    lsum;
    reg [8*256:1] fimem, fcsv;

    task check(input cond, input [8*64:1] what);
        begin
            n = n + 1;
            if (!cond) begin nerr = nerr + 1; $display("loi %0s", what); end
        end
    endtask

    wire        ret = !dut.rst && dut.u_cpu.retire && dut.u_cpu.mem_read;
    wire [31:0] ma  = dut.u_cpu.maddr;
    wire [31:0] lv  = dut.u_cpu.load_v;

    always @(posedge clk) if (!dut.rst) begin
        cyc <= cyc + 1;
        if (dut.press[2] && kp < NMAX) begin
            t_p[kp] = cyc; ms_p[kp] = dut.ms; sw_p[kp] = dut.u_sw.val; kp = kp + 1;
        end
        if (ret && ma == 32'hFFFF_FF04 && kf < NMAX) begin t_f[kf] = cyc; v_f[kf] = lv; kf = kf + 1; end   // MS_OF_DAY
        if (ret && ma == 32'hFFFF_FF24 && kl < NMAX) begin v_l[kl] = lv[28:0]; kl = kl + 1; end         // SW_LAP
        if (ret && ma == 32'hFFFF_FF40 && lv[31] && kb < NMAX) begin v_b[kb] = lv[26:0]; kb = kb + 1; end // BTN_EVENT hợp lệ
    end

    initial begin
        n = 0; nerr = 0; cyc = 0; kp = 0; kf = 0; kl = 0; kb = 0; seed = 26;
        if (!$value$plusargs("imem=%s", fimem)) begin $display("FAIL exp_e3_tb thieu +imem="); $finish; end
        if (!$value$plusargs("d=%d", d)) d = 2;
        if (!$value$plusargs("n=%d", np)) np = 30;
        #1;
        $readmemh(fimem, dut.u_cpu.imem);
        repeat (6) @(negedge clk);
        rst_in = 0;
        while (dut.u_cpu.dmem[0] != 1 && cyc < 1000000) @(negedge clk);
        check(cyc < 1000000, "firmware bao san sang (DMEM[0] = 1)");

        // bấm: giữ 700 chu kỳ (> khóa chống rung 10 ms = 500), rồi nghỉ ≥ 60·D + 2000 (> phản ứng chậm nhất của firmware)
        for (k = 0; k < np; k = k + 1) begin
            gap = 60 * d + 2000 + ($unsigned($random(seed)) % (30 * d + 1000));
            repeat (gap) @(negedge clk);
            btn[2] = 1; repeat (700) @(negedge clk); btn[2] = 0;
        end
        repeat (60 * d + 2000) @(negedge clk);

        check(kp == np && kf == np && kl == np && kb == np, "moi lan bam: 1 xung, 1 MS_OF_DAY, 1 lap, 1 BTN_EVENT");
        lmin = 1 << 30; lmax = 0; lsum = 0; nlap_bad = 0; nstamp_bad = 0; nms_neg = 0;
        fd = 0;
        if ($value$plusargs("csv=%s", fcsv)) begin
            fd = $fopen(fcsv, "w");
            $fwrite(fd, "k,t_press,lat_cyc,ms_err_sim,lap_err,stamp_err\n");
        end
        for (k = 0; k < np && k < kf && k < kl && k < kb; k = k + 1) begin
            lat = t_f[k] - t_p[k];
            if (lat < lmin) lmin = lat;
            if (lat > lmax) lmax = lat;
            lsum = lsum + lat;
            if (v_l[k] != sw_p[k]) nlap_bad = nlap_bad + 1;
            if (v_b[k] != ms_p[k]) nstamp_bad = nstamp_bad + 1;
            if (v_f[k] < ms_p[k]) nms_neg = nms_neg + 1;
            if (fd != 0) $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d\n", k, t_p[k], lat, v_f[k] - ms_p[k], v_l[k] - sw_p[k], v_b[k] - ms_p[k]);
        end
        if (fd != 0) $fclose(fd);
        check(lmin > 0 && nms_neg == 0, "firmware doc MS_OF_DAY sau luc nhan");
        check(nlap_bad == 0, "capture lap = gia tri stopwatch dung chu ky nhan");
        check(nstamp_bad == 0, "dau thoi gian BTN_EVENT = MS_OF_DAY dung chu ky nhan");
        $display("E3 D=%0d n=%0d tre_chu_ky min=%0d tb=%0.1f max=%0d lap_lech=%0d stamp_lech=%0d", d, np, lmin,
                 lsum / np, lmax, nlap_bad, nstamp_bad);
        if (nerr == 0) $display("PASS exp_e3_tb %0d", n);
        else           $display("FAIL exp_e3_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
