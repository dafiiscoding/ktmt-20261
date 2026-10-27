// display_ctrl_tb.v — gói D2: reset (trống, BRIGHT 15), ghi DISPi qua bus → chân đoạn đúng ở khe i,
// BRIGHT qua bus, D-4 / D-5 qua bus, đọc ra 0, ghi địa chỉ khác không ảnh hưởng. G_SLOT 40, G_BLANK 4.
`timescale 1ns/1ps
module display_ctrl_tb;
    localparam SLOT = 40, ND = 8, ROUND = SLOT * ND;
    localparam A_DISP0 = 8'h5C, A_BLINK = 8'h7C, A_BRIGHT = 8'h80;

    reg         clk = 0, rst = 1, tick_ms = 0, bus_we = 0, bus_re = 0;
    reg  [7:0]  bus_addr = 0;
    reg  [31:0] bus_wdata = 0;
    wire [31:0] bus_rdata;
    wire [7:0]  an;
    wire [6:0]  seg;
    wire        dp;

    display_ctrl #(.G_SLOT(SLOT), .G_BLANK(4)) dut (
        .clk(clk), .rst(rst), .tick_ms(tick_ms), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .bus_we(bus_we), .bus_re(bus_re), .bus_rdata(bus_rdata), .an(an), .seg(seg), .dp(dp));

    always #10 clk = ~clk;

    reg [6:0] golden [0:31];
    integer fd, c, r, i, k, n, nerr, cyc, ticks;
    reg [8*200:1] rest;
    reg [31:0] e_code, e_seg, rv;
    integer lit [0:7];
    reg [7:0] seen [0:7];          // {dp, seg} thấy ở khe i
    reg [7:0] codes [0:7];

    task check(input cond, input [8*40:1] what);
        begin
            n = n + 1;
            if (!cond) begin
                nerr = nerr + 1;
                if (nerr <= 10) $display("loi %0s: cyc=%0d ticks=%0d", what, cyc, ticks);
            end
        end
    endtask

    // 1 chu kỳ (bắt đầu/kết thúc ở negedge): ghi nhận chữ số đang sáng
    task step;
        begin
            #1;
            for (k = 0; k < ND; k = k + 1)
                if (an[k]) begin lit[k] = lit[k] + 1; seen[k] = {dp, seg}; end
            @(posedge clk);
            if (!rst) cyc = cyc + 1;
            if (tick_ms) ticks = ticks + 1;
            @(negedge clk);
        end
    endtask
    task clear_stats;
        begin for (k = 0; k < ND; k = k + 1) begin lit[k] = 0; seen[k] = 8'hEE; end end
    endtask
    // chạy tới đầu vòng quét kế tiếp rồi quét trọn 1 vòng
    task one_round;
        begin
            while (cyc % ROUND != 0) step;
            clear_stats;
            repeat (ROUND) step;
        end
    endtask
    task wr(input [7:0] a, input [31:0] d);
        begin bus_addr = a; bus_wdata = d; bus_we = 1; step; bus_we = 0; end
    endtask

    initial begin
        n = 0; nerr = 0; cyc = 0; ticks = 0;
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

        repeat (2) @(negedge clk);
        rst = 0;

        // ---- reset: 8 ô trống (đoạn tắt), BRIGHT 15 → mỗi chữ số bật 30 chu kỳ
        one_round;
        for (i = 0; i < ND; i = i + 1) check(lit[i] == 30 && seen[i] == 8'h00, "reset: trong, bright 15");

        // ---- ghi DISPi qua bus: chữ số i hiện đúng mã, chấm ở ô lẻ
        for (i = 0; i < ND; i = i + 1) begin
            codes[i] = {i[0], 2'b00, 5'h0A + {i[3:0], 1'b0}};   // mã 0x0A, 0x0C, …, 0x18
            wr(A_DISP0 + 4 * i, {24'hFFFFFF, codes[i]});   // bit cao rác phải bị bỏ
        end
        one_round;
        for (i = 0; i < ND; i = i + 1)
            check(seen[i] == {codes[i][7], golden[codes[i][4:0]]}, "DISPi -> doan o khe i");

        // ---- BRIGHT qua bus
        wr(A_BRIGHT, 1); one_round;
        for (i = 0; i < ND; i = i + 1) check(lit[i] == 2, "BRIGHT 1");
        wr(A_BRIGHT, 0); one_round;
        for (i = 0; i < ND; i = i + 1) check(lit[i] == 0, "BRIGHT 0");
        wr(A_BRIGHT, 15);

        // ghi địa chỉ khác (BEEP_FREQ 0x84, BLINK sai 0x7D không căn) không đụng màn
        wr(8'h84, 32'h1); wr(8'h58, 32'h3);
        one_round;
        for (i = 0; i < ND; i = i + 1) check(lit[i] == 30, "ghi dia chi khac khong anh huong");

        // đọc mọi địa chỉ của khối → 0 (thanh ghi chỉ-ghi)
        bus_addr = A_DISP0; bus_re = 1; step; bus_re = 0;
        check(bus_rdata == 0, "doc ra 0");

        // ---- D-4: BLINK_MASK = 0x01 → chữ số 0 tắt đúng tick 250…499, sáng lại ở 500
        wr(A_BLINK, 8'h01); ticks = 0;
        while (ticks < 249) begin tick_ms = 1; step; end
        tick_ms = 0; one_round;
        check(lit[0] == 30, "D-4 tick 249 sang");
        check(dut.u_vga.dim == 8'h00, "VGA cung pha nhay: dang sang");
        tick_ms = 1; step; tick_ms = 0; one_round;
        check(lit[0] == 0, "D-4 tick 250 tat");
        check(dut.u_vga.dim == 8'h01, "VGA cung pha nhay: o 0 chi con vet mo");
        for (i = 1; i < ND; i = i + 1) check(lit[i] == 30, "D-4 chu so khac khong doi");
        while (ticks < 499) begin tick_ms = 1; step; end
        tick_ms = 0; one_round;
        check(lit[0] == 0, "D-4 tick 499 tat");
        tick_ms = 1; step; tick_ms = 0; one_round;
        check(lit[0] == 30, "D-4 tick 500 sang lai");

        // ---- D-5: đang ở nửa tắt, ghi lại BLINK_MASK → sáng ngay ở vòng kế
        while (ticks < 800) begin tick_ms = 1; step; end      // 800 % 500 = 300: nửa tắt
        tick_ms = 0; one_round;
        check(lit[0] == 0, "D-5 dang tat");
        wr(A_BLINK, 8'h01); ticks = 0;
        one_round;
        check(lit[0] == 30, "D-5 ghi BLINK_MASK -> sang ngay");

        if (nerr == 0) $display("PASS display_ctrl_tb %0d", n);
        else $display("FAIL display_ctrl_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
