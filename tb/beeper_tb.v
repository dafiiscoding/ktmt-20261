// beeper_tb.v — gói D3 (bộ tạo âm): BP-1…BP-3 (display-spec §9) + reset 12 500, FREQ = 0 im, ghi 0 tắt ngay, pha sóng bắt đầu lại mỗi lần kêu,
// hw_trig trùng chu kỳ CPU ghi mẫu → hw thắng. G_N = 50 → 1 khe 64 ms = 3 200 chu kỳ.
`timescale 1ns/1ps
module beeper_tb;
    localparam A_FREQ = 8'h84, A_PAT = 8'h88, SLOT = 64 * 50;

    reg         clk = 0, rst = 1, bus_we = 0, hw_trig = 0;
    reg  [7:0]  bus_addr = 0;
    reg  [31:0] bus_wdata = 0;
    wire        tick_ms, beep, sounding;

    timebase #(.G_N(50)) u_tb (.clk(clk), .rst(rst), .clr(1'b0), .en(1'b1), .cal(32'sd0), .tick(tick_ms));
    beeper dut (.clk(clk), .rst(rst), .tick_ms(tick_ms), .hw_trig(hw_trig), .bus_addr(bus_addr),
                .bus_wdata(bus_wdata), .bus_we(bus_we), .beep(beep), .sounding(sounding));

    always #10 clk = ~clk;

    integer n, nerr, cyc, last_edge, gap_bad, nedge, i;
    reg     beep_q;
    reg [15:0] son;                     // khe nào có kêu (đo theo thời gian từ lúc ghi)
    integer t_load, t_on, nstart, nphase_bad;
    reg     snd_q;

    task check(input cond, input [8*48:1] what);
        begin
            n = n + 1;
            if (!cond) begin nerr = nerr + 1; if (nerr <= 10) $display("loi %0s: son=%b gap_bad=%0d nedge=%0d pat=%h", what, son, gap_bad, nedge, dut.pat); end
        end
    endtask
    task wr(input [7:0] a, input [31:0] d);
        begin @(negedge clk); bus_addr = a; bus_wdata = d; bus_we = 1; t_load = cyc + 1; @(negedge clk); bus_we = 0; end
    endtask
    // ghi lại khe nào có `sounding` trong 16 khe kể từ lúc nạp (khe tính theo tick_ms thật, lấy mẫu giữa khe)
    task watch16;
        begin
            son = 0;
            for (i = 0; i < 16; i = i + 1) begin
                while (dut.slot != i[3:0] || dut.tc != 6'd32) @(negedge clk);
                son[i] = sounding;
                @(negedge clk);
            end
        end
    endtask

    always @(posedge clk) begin
        cyc <= cyc + 1;
        beep_q <= beep;
        if (beep !== beep_q && sounding && dut.wc == 16'd0 && cyc > 0) begin
            nedge = nedge + 1;
            if (last_edge >= 0 && cyc - last_edge != dut.freq) gap_bad = gap_bad + 1;
            last_edge = cyc;
        end
        if (!sounding) last_edge = -1;
        // mỗi lần bắt đầu kêu (khe im → khe kêu, hoặc nạp): sóng bắt đầu từ mức 0, cạnh lên đầu sau đúng FREQ chu kỳ
        snd_q <= sounding;
        if (sounding && !snd_q) t_on = cyc;
        if (beep && !beep_q && t_on >= 0) begin
            nstart = nstart + 1;
            if (cyc - t_on != dut.freq) nphase_bad = nphase_bad + 1;
            t_on = -1;
        end
        if (beep && !sounding) gap_bad = gap_bad + 1000;    // không bao giờ kêu khi khe tắt
    end

    initial begin
        n = 0; nerr = 0; cyc = 0; gap_bad = 0; nedge = 0; last_edge = -1; beep_q = 0; snd_q = 0; t_on = -1;
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);
        check(dut.freq == 12500 && !beep, "reset: FREQ = 12500, im");

        // ---- BP-1: 0x00005, FREQ = 4 → kêu khe 0, im khe 1, kêu khe 2, rồi im hẳn; đảo mỗi 4 chu kỳ
        wr(A_FREQ, 4);
        nedge = 0; gap_bad = 0; nstart = 0; nphase_bad = 0;
        wr(A_PAT, 32'h5);
        watch16;
        check(son == 16'h0005, "BP-1 khe 0, 2 keu; con lai im");
        repeat (SLOT) @(negedge clk);
        check(dut.pat == 0 && !sounding, "BP-1 het 16 khe -> mau ve 0");
        check(gap_bad == 0 && nedge > 2 * SLOT / 4 - 10, "BP-1 song vuong dao dung moi 4 chu ky");
        check(nstart == 2 && nphase_bad == 0, "BP-1 khe 0 va khe 2: song bat dau tu 0, canh len sau FREQ");

        // ---- BP-2: REPEAT → lặp sau 16 khe
        wr(A_PAT, 32'h1_0003);
        watch16;
        check(son == 16'h0003, "BP-2 vong 1");
        watch16;
        check(son == 16'h0003, "BP-2 lap sau 16 khe");
        // ghi 0 = tắt ngay
        wr(A_PAT, 0);
        @(negedge clk); check(!sounding && !beep, "ghi 0: tat ngay");

        // ---- BP-3: hw_trig → nạp 0x10F0F, kêu từ chu kỳ đó
        @(negedge clk); hw_trig = 1; @(negedge clk); hw_trig = 0;
        check(sounding && dut.pat == 17'h10F0F && dut.slot == 0, "BP-3 hw_trig: keu tu chu ky do, mau 0x10F0F");
        watch16;
        check(son == 16'h0F0F, "BP-3 mau 256 ms keu, 256 ms nghi");
        // hw_trig trùng chu kỳ CPU ghi mẫu → hw thắng
        @(negedge clk); bus_addr = A_PAT; bus_wdata = 32'h1; bus_we = 1; hw_trig = 1;
        @(negedge clk); bus_we = 0; hw_trig = 0;
        check(dut.pat == 17'h10F0F, "hw_trig trung CPU ghi: hw thang");
        // FREQ = 0 → im dù khe bật
        wr(A_FREQ, 0);
        repeat (100) @(negedge clk);
        check(!sounding && !beep, "FREQ = 0: im");
        // ghi mẫu giữa khe → bắt đầu lại từ khe 0, đủ 64 ms
        wr(A_FREQ, 6); wr(A_PAT, 32'h2);
        repeat (SLOT / 2) @(negedge clk);
        wr(A_PAT, 32'h2);
        repeat (SLOT - 60) @(negedge clk);                  // khe 0 = 64 tick_ms kể từ lần ghi: 63–64 ms tùy pha
        check(!sounding, "ghi lai mau: bat dau lai tu khe 0");
        repeat (70) @(negedge clk);
        check(sounding, "sang khe 1 sau 64 tick ms");
        check(gap_bad == 0, "moi doan keu: dao dung moi FREQ chu ky, khong keu khi khe tat");

        if (nerr == 0) $display("PASS beeper_tb %0d", n);
        else $display("FAIL beeper_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
