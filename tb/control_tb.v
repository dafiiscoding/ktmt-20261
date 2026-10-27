// control_tb.v — gói C2: so control với tb/vectors/control.txt (84 ca 28 lệnh + 5 mã lạ ra toàn 0).
// Chạy 2 bản: bcd tuần tự (multi = 10, đúng file) và bcd tổ hợp (G_BCD_COMB = 1 → dòng bcd ra multi = 00).
// Thêm: valid = 1 đúng ở 84 dòng lệnh thật; 100 000 lệnh ngẫu nhiên — valid = 0 thì mọi tín hiệu = 0.
`timescale 1ns/1ps
module control_tb;
    reg  [31:0] instr;
    wire [27:0] y0, y1;      // 16 tín hiệu ghép theo thứ tự cột của file
    wire        v0, v1;

    control_pack #(.G_BCD_COMB(0)) u0 (.instr(instr), .y(y0), .valid(v0));
    control_pack #(.G_BCD_COMB(1)) u1 (.instr(instr), .y(y1), .valid(v1));

    integer fd, c, r, n, nerr, nline, k;
    reg [8*200:1] rest;
    reg [8*12:1]  name;
    reg [31:0] e_in;
    reg [31:0] e [0:15];
    reg [27:0] want, want_comb;
    reg        is_bcd;

    task check(input cond, input [8*40:1] what);
        begin
            n = n + 1;
            if (!cond) begin
                nerr = nerr + 1;
                if (nerr <= 10) $display("loi %0s: instr=%h y0=%h y1=%h v=%b%b", what, instr, y0, y1, v0, v1);
            end
        end
    endtask

    initial begin
        n = 0; nerr = 0; nline = 0;
        fd = $fopen("tb/vectors/control.txt", "r");
        if (fd == 0) begin $display("FAIL control_tb khong mo duoc tb/vectors/control.txt"); $finish; end
        while (!$feof(fd)) begin
            c = $fgetc(fd);
            if (c == "#" || c == "\n") r = $fgets(rest, fd);
            else if (c != -1) begin
                r = $ungetc(c, fd);
                r = $fscanf(fd, "%h %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d # %s",
                            e_in, e[0], e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8], e[9], e[10],
                            e[11], e[12], e[13], e[14], e[15], name);
                r = $fgets(rest, fd);
                want = {2'b00, e[0][0], e[1][1:0], e[2][0], e[3][1:0], e[4][3:0], e[5][2:0], e[6][0], e[7][0],
                        e[8][0], e[9][1:0], e[10][0], e[11][0], e[12][1:0], e[13][1:0], e[14][0], e[15][0]};
                is_bcd = (name == "bcd");
                want_comb = want;
                if (is_bcd) want_comb[5:4] = 2'b00;          // multi
                instr = e_in;
                #1;
                nline = nline + 1;
                check(y0 === want, "ban tuan tu vs control.txt");
                check(y1 === want_comb, "ban to hop vs control.txt");
                check(v0 === (name != "illegal") && v1 === v0, "valid");
            end
        end
        $fclose(fd);
        check(nline == 89, "du 89 dong (84 + 5 ma la)");

        // lệnh lạ ngẫu nhiên: valid = 0 ⇒ mọi tín hiệu = 0
        for (k = 0; k < 100000; k = k + 1) begin
            instr = $random;
            #1;
            if (!v0) check(y0 === 28'd0 && y1 === 28'd0, "ma la -> toan 0");
        end

        if (nerr == 0) $display("PASS control_tb %0d", n);
        else $display("FAIL control_tb %0d loi / %0d kiem tra", nerr, n);
        $finish;
    end
endmodule

// ghép 16 tín hiệu theo thứ tự cột của control.txt (26 bit, đệm 2 bit 0 ở đầu)
module control_pack #(parameter G_BCD_COMB = 0) (input wire [31:0] instr, output wire [27:0] y, output wire valid);
    wire       rw, as, mr, mw, m2r, j, jr, urs, urt;
    wire [1:0] dst, ext, br, mu, cp;
    wire [3:0] alu;
    wire [2:0] rs;
    control #(.G_BCD_COMB(G_BCD_COMB)) dut (
        .instr(instr), .reg_write(rw), .dst(dst), .alu_src(as), .ext(ext), .alu_ctl(alu), .res_sel(rs),
        .mem_read(mr), .mem_write(mw), .mem_to_reg(m2r), .branch(br), .jump(j), .jump_reg(jr),
        .multi(mu), .cp0_op(cp), .uses_rs(urs), .uses_rt(urt), .valid(valid));
    assign y = {2'b00, rw, dst, as, ext, alu, rs, mr, mw, m2r, br, j, jr, mu, cp, urs, urt};
endmodule
