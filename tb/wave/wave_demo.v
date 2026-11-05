// wave_demo.v — testbench ĐỂ XEM SÓNG (không kiểm đúng/sai): soc_top G1 + fw/main.s, G_N = 50, ghi work/wave_demo.vcd.
// Chạy: bash tools/wave_demo.sh  (dịch firmware, mô phỏng, in dòng thời gian sự kiện; thêm "view" để mở GTKWave).
// Đặt ở tb/wave/ (không phải tb/*.v) nên run_unit.sh không chạy nó trong hồi quy.
//
// Kịch bản (lấy từ system_tb, sys_2 và sys_4): 12:00:00 → MODE vào STOPWATCH → A chạy → B chụp lap → A dừng
// → MODE sang TIMER (đặt sẵn 2,000 s) → A chạy → về 0 đúng 2000 ms → còi + ngắt → chạy tiếp sang số âm.
// Nút bấm do tb ép chân btn (có rung như nút thật); không có bấm nút thời gian thực.
`timescale 1ns/1ps
module wave_demo;
    reg  clk = 0, rst_in = 1;
    reg  [3:0] btn = 4'd0;
    reg        urx = 1'b1;                               // chân UART RX (PC → chip), nghỉ = 1
    wire [7:0] an;
    wire [6:0] seg;
    wire       dp, beep, utx;

    soc_top #(.G_N(50), .G_SLOT(40), .G_BLANK(4), .G_BIT(8)) dut (.clk(clk), .rst_in(rst_in), .btn(btn), .an(an),
        .seg(seg), .dp(dp), .beep(beep), .uart_rx(urx), .uart_tx(utx), .vga_hs(), .vga_vs(), .vga_rgb());

    always #10 clk = ~clk;                               // 50 MHz

    localparam B_MODE = 0, B_A = 1, B_B = 2;

    // ---- tín hiệu đưa lên sóng (đặt tên dễ đọc trong GTKWave)
    wire [1:0]  st_mode = dut.u_btn.st[0];               // máy trạng thái chống rung: 0 IDLE 1 LOCK_P 2 HELD 3 LOCK_R
    wire [1:0]  st_a    = dut.u_btn.st[1];
    wire [1:0]  st_b    = dut.u_btn.st[2];
    wire        btn_ev  = dut.btn_ev;                    // sự kiện nút vào FIFO (ngắt bit 5)
    wire        irq     = dut.irq;
    wire [7:0]  irq_ip  = dut.irq_ip;
    wire [31:0] pc      = dut.pc;
    wire        tick_ms = dut.tick_ms;
    wire [26:0] ms      = dut.ms;
    wire        sw_run  = dut.u_sw.run;
    wire [28:0] sw_val  = dut.u_sw.val;
    wire        sw_cap  = dut.sw_capture;
    wire signed [31:0] tmr_val = dut.u_tmr.val;
    wire        tmr_run = dut.u_tmr.run;
    wire        tmr_zero = dut.tmr_zero;
    wire [16:0] beep_pat = dut.u_beep.pat;
    wire        urx_ev  = dut.uart_rx_ev;                // nhận xong 1 byte (ngắt bit 6)

    initial begin
        $dumpfile("work/wave_demo.vcd");
        $dumpvars(1, wave_demo);                         // chỉ các tín hiệu khai báo ở trên (file nhỏ, dễ chọn)
    end

    // ---- dòng thời gian sự kiện (để thuyết minh khi chiếu sóng)
    integer cyc = 0;
    always @(posedge clk) begin
        cyc <= cyc + 1;
        if (dut.press[0] || dut.press[1] || dut.press[2])
            $display("[ms %6d | chu ky %7d] chan nut nhan: MODE=%b A=%b B=%b", ms, cyc, dut.press[0], dut.press[1], dut.press[2]);
        if (btn_ev)   $display("[ms %6d | chu ky %7d] su kien nut vao FIFO -> ngat bit 5", ms, cyc);
        if (sw_cap)   $display("[ms %6d | chu ky %7d] stopwatch: phan cung bat nut (SW_CAPTURE)", ms, cyc);
        if (tmr_zero) $display("[ms %6d | chu ky %7d] timer ve 0 (TMR_ZERO)", ms, cyc);
        if (dut.u_cpu.take_irq && dut.u_cpu.ph_a)
            $display("[ms %6d | chu ky %7d] CPU nhan ngat: EPC <- %h, nhay toi 0x180, IP = %b", ms, cyc, dut.u_cpu.next_pc, irq_ip);
    end
    reg beep_q = 0;
    always @(posedge clk) begin
        beep_q <= beep;
        if (beep && !beep_q) $display("[ms %6d | chu ky %7d] chan beep bat dau keu", ms, cyc);
    end

    task wait_ms(input integer k);
        begin repeat (k) @(posedge tick_ms); end
    endtask
    task press(input integer b);                         // cạnh đầu, rung, giữ 20 ms, nhả có rung (như system_tb)
        begin
            btn[b] = 1'b1;
            repeat (7) @(negedge clk);  btn[b] = 1'b0;
            repeat (5) @(negedge clk);  btn[b] = 1'b1;
            repeat (11) @(negedge clk); btn[b] = 1'b0;
            repeat (3) @(negedge clk);  btn[b] = 1'b1;
            wait_ms(20);
            btn[b] = 1'b0;
            repeat (9) @(negedge clk);  btn[b] = 1'b1;
            repeat (4) @(negedge clk);  btn[b] = 1'b0;
            wait_ms(15);
        end
    endtask

    // ---- UART: tb đóng vai PC. Mỗi bit = 8 chu kỳ (G_BIT = 8), 8N1, bit 0 trước.
    integer ub;
    task ubyte(input [7:0] b);
        begin
            @(negedge clk) urx = 1'b0;
            repeat (8) @(negedge clk);
            for (ub = 0; ub < 8; ub = ub + 1) begin urx = b[ub]; repeat (8) @(negedge clk); end
            urx = 1'b1;
            repeat (8) @(negedge clk);
        end
    endtask
    // bộ giải mã chân TX của chip: bắt cạnh xuống, lấy mẫu giữa mỗi bit, in từng ký tự
    reg [7:0] tb_byte;
    integer   tj;
    reg [8*40:1] tline;
    initial forever begin
        @(negedge utx);
        repeat (12) @(posedge clk);
        for (tj = 0; tj < 8; tj = tj + 1) begin tb_byte[tj] = utx; repeat (8) @(posedge clk); end
        if (tb_byte == 8'd10) begin $display("[ms %6d | chu ky %7d] chip tra loi: %0s", ms, cyc, tline); tline = 0; end
        else tline = {tline[8*39:1], tb_byte};
    end

    reg [8*256:1] fimem;
    initial begin
        if (!$value$plusargs("imem=%s", fimem)) begin $display("thieu +imem=<file.hex>"); $finish; end
        #1;
        $readmemh(fimem, dut.u_cpu.imem);
        // khối cấu hình firmware đọc lúc khởi động (như system_tb): cờ, giờ (ms), {thứ, ngày}, timer
        dut.u_cpu.dmem[504] = 1;
        dut.u_cpu.dmem[505] = 43200000;                  // 12:00:00.000
        dut.u_cpu.dmem[506] = (5 << 16) | 9771;          // Thứ Sáu 02/10/2026
        dut.u_cpu.dmem[507] = 2000;                      // timer 2,000 s
        repeat (6) @(negedge clk);
        rst_in = 0;

        wait_ms(60);                                     // firmware khởi động, vẽ khung đầu
        $display("---- MODE: vao STOPWATCH");
        press(B_MODE);
        $display("---- A: chay stopwatch");
        press(B_A);
        wait_ms(120);
        $display("---- B: chup lap");
        press(B_B);
        wait_ms(80);
        $display("---- A: dung stopwatch");
        press(B_A);
        $display("---- MODE: sang TIMER");
        press(B_MODE);
        $display("---- A: chay timer (2000 ms)");
        press(B_A);
        wait_ms(2300);                                   // về 0 ở ~2000 ms, rồi đếm sang số âm
        $display("---- PC gui $Q*51 qua UART RX (hoi gio)");
        ubyte("$"); ubyte("Q"); ubyte("*"); ubyte("5"); ubyte("1"); ubyte(8'd10);
        wait_ms(60);                                     // chip nhận (ngắt UART), xử lý, trả lời qua TX
        $display("---- ket thuc: stopwatch val = %0d ms, timer val = %0d ms", sw_val, tmr_val);
        $finish;
    end

    initial begin                                        // chặn treo
        #(20 * 50 * 6000);
        $display("het gio an toan");
        $finish;
    end
endmodule
