// system_tb.v — (fw: fw/main.s) gói C8: kịch bản 1–7 của plan §10 trên soc_top G1 + firmware main.s, G_N = 50, G_BIT = 8.
// Code do Claude viết theo yêu cầu Long (03/10/2026); chủ gói (TV3) đọc hiểu để vấn đáp.
//
// Cách nhìn: tb đọc thẳng Display RAM (dut.u_disp.disp, DISP7 ở [63:56]) và BLINK_MASK. "Khung" = lúc firmware ghi
// DISP7 (flush ghi DISP0 → DISP7), nên khung luôn là 1 lần vẽ trọn. Giá trị mong đợi tính bằng hàm fA/fB/fD/fT/fAL/fDT;
// sys_0 kiểm chính các hàm đó với tb/vectors/fmt_*.txt + date.txt (người kiểm cũng phải đúng spec).
// Màn ảo (gói D7, 26/10): screen_dump nhìn CHÂN an/seg/dp → work/screen_system.log (xem: python tools/screen.py). Mỗi vòng
// quét 8 khe mà Display RAM, BLINK_MASK, pha nháy, BRIGHT không đổi suốt vòng: ảnh từ chân phải = RAM qua bảng seg7.txt
// (chữ số tắt do nháy / BRIGHT 0 → không sáng). Kết hợp với kiểm RAM = fmt_*.txt ở các kịch bản → chân = fmt_*.txt.
// Nút: tb tạo cạnh có rung (rung trong 1 ms đầu và lúc nhả, khóa của buttons là 10 ms).
// Hai kỹ thuật chỉ có trong tb (ghi rõ trong báo cáo):
//   - "Tua giờ": gán thẳng dut.u_rtc.ms/day/dow để nhảy tới 06:59:59.990 thay vì mô phỏng hàng giờ (G_N = 50 vẫn
//     tốn ~15 000 chu kỳ/giây thật của máy). Báo thức vẫn phải tự khớp ở tick kế tiếp như bình thường.
//   - "Đóng băng": force en của bộ chia ms (RTC) / tick của timer = 0 để firmware vẽ xong 1 khung trong lúc giá trị đứng
//     yên. Ở G_N = 50 CPU (D = 2) chỉ chạy 25 lệnh/ms nên 1 khung mất ~10 ms; chip thật (G_N = 50 000) thì không cần.
// Kịch bản 7 (gói E6, 26/10): tb đóng vai PC trên chân UART — ubyte/usend phát câu vào uart_rx, khối "urx_mon" gom từng
// dòng chip phát ra ở uart_tx vào lns[]. Câu chip trả lời được so đúng từng byte với câu tb tự dựng (checksum tính lại).
`timescale 1ns/1ps
module system_tb;
    reg  clk = 0, rst_in = 1;
    reg  [3:0] btn = 4'd0;
    reg        urx = 1'b1;
    wire [7:0] an;
    wire [6:0] seg;
    wire       dp, beep, utx;

    soc_top #(.G_N(50), .G_SLOT(40), .G_BLANK(4), .G_BIT(8)) dut (.clk(clk), .rst_in(rst_in), .btn(btn), .an(an),
        .seg(seg), .dp(dp), .beep(beep), .uart_rx(urx), .uart_tx(utx));

    always #10 clk = ~clk;

    localparam B_MODE = 0, B_A = 1, B_B = 2, B_C = 3;
    localparam [16:0] P_ALARM = 17'h10F0F;

    integer cyc, nchk, nerr_all, nerr, nbad, nal, i, k, fd, r;
    integer t_edge, ms_edge, c0, cz, cv, lapn, ring_ms, off_ms, nlap;
    integer lapv [0:7];
    integer v1, v2, v3, v4, v5;
    reg [63:0] fr, e1, e2, e3;
    reg [8*200:1] line;
    reg [8*256:1] fimem, ftrace;
    reg run_q, ok, poll;                                 // poll: +poll = firmware dịch với USE_IRQ = 0 (run_unit.sh)
    reg [16:0] pat_q;
    integer nchime;
    reg [8*40:1] lns [0:15];                             // dòng chip phát (không có '\n'), canh phải
    reg [8*40:1] ucur, ubody, usent;
    reg [7:0]    urb;
    integer nl, uj, uk, ub, ut, zms, zday, ms_nl, d0;

    // ------------------------------------------------------------------ D7: màn ảo từ chân
    screen_dump #(.G_DIGITS(8), .G_SLOT(40), .FILE("work/screen_system.log")) u_scr (
        .clk(clk), .rst(dut.rst), .tick_ms(dut.tick_ms), .an(an), .seg(seg), .dp(dp));
    reg [6:0] rom7 [0:31];                               // seg7.txt: mã → gfedcba
    reg       sdirty = 1'b1;
    reg [7:0] sd, se;
    reg       sl;
    integer   si, nscr = 0, nscr_bad = 0, nscr_off = 0;
    always @(dut.u_disp.disp or dut.u_disp.blink_mask or dut.u_disp.blink_ph or dut.u_disp.bright) sdirty = 1'b1;
    always @(u_scr.round) begin
        if (!sdirty) begin
            nscr = nscr + 1;
            if (u_scr.lit != 8'hFF) nscr_off = nscr_off + 1;
            for (si = 0; si < 8; si = si + 1) begin
                sd = dut.u_disp.disp[8*si +: 8];
                sl = dut.u_disp.bright != 0 && !(dut.u_disp.blink_mask[si] && dut.u_disp.blink_ph);
                se = sl ? {sd[7], rom7[sd[4:0]]} : 8'h00;
                if (u_scr.frame[8*si +: 8] !== se || u_scr.lit[si] !== sl) begin
                    if (nscr_bad < 5) $display("  loi D7 (ms %0d): o %0d chan %h lit %b, RAM %h -> mong %h",
                                               dut.ms, si, u_scr.frame[8*si +: 8], u_scr.lit[si], sd, se);
                    nscr_bad = nscr_bad + 1;
                end
            end
        end
        sdirty = 1'b0;
    end

    // ------------------------------------------------------------------ đếm, theo dõi
    always @(posedge clk) begin
        cyc <= cyc + 1;
        if (dut.u_cpu.retire && !dut.u_cpu.valid) nbad <= nbad + 1;
        if (cyc == 4000000) begin $display("FAIL system_tb: qua 4 000 000 chu ky"); $finish; end
        if (dut.alarm_ev) nal <= nal + 1;
        if (dut.u_sw.accept) begin
            if (nlap < 8) lapv[nlap] = dut.u_sw.val;
            nlap = nlap + 1;
        end
        run_q <= dut.u_tmr.run;
        pat_q <= dut.u_beep.pat;
        if (dut.u_beep.pat == 17'h00005 && pat_q != 17'h00005) nchime = nchime + 1;
        if (dut.u_tmr.run && !run_q) c0 = cyc - 1;         // cạnh ghi RUN (cạnh trước lần đầu thấy run = 1)
        if (dut.u_tmr.zero_ev) begin cz = cyc; zms = dut.ms; zday = dut.day; end   // cạnh áp dụng sự kiện ZERO
    end

    // ------------------------------------------------------------------ UART phía PC (G_BIT = 8)
    initial begin : urx_mon                              // chip → PC: 8N1, lấy mẫu giữa bit
        nl = 0;  ucur = 0;
        forever begin
            @(negedge utx);
            repeat (4) @(posedge clk);
            for (uj = 0; uj < 8; uj = uj + 1) begin repeat (8) @(posedge clk); urb[uj] = utx; end
            repeat (8) @(posedge clk);
            if (urb == 8'd10) begin
                if (nl < 16) lns[nl] = ucur;
                nl = nl + 1;  ucur = 0;
            end else ucur = {ucur[8*39:1], urb};
        end
    end
    task ubyte(input [7:0] b);                           // PC → chip: start, 8 bit (bit 0 trước), stop
        begin
            @(negedge clk) urx = 1'b0;
            repeat (8) @(negedge clk);
            for (ub = 0; ub < 8; ub = ub + 1) begin urx = b[ub]; repeat (8) @(negedge clk); end
            urx = 1'b1;
            repeat (8) @(negedge clk);
        end
    endtask
    task usend(input [8*40:1] s);                        // phát các byte khác 0 của s rồi '\n'; ms_nl = RTC lúc '\n' vào FIFO
        begin
            for (uk = 39; uk >= 0; uk = uk - 1) if (s[8*uk+1 +: 8] != 0) ubyte(s[8*uk+1 +: 8]);
            ubyte(8'd10);
            ms_nl = dut.ms;
        end
    endtask
    function [7:0] xs(input [8*40:1] s);                 // XOR mọi byte (byte 0 đệm trái không đổi kết quả)
        integer q;
        begin xs = 0; for (q = 0; q < 40; q = q + 1) xs = xs ^ s[8*q+1 +: 8]; end
    endfunction
    function [15:0] hx2(input [7:0] v);                  // 2 chữ số hex hoa
        begin
            hx2[15:8] = v[7:4] < 10 ? "0" + v[7:4] : "A" + v[7:4] - 10;
            hx2[7:0]  = v[3:0] < 10 ? "0" + v[3:0] : "A" + v[3:0] - 10;
        end
    endfunction
    task tsent(input integer m, input integer dy);       // usent = "$T,<m>,<dy>*CS"
        begin
            $sformat(ubody, "T,%0d,%0d", m, dy);
            $sformat(usent, "$T,%0d,%0d*%s", m, dy, hx2(xs(ubody)));
        end
    endtask
    task tline(input [7:0] c, input integer m0, input integer m1, input integer dy, input [8*40:1] got);
        begin                                            // ok = got là "$<c>,<m>,<dy>*CS" với m0 ≤ m ≤ m1 nào đó; v1 = m
            ok = 0;  v1 = -1;
            for (ut = m0; ut <= m1 && !ok; ut = ut + 1) begin
                $sformat(ubody, "%c,%0d,%0d", c, ut, dy);
                $sformat(usent, "$%c,%0d,%0d*%s", c, ut, dy, hx2(xs(ubody)));
                if (usent == got) begin ok = 1; v1 = ut; end
            end
        end
    endtask
    task cal_step(input integer t2, input integer dy2, input integer dd, input integer cal_exp, input [8*72:1] what);
        begin                                            // chip đang ở T2 + dd (đóng băng) khi nhận câu đặt giờ T2
            force dut.u_tb.en = 1'b0;
            warp(t2 + dd, dy2, (dy2 + 6) % 7);
            tsent(t2, dy2);
            usend(usent);
            repeat (3000) @(negedge clk);                // firmware lấy '\n', tính CAL, chờ ARM (cần tick)
            release dut.u_tb.en;
            wait_ms(5);
            check(dut.cal == cal_exp, what);
            check(dut.day == dy2 && dut.ms >= t2 && dut.ms < t2 + 10, "dat gio T2 sau khi tinh CAL");
            if (dut.cal != cal_exp) $display("  CAL = %0d, mong %0d", dut.cal, cal_exp);
        end
    endtask

    // ------------------------------------------------------------------ hàm mong đợi (display-spec §8)
    function [7:0] d8(input integer x);
        d8 = x;
    endfunction
    function [63:0] fA(input integer v);                 // "_MM.SS.mmm"
        integer mm, ss, mmm;
        begin
            mm = v / 60000;  ss = (v % 60000) / 1000;  mmm = v % 1000;
            fA = {8'h1A, d8(mm / 10), 8'h80 | d8(mm % 10), d8(ss / 10), 8'h80 | d8(ss % 10),
                  d8(mmm / 100), d8((mmm / 10) % 10), d8(mmm % 10)};
        end
    endfunction
    function [63:0] fB(input integer v, input integer h12);   // "__HH.MM.SS" / "A_HH.MM.SS" / "P_HH.MM.SS"
        integer s, hh, mi, se;
        reg [7:0] c7;
        begin
            s = v / 1000;  hh = s / 3600;  mi = (s % 3600) / 60;  se = s % 60;  c7 = 8'h1A;
            if (h12 != 0) begin
                c7 = (hh >= 12) ? 8'h14 : 8'h0A;
                hh = hh % 12;
                if (hh == 0) hh = 12;
            end
            fB = {c7, 8'h1A, d8(hh / 10), 8'h80 | d8(hh % 10), d8(mi / 10), 8'h80 | d8(mi % 10), d8(se / 10),
                  d8(se % 10)};
        end
    endfunction
    function [63:0] fD(input integer v);                 // stopwatch / trị tuyệt đối timer
        begin
            if (v >= 360000000)    fD = {8'h1A, 8'h1A, 8'h19, 8'h99, 8'h19, 8'h99, 8'h19, 8'h19};
            else if (v >= 3600000) fD = fB(v, 0);
            else                   fD = fA(v);
        end
    endfunction
    function [63:0] fT(input integer x);                 // timer có dấu
        reg [63:0] t;
        begin
            if (x < -359999999) fT = {8'h19, 8'h1A, 8'h19, 8'h99, 8'h19, 8'h99, 8'h19, 8'h19};
            else begin
                t = fD(x < 0 ? -x : x);
                fT = {x < 0 ? 8'h19 : 8'h1A, t[55:0]};
            end
        end
    endfunction
    function [63:0] fAL(input integer kk, input integer en, input integer m);   // "ALko HH.MM"
        begin
            fAL = {8'h0A, 8'h11, d8(kk), en ? 8'h13 : 8'h1A, d8(m / 60 / 10), 8'h80 | d8(m / 60 % 10),
                   d8(m % 60 / 10), d8(m % 60 % 10)};
        end
    endfunction
    function [63:0] fDT(input integer dd, input integer mo, input integer yy);  // "dd-MM-YY"
        begin
            fDT = {d8(dd / 10), d8(dd % 10), 8'h19, d8(mo / 10), d8(mo % 10), 8'h19, d8(yy % 100 / 10),
                   d8(yy % 10)};
        end
    endfunction

    // ------------------------------------------------------------------ tiện ích
    task check(input cond, input [8*72:1] what);
        begin
            nchk = nchk + 1;
            if (!cond) begin nerr = nerr + 1; $display("  loi: %0s", what); end
        end
    endtask
    task checkf(input [63:0] got, input [63:0] exp, input [8*72:1] what);
        begin
            nchk = nchk + 1;
            if (got !== exp) begin
                nerr = nerr + 1;  $display("  loi: %0s: man %h, mong %h", what, got, exp);
            end
        end
    endtask
    task done(input integer kk, input [8*64:1] what);
        begin
            if (nerr == 0) $display("PASS sys_%0d %0s", kk, what);
            else           $display("FAIL sys_%0d %0s (%0d loi)", kk, what, nerr);
            nerr_all = nerr_all + nerr;  nerr = 0;
        end
    endtask
    task wait_ms(input integer n);
        repeat (n * 50) @(negedge clk);
    endtask
    task frame;                                          // chờ firmware ghi xong DISP7 → fr = 8 ô vừa vẽ
        begin
            @(negedge clk);
            v4 = cyc;
            while (!(dut.bus_we && dut.bus_addr == 8'h78)) begin
                @(negedge clk);
                if (cyc > v4 + 20000) begin
                    $display("FAIL system_tb: 400 ms khong co khung (pc %h, cyc %0d)", dut.pc, cyc);  $finish;
                end
            end
            @(negedge clk);
            fr = dut.u_disp.disp;
        end
    endtask
    task frame2;                                         // khung thứ 2: chắc chắn đã đọc giá trị sau thời điểm gọi
        begin frame; frame; end
    endtask
    task press(input integer b);                         // cạnh đầu ngay lúc gọi, rung, giữ 20 ms, nhả có rung
        begin
            btn[b] = 1'b1;  t_edge = cyc;  ms_edge = dut.ms;
            repeat (7) @(negedge clk);  btn[b] = 1'b0;
            repeat (5) @(negedge clk);  btn[b] = 1'b1;
            repeat (11) @(negedge clk); btn[b] = 1'b0;
            repeat (3) @(negedge clk);  btn[b] = 1'b1;
            wait_ms(20);
            btn[b] = 1'b0;
            repeat (9) @(negedge clk);  btn[b] = 1'b1;
            repeat (4) @(negedge clk);  btn[b] = 1'b0;
            wait_ms(15);
            frame2;                                      // firmware đã xử lý sự kiện và vẽ lại
        end
    endtask
    task warp(input integer m, input integer dy, input integer dw);   // tua giờ RTC (chỉ tb)
        begin
            @(negedge clk);
            dut.u_rtc.ms = m;  dut.u_rtc.day = dy;  dut.u_rtc.dow = dw;
        end
    endtask
    task freeze_rtc_frame;                               // RTC đứng yên → khung vẽ đúng giá trị đang có
        begin
            force dut.u_tb.en = 1'b0;                    // bộ chia ms đứng yên (cnt giữ nguyên), thả ra chạy tiếp
            frame2;
            v5 = dut.ms;
            release dut.u_tb.en;
        end
    endtask

    // ------------------------------------------------------------------ chạy
    initial begin
        cyc = 0; nchime = 0; nchk = 0; nerr_all = 0; nerr = 0; nbad = 0; nal = 0; nlap = 0; c0 = 0; cz = 0;
        if (!$value$plusargs("imem=%s", fimem)) begin $display("FAIL system_tb thieu +imem="); $finish; end
        poll = $test$plusargs("poll");
        fd = $fopen("tb/vectors/seg7.txt", "r");
        r = $fgets(line, fd);
        while (!$feof(fd)) begin
            r = $fscanf(fd, "%h %h\n", v1, v2);
            if (r == 2) rom7[v1] = v2;
        end
        $fclose(fd);

        // ---- sys_0: hàm mong đợi của tb khớp vector của spec
        fd = $fopen("tb/vectors/fmt_time.txt", "r");
        while (!$feof(fd)) begin
            r = $fgets(line, fd);
            r = $sscanf(line, "%d | %h %h %h %h %h %h %h %h | %h %h %h %h %h %h %h %h | %h %h %h %h %h %h %h %h", v1,
                        e1[63:56], e1[55:48], e1[47:40], e1[39:32], e1[31:24], e1[23:16], e1[15:8], e1[7:0],
                        e2[63:56], e2[55:48], e2[47:40], e2[39:32], e2[31:24], e2[23:16], e2[15:8], e2[7:0],
                        e3[63:56], e3[55:48], e3[47:40], e3[39:32], e3[31:24], e3[23:16], e3[15:8], e3[7:0]);
            if (r == 25) begin
                checkf(fB(v1, 0), e1, "fmt_time 24h");  checkf(fB(v1, 1), e2, "fmt_time 12h");
                checkf(fA(v1 % 3600000), e3, "fmt_time giay.ms");
            end
        end
        $fclose(fd);
        fd = $fopen("tb/vectors/fmt_sw.txt", "r");
        while (!$feof(fd)) begin
            r = $fgets(line, fd);
            r = $sscanf(line, "%d | %h %h %h %h %h %h %h %h", v1,
                        e1[63:56], e1[55:48], e1[47:40], e1[39:32], e1[31:24], e1[23:16], e1[15:8], e1[7:0]);
            if (r == 9) checkf(fD(v1), e1, "fmt_sw");
        end
        $fclose(fd);
        fd = $fopen("tb/vectors/fmt_timer.txt", "r");
        while (!$feof(fd)) begin
            r = $fgets(line, fd);
            r = $sscanf(line, "%d | %h %h %h %h %h %h %h %h", v1,
                        e1[63:56], e1[55:48], e1[47:40], e1[39:32], e1[31:24], e1[23:16], e1[15:8], e1[7:0]);
            if (r == 9) checkf(fT(v1), e1, "fmt_timer");
        end
        $fclose(fd);
        fd = $fopen("tb/vectors/fmt_alarm.txt", "r");
        while (!$feof(fd)) begin
            r = $fgets(line, fd);
            r = $sscanf(line, "%d %d %d | %h %h %h %h %h %h %h %h", v1, v2, v3,
                        e1[63:56], e1[55:48], e1[47:40], e1[39:32], e1[31:24], e1[23:16], e1[15:8], e1[7:0]);
            if (r == 11) checkf(fAL(v1, v2, v3), e1, "fmt_alarm");
        end
        $fclose(fd);
        k = 0;
        fd = $fopen("tb/vectors/date.txt", "r");
        while (!$feof(fd)) begin
            r = $fgets(line, fd);
            r = $sscanf(line, "%d %d %d %d %d | %h %h %h %h %h %h %h %h", v1, v2, v3, v4, v5,
                        e1[63:56], e1[55:48], e1[47:40], e1[39:32], e1[31:24], e1[23:16], e1[15:8], e1[7:0]);
            if (r == 13) begin checkf(fDT(v4, v3, v2 - 2000), e1, "date trang 2"); k = k + 1; end
        end
        $fclose(fd);
        check(k > 200 && nchk > 300, "doc du vector");
        $display("  sys_0: %0d dong vector", nchk);
        done(0, "ham mong doi cua tb khop fmt_*.txt, date.txt");

        // ---- khởi động: khối cấu hình DMEM 0x7E0 = 23:59:59.990 Thứ 6 02/10/2026 (ngày 9771), timer 00:02.000
        #1;
        $readmemh(fimem, dut.u_cpu.imem);
        if ($value$plusargs("trace=%s", ftrace)) dut.u_cpu.tf = $fopen(ftrace, "w");   // trace isa-spec §8 cho cosim_iss
        dut.u_cpu.dmem[504] = 1;
        dut.u_cpu.dmem[505] = 86399990;
        dut.u_cpu.dmem[506] = (5 << 16) | 9771;
        dut.u_cpu.dmem[507] = 2000;
        repeat (6) @(negedge clk);
        rst_in = 0;

        // ---- sys_1: qua nửa đêm, ngày +1, thứ đúng, không xé số; 12 h, giây.ms, trang ngày (+ quét date.txt)
        frame;
        k = 0; ok = 1;
        while (!(dut.day == 9772 && dut.ms >= 40) && cyc < 100000) begin
            if (fr !== fB(86399000, 0) && fr !== fB(0, 0)) begin
                ok = 0;  $display("  khung la qua nua dem: %h", fr);
            end
            k = k + 1;
            frame;
        end
        check(ok && k >= 1, "moi khung quanh nua dem la 23.59.59 hoac 00.00.00");
        checkf(fr, fB(0, 0), "sau nua dem hien 00.00.00");
        check(dut.day == 9772 && dut.dow == 6, "ngay 9772 (03/10/2026), thu 7 (dow 6)");
        press(B_A);                                      // 12 h
        freeze_rtc_frame;
        checkf(fr, fB(v5, 1), "12 h: 0 h -> A 12");
        warp(47100000, 9772, 6);                         // 13:05:00.000
        freeze_rtc_frame;
        checkf(fr, fB(v5, 1), "12 h: 13 h -> P 01");
        warp(1000, 9772, 6);                             // về 00:00:01.000
        press(B_A);
        press(B_B);                                      // giây.ms
        freeze_rtc_frame;
        checkf(fr, fA(v5 % 3600000), "TIME giay.ms");
        press(B_B);                                      // trang ngày
        checkf(fr, fDT(3, 10, 26), "trang ngay 03-10-26");
        k = 0;
        fd = $fopen("tb/vectors/date.txt", "r");
        while (!$feof(fd)) begin
            r = $fgets(line, fd);
            r = $sscanf(line, "%d %d %d %d %d | %h %h %h %h %h %h %h %h", v1, v2, v3, v4, v5,
                        e1[63:56], e1[55:48], e1[47:40], e1[39:32], e1[31:24], e1[23:16], e1[15:8], e1[7:0]);
            if (r == 13) begin
                warp(dut.ms, v1, v5);
                frame2;
                if (fr !== e1) begin k = k + 1; $display("  date.txt ngay %0d: man %h, mong %h", v1, fr, e1); end
            end
        end
        $fclose(fd);
        check(k == 0, "firmware d2ymd dung moi dong date.txt");
        warp(dut.ms, 9772, 6);
        press(B_B);                                      // về giờ
        done(1, "nua dem, ngay/thu, 12h, giay.ms, trang ngay");

        // ---- sys_2: stopwatch start/stop cách nhau 1234,56 ms (61 728 chu kỳ), nút có rung
        press(B_MODE);
        check(dut.u_sw.src == 1'b1, "vao STOPWATCH: SRC = 1");
        checkf(fr, fA(0), "stopwatch 00:00.000");
        press(B_A);
        c0 = t_edge;
        while (cyc < c0 + 61728) @(negedge clk);
        press(B_A);
        check(t_edge - c0 == 61728, "2 canh nhan cach 61 728 chu ky");
        check(dut.u_sw.run == 1'b0 && dut.u_sw.val == 1234, "SW_VALUE = 1234 (dung toi ms)");
        frame2;
        checkf(fr, fA(1234), "hien 00:01.234");
        done(2, "stopwatch 1234 ms");

        // ---- sys_3: reset, lap ×3, xem lại đúng thứ tự
        press(B_B);                                      // đang dừng → reset
        check(dut.u_sw.val == 0, "B khi dung = reset");
        checkf(fr, fA(0), "sau reset 00:00.000");
        nlap = 0;
        press(B_A);
        wait_ms(200);  press(B_B);
        wait_ms(250);  press(B_B);
        wait_ms(300);  press(B_B);
        wait_ms(100);  press(B_A);
        check(nlap == 3 && dut.u_sw.run == 1'b0, "phan cung chup 3 lap");
        check(lapv[0] < lapv[1] && lapv[1] < lapv[2], "lap tang dan");
        frame2;
        check(dut.u_sw.cnt == 0 && dut.u_cpu.dmem[12'h430 >> 2] == 3, "firmware lay het FIFO: LAPN = 3");
        for (i = 0; i < 3; i = i + 1) begin
            press(B_C);
            e2 = fD(lapv[i]);
            checkf(fr, {d8(i + 1), e2[55:0]}, "xem lap i (DISP7 = so lap)");
        end
        press(B_C);
        checkf(fr, fD(dut.u_sw.val), "C lan 4: ve gia tri dang dung");
        $display("  lap: %0d %0d %0d, dung o %0d ms", lapv[0], lapv[1], lapv[2], dut.u_sw.val);
        done(3, "lap x3 dung thu tu");

        // ---- sys_4: timer 00:02.000 → về 0 đúng ms, chuông, −00:00.500 ở 2,5 s
        press(B_MODE);
        check(dut.u_sw.src == 1'b0, "roi STOPWATCH: SRC = 0");
        checkf(fr, fT(2000), "timer 00:02.000");
        cz = 0;
        press(B_A);
        while (cz == 0 && cyc < c0 + 200000) @(negedge clk);
        check(cz - c0 == 100000, "ZERO dung 2000 ms (100 000 chu ky) sau RUN");
        @(negedge clk);
        check(dut.u_beep.pat == P_ALARM, "chuong 0x10F0F nap ngay luc ZERO");
        while (dut.u_tmr.val != -500) @(negedge clk);
        cv = cyc - 1;                                    // cạnh vừa đổi val (cyc đã tăng ở cạnh đó)
        force dut.u_tmr.tick = 1'b0;
        frame2;
        checkf(fr, fT(-500), "2,5 s: hien -00:00.500");
        release dut.u_tmr.tick;                          // cnt của bộ chia timer đã vượt; B (ghi TMR_VALUE → clr) đưa về 0
        check(cv - c0 == 125000, "-500 dung 2500 ms (125 000 chu ky) sau RUN");
        $display("  RUN -> ZERO %0d chu ky, RUN -> -500 %0d chu ky", cz - c0, cv - c0);
        // biên ±100 h (display-spec §8): gán thẳng TMR_VALUE (tick timer đã đứng sau lần đóng băng)
        @(negedge clk) dut.u_tmr.val = -359999999;
        frame2;
        checkf(fr, fT(-359999999), "-359 999 999 -> -_99.59.59");
        @(negedge clk) dut.u_tmr.val = -360000000;
        frame2;
        checkf(fr, fT(-360000000), "-360 000 000 -> -_--.--.--");
        @(negedge clk) dut.u_tmr.val = 32'h8000_0000;
        frame2;
        checkf(fr, fT(-2147483648), "-2^31 -> -_--.--.-- (so truoc khi lay tri tuyet doi)");
        press(B_B);                                      // nút đầu chỉ tắt chuông
        check(dut.u_beep.pat == 17'd0 && dut.u_tmr.run == 1'b1, "nut dau: tat chuong, timer van chay");
        press(B_B);                                      // về giá trị đặt
        check(dut.u_tmr.run == 1'b0 && dut.u_tmr.zero == 1'b0 && dut.u_tmr.val == 2000, "B: ve 2000, dung, xoa ZERO");
        checkf(fr, fT(2000), "lai 00:02.000");
        done(4, "timer ve 0 dung ms, chuong, so am");

        // ---- sys_5: báo thức 07:00 thứ 2 → kêu đúng phút; snooze 5 phút; tự tắt sau 60 s; Chủ nhật không kêu
        press(B_MODE);
        checkf(fr, fAL(1, 0, 420), "ALARM: AL1 07.00 tat");
        press(B_A);
        checkf(fr, fAL(1, 1, 420), "A: AL1 bat");
        k = nal;
        warp(25199990, 9774, 1);                         // Thứ 2 05/10/2026 06:59:59.990
        v2 = cyc;
        while (nal == k && cyc < v2 + 5000) @(negedge clk);
        check(dut.ms == 25200000 && dut.dow == 1, "HIT dung 07:00:00.000 thu 2");
        while (dut.u_beep.pat != P_ALARM && dut.ms < 25200000 + 40) @(negedge clk);
        check(dut.u_beep.pat == P_ALARM, "firmware keu 0x10F0F trong 40 ms");
        $display("  bao thuc: HIT o ms %0d, chuong o ms %0d", 25200000, dut.ms);
        press(B_C);                                      // snooze
        v1 = ms_edge;
        check(dut.u_beep.pat == 17'd0, "C: tat chuong (snooze)");
        warp(v1 + 300000 - 20, 9774, 1);
        while (dut.u_beep.pat != P_ALARM && dut.ms < v1 + 300000 + 100) @(negedge clk);
        ring_ms = dut.ms;
        check(ring_ms >= v1 + 300000 && ring_ms <= v1 + 300000 + 40, "snooze: keu lai 5 phut sau luc nhan C");
        $display("  snooze: nhan C o ms %0d, keu lai o ms %0d (+%0d ms)", v1, ring_ms, ring_ms - v1);
        warp(ring_ms + 60000 - 20, 9774, 1);
        while (dut.u_beep.pat != 17'd0 && dut.ms < ring_ms + 60000 + 100) @(negedge clk);
        off_ms = dut.ms;
        check(dut.u_beep.pat == 17'd0 && off_ms >= ring_ms + 59999 && off_ms <= ring_ms + 60040,
              "chuong tu tat sau 60 s");
        k = nal;
        warp(25199990, 9780, 0);                         // Chủ nhật 11/10/2026 06:59:59.990
        wait_ms(100);
        check(nal == k && dut.u_beep.pat != P_ALARM, "Chu nhat: khong keu (DAYMASK)");
        for (i = 0; i < 4; i = i + 1) press(B_B);        // → trang chuông giờ
        checkf(fr, {8'h0C, 8'h10, 8'h1A, 8'h1A, 8'h1A, 8'h1A, 8'h1A, 8'h1A}, "trang chuong gio (tat)");
        press(B_A);
        check(fr[39:32] == 8'h13, "A: chuong gio bat");
        warp(28799990, 9780, 0);                         // 07:59:59.990
        while (dut.u_beep.pat != 17'h00005 && dut.ms < 28800000 + 60) @(negedge clk);
        check(dut.u_beep.pat == 17'h00005 && dut.ms >= 28800000, "chuong gio 0x00005 khi qua 08:00");
        press(B_B);                                      // về AL1
        press(B_C);                                      // sửa giờ báo thức AL1 (đang bật, 07:00)
        check(dut.u_disp.blink_mask == 8'h0C, "sua bao thuc: gio nhay (0x0C)");
        press(B_A);
        press(B_B);
        check(dut.u_disp.blink_mask == 8'h03, "sua bao thuc: phut nhay (0x03)");
        press(B_A);
        checkf(fr, fAL(1, 1, 481), "dang sua: 08.01");
        press(B_C);
        check(dut.u_disp.blink_mask == 8'h00, "luu: het nhay");
        checkf(fr, fAL(1, 1, 481), "luu: AL1 doc lai tu ALARM0 = 08.01, van bat");
        done(5, "bao thuc, snooze, tu tat, Chu nhat, chuong gio, sua gio");

        // ---- sys_6: SET: trường nháy (BLINK_MASK), giờ 23 + 1 → 0, lưu; ngày +1 → thứ đúng
        warp(84615000, 9780, 0);                         // 23:30:15.000
        press(B_MODE);
        checkf(fr, fB(84615000, 0), "SET: chup 23.30.15");
        check(dut.u_disp.blink_mask == 8'h30, "SET: gio nhay (0x30)");
        v1 = nscr_off;
        wait_ms(600);                                    // D7: qua trọn 1 chu kỳ nháy → màn ảo thấy giờ tắt rồi sáng lại
        check(nscr_off > v1 && u_scr.lit == 8'hFF, "D7: chan thay o 5, 4 tat nua chu ky nhay roi sang lai");
        press(B_A);
        checkf(fr, fB(1815000, 0), "gio 23 + 1 -> 00");
        check(dut.u_disp.blink_mask == 8'h30, "van nhay gio");
        e1 = {8'h0C, 8'h03, 8'hC0, 8'h18, 8'h03, 8'h30, 8'h00, 8'h00};
        for (i = 0; i < 6; i = i + 1) begin
            press(B_B);
            check(dut.u_disp.blink_mask == e1[63 - 8 * i -: 8], "B: BLINK_MASK theo truong");
            if (i == 2) checkf(fr, fDT(11, 10, 26), "truong ngay: hien 11-10-26");
        end
        checkf(fr, fB(1815000, 0), "B x6: ve truong gio");
        k = nchime;
        press(B_C);                                      // lưu (chuông giờ đang bật: nhảy 23 h → 0 h không được kêu)
        wait_ms(50);
        check(nchime == k, "luu gio: khong keu chuong gio vi nhay gio");
        check(dut.ms >= 1815000 && dut.ms < 1815000 + 150, "luu: RTC = 00:30:15");   // nhấn ~55 ms + 50 ms (26/10: +sync → 100 ms sát)
        check(dut.day == 9780 && dut.dow == 0, "luu: ngay giu nguyen 9780, Chu nhat (doi qua lai dung)");
        check(dut.u_disp.blink_mask == 8'h00 && dut.u_cpu.dmem[12'h400 >> 2] == 0, "ve TIME, het nhay");
        checkf(fr, fB(1815000, 0), "TIME hien 00.30.15");
        for (i = 0; i < 4; i = i + 1) press(B_MODE);     // → SET
        for (i = 0; i < 3; i = i + 1) press(B_B);        // → trường ngày
        check(dut.u_disp.blink_mask == 8'hC0, "truong ngay nhay (0xC0)");
        press(B_A);
        checkf(fr, fDT(12, 10, 26), "ngay 11 + 1 = 12");
        press(B_C);
        check(dut.day == 9781 && dut.dow == 1, "luu 12/10/2026 = ngay 9781, thu 2");
        warp(dut.ms, 9892, 0);                           // 31/01/2027 Chủ nhật
        for (i = 0; i < 4; i = i + 1) press(B_MODE);     // → SET
        for (i = 0; i < 4; i = i + 1) press(B_B);        // → trường tháng
        check(dut.u_disp.blink_mask == 8'h18, "truong thang nhay (0x18)");
        press(B_A);
        checkf(fr, fDT(28, 2, 27), "31/01 + 1 thang -> 28/02/2027 (kep ngay)");
        press(B_C);
        check(dut.day == 9920 && dut.dow == 0, "luu 28/02/2027 = ngay 9920, Chu nhat");
        done(6, "SET: nhay, 23+1 -> 0, luu, ngay/thu, kep ngay");

        // ---- sys_7: đồng bộ giờ qua UART (timer-spec §9): $Z từ sys_4, $T đúng/sai, $Q → $R, CAL sau 2 lần đặt giờ
        check(nl == 1, "truoc sys_7 chip chi phat 1 dong ($Z o sys_4)");
        tline("Z", zms, zms + 30, zday, lns[0]);
        check(ok, "$Z,<ms luc ZERO>,<ngay>*CS dung tung byte");
        $display("  $Z: ms %0d (ZERO o ms %0d)", v1, zms);
        tsent(54149696, 64284);
        check(usent == "$T,54149696,64284*6C", "cau tb dung = dong 1 sync_sentences.txt");
        usend(usent);
        wait_ms(40);                                     // G_N = 50: 1 vòng firmware ~10 ms mô phỏng; LF → đặt giờ đo được
                                                         // 25 ms, 31 ms từ 27/10 (chép bộ đệm đôi 300 chu kỳ = 6 µs chip thật)
        check(dut.day == 64284 && dut.dow == (64284 + 6) % 7, "$T: ngay 64284, thu = (ngay + 6) mod 7");
        check(dut.ms >= 54149696 && dut.ms < 54149696 + 30, "$T: ms = 54 149 696 (+ vai ms)");
        d0 = dut.ms;
        usend("$T,82685073,36744*62");                   // sai checksum
        usend("$T,1028,5*6a");                           // checksum chữ thường
        usend("T,1000,5*60");                            // thiếu '$'
        usend("$T,86400000,1*6F");                       // ms quá ngày
        usend("garbage-garbage-garbage-garbage-garbage"); // > 32 byte
        wait_ms(30);
        check(dut.day == 64284 && dut.ms > d0, "5 cau sai: khong dat gio");
        check(nl == 1, "cau sai: khong tra loi");
        usend("$Q*51");
        wait_ms(60);                                     // ≤ 1 vòng firmware + 21 byte × 80 chu kỳ
        check(nl == 2, "$Q: dung 1 dong tra loi");
        // ngắt UART_RX: chụp giờ vài chục chu kỳ sau LF (1 ms = 50 chu kỳ ở G_N = 50); polling: trễ ≤ 1 vòng (~10 ms)
        check(dut.u_irq.enable == (poll ? 8'h00 : 8'h40), "IRQ_ENABLE dung che do (USE_IRQ 0: 00, 1: 40)");
        tline("R", ms_nl - 1, ms_nl + (poll ? 20 : 1), 64284, lns[1]);
        check(ok, "$R,<ms luc nhan LF>,64284*CS dung tung byte");
        $display("  $Q: LF vao FIFO o ms %0d, $R tra ms %0d", ms_nl, v1);
        if (!ok) $display("  dong nhan duoc: %0s", lns[1]);
        // CAL: T1 = 54 149 696 (câu $T ở trên). Mỗi bước: chip lệch dd ms so với T2 lúc nhận câu
        check(dut.cal == 0, "CAL ban dau 0");
        cal_step(57749696, 64284, 72, 65500, "I 1 h, D +72 -> CAL 65 500 (sync_cal dong 1)");
        cal_step(61349696, 64284, -72, 0, "I 1 h, D -72 -> CAL 65 500 - 65 500 = 0");
        cal_step(64949696, 64284, 858994, 0, "D 858 994: |D| x 5000 tran 32 bit -> van bo");
        cal_step(65249696, 64284, 10, 0, "I 300 000 < 600 000 -> bo, giu T1, cong don D = 10");
        cal_step(449696, 64285, 432, 66100, "I tu T1 giu lai = 6 h 5 ph qua nua dem, D 432 + 10 -> +66 100");
        check(nl == 2, "$T khong tra loi");
        done(7, "sync UART: $Z, $T, cau sai, $Q/$R, CAL");

        check(nscr > 1000 && nscr_bad == 0, "D7: anh tu chan = Display RAM qua seg7.txt (moi vong quet on dinh)");
        $display("  D7: %0d vong quet duoc so, %0d vong co chu so tat (nhay / BRIGHT 0), %0d sai -> work/screen_system.log",
                 nscr, nscr_off, nscr_bad);
        check(nbad == 0, "khong lenh la");
        if (nbad != 0) $display("  %0d lenh la", nbad);
        nerr_all = nerr_all + nerr;
        $display("chay %0d chu ky (%0d ms mo phong)", cyc, cyc / 50);
        if (nerr_all == 0) $display("PASS system_tb %0d", nchk);
        else               $display("FAIL system_tb %0d loi / %0d kiem tra", nerr_all, nchk);
        $finish;
    end
endmodule
