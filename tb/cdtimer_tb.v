// cdtimer_tb.v — gói E3 (timer đếm ngược sang âm): TM-1…TM-5 (timer-spec §10), G_N = 50, CAL = 0.
`timescale 1ns/1ps
module cdtimer_tb;
    localparam A_VAL = 8'h28, A_CTL = 8'h2C;

    reg         clk = 0, rst = 1, bus_we = 0, bus_re = 0;
    reg  [7:0]  bus_addr = 0;
    reg  [31:0] bus_wdata = 0;
    wire [31:0] bus_rdata;
    wire        zero_ev, beep;

    cdtimer #(.G_N(50)) dut (.clk(clk), .rst(rst), .cal(32'sd0), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
                             .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(bus_rdata), .zero_ev(zero_ev), .beep(beep));

    always #10 clk = ~clk;

    integer n, nerr, cyc, nzero, nbeep, nbeep_bad, c_run, c_zero, ncoll;
    reg [31:0] rv, k_hold;

    task check(input cond, input [8*48:1] what);
        begin
            n = n + 1;
            if (!cond) begin nerr = nerr + 1; if (nerr <= 10) $display("loi %0s: val=%0d rv=%h", what, $signed(dut.val), rv); end
        end
    endtask
    task wr(input [7:0] a, input [31:0] d);
        begin @(negedge clk); bus_addr = a; bus_wdata = d; bus_we = 1; @(negedge clk); bus_we = 0; end
    endtask
    task rd(input [7:0] a);
        begin @(negedge clk); bus_addr = a; bus_re = 1; @(negedge clk); bus_re = 0; rv = bus_rdata; end
    endtask
    // ghi RUN = 1, ghi lại số chu kỳ của cạnh ghi
    task start;
        begin @(negedge clk); bus_addr = A_CTL; bus_wdata = 32'h1; bus_we = 1; c_run = cyc + 1; @(negedge clk); bus_we = 0; end
    endtask

    always @(posedge clk) begin
        cyc <= cyc + 1;
        if (zero_ev) begin nzero = nzero + 1; c_zero = cyc + 1; end      // cyc + 1 = số thứ tự cạnh này
        if (beep) nbeep = nbeep + 1;
        if (dut.tick && dut.w_val) ncoll = ncoll + 1;
        if (beep !== (zero_ev && dut.beep_en)) nbeep_bad = nbeep_bad + 1;
    end

    initial begin
        n = 0; nerr = 0; cyc = 0; nzero = 0; nbeep = 0; nbeep_bad = 0; ncoll = 0;
        repeat (3) @(negedge clk);
        rst = 0;

        // ---- TM-1: 2000, RUN → ZERO đúng tick thứ 2000 (cạnh thứ 2000·50 kể từ cạnh RUN); sau 2500 ms = −500
        wr(A_VAL, 2000);
        start;
        repeat (2500 * 50) @(negedge clk);
        check(nzero == 1 && c_zero - c_run == 2000 * 50, "TM-1 ZERO dung tick thu 2000");
        rd(A_VAL); check(rv == -32'sd500, "TM-1 sau 2500 ms = -500");
        rd(A_CTL); check(rv[1] == 1, "TM-1 ZERO dinh");
        wr(A_CTL, 32'h1); rd(A_CTL); check(rv[1] == 1, "ghi CTL bit 1 = 0: ZERO giu");
        wr(A_CTL, 32'h3); rd(A_CTL); check(rv[1] == 0 && rv[0] == 1, "ghi 1 xoa ZERO, RUN giu");
        wr(A_CTL, 32'h0);

        // ---- TM-2: 0, RUN → −1 sau 1 ms, không ZERO
        nzero = 0;
        wr(A_VAL, 0); start;
        repeat (50) @(negedge clk);
        rd(A_VAL); check(rv == 32'hFFFF_FFFF, "TM-2 0 -> -1 sau 1 ms");
        repeat (200) @(negedge clk);
        check(nzero == 0, "TM-2 khong co ZERO");
        wr(A_CTL, 32'h0);

        // ---- TM-3: 1 → ZERO sau 1 ms, chỉ 1 lần
        wr(A_VAL, 1); start;
        repeat (300) @(negedge clk);
        check(nzero == 1 && c_zero - c_run == 50, "TM-3 ZERO sau 1 ms, 1 lan");
        wr(A_CTL, 32'h0);

        // ---- TM-4: −2³¹ + 1 → 1 ms: −2³¹, SAT = 0; 2 ms: vẫn −2³¹, SAT = 1
        wr(A_VAL, 32'h8000_0001); start;
        repeat (50) @(negedge clk);
        rd(A_VAL); check(rv == 32'h8000_0000, "TM-4 sau 1 ms = -2^31");
        rd(A_CTL); check(rv[3] == 0, "TM-4 sau 1 ms SAT = 0");
        repeat (50) @(negedge clk);
        rd(A_VAL); check(rv == 32'h8000_0000, "TM-4 sau 2 ms van -2^31");
        rd(A_CTL); check(rv[3] == 1, "TM-4 sau 2 ms SAT = 1");
        wr(A_VAL, 5); rd(A_CTL); check(rv[3] == 0, "ghi TMR_VALUE xoa SAT");
        wr(A_CTL, 32'h0);

        // ---- TM-5: BEEP_EN = 1 → beep cùng chu kỳ ZERO; BEEP_EN = 0 → không
        nbeep = 0; nzero = 0;
        wr(A_VAL, 2); wr(A_CTL, 32'h5);                   // RUN + BEEP_EN
        repeat (200) @(negedge clk);
        check(nzero == 1 && nbeep == 1, "TM-5 beep cung chu ky ZERO");
        wr(A_CTL, 32'h0);
        nbeep = 0; nzero = 0;
        wr(A_VAL, 2); wr(A_CTL, 32'h1);
        repeat (200) @(negedge clk);
        check(nzero == 1 && nbeep == 0, "BEEP_EN = 0: khong beep");
        check(nbeep_bad == 0, "beep == zero_ev & BEEP_EN moi chu ky");
        wr(A_CTL, 32'h0);

        // ---- ghi TMR_VALUE xóa bộ chia: chạy 30 chu kỳ rồi ghi 3 → ZERO sau 3 ms đầy đủ kể từ lúc ghi
        nzero = 0;
        wr(A_VAL, 100); start;
        repeat (30) @(negedge clk);
        @(negedge clk); bus_addr = A_VAL; bus_wdata = 3; bus_we = 1; c_run = cyc + 1; @(negedge clk); bus_we = 0;
        repeat (300) @(negedge clk);
        check(nzero == 1 && c_zero - c_run == 150, "ghi TMR_VALUE xoa bo chia (khong mat/du phan le)");
        wr(A_CTL, 32'h0);
        // ghi TMR_VALUE đúng chu kỳ tick khi giá trị = 1 → ghi thắng, không có ZERO (giá trị không đi 1 → 0)
        nzero = 0; ncoll = 0;
        wr(A_VAL, 1); start;                               // tick đầu ở cạnh c_run + 50
        repeat (48) @(negedge clk);
        @(negedge clk); bus_addr = A_VAL; bus_wdata = 7; bus_we = 1;
        @(negedge clk); bus_we = 0;
        check(ncoll == 1 && nzero == 0, "ghi TMR_VALUE trung tick khi = 1: khong ZERO");
        rd(A_VAL); check(rv == 7, "ghi trung tick: gia tri = gia tri ghi");
        // dừng giữ nguyên giá trị
        wr(A_CTL, 32'h0); rd(A_VAL); k_hold = rv;
        repeat (500) @(negedge clk);
        rd(A_VAL); check(rv == k_hold, "RUN = 0: gia tri dung yen");

        if (nerr == 0) $display("PASS cdtimer_tb %0d", n);
        else $display("FAIL cdtimer_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
