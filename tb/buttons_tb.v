// buttons_tb.v — gói E4 (nút): BTN-1…BTN-4 (timer-spec §10) + 2 nút cùng lúc, G_ACTIVE_LOW, đọc FIFO rỗng.
// G_N = 50 → 1 ms = 50 chu kỳ; xung nhiễu "1 µs" của BTN-4 co lại thành 1 chu kỳ (vẫn qua được đồng bộ).
// Cuối tb (chỉ khi +slow, PLUSARGS=+slow bash tools/run_unit.sh buttons): bản tỉ lệ thật dut_r (G_N = 50 000, clock 50 MHz như chip): BTN-1 rung 0,3/0,5/1,2/1,5 ms, BTN-4 nhiễu đúng 1 µs.
`timescale 1ns/1ps
module buttons_tb;
    localparam A_EVT = 8'h40;

    reg         clk = 0, rst = 1, bus_re = 0;
    reg  [7:0]  bus_addr = 0;
    reg  [3:0]  btn = 0;
    reg  [26:0] ms = 27'd1000;          // MS_OF_DAY giả: +1 mỗi tick
    wire [31:0] bus_rdata, rd_lo;
    wire        tick_ms, ev, ev_lo;
    wire [3:0]  press, press_lo;

    timebase #(.G_N(50)) u_tb (.clk(clk), .rst(rst), .clr(1'b0), .en(1'b1), .cal(32'sd0), .tick(tick_ms));
    buttons dut (.clk(clk), .rst(rst), .btn(btn), .tick_ms(tick_ms), .ms(ms), .bus_addr(bus_addr),
                 .bus_wdata(32'd0), .bus_we(1'b0), .bus_re(bus_re), .bus_rdata(bus_rdata), .press(press), .ev(ev));
    // bản tích cực mức thấp, chân = ~btn → phải cho ra đúng như bản thường
    buttons #(.G_ACTIVE_LOW(1)) dut_lo (.clk(clk), .rst(rst), .btn(~btn), .tick_ms(tick_ms), .ms(ms), .bus_addr(bus_addr),
                 .bus_wdata(32'd0), .bus_we(1'b0), .bus_re(bus_re), .bus_rdata(rd_lo), .press(press_lo), .ev(ev_lo));

    always #10 clk = ~clk;
    always @(posedge clk) if (tick_ms) ms <= ms + 27'd1;

    integer n, nerr, nev, npress, nmis, k, nts_bad;
    reg [31:0] rv;
    reg [26:0] t0, ms_press;

    // tỉ lệ thật: bus riêng (chỉ đọc), btn riêng
    reg         re_r = 0;
    reg  [3:0]  btn_r = 0;
    wire [31:0] rd_r;
    wire        tick_r, ev_r;
    wire [3:0]  press_r;
    integer     nev_r;
    timebase #(.G_N(50000)) u_tb_r (.clk(clk), .rst(rst), .clr(1'b0), .en(1'b1), .cal(32'sd0), .tick(tick_r));
    buttons dut_r (.clk(clk), .rst(rst), .btn(btn_r), .tick_ms(tick_r), .ms(ms), .bus_addr(A_EVT),
                   .bus_wdata(32'd0), .bus_we(1'b0), .bus_re(re_r), .bus_rdata(rd_r), .press(press_r), .ev(ev_r));
    always @(posedge clk) if (ev_r) nev_r = nev_r + 1;
    task rd_r_evt;
        begin @(negedge clk); re_r = 1; @(negedge clk); re_r = 0; rv = rd_r; end
    endtask


    task check(input cond, input [8*48:1] what);
        begin
            n = n + 1;
            if (!cond) begin nerr = nerr + 1; if (nerr <= 10) $display("loi %0s: nev=%0d rv=%h t0=%0d", what, nev, rv, t0); end
        end
    endtask
    task rd;
        begin @(negedge clk); bus_addr = A_EVT; bus_re = 1; @(negedge clk); bus_re = 0; rv = bus_rdata; end
    endtask
    // nhấn có rung theo BTN-1 (đơn vị ms → ×50 chu kỳ), giữ `hold_ms`, nhả có rung
    task press_bounce(input integer b, input integer hold_ms);
        begin
            @(negedge clk); t0 = ms;
            btn[b] = 1; #(15 * 20) btn[b] = 0; #(10 * 20) btn[b] = 1; #(35 * 20) btn[b] = 0; #(15 * 20) btn[b] = 1;
            #((hold_ms * 50 - 75) * 20) btn[b] = 0; #(20 * 20) btn[b] = 1; #(20 * 20) btn[b] = 0; #(15 * 20) btn[b] = 1;
            #(10 * 20) btn[b] = 0;
        end
    endtask

    always @(posedge clk) begin
        if (ev) nev = nev + 1;
        if (press[0]) ms_press = ms;                    // ms trước cạnh (ms đổi bằng <=)
        npress = npress + press[0] + press[1] + press[2] + press[3];
        if (press !== press_lo || ev !== ev_lo) nmis = nmis + 1;
    end
    always @(negedge clk) if (bus_rdata !== rd_lo) nmis = nmis + 1;

    initial begin
        n = 0; nerr = 0; nev = 0; npress = 0; nmis = 0;
        repeat (3) @(negedge clk);
        rst = 0;
        repeat (100) @(negedge clk);

        // ---- BTN-1: 1 lần nhấn có rung, giữ 200 ms → đúng 1 sự kiện, dấu thời gian = MS_OF_DAY tại t₀
        press_bounce(1, 200);
        repeat (30 * 50) @(negedge clk);
        check(nev == 1 && npress == 1, "BTN-1 dung 1 su kien, 1 xung nhan");
        rd; check(rv == {1'b1, 2'd1, 1'b0, 1'b0, t0}, "BTN-1 VALID, ma A, ms = t0");
        rd; check(rv == 0, "FIFO rong doc 0");

        // ---- BTN-2: 2 lần nhấn cách 50 ms → 2 sự kiện
        nev = 0;
        press_bounce(2, 20);
        repeat (50 * 50 - 20 * 50) @(negedge clk);
        press_bounce(2, 20);
        repeat (30 * 50) @(negedge clk);
        check(nev == 2, "BTN-2 hai lan nhan cach 50 ms -> 2 su kien");
        rd; check(rv[31:29] == 3'b110, "BTN-2 su kien 1 (B)");
        rd; check(rv[31:29] == 3'b110 && rv[26:0] == t0, "BTN-2 su kien 2 (B), ms = t0 lan 2");

        // ---- BTN-3: 5 lần nhấn không đọc → đọc ra 4, sự kiện đầu LOST = 1
        nev = 0;
        repeat (5) begin press_bounce(3, 15); repeat (30 * 50) @(negedge clk); end
        check(nev == 4, "BTN-3 chi 4 su kien vao FIFO");
        rd; check(rv[31] && rv[28], "BTN-3 su kien dau LOST = 1");
        rd; check(rv[31] && !rv[28], "BTN-3 su kien 2 LOST = 0");
        rd; check(rv[31], "BTN-3 su kien 3");
        rd; check(rv[31], "BTN-3 su kien 4");
        rd; check(rv == 0, "BTN-3 het, VALID = 0");

        // ---- BTN-4: xung nhiễu 1 chu kỳ qua cạnh lên → 1 sự kiện (hành vi đã biết)
        nev = 0;
        @(negedge clk); btn[0] = 1; @(negedge clk); btn[0] = 0;
        repeat (30 * 50) @(negedge clk);
        check(nev == 1, "BTN-4 xung nhieu 1 chu ky -> 1 su kien");
        rd; check(rv[31:29] == 3'b100, "BTN-4 ma MODE");

        // ---- 2 nút cùng chu kỳ → 2 sự kiện, số nhỏ trước, cùng dấu thời gian
        nev = 0;
        @(negedge clk); t0 = ms; btn[3] = 1; btn[1] = 1;
        repeat (20 * 50) @(negedge clk); btn[3] = 0; btn[1] = 0;
        repeat (30 * 50) @(negedge clk);
        check(nev == 2, "2 nut cung luc -> 2 su kien");
        rd; check(rv == {1'b1, 2'd1, 2'b00, t0}, "2 nut: A truoc");
        rd; check(rv == {1'b1, 2'd3, 2'b00, t0}, "2 nut: C sau, cung ms");

        // ---- giữ lâu không lặp sự kiện
        nev = 0;
        @(negedge clk); btn[2] = 1; repeat (500 * 50) @(negedge clk); btn[2] = 0;
        repeat (30 * 50) @(negedge clk);
        check(nev == 1, "giu 500 ms -> 1 su kien");
        rd;

        // ---- dấu thời gian = MS_OF_DAY ở chu kỳ xung nhấn, kể cả khi tick ms rơi giữa xung nhấn và lúc vào FIFO:
        // quét 50 pha của cạnh nhấn so với tick
        nts_bad = 0;
        for (k = 0; k < 50; k = k + 1) begin
            @(posedge tick_ms); repeat (k) @(negedge clk);
            btn[0] = 1; repeat (15 * 50) @(negedge clk); btn[0] = 0; repeat (15 * 50) @(negedge clk);
            rd; if (rv !== {1'b1, 2'd0, 2'b00, ms_press}) nts_bad = nts_bad + 1;
        end
        check(nts_bad == 0, "dau thoi gian dung o moi pha so voi tick");

        check(nmis == 0, "G_ACTIVE_LOW = 1 khop ban thuong tung chu ky");

        // ---- tỉ lệ thật (1 ms = 50 000 chu kỳ = 1 ms thời gian mô phỏng); ~2 phút → chỉ chạy với +slow
        if ($test$plusargs("slow")) begin
        nev_r = 0;
        btn_r[1] = 1; #300000 btn_r[1] = 0; #200000 btn_r[1] = 1; #700000 btn_r[1] = 0; #300000 btn_r[1] = 1;
        #18500000 btn_r[1] = 0; #400000 btn_r[1] = 1; #400000 btn_r[1] = 0;          // giữ 20 ms, nhả có rung
        #30000000;
        check(nev_r == 1, "that BTN-1: rung 0,3/0,5/1,2/1,5 ms -> 1 su kien");
        rd_r_evt; check(rv[31:29] == 3'b101, "that BTN-1: VALID, ma A");
        nev_r = 0;
        btn_r[0] = 1; #1000 btn_r[0] = 0;                                              // nhiễu đúng 1 µs = 50 chu kỳ
        #30000000;
        check(nev_r == 1, "that BTN-4: nhieu 1 us -> 1 su kien (hanh vi da biet)");
        rd_r_evt; check(rv[31:29] == 3'b100, "that BTN-4: ma MODE");
        end

        if (nerr == 0) $display("PASS buttons_tb %0d", n);
        else $display("FAIL buttons_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
