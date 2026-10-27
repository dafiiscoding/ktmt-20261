// soc_clock_tb.v — (fw: fw/demo/clock.s) đồng hồ chạy bằng firmware thật trên CPU G1 trong soc_top.
// run_unit.sh dịch fw/demo/clock.s → work/soc_clock.hex rồi chạy với +imem=work/soc_clock.hex.
// G_N = 50 (1 ms = 50 chu kỳ). Firmware đặt 23:59:55 ngày 02/10/2026 (Thứ Sáu), bật ngắt TICK_1S,
// mỗi ngắt đọc MS_OF_DAY và ghi 8 ô DISP (div + mul + bcd). Chạy qua nửa đêm tới 00:00:05.
// Kiểm:
//   - giữa mỗi giây (ms % 1000 = 500): Display RAM == "__HH.MM.SS" của giờ RTC             [B7/C8 rút gọn]
//   - số lần vào handler == số xung TICK_1S sau khi bật ngắt; không lệnh lạ
//   - độ trễ ngắt: CYCLE_COUNT lúc vào handler − IRQ_STAMP (C5-5, D = 2), in min/max
//   - màn ảo (chỉ đọc chân) cuối cùng khớp DISP qua ROM ký tự (seg7.txt); RTC qua nửa đêm: 03/10, Thứ Bảy
// Xem ảnh: python tools/screen.py work/screen_soc_clock.log
`timescale 1ns/1ps
module soc_clock_tb;
    reg  clk = 0, rst_in = 1;
    wire [7:0] an;
    wire [6:0] seg;
    wire       dp;

    soc_top #(.G_N(50), .G_SLOT(40), .G_BLANK(4)) dut (.clk(clk), .rst_in(rst_in), .btn(4'b0), .an(an), .seg(seg), .dp(dp), .beep(), .uart_rx(1'b1), .uart_tx());
    screen_dump #(.G_DIGITS(8), .G_SLOT(40), .FILE("work/screen_soc_clock.log")) u_dump (
        .clk(clk), .rst(dut.rst), .tick_ms(dut.tick_ms), .an(an), .seg(seg), .dp(dp));

    always #10 clk = ~clk;

    integer fd, c, r, i, n, nerr, nsec, nirq, n1s, nbad, lat, lat_min, lat_max, ncmp;
    reg [8*256:1] fimem, ftrace, rest;
    reg [6:0]  golden [0:31];
    reg [31:0] e_code, e_seg;
    reg        irq_on;

    task check(input cond, input [8*48:1] what);
        begin
            n = n + 1;
            if (!cond) begin
                nerr = nerr + 1;
                if (nerr <= 10) $display("loi %0s: ms=%0d day=%0d disp=%h", what, dut.ms, dut.day, dut.u_disp.disp);
            end
        end
    endtask

    // TIME 24 h `__HH.MM.SS` (display-spec §8) → {DISP7, …, DISP0}; giống clock_demo_tb (đã so fmt_time.txt)
    function [63:0] fmt24(input [31:0] t);
        reg [31:0] h, m, s;
        reg [7:0]  h1, h0, m1, m0, s1, s0;
        begin
            h = t / 3600000; m = (t / 60000) % 60; s = (t / 1000) % 60;
            h1 = h / 10; h0 = h % 10; m1 = m / 10; m0 = m % 10; s1 = s / 10; s0 = s % 10;
            fmt24 = {8'h1A, 8'h1A, h1, h0 | 8'h80, m1, m0 | 8'h80, s1, s0};
        end
    endfunction

    // giám sát: so màn giữa giây; đếm ngắt và độ trễ
    always @(posedge clk) if (!dut.rst) begin
        if (dut.tick_ms && dut.u_cpu.status[0] && (dut.ms % 1000) == 499) begin   // ms sẽ thành x500 ở cạnh này
            ncmp = ncmp + 1;
            check(dut.u_disp.disp == fmt24(dut.ms + 1), "giua giay: DISP == gio RTC");
        end
        if (dut.tick_1s && irq_on) n1s = n1s + 1;
        if (dut.u_cpu.retire && dut.u_cpu.take_irq) nirq = nirq + 1;
        // lệnh đầu handler xong ở pha A: CYCLE_COUNT lúc đó − IRQ_STAMP
        if (dut.u_cpu.retire && dut.u_cpu.pc == 32'h180) begin
            lat = dut.cycle_count - dut.u_irq.stamp;
            if (lat < lat_min) lat_min = lat;
            if (lat > lat_max) lat_max = lat;
        end
        if (dut.u_cpu.retire && !dut.u_cpu.valid) nbad = nbad + 1;
    end
    always @(posedge clk) if (!dut.rst && dut.u_irq.enable[1] && dut.u_cpu.status[0]) irq_on <= 1'b1;

    initial begin
        n = 0; nerr = 0; nirq = 0; n1s = 0; nbad = 0; ncmp = 0; lat_min = 1 << 30; lat_max = 0; irq_on = 0;
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

        if (!$value$plusargs("imem=%s", fimem)) begin $display("FAIL soc_clock_tb thieu +imem="); $finish; end
        #1;                                     // sau initial xóa imem của cpu_g1 (cùng t = 0 thì thứ tự tùy simulator)
        $readmemh(fimem, dut.u_cpu.imem);
        if ($value$plusargs("trace=%s", ftrace)) dut.u_cpu.tf = $fopen(ftrace, "w");   // trace isa-spec §8 cho cosim_iss
        repeat (6) @(negedge clk);
        rst_in = 0;

        // chạy tới 00:00:05.600 ngày 03/10 (hoặc hết 20 s mô phỏng)
        while (!(dut.day == 9772 && dut.ms >= 5600) && dut.cycle_count < 20 * 1000 * 50) @(negedge clk);

        check(dut.day == 9772 && dut.dow == 6, "qua nua dem: 03/10 Thu Bay");
        check(ncmp == 11, "so giua giay du 11 lan (55..59, 00..05)");
        check(nirq == n1s && nirq >= 10, "so lan vao handler == so xung TICK_1S");
        check(nbad == 0, "khong lenh la");
        check(dut.u_disp.disp == fmt24(dut.ms), "cuoi: DISP = 00.00.05");
        for (i = 0; i < 8; i = i + 1)
            check(u_dump.last[8*i +: 8] == {dut.u_disp.disp[8*i + 7], golden[dut.u_disp.disp[8*i +: 5]]},
                  "man ao (chan) khop DISP");
        $display("ngat: %0d lan, do tre (CYCLE_COUNT dau handler - IRQ_STAMP) min %0d max %0d chu ky he thong (D = 2)",
                 nirq, lat_min, lat_max);
        $display("man ao: %0d anh -> work/screen_soc_clock.log", u_dump.nframes);

        if (nerr == 0) $display("PASS soc_clock_tb %0d", n);
        else $display("FAIL soc_clock_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
