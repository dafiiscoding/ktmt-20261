// timebase_tb.v — gói E1: TB-1…5 (timer-spec.md §2). Chạy từ thư mục gốc project.
// Mặc định: G_N = 50 cho mọi dòng; dòng G_N = 50 000 của timebase_len chạy luôn (20 ms/dòng).
// +slow: chạy thêm TB-3 với G_N = 50 000, CAL = 163 840, 1 000 ms (5·10⁷ chu kỳ, chậm).
`timescale 1ns/1ps
module timebase_tb;
    reg                clk = 0, rst = 1, clr = 0, en = 1;
    reg  signed [31:0] cal = 0;
    reg                big = 0;           // 0: đọc tick của G_N = 50, 1: của G_N = 50 000
    wire               tick_s, tick_b;
    wire               tick = big ? tick_b : tick_s;

    timebase #(.G_N(50))    u_s (.clk(clk), .rst(rst), .clr(clr), .en(en), .cal(cal), .tick(tick_s));
    timebase #(.G_N(50000)) u_b (.clk(clk), .rst(rst), .clr(clr), .en(en), .cal(cal), .tick(tick_b));

    always #10 clk = ~clk;

    integer fd, c, r, i, n, nerr, cyc, nt, ln, gn, kk;
    integer t_at [0:19];                   // chu kỳ (đếm từ 1) của tick 1..20
    integer e_len [0:19];
    reg [8*200:1] rest;
    integer e_cal, e_k, e_tot, e_gn;
    reg signed [63:0] s0, s1;
    integer len0, len1;

    task check(input cond, input [8*40:1] what);
        begin
            n = n + 1;
            if (!cond) begin
                nerr = nerr + 1;
                if (nerr <= 10) $display("loi %0s: G_N=%0d cal=%0d", what, big ? 50000 : 50, cal);
            end
        end
    endtask

    // xóa pha; sau task này chu kỳ hiện tại là chu kỳ đếm số 1
    task do_clr;
        begin
            @(negedge clk); clr = 1;
            @(negedge clk); clr = 0;
            cyc = 0; nt = 0;
        end
    endtask

    // chạy tới khi đủ k tick; ghi chu kỳ của 20 tick đầu vào t_at
    task run_ticks(input integer k);
        begin
            while (nt < k) begin
                cyc = cyc + 1;
                #1;
                if (tick) begin
                    if (nt < 20) t_at[nt] = cyc;
                    nt = nt + 1;
                end
                @(negedge clk);
            end
        end
    endtask

    initial begin
        n = 0; nerr = 0;
        repeat (2) @(negedge clk);
        rst = 0;

        // ---- TB-1: CAL = 0 → tick ở chu kỳ 50, 100, …, 1000
        big = 0; cal = 0;
        do_clr; run_ticks(20);
        for (i = 0; i < 20; i = i + 1) check(t_at[i] == 50 * (i + 1), "TB-1");

        // ---- TB-2: 20 len_k đầu theo timebase_len.txt (cả G_N = 50 và 50 000)
        fd = $fopen("tb/vectors/timebase_len.txt", "r");
        if (fd == 0) begin $display("FAIL timebase_tb khong mo duoc timebase_len.txt"); $finish; end
        ln = 0;
        while (!$feof(fd)) begin
            c = $fgetc(fd);
            if (c == "#" || c == "\n") r = $fgets(rest, fd);
            else if (c != -1) begin
                r = $ungetc(c, fd);
                r = $fscanf(fd, "%d %d", gn, e_cal);
                for (i = 0; i < 20; i = i + 1) r = $fscanf(fd, " %d", e_len[i]);
                r = $fgets(rest, fd);
                big = (gn == 50000); cal = e_cal;
                do_clr; run_ticks(20);
                for (i = 0; i < 20; i = i + 1)
                    check(t_at[i] - (i == 0 ? 0 : t_at[i - 1]) == e_len[i], "TB-2 len_k");
                ln = ln + 1;
            end
        end
        $fclose(fd);
        check(ln == 28, "TB-2 du 28 dong");

        // ---- TB-3: tổng chu kỳ của K ms (G_N = 50, K = 1 000; dòng K = 65 536 và G_N = 50 000 bỏ trừ khi +slow)
        fd = $fopen("tb/vectors/timebase_total.txt", "r");
        ln = 0;
        while (!$feof(fd)) begin
            c = $fgetc(fd);
            if (c == "#" || c == "\n") r = $fgets(rest, fd);
            else if (c != -1) begin
                r = $ungetc(c, fd);
                r = $fscanf(fd, "%d %d %d %d\n", e_gn, e_cal, e_k, e_tot);
                if ((e_gn == 50 && e_k == 1000) ||
                    ($test$plusargs("slow") && e_gn == 50000 && e_k == 1000 && e_cal == 163840)) begin
                    big = (e_gn == 50000); cal = e_cal;
                    do_clr; run_ticks(e_k);
                    check(cyc == e_tot, "TB-3 tong chu ky");
                    ln = ln + 1;
                end
            end
        end
        $fclose(fd);
        check(ln == ($test$plusargs("slow") ? 15 : 14), "TB-3 so dong da chay");

        // ---- TB-4: en = 0 trong 37 chu kỳ ở giữa ms thứ 3 → tick từ đó lùi đúng 37
        big = 0; cal = 100000;
        do_clr; run_ticks(20);
        for (i = 0; i < 20; i = i + 1) e_len[i] = t_at[i];
        do_clr; run_ticks(2);
        repeat (20) begin cyc = cyc + 1; @(negedge clk); end    // vào giữa ms thứ 3
        en = 0;
        repeat (37) begin cyc = cyc + 1; #1; check(!tick, "TB-4 khong tick khi en=0"); @(negedge clk); end
        en = 1;
        run_ticks(20);
        check(t_at[0] == e_len[0] && t_at[1] == e_len[1], "TB-4 2 tick dau khong doi");
        for (i = 2; i < 20; i = i + 1) check(t_at[i] == e_len[i] + 37, "TB-4 tick lui 37");

        // ---- TB-4b: en = 0 đúng chu kỳ cuối ms (cnt = len - 1) → không tick khi dừng, tick ngay khi chạy lại
        big = 0; cal = 0;
        do_clr;
        repeat (49) begin cyc = cyc + 1; @(negedge clk); end    // chu kỳ hiện tại = chu kỳ 50
        en = 0;
        repeat (37) begin #1; check(!tick, "TB-4b khong tick khi dung o bien"); @(negedge clk); end
        en = 1;
        #1; check(tick, "TB-4b tick ngay khi en = 1");
        @(negedge clk); #1; check(!tick, "TB-4b chi 1 tick");
        @(negedge clk);

        // ---- TB-5: đổi CAL giữa ms 0 → ms 0 giữ len cũ, ms 1 dùng CAL mới (frac mang sang)
        big = 0; cal = 100000;
        do_clr;
        repeat (10) begin cyc = cyc + 1; #1; @(negedge clk); end
        cal = -100000;
        run_ticks(2);
        s0 = 100000;                len0 = 50 + (s0 >>> 16);       // 51
        s1 = (s0 & 16'hFFFF) - 100000; len1 = 50 + (s1 >>> 16);    // 49
        check(t_at[0] == len0 && t_at[1] - t_at[0] == len1, "TB-5 doi CAL giua ms");
        check(len0 == 51 && len1 == 49, "TB-5 golden");

        if (nerr == 0) $display("PASS timebase_tb %0d", n);
        else $display("FAIL timebase_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
