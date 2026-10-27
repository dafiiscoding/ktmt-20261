// irq_tb.v — gói C5 (phần irq_ctrl): IRQ-1…4 (mmio-map §6) + đọc lại ENABLE, giữ bus_rdata, địa chỉ lạ → 0.
`timescale 1ns/1ps
module irq_tb;
    localparam A_EN = 8'h44, A_PEND = 8'h48, A_STAMP = 8'h4C;

    reg         clk = 0, rst = 1, bus_we = 0, bus_re = 0;
    reg  [7:0]  ev = 0, bus_addr = 0;
    reg  [31:0] bus_wdata = 0, cyc = 0;
    wire [31:0] bus_rdata;
    wire        irq;
    wire [7:0]  ip;

    irq_ctrl dut (.clk(clk), .rst(rst), .ev(ev), .cycle_count(cyc), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
                  .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(bus_rdata), .irq(irq), .ip(ip));

    always #10 clk = ~clk;
    always @(posedge clk) cyc <= rst ? 0 : cyc + 1;

    integer n, nerr;
    reg [31:0] rv, c_irq;

    task check(input cond, input [8*48:1] what);
        begin
            n = n + 1;
            if (!cond) begin
                nerr = nerr + 1;
                if (nerr <= 10) $display("loi %0s: pending=%h enable=%h irq=%b rv=%h", what, dut.pending, dut.enable, irq, rv);
            end
        end
    endtask
    task wr(input [7:0] a, input [31:0] d);
        begin bus_addr = a; bus_wdata = d; bus_we = 1; @(negedge clk); bus_we = 0; end
    endtask
    task rd(input [7:0] a);
        begin bus_addr = a; bus_re = 1; @(negedge clk); bus_re = 0; #1 rv = bus_rdata; end
    endtask
    task pulse(input [7:0] e);
        begin ev = e; @(negedge clk); ev = 0; end
    endtask

    initial begin
        n = 0; nerr = 0;
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);

        // IRQ-1: sự kiện bit 3 khi ENABLE = 0 → PENDING[3] = 1, irq = 0
        pulse(8'h08);
        check(dut.pending == 8'h08 && !irq, "IRQ-1 pending=1, irq=0");
        rd(A_PEND); check(rv == 32'h08, "IRQ-1 doc PENDING");

        // IRQ-2: ENABLE[3] = 1 → irq = 1 ngay chu kỳ sau cạnh ghi, STAMP = CYCLE_COUNT của chu kỳ đó
        wr(A_EN, 32'h08);
        c_irq = cyc;                                   // chu kỳ đầu tiên irq = 1
        check(irq && ip == 8'h08, "IRQ-2 irq=1, ip");
        @(negedge clk);
        rd(A_STAMP); check(rv == c_irq, "IRQ-2 STAMP = CYCLE_COUNT luc irq len");
        rd(A_EN); check(rv == 32'h08, "doc lai ENABLE");
        // bus_rdata giữ tới lần đọc sau (mmio-map §2), địa chỉ khối khác → 0
        repeat (5) @(negedge clk);
        check(bus_rdata == 32'h08, "bus_rdata giu nguyen");
        rd(8'h04); check(rv == 0, "dia chi khoi khac -> 0");

        // IRQ-3: ghi 1 xóa PENDING[3] cùng chu kỳ sự kiện mới bit 3 → vẫn 1
        bus_addr = A_PEND; bus_wdata = 32'h08; bus_we = 1; ev = 8'h08;
        @(negedge clk); bus_we = 0; ev = 0;
        check(dut.pending[3] == 1'b1, "IRQ-3 su kien thang lenh xoa");

        // IRQ-4: PENDING = 0x0C, ghi 0x08 → 0x04
        pulse(8'h04);
        check(dut.pending == 8'h0C, "IRQ-4 chuan bi 0x0C");
        wr(A_PEND, 32'h08);
        check(dut.pending == 8'h04, "IRQ-4 ghi 0x08 -> 0x04");
        check(!irq, "irq tat khi bit bat da xoa");

        // STAMP chỉ chốt ở cạnh lên: irq giữ 1 thì không chốt lại
        wr(A_EN, 32'h04);
        c_irq = cyc;
        repeat (4) @(negedge clk);
        rd(A_STAMP); check(rv == c_irq, "STAMP chi chot o canh len");

        if (nerr == 0) $display("PASS irq_tb %0d", n);
        else $display("FAIL irq_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
