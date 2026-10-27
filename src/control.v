// control.v — giải mã một cấp: instr → 16 tín hiệu điều khiển (tổ hợp), dùng chung G1 và G2
// Gói C2 · chủ: TV3 · spec: control-table.md §1.1 (mã nhị phân), §2 (bảng 28 lệnh), §3 (trường lạ)
// Code do Claude viết theo yêu cầu Long (02/10/2026); chủ gói đọc hiểu để vấn đáp.
// Mã lạ → mọi tín hiệu = 0 và valid = 0 (CPU coi là NOP, mô phỏng báo "lệnh lạ").
module control #(
    parameter G_BCD_COMB = 0          // 1: bcd tổ hợp → multi = 00 (control-table §1)
) (
    input  wire [31:0] instr,
    output reg         reg_write,
    output reg  [1:0]  dst,           // 00 –, 01 rd, 10 rt, 11 $31
    output reg         alu_src,       // 1: toán hạng B = immediate
    output reg  [1:0]  ext,           // 00 SE, 01 ZE, 10 LUI
    output reg  [3:0]  alu_ctl,
    output reg  [2:0]  res_sel,       // 0 ALU, 1 MUL, 2 HI, 3 LO, 4 BCD, 5 CP0, 6 PC4
    output reg         mem_read,
    output reg         mem_write,
    output reg         mem_to_reg,
    output reg  [1:0]  branch,        // 01 beq, 10 bne
    output reg         jump,
    output reg         jump_reg,
    output reg  [1:0]  multi,         // 01 div, 10 bcd tuần tự
    output reg  [1:0]  cp0_op,        // 01 mtc0, 10 eret
    output reg         uses_rs,
    output reg         uses_rt,
    output reg         valid          // 0 = lệnh lạ (không thuộc 28 lệnh)
);
    localparam D_NONE = 2'b00, D_RD = 2'b01, D_RT = 2'b10, D_31 = 2'b11;
    localparam E_SE = 2'b00, E_ZE = 2'b01, E_LUI = 2'b10;
    localparam A_ADD = 4'd0, A_SUB = 4'd1, A_AND = 4'd2, A_OR = 4'd3,
               A_XOR = 4'd4, A_SLT = 4'd5, A_SLL = 4'd6, A_SRA = 4'd7;
    localparam R_ALU = 3'd0, R_MUL = 3'd1, R_HI = 3'd2, R_LO = 3'd3,
               R_BCD = 3'd4, R_CP0 = 3'd5, R_PC4 = 3'd6;

    wire [5:0] op    = instr[31:26];
    wire [4:0] rs    = instr[25:21];
    wire [5:0] funct = instr[5:0];

    // ghi R-type ALU: reg_write, dst rd, alu_ctl, dùng rs/rt
    task r_alu(input [3:0] ctl, input u_rs);
        begin
            valid = 1; reg_write = 1; dst = D_RD; alu_ctl = ctl; res_sel = R_ALU;
            uses_rs = u_rs; uses_rt = 1;
        end
    endtask
    // I-type ALU: ghi rt, B = immediate
    task i_alu(input [3:0] ctl, input [1:0] e, input u_rs);
        begin
            valid = 1; reg_write = 1; dst = D_RT; alu_src = 1; ext = e; alu_ctl = ctl; res_sel = R_ALU;
            uses_rs = u_rs;
        end
    endtask

    always @* begin
        valid = 0; reg_write = 0; dst = D_NONE; alu_src = 0; ext = E_SE; alu_ctl = A_ADD; res_sel = R_ALU;
        mem_read = 0; mem_write = 0; mem_to_reg = 0; branch = 2'b00; jump = 0; jump_reg = 0;
        multi = 2'b00; cp0_op = 2'b00; uses_rs = 0; uses_rt = 0;
        case (op)
            6'h00: case (funct)
                6'h21: r_alu(A_ADD, 1);                                   // addu
                6'h23: r_alu(A_SUB, 1);                                   // subu
                6'h24: r_alu(A_AND, 1);                                   // and
                6'h25: r_alu(A_OR,  1);                                   // or
                6'h26: r_alu(A_XOR, 1);                                   // xor
                6'h2A: r_alu(A_SLT, 1);                                   // slt
                6'h00: r_alu(A_SLL, 0);                                   // sll (nop = 0)
                6'h03: r_alu(A_SRA, 0);                                   // sra
                6'h08: begin valid = 1; jump_reg = 1; uses_rs = 1; end   // jr
                6'h1A: begin valid = 1; multi = 2'b01; uses_rs = 1; uses_rt = 1; end  // div
                6'h10: begin valid = 1; reg_write = 1; dst = D_RD; res_sel = R_HI; end // mfhi
                6'h12: begin valid = 1; reg_write = 1; dst = D_RD; res_sel = R_LO; end // mflo
                default: ;
            endcase
            6'h09: i_alu(A_ADD, E_SE,  1);                                // addiu
            6'h0A: i_alu(A_SLT, E_SE,  1);                                // slti
            6'h0C: i_alu(A_AND, E_ZE,  1);                                // andi
            6'h0D: i_alu(A_OR,  E_ZE,  1);                                // ori
            6'h0F: i_alu(A_OR,  E_LUI, 0);                                // lui (rs = $0)
            6'h23: begin i_alu(A_ADD, E_SE, 1); mem_read = 1; mem_to_reg = 1; end   // lw
            6'h2B: begin                                                  // sw
                valid = 1; alu_src = 1; ext = E_SE; alu_ctl = A_ADD; mem_write = 1;
                uses_rs = 1; uses_rt = 1;
            end
            6'h04: begin valid = 1; branch = 2'b01; uses_rs = 1; uses_rt = 1; end  // beq
            6'h05: begin valid = 1; branch = 2'b10; uses_rs = 1; uses_rt = 1; end  // bne
            6'h02: begin valid = 1; jump = 1; end                                  // j
            6'h03: begin valid = 1; jump = 1; reg_write = 1; dst = D_31; res_sel = R_PC4; end  // jal
            6'h1C: case (funct)                                           // SPECIAL2
                6'h02: begin valid = 1; reg_write = 1; dst = D_RD; res_sel = R_MUL;           // mul
                             uses_rs = 1; uses_rt = 1; end
                6'h10: begin valid = 1; reg_write = 1; dst = D_RD; res_sel = R_BCD;           // bcd
                             multi = (G_BCD_COMB != 0) ? 2'b00 : 2'b10; uses_rs = 1; end
                default: ;
            endcase
            6'h10: begin                                                  // COP0
                if (rs == 5'h00 && instr[10:0] == 11'd0) begin                            // mfc0
                    valid = 1; reg_write = 1; dst = D_RT; res_sel = R_CP0;
                end else if (rs == 5'h04 && instr[10:0] == 11'd0) begin                   // mtc0
                    valid = 1; cp0_op = 2'b01; uses_rt = 1;
                end else if (instr == 32'h42000018) begin                                 // eret
                    valid = 1; cp0_op = 2'b10;
                end
            end
            default: ;
        endcase
    end
endmodule
