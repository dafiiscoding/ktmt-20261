// soc_irqlat_tb.v — (fw: fw/tests/soc/irq_lat.s) C5-5: độ trễ ngắt ở D = 1526 trên soc_top, chỉ bật TICK_1S.
// Độ trễ = CYCLE_COUNT lúc lệnh đầu handler xong (pha A) − IRQ_STAMP. Lý thuyết (vòng 1 lệnh, không stall):
// ngắt nhận ở cạnh pha A kế tiếp (chờ ≤ D) + lệnh đầu handler (D) → (D, 2D] cộng hằng nhỏ như ở D = 2 (= 3).
// Vòng có div: ngắt bị chặn khi stall → chờ tới khi div xong (≤ 33 chu kỳ CPU) → in để ghi báo cáo (plan §8).
`timescale 1ns/1ps
module soc_irqlat_tb;
    localparam D = 1526;
    reg  clk = 0, rst_in = 1;
    wire [7:0] an;
    wire [6:0] seg;
    wire       dp, beep;

    soc_top #(.G_N(50), .G_SLOT(40), .G_BLANK(4)) dut (.clk(clk), .rst_in(rst_in), .btn(4'b0), .an(an), .seg(seg),
                                                     .dp(dp), .beep(beep), .uart_rx(1'b1), .uart_tx());

    always #10 clk = ~clk;

    integer n, nerr, cyc, lat, ph, i, nirq [0:1], lmin [0:1], lmax [0:1], nbad_d;
    reg [8*256:1] fimem, ftrace;

    task check(input cond, input [8*64:1] what);
        begin
            n = n + 1;
            if (!cond) begin nerr = nerr + 1; $display("loi %0s", what); end
        end
    endtask

    always @(posedge clk) if (!dut.rst) begin
        cyc <= cyc + 1;
        if (dut.u_cpu.retire && dut.pc == 32'h180) begin
            lat = dut.cycle_count - dut.u_irq.stamp;
            ph  = dut.u_cpu.u_rf.r[17];
            if (dut.u_regs.p != D / 2) nbad_d = nbad_d + 1;          // đo đúng lúc D = 1526 (p = D/2 ở G1)
            nirq[ph] = nirq[ph] + 1;
            if (lat < lmin[ph]) lmin[ph] = lat;
            if (lat > lmax[ph]) lmax[ph] = lat;
        end
    end

    initial begin
        n = 0; nerr = 0; cyc = 0; nbad_d = 0;
        for (i = 0; i < 2; i = i + 1) begin nirq[i] = 0; lmin[i] = 1 << 30; lmax[i] = 0; end
        if (!$value$plusargs("imem=%s", fimem)) begin $display("FAIL soc_irqlat_tb thieu +imem="); $finish; end
        #1;
        $readmemh(fimem, dut.u_cpu.imem);
        if ($value$plusargs("trace=%s", ftrace)) dut.u_cpu.tf = $fopen(ftrace, "w");   // trace isa-spec §8 cho cosim_iss
        repeat (6) @(negedge clk);
        rst_in = 0;
        while (!(dut.u_cpu.jump && dut.u_cpu.instr[25:0] == dut.pc[27:2] && dut.u_cpu.retire) && cyc < 2000000)
            @(negedge clk);
        check(cyc < 2000000, "chay toi j . truoc 2 000 000 chu ky");
        check(nirq[0] == 6 && nirq[1] >= 6 && nbad_d == 0, "6 + >=6 ngat, deu o D = 1526");
        check(lmin[0] > D && lmax[0] <= 2 * D + 3, "vong 1 lenh: do tre trong (D, 2D + 3]");
        check(lmax[0] - lmin[0] > D / 4, "vong 1 lenh: do tre thay doi theo pha (khong dong bo gia)");
        check(lmax[1] <= 34 * D + 2 * D, "vong div: do tre <= div 33 + 2 chu ky CPU");
        $display("C5-5 D = %0d: vong 1 lenh min %0d max %0d; vong div min %0d max %0d chu ky he thong",
                 D, lmin[0], lmax[0], lmin[1], lmax[1]);
        if (nerr == 0) $display("PASS soc_irqlat_tb %0d", n);
        else $display("FAIL soc_irqlat_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
