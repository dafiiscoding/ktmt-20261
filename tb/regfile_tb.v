// regfile_tb.v — gói C1: reset = 0, $0 luôn 0, bypass bật/tắt, 1 000 thao tác ngẫu nhiên so mô hình.
`timescale 1ns/1ps
module regfile_tb;
    reg         clk = 0, rst = 1, we = 0;
    reg  [4:0]  wa = 0, ra1 = 0, ra2 = 0;
    reg  [31:0] wd = 0;
    wire [31:0] b_rd1, b_rd2, n_rd1, n_rd2;   // b_ = G_BYPASS 1, n_ = G_BYPASS 0

    regfile #(.G_BYPASS(1)) u_byp (.clk(clk), .rst(rst), .we(we), .wa(wa), .wd(wd),
                                   .ra1(ra1), .ra2(ra2), .rd1(b_rd1), .rd2(b_rd2));
    regfile #(.G_BYPASS(0)) u_nob (.clk(clk), .rst(rst), .we(we), .wa(wa), .wd(wd),
                                   .ra1(ra1), .ra2(ra2), .rd1(n_rd1), .rd2(n_rd2));

    always #10 clk = ~clk;

    reg [31:0] m [0:31];      // mô hình
    integer i, n, nerr;
    reg [31:0] eb1, eb2, en1, en2;

    task check(input cond, input [8*32:1] what);
        begin
            n = n + 1;
            if (!cond) begin
                nerr = nerr + 1;
                if (nerr <= 10) $display("loi %0s: we=%b wa=%0d wd=%h ra1=%0d ra2=%0d byp=%h %h nob=%h %h",
                                         what, we, wa, wd, ra1, ra2, b_rd1, b_rd2, n_rd1, n_rd2);
            end
        end
    endtask

    // kiểm cổng đọc trong chu kỳ hiện tại (trước sườn lên), rồi cập nhật mô hình ở sườn
    task step_check;
        begin
            #1;
            en1 = (ra1 == 0) ? 0 : m[ra1];
            en2 = (ra2 == 0) ? 0 : m[ra2];
            eb1 = (ra1 != 0 && we && wa == ra1) ? wd : en1;
            eb2 = (ra2 != 0 && we && wa == ra2) ? wd : en2;
            check(b_rd1 === eb1 && b_rd2 === eb2, "bypass=1");
            check(n_rd1 === en1 && n_rd2 === en2, "bypass=0");
            @(posedge clk);
            if (we && wa != 0) m[wa] = wd;
            @(negedge clk);
        end
    endtask

    initial begin
        n = 0; nerr = 0;
        for (i = 0; i < 32; i = i + 1) m[i] = 0;
        // làm bẩn trước reset để thấy reset xóa thật
        repeat (2) @(negedge clk);
        rst = 0;
        we = 1; wa = 7; wd = 32'hDEADBEEF;
        @(negedge clk);
        rst = 1; we = 0;
        @(negedge clk);
        rst = 0;

        // reset: mọi thanh ghi = 0
        for (i = 0; i < 32; i = i + 1) begin
            ra1 = i; ra2 = 31 - i; #1;
            check(b_rd1 === 0 && b_rd2 === 0 && n_rd1 === 0 && n_rd2 === 0, "reset");
        end

        // ghi $0 bị bỏ, kể cả khi đang đọc $0 cùng chu kỳ
        we = 1; wa = 0; wd = 32'hFFFFFFFF; ra1 = 0; ra2 = 0;
        step_check;
        we = 0; #1;
        check(b_rd1 === 0 && n_rd1 === 0, "$0 sau ghi");

        // bypass: ghi $5 và đọc $5 cùng chu kỳ
        we = 1; wa = 5; wd = 32'h12345678; ra1 = 5; ra2 = 6; #1;
        check(b_rd1 === 32'h12345678, "G_BYPASS=1 tra wd");
        check(n_rd1 === 32'h00000000, "G_BYPASS=0 tra gia tri cu");
        step_check;
        we = 0; ra1 = 5; #1;
        check(b_rd1 === 32'h12345678 && n_rd1 === 32'h12345678, "doc sau ghi");

        // 1 000 thao tác ngẫu nhiên
        repeat (1000) begin
            we  = $random;
            wa  = $random;
            wd  = $random;
            ra1 = ($random & 3) == 0 ? wa : $random;   // 1/4 số lần đọc trùng thanh ghi đang ghi
            ra2 = $random;
            step_check;
        end

        if (nerr == 0) $display("PASS regfile_tb %0d", n);
        else $display("FAIL regfile_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
