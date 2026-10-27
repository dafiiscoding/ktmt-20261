// soc_bus_tb.v — (fw: fw/tests/soc/bus.s) bus MMIO + thanh ghi soc (C4) chạy bằng firmware tự kiểm trên soc_top.
// Firmware bật 1 bit $v0 cho mỗi ca đúng rồi dừng ở "j ."; tb đòi $v0 = 0x7FFF, đếm lệnh lạ,
// nhấn nút C rồi A (có rung) khi firmware chuyển stopwatch sang SRC = 1 (ca bit 13), và kiểm mỗi lw/sw vào MMIO bật bus_re/bus_we đúng 1 chu kỳ hệ thống (cả lúc D = 1526).
`timescale 1ns/1ps
module soc_bus_tb;
    reg  clk = 0, rst_in = 1;
    reg  [3:0] btn = 0;
    wire [7:0] an;
    wire [6:0] seg;
    wire       dp, beep;

    soc_top #(.G_N(50), .G_SLOT(40), .G_BLANK(4)) dut (.clk(clk), .rst_in(rst_in), .btn(btn), .an(an), .seg(seg), .dp(dp), .beep(beep), .uart_rx(1'b1), .uart_tx());

    always #10 clk = ~clk;

    // ca bit 13: firmware bật SW SRC = 1 → nhấn C, 60 ms sau nhấn A; có rung (cạnh 0; +0,3; +0,5; +1,2; +1,5 ms), giữ 20 ms
    task press_bounce(input integer b);
        begin
            btn[b] = 1; #(15 * 20) btn[b] = 0; #(10 * 20) btn[b] = 1; #(35 * 20) btn[b] = 0; #(15 * 20) btn[b] = 1;
            #(1000 * 20) btn[b] = 0;
        end
    endtask
    initial begin
        @(posedge dut.u_sw.src);
        repeat (100) @(negedge clk);
        press_bounce(3);
        repeat (2000) @(negedge clk);
        press_bounce(1);
    end

    integer n, nerr, nbad, nbus, mem_ops, cyc, i;
    reg [8*256:1] fimem, ftrace;
    reg [31:0] v0;
    reg [8*40:1] name [0:14];
    integer nzero_b, nzero_nb, nbeep_bad, nbeep_edge;
    reg     beep_q;

    task check(input cond, input [8*48:1] what);
        begin
            n = n + 1;
            if (!cond) begin nerr = nerr + 1; $display("loi %0s", what); end
        end
    endtask

    always @(posedge clk) if (!dut.rst) begin
        cyc <= cyc + 1;
        if (dut.bus_we || dut.bus_re) nbus <= nbus + 1;
        // dây tmr_beep → beeper: ZERO có BEEP_EN thì cạnh này nạp 0x10F0F, không có thì không nạp
        if (dut.u_tmr.zero_ev) begin
            if (dut.u_tmr.beep_en) nzero_b = nzero_b + 1; else nzero_nb = nzero_nb + 1;
            #1 if ((dut.u_beep.pat == 17'h10F0F) !== dut.u_tmr.beep_en) nbeep_bad = nbeep_bad + 1;
        end
        beep_q <= beep;
        if (beep !== beep_q) nbeep_edge = nbeep_edge + 1;
        if (dut.u_cpu.retire && (dut.u_cpu.mem_read || dut.u_cpu.mem_write) && dut.u_cpu.in_mmio) mem_ops <= mem_ops + 1;
        if (dut.u_cpu.retire && !dut.u_cpu.valid) nbad <= nbad + 1;
    end

    initial begin
        n = 0; nerr = 0; nbad = 0; nbus = 0; mem_ops = 0; cyc = 0; nzero_b = 0; nzero_nb = 0; nbeep_bad = 0; nbeep_edge = 0; beep_q = 0;
        name[0] = "BUS-2 dia chi trong doc 0";     name[1] = "BUS-3 ghi CYCLE_COUNT bi bo";
        name[2] = "BUS-5 CPU_CLK_DIV 0,1,3,1526";  name[3] = "D=1526: 1 chu ky CPU = 1526";
        name[4] = "D moi tu chu ky CPU ke";         name[5] = "DIV_FLAGS.DZ";
        name[6] = "CAL doc/ghi";                    name[7] = "IRQ_ENABLE/PENDING qua bus";
        name[8] = "MS_OF_DAY tang 1 sau 1 ms";      name[9] = "CYCLE_COUNT = 0 o lenh dau";
        name[10] = "BUS-4 D=1526: 3 lw SW_LAP lay dung 3";  name[11] = "TMR_ZERO -> IRQ_PENDING bit 2";
        name[12] = "ALARM -> IRQ_PENDING bit 3";          name[13] = "nut C -> bit 5; A -> bit 4+5, SW chay";
        name[14] = "TMR_ZERO + BEEP_EN -> chuong (chay xong)";
        if (!$value$plusargs("imem=%s", fimem)) begin $display("FAIL soc_bus_tb thieu +imem="); $finish; end
        #1;                                     // sau initial xóa imem của cpu_g1 (cùng t = 0 thì thứ tự tùy simulator)
        $readmemh(fimem, dut.u_cpu.imem);
        if ($value$plusargs("trace=%s", ftrace)) dut.u_cpu.tf = $fopen(ftrace, "w");   // trace isa-spec §8 cho cosim_iss
        repeat (6) @(negedge clk);
        rst_in = 0;
        while (!(dut.u_cpu.jump && dut.u_cpu.instr[25:0] == dut.pc[27:2] && dut.u_cpu.retire) && cyc < 200000)
            @(negedge clk);
        @(negedge clk);
        v0 = dut.u_cpu.u_rf.r[2];
        check(cyc < 200000, "chay toi j . truoc 200000 chu ky");
        for (i = 0; i < 15; i = i + 1) check(v0[i], name[i]);
        check(nbad == 0, "khong lenh la");
        check(nzero_b == 1 && nzero_nb == 1 && nbeep_bad == 0, "tmr_beep -> beeper: nap 0x10F0F chi khi BEEP_EN");
        check(nbeep_edge > 20 && dut.u_beep.pat == 0 && !beep, "chan beep dao khi keu, tat sau ghi 0");
        check(nbus == mem_ops, "moi lw/sw MMIO: bus_re/bus_we dung 1 chu ky");
        $display("v0 = %h, %0d lenh MMIO, %0d chu ky he thong", v0, mem_ops, cyc);
        if (nerr == 0) $display("PASS soc_bus_tb %0d", n);
        else $display("FAIL soc_bus_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
