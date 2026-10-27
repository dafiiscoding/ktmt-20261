// hazard_tb.v — gói B5: tb đơn vị hazard.v. Đưa tổ hợp ngẫu nhiên (thanh ghi 0..3 để trùng nhiều hơn)
// và so với mô hình tham chiếu viết lại theo bảng chân lý của pipeline-policy §3–§5 (không sao chép RTL).
// Kiểm thêm: mọi tổ hợp đầy đủ của các cờ nhỏ (valid, uses, mem_read, reg_write) × so sánh thanh ghi.
// Dòng cuối: PASS hazard_tb <n> hoặc FAIL.
`timescale 1ns/1ps
module hazard_tb;
    reg        ifid_valid = 0, ifid_uses_rs = 0, ifid_uses_rt = 0, idex_mem_read = 0;
    reg  [4:0] ifid_rs = 0, ifid_rt = 0, idex_dst = 0, idex_rs = 0, idex_rt = 0, exmem_dst = 0, memwb_dst = 0;
    reg        exmem_reg_write = 0, memwb_reg_write = 0, taken = 0;
    wire       stall_lu, flush;
    wire [1:0] fwd_a, fwd_b;

    hazard dut (.ifid_valid(ifid_valid), .ifid_rs(ifid_rs), .ifid_rt(ifid_rt), .ifid_uses_rs(ifid_uses_rs),
                .ifid_uses_rt(ifid_uses_rt), .idex_mem_read(idex_mem_read), .idex_dst(idex_dst),
                .idex_rs(idex_rs), .idex_rt(idex_rt), .exmem_reg_write(exmem_reg_write), .exmem_dst(exmem_dst),
                .memwb_reg_write(memwb_reg_write), .memwb_dst(memwb_dst), .taken(taken),
                .stall_lu(stall_lu), .flush(flush), .fwd_a(fwd_a), .fwd_b(fwd_b));

    // mô hình tham chiếu: viết theo lời trong pipeline-policy (không dùng biểu thức của RTL)
    reg        r_lu, r_fa_ex, r_fa_wb, r_fb_ex, r_fb_wb;
    task ref_model;
        reg match_rs, match_rt, dep_rs, dep_rt, a_ex, a_wb, b_ex, b_wb;
        begin
            // load-use: lệnh ID đọc thanh ghi mà lệnh EX đang load ghi
            dep_rs = ifid_uses_rs && (idex_dst == ifid_rs);
            dep_rt = ifid_uses_rt && (idex_dst == ifid_rt);
            r_lu = ifid_valid && idex_mem_read && (idex_dst != 0) && (dep_rs || dep_rt);
            // forwarding: EX/MEM trước MEM/WB
            a_ex = exmem_reg_write && (exmem_dst != 0) && (exmem_dst == idex_rs);
            a_wb = memwb_reg_write && (memwb_dst != 0) && (memwb_dst == idex_rs);
            b_ex = exmem_reg_write && (exmem_dst != 0) && (exmem_dst == idex_rt);
            b_wb = memwb_reg_write && (memwb_dst != 0) && (memwb_dst == idex_rt);
            r_fa_ex = a_ex;
            r_fa_wb = !a_ex && a_wb;
            r_fb_ex = b_ex;
            r_fb_wb = !b_ex && b_wb;
        end
    endtask

    integer i, n, nerr, seed;
    reg [1:0] exp_a, exp_b;
    initial begin
        n = 0; nerr = 0;
        seed = 12345;
        for (i = 0; i < 200000; i = i + 1) begin
            ifid_valid = $random(seed);
            ifid_uses_rs = $random(seed);
            ifid_uses_rt = $random(seed);
            idex_mem_read = $random(seed);
            exmem_reg_write = $random(seed);
            memwb_reg_write = $random(seed);
            taken = $random(seed);
            ifid_rs = $random(seed) & 3;  ifid_rt = $random(seed) & 3;
            idex_dst = $random(seed) & 3; idex_rs = $random(seed) & 3; idex_rt = $random(seed) & 3;
            exmem_dst = $random(seed) & 3; memwb_dst = $random(seed) & 3;
            #1;
            ref_model;
            exp_a = r_fa_ex ? 2'b10 : r_fa_wb ? 2'b01 : 2'b00;
            exp_b = r_fb_ex ? 2'b10 : r_fb_wb ? 2'b01 : 2'b00;
            n = n + 1;
            if (stall_lu !== r_lu || flush !== taken || fwd_a !== exp_a || fwd_b !== exp_b) begin
                nerr = nerr + 1;
                if (nerr <= 10)
                    $display("loi vec %0d: lu %b/%b flush %b/%b fwdA %b/%b fwdB %b/%b", i,
                             stall_lu, r_lu, flush, taken, fwd_a, exp_a, fwd_b, exp_b);
            end
        end
        // ca cụ thể (pipeline-policy §4): lw ở EX, addu ở ID dùng rs → stall; cùng với rt không đọc → không stall
        ifid_valid = 1; idex_mem_read = 1; idex_dst = 8; ifid_rs = 8; ifid_rt = 9;
        ifid_uses_rs = 1; ifid_uses_rt = 0; #1;
        n = n + 1; if (stall_lu !== 1'b1) begin nerr = nerr + 1; $display("loi lu rs"); end
        ifid_uses_rs = 0; ifid_uses_rt = 1; ifid_rt = 8; #1;
        n = n + 1; if (stall_lu !== 1'b1) begin nerr = nerr + 1; $display("loi lu rt"); end
        ifid_rt = 9; #1;                                                  // rt không khớp, rs không đọc
        n = n + 1; if (stall_lu !== 1'b0) begin nerr = nerr + 1; $display("loi lu thua"); end
        ifid_uses_rt = 0; ifid_rt = 8; ifid_valid = 0; #1;               // bong bóng ở IF/ID: không stall
        n = n + 1; if (stall_lu !== 1'b0) begin nerr = nerr + 1; $display("loi lu bong bong"); end
        // ưu tiên EX/MEM khi cả hai nguồn cùng ghi $5 (pipeline-policy §3)
        idex_rs = 5; exmem_reg_write = 1; exmem_dst = 5; memwb_reg_write = 1; memwb_dst = 5; #1;
        n = n + 1; if (fwd_a !== 2'b10) begin nerr = nerr + 1; $display("loi uu tien EX/MEM"); end
        exmem_dst = 6; #1;                                                // EX/MEM không khớp → lấy MEM/WB
        n = n + 1; if (fwd_a !== 2'b01) begin nerr = nerr + 1; $display("loi fwd MEM/WB"); end
        memwb_dst = 0; #1;                                                // $0 không bao giờ được forward
        n = n + 1; if (fwd_a !== 2'b00) begin nerr = nerr + 1; $display("loi fwd $0"); end

        if (nerr == 0) $display("PASS hazard_tb %0d", n);
        else $display("FAIL hazard_tb %0d loi / %0d vector", nerr, n);
        $finish;
    end
endmodule
