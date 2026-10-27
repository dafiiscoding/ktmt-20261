// stopwatch_tb.v — gói E3 (stopwatch): SW-1…SW-6 (timer-spec §10), G_N = 50, CAL = 0.
// Nút có rung đi qua buttons.v thật (SW-3, SW-4), nên kiểm luôn đường xung nhấn A/B → stopwatch.
`timescale 1ns/1ps
module stopwatch_tb;
    localparam A_CTRL = 8'h1C, A_VAL = 8'h20, A_LAP = 8'h24;

    reg         clk = 0, rst = 1, bus_we = 0, bus_re = 0;
    reg  [7:0]  bus_addr = 0;
    reg  [31:0] bus_wdata = 0;
    reg  [3:0]  btn = 0;
    reg         sel5 = 0;                      // 1 = bus nói với dut5 (SW-5)
    wire [31:0] rd_sw, rd_sw5, rd_btn;
    wire [31:0] bus_rdata = rd_sw | rd_btn;
    wire        tick_ms, capture, capture5, btn_ev;
    wire [3:0]  press;

    timebase #(.G_N(50)) u_tb (.clk(clk), .rst(rst), .clr(1'b0), .en(1'b1), .cal(32'sd0), .tick(tick_ms));
    buttons u_btn (.clk(clk), .rst(rst), .btn(btn), .tick_ms(tick_ms), .ms(27'd0), .bus_addr(bus_addr),
                   .bus_wdata(bus_wdata), .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(rd_btn), .press(press), .ev(btn_ev));
    stopwatch #(.G_N(50)) dut (.clk(clk), .rst(rst), .cal(32'sd0), .press_a(press[1]), .press_b(press[2]),
                   .bus_addr(bus_addr), .bus_wdata(bus_wdata), .bus_we(bus_we && !sel5), .bus_re(bus_re && !sel5),
                   .bus_rdata(rd_sw), .capture(capture));
    // SW-5: bản G_SW_MAX = 1234, cùng bus nhưng đọc riêng
    stopwatch #(.G_N(50), .G_SW_MAX(1234)) dut5 (.clk(clk), .rst(rst), .cal(32'sd0), .press_a(1'b0), .press_b(1'b0),
                   .bus_addr(bus_addr), .bus_wdata(bus_wdata), .bus_we(bus_we && sel5), .bus_re(bus_re && sel5),
                   .bus_rdata(rd_sw5), .capture(capture5));

    always #10 clk = ~clk;

    integer n, nerr, ncap, i, k;
    reg [31:0] rv, laps [0:15];
    integer nlap;

    task check(input cond, input [8*48:1] what);
        begin
            n = n + 1;
            if (!cond) begin nerr = nerr + 1; if (nerr <= 10) $display("loi %0s: val=%0d rv=%h", what, dut.val, rv); end
        end
    endtask
    task wr(input [7:0] a, input [31:0] d);
        begin @(negedge clk); bus_addr = a; bus_wdata = d; bus_we = 1; @(negedge clk); bus_we = 0; end
    endtask
    task rd(input [7:0] a);
        begin @(negedge clk); bus_addr = a; bus_re = 1; @(negedge clk); bus_re = 0; rv = sel5 ? rd_sw5 : bus_rdata; end
    endtask
    // RUN = 1 đúng `c` chu kỳ: cạnh ghi RUN=1 là E, cạnh ghi RUN=0 là E + c
    task run_for(input integer c);
        begin
            @(negedge clk); bus_addr = A_CTRL; bus_wdata = 32'h1; bus_we = 1;
            @(negedge clk); bus_we = 0;
            repeat (c - 1) @(negedge clk);
            bus_wdata = 32'h0; bus_we = 1;
            @(negedge clk); bus_we = 0;
        end
    endtask
    // nhấn nút b có rung (mẫu BTN-1: cạnh ở 0; +0,3; +0,5; +1,2; +1,5 ms), giữ `hold` chu kỳ kể từ cạnh đầu, nhả có rung
    task press_bounce(input integer b, input integer hold);
        begin
            btn[b] = 1; #(15 * 20) btn[b] = 0; #(10 * 20) btn[b] = 1; #(35 * 20) btn[b] = 0; #(15 * 20) btn[b] = 1;
            #((hold - 75) * 20) btn[b] = 0; #(20 * 20) btn[b] = 1; #(20 * 20) btn[b] = 0;
        end
    endtask

    always @(posedge clk) if (capture) ncap = ncap + 1;
    always @(posedge clk) if (capture && press[2]) begin laps[nlap] = dut.val; nlap = nlap + 1; end

    initial begin
        n = 0; nerr = 0; ncap = 0; nlap = 0;
        repeat (3) @(negedge clk);
        rst = 0;

        // ---- SW-1: RUN đúng 49 / 50 / 61 728 chu kỳ → 0 / 1 / 1 234
        run_for(49);    rd(A_VAL); check(rv == 0, "SW-1 49 chu ky -> 0");
        wr(A_CTRL, 32'h2);
        run_for(50);    rd(A_VAL); check(rv == 1, "SW-1 50 chu ky -> 1");
        wr(A_CTRL, 32'h2);
        run_for(61728); rd(A_VAL); check(rv == 1234, "SW-1 61728 chu ky -> 1234");

        // ---- SW-2: 30 chu kỳ, dừng, 20 chu kỳ → 1 (bộ chia giữ phần lẻ khi dừng)
        wr(A_CTRL, 32'h2);
        run_for(30); repeat (100) @(negedge clk); run_for(20);
        rd(A_VAL); check(rv == 1, "SW-2 30 + 20 chu ky -> 1");

        // ---- SW-6: SRC = 0, CPU ghi LAP → FIFO giữ đúng giá trị lúc ghi
        wr(A_CTRL, 32'h2);
        wr(A_CTRL, 32'h1);                                  // chạy
        repeat (300) @(negedge clk);
        @(negedge clk); bus_addr = A_CTRL; bus_wdata = 32'h21; bus_we = 1; k = dut.val;  // LAP + giữ RUN
        @(negedge clk); bus_we = 0;
        wr(A_CTRL, 32'h0);
        rd(A_CTRL); check(rv[11:8] == 1 && rv[0] == 0, "SW-6 LAP_COUNT = 1, da dung");
        rd(A_LAP);  check(rv == {1'b1, 2'd0, k[28:0]}, "SW-6 lap = gia tri luc ghi");
        rd(A_LAP);  check(rv == 0, "FIFO rong -> VALID = 0");

        // ---- SW-3: SRC = 1, nút A có rung: nhấn, 61 728 chu kỳ sau nhấn lại → 1 234; đúng 2 sự kiện capture
        wr(A_CTRL, 32'h2);
        wr(A_CTRL, 32'h4);                                  // SRC = 1 (RUN do nút)
        ncap = 0;
        fork
            press_bounce(1, 1000);
            begin #(61728 * 20) press_bounce(1, 1000); end
        join
        repeat (2000) @(negedge clk);
        rd(A_VAL);  check(rv == 1234, "SW-3 start/stop bang nut co rung -> 1234");
        rd(A_CTRL); check(rv[0] == 0 && rv[2] == 1, "SW-3 da dung, SRC = 1");
        check(ncap == 2, "SW-3 dung 2 su kien SW_CAPTURE");
        // CPU ghi RUN khi SRC = 1 → bị bỏ (chỉ khi ghi SRC = 0 mới đặt RUN)
        wr(A_CTRL, 32'h5); rd(A_CTRL); check(rv[0] == 0, "ghi RUN kem SRC = 1 bi bo");

        // ---- SW-4: 9 lần B khi chạy → 8 lap đúng thứ tự, LAP_OVF = 1
        wr(A_CTRL, 32'h2);
        wr(A_CTRL, 32'h1);                                  // CPU cho chạy
        wr(A_CTRL, 32'h5);                                  // chuyển SRC = 1, RUN giữ nguyên
        nlap = 0; ncap = 0;
        for (i = 0; i < 9; i = i + 1) begin press_bounce(2, 1500); #(1700 * 20); end
        rd(A_CTRL); check(rv[11:8] == 8 && rv[4] == 1 && rv[0] == 1, "SW-4 8 lap, LAP_OVF = 1, van chay");
        check(ncap == 9, "SW-4 9 su kien capture");
        for (i = 0; i < 8; i = i + 1) begin
            rd(A_LAP); check(rv == {1'b1, 2'd0, laps[i][28:0]}, "SW-4 lap dung thu tu");
        end
        check(laps[1] > laps[0] && laps[7] > laps[6], "SW-4 lap tang dan");
        rd(A_LAP); check(rv[31] == 0, "SW-4 lap thu 9 bi bo");
        // B khi đang dừng: phần cứng không làm gì
        wr(A_CTRL, 32'h0); wr(A_CTRL, 32'h4); ncap = 0;
        press_bounce(2, 1500); #(1700 * 20);
        rd(A_CTRL); check(rv[11:8] == 0 && ncap == 0, "B khi dung: khong lap, khong capture");
        // RESET xóa FIFO, OVF, LAP_OVF
        wr(A_CTRL, 32'h2); rd(A_CTRL); check(rv[11:8] == 0 && rv[4:3] == 0, "RESET xoa LAP_OVF, FIFO");

        // ---- va chạm cùng chu kỳ: ép xung nhấn thẳng vào cổng stopwatch để trùng đúng cạnh ghi/đọc
        // ghi RESET kèm SRC = 1 cùng chu kỳ nhấn A → A vẫn đảo RUN (spec §4: CPU chỉ đặt RUN khi ghi SRC = 0)
        wr(A_CTRL, 32'h0); wr(A_CTRL, 32'h4);              // dừng, SRC = 1
        ncap = 0;
        @(negedge clk); bus_addr = A_CTRL; bus_wdata = 32'h6; bus_we = 1; force dut.press_a = 1'b1;
        @(negedge clk); bus_we = 0; release dut.press_a;
        rd(A_CTRL); check(rv[0] == 1 && rv[2] == 1 && ncap == 1, "RESET (SRC=1) cung chu ky nhan A: A van dao RUN");
        // ghi SRC = 0, RUN = 1 cùng chu kỳ nhấn A (đang chạy) → CPU thắng, RUN = 1, không SW_CAPTURE
        ncap = 0;
        @(negedge clk); bus_addr = A_CTRL; bus_wdata = 32'h1; bus_we = 1; force dut.press_a = 1'b1;
        @(negedge clk); bus_we = 0; release dut.press_a;
        rd(A_CTRL); check(rv[0] == 1 && rv[2] == 0 && ncap == 0, "ghi SRC=0 RUN=1 cung chu ky nhan A: CPU thang");
        // CPU ghi LAP (SRC = 0) cùng chu kỳ nút B (SRC cũ = 1, đang chạy) → đúng 1 lap, không SW_CAPTURE
        wr(A_CTRL, 32'h5); ncap = 0;
        @(negedge clk); bus_addr = A_CTRL; bus_wdata = 32'h21; bus_we = 1; force dut.press_b = 1'b1;
        @(negedge clk); bus_we = 0; release dut.press_b;
        rd(A_CTRL); check(rv[11:8] == 1 && rv[2] == 0 && ncap == 0, "CPU LAP + nut B cung chu ky: 1 lap, khong capture");
        // RESET (SRC = 1) cùng chu kỳ nút B khi đang chạy → FIFO rỗng, không SW_CAPTURE
        wr(A_CTRL, 32'h5); ncap = 0;
        @(negedge clk); bus_addr = A_CTRL; bus_wdata = 32'h6; bus_we = 1; force dut.press_b = 1'b1;
        @(negedge clk); bus_we = 0; release dut.press_b;
        rd(A_CTRL); check(rv[11:8] == 0 && rv[0] == 1 && ncap == 0, "RESET + nut B cung chu ky: khong lap, khong capture");
        wr(A_CTRL, 32'h0);
        // FIFO đầy, lap bằng nút B cùng chu kỳ đọc SW_LAP → nhận (có chỗ trống ngay chu kỳ đó), không LAP_OVF
        wr(A_CTRL, 32'h2);
        wr(A_CTRL, 32'h1);
        for (i = 0; i < 8; i = i + 1) begin repeat (60) @(negedge clk); wr(A_CTRL, 32'h21); end
        wr(A_CTRL, 32'h5);                                  // SRC = 1, RUN giữ
        repeat (200) @(negedge clk);
        @(negedge clk); bus_addr = A_LAP; bus_re = 1; force dut.press_b = 1'b1; k = dut.val;
        @(negedge clk); bus_re = 0; release dut.press_b;
        rd(A_CTRL); check(rv[11:8] == 8 && rv[4] == 0, "FIFO day: lap + doc cung chu ky -> nhan, khong LAP_OVF");
        for (i = 0; i < 7; i = i + 1) rd(A_LAP);
        rd(A_LAP); check(rv == {1'b1, 2'd0, k[28:0]}, "lap cuoi = gia tri luc va cham");
        wr(A_CTRL, 32'h2);

        // ---- SW-5: G_SW_MAX = 1234, chạy 2 000 ms → đứng ở 1 234, OVF = 1
        sel5 = 1;
        wr(A_CTRL, 32'h1);
        repeat (2000 * 50) @(negedge clk);
        rd(A_VAL);  check(rv == 1234, "SW-5 dung o 1234");
        rd(A_CTRL); check(rv[3] == 1, "SW-5 OVF = 1");
        wr(A_CTRL, 32'h2); rd(A_CTRL); check(rv[3] == 0, "RESET xoa OVF");
        sel5 = 0;

        if (nerr == 0) $display("PASS stopwatch_tb %0d", n);
        else $display("FAIL stopwatch_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
