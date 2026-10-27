// alu_tb.v — gói A1: so ALU với tb/vectors/alu.txt (4 200 ca). Chạy từ thư mục gốc project.
`timescale 1ns/1ps
module alu_tb;
    reg  [31:0] a, b;
    reg  [4:0]  shamt;
    reg  [3:0]  ctl;
    wire [31:0] y;
    wire        zero;

    alu dut (.a(a), .b(b), .shamt(shamt), .ctl(ctl), .y(y), .zero(zero));

    integer fd, c, r, n, nerr;
    reg [8*200:1] rest;
    reg [31:0] e_ctl, e_a, e_b, e_sh, e_y;
    integer e_zero;

    initial begin
        n = 0; nerr = 0;
        fd = $fopen("tb/vectors/alu.txt", "r");
        if (fd == 0) begin $display("FAIL alu_tb khong mo duoc tb/vectors/alu.txt"); $finish; end
        while (!$feof(fd)) begin
            c = $fgetc(fd);
            if (c == "#" || c == "\n") r = $fgets(rest, fd);
            else if (c != -1) begin
                r = $ungetc(c, fd);
                r = $fscanf(fd, "%h %h %h %h %h %d\n", e_ctl, e_a, e_b, e_sh, e_y, e_zero);
                ctl = e_ctl[3:0]; a = e_a; b = e_b; shamt = e_sh[4:0];
                #1;
                n = n + 1;
                if (y !== e_y || zero !== e_zero[0]) begin
                    nerr = nerr + 1;
                    if (nerr <= 10)
                        $display("loi ctl=%0d a=%h b=%h sh=%0d: y=%h zero=%b, can %h %0d",
                                 ctl, a, b, shamt, y, zero, e_y, e_zero);
                end
            end
        end
        $fclose(fd);
        if (nerr == 0 && n == 4200) $display("PASS alu_tb %0d", n);
        else $display("FAIL alu_tb %0d loi / %0d ca", nerr, n);
        $finish;
    end
endmodule
