// muldiv_tb.v — gói A2: mul.txt (825), div.txt (830), toán hạng đổi sau start, số chu kỳ busy,
// chạy lại div.txt với ce = 1 mỗi 2 chu kỳ (như G1, D = 2). Chạy từ thư mục gốc project.
`timescale 1ns/1ps
module muldiv_tb;
    reg         clk = 0, rst = 1, ce = 1, start = 0;
    reg  [31:0] a = 0, b = 0;
    wire [31:0] mul_y, lo, hi;
    wire        busy, done, dz;

    muldiv dut (.clk(clk), .rst(rst), .ce(ce), .start(start), .a(a), .b(b),
                .mul_y(mul_y), .busy(busy), .done(done), .lo(lo), .hi(hi), .dz(dz));

    always #10 clk = ~clk;

    integer fd, c, r, n, nerr, ncase, cyc, busy_cyc, pass, ce_div, phase;
    reg [8*200:1] rest;
    reg [31:0] e_a, e_b, e_lo, e_hi, e_y;
    integer e_dz;

    // ce = 1 ở 1 trong ce_div chu kỳ clk (ce_div = 1: luôn bật)
    always @(posedge clk) begin
        phase <= (phase + 1) % ce_div;
    end
    always @* ce = (phase == 0);

    task check(input cond, input [8*40:1] what);
        begin
            n = n + 1;
            if (!cond) begin
                nerr = nerr + 1;
                if (nerr <= 10) $display("loi %0s: a=%h b=%h lo=%h hi=%h dz=%b busy_cyc=%0d (can %h %h %0d)",
                                         what, e_a, e_b, lo, hi, dz, busy_cyc, e_lo, e_hi, e_dz);
            end
        end
    endtask

    // Một lệnh div theo đúng giao thức CPU: start 1 chu kỳ CPU, rồi đứng chờ tới chu kỳ done.
    // cyc = số chu kỳ CPU từ chu kỳ start tới chu kỳ done (gồm cả hai đầu).
    task run_div;
        begin
            @(negedge clk);
            while (!ce) @(negedge clk);
            a = e_a; b = e_b; start = 1;
            cyc = 1; busy_cyc = 0;
            #1;
            while (!done) begin
                @(negedge clk);
                if (ce) begin
                    start = 0;
                    a = $random; b = $random;     // CPU đã đổi toán hạng: kết quả không được đổi
                    cyc = cyc + 1;
                    #1;
                    if (busy) busy_cyc = busy_cyc + 1;
                end
            end
            @(negedge clk);
            start = 0;
        end
    endtask

    initial begin
        n = 0; nerr = 0; ce_div = 1; phase = 0;
        repeat (3) @(negedge clk);
        rst = 0;

        // ---- mul (tổ hợp)
        fd = $fopen("tb/vectors/mul.txt", "r");
        if (fd == 0) begin $display("FAIL muldiv_tb khong mo duoc mul.txt"); $finish; end
        ncase = 0;
        while (!$feof(fd)) begin
            c = $fgetc(fd);
            if (c == "#" || c == "\n") r = $fgets(rest, fd);
            else if (c != -1) begin
                r = $ungetc(c, fd);
                r = $fscanf(fd, "%h %h %h\n", e_a, e_b, e_y);
                a = e_a; b = e_b; #1;
                ncase = ncase + 1;
                e_lo = 0; e_hi = 0; e_dz = 0;
                check(mul_y === e_y, "mul");
            end
        end
        $fclose(fd);
        if (ncase != 825) begin nerr = nerr + 1; $display("loi so ca mul = %0d", ncase); end

        // ---- div: lần 1 ce luôn bật, lần 2 ce mỗi 2 chu kỳ clk
        for (pass = 1; pass <= 2; pass = pass + 1) begin
            ce_div = pass;
            fd = $fopen("tb/vectors/div.txt", "r");
            ncase = 0;
            while (!$feof(fd)) begin
                c = $fgetc(fd);
                if (c == "#" || c == "\n") r = $fgets(rest, fd);
                else if (c != -1) begin
                    r = $ungetc(c, fd);
                    r = $fscanf(fd, "%h %h %h %h %d\n", e_a, e_b, e_lo, e_hi, e_dz);
                    run_div;
                    ncase = ncase + 1;
                    check(lo === e_lo && hi === e_hi && dz === e_dz[0], "div");
                    if (e_dz) check(cyc == 1 && busy_cyc == 0, "so chu ky chia 0");
                    else      check(cyc == 33 && busy_cyc == 32, "so chu ky div");
                    check(!busy, "busy sau done");
                end
            end
            $fclose(fd);
            if (ncase != 830) begin nerr = nerr + 1; $display("loi so ca div = %0d", ncase); end
        end

        // ---- mul không đụng HI/LO: giữ kết quả div cuối, đổi a, b tùy ý
        e_lo = lo; e_hi = hi; e_dz = dz;
        repeat (20) begin
            @(negedge clk); a = $random; b = $random;
        end
        check(lo === e_lo && hi === e_hi && dz === e_dz[0], "HI/LO doi khi khong start");

        if (nerr == 0) $display("PASS muldiv_tb %0d", n);
        else $display("FAIL muldiv_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule
