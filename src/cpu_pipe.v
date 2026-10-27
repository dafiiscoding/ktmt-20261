// cpu_pipe.v — lõi MIPS pipeline 5 tầng (G2), cùng 28 lệnh và cùng cổng với cpu_g1
// Gói C7 · chủ: TV3 · spec: pipeline-policy.md (toàn bộ), mmio-map.md §1.2, §2; control-table.md; isa-spec.md §8
// Code do Claude viết theo yêu cầu Long (20/10/2026, ngoại lệ luật tự viết); chủ gói đọc hiểu để vấn đáp.
//
// Một bước = một cạnh cpu_ce (G2: D = 1 → mỗi chu kỳ hệ thống). Mọi thanh ghi tầng chỉ đổi ở cạnh cpu_ce.
//   IF : pc → IF/ID (imem chốt ở cạnh cuối IF; thanh ghi đầu ra = IF/ID.instr)
//   ID : giải mã, đọc regfile (bypass nội bộ), chọn dst, mở rộng immediate → ID/EX
//   EX : forwarding, ALU / mul / div / bcd, quyết định nhánh, CP0 ghi (mtc0/eret) → EX/MEM
//   MEM: DMEM ghi/đọc đồng bộ; MMIO bus_we/bus_re đúng 1 bước cho mỗi lệnh → MEM/WB
//   WB : ghi regfile (cạnh cuối WB); lệnh retire ở đây → trace
// Ngắt chính xác (pipeline-policy §10): nhận ở ID/EX; lệnh ở ID/EX bị hủy, EX/MEM và MEM/WB hoàn thành; EPC = PC lệnh cũ nhất chưa retire.
// Bong bóng (bubble) = mọi bit điều khiển bằng 0; trace chỉ ghi lệnh có valid.
module cpu_pipe #(
    parameter IMEM_FILE  = "",
    parameter DMEM_FILE  = "",
    parameter G_IMEM_AW  = 10,
    parameter G_BCD_COMB = 0,
    parameter TRACE_FILE = ""
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        cpu_ce,
    output wire [7:0]  bus_addr,
    output wire [31:0] bus_wdata,
    output wire        bus_we,
    output wire        bus_re,
    input  wire [31:0] bus_rdata,
    input  wire        irq,             // mức, từ irq_ctrl (ngắt chính xác, pipeline-policy §10)
    input  wire [7:0]  irq_ip,          // Cause.IP, đọc qua mfc0 $13
    output wire        div_dz,
    output wire [31:0] pc_out,
    output wire        retire           // xung: lệnh hợp lệ rời WB ở bước này
);
    localparam NI = 1 << G_IMEM_AW;

    reg  [31:0] imem [0:NI-1];
    reg  [31:0] dmem [0:1023];
    reg  [31:0] pc;
    reg  [1:0]  status;                 // [1] EXL, [0] IE
    reg  [31:0] epc;
    reg         started;                // khối nhiều chu kỳ đã nhận start (pipeline-policy §6)

    // ------------------------------------------------------------ IF/ID
    reg         ifid_v;
    reg  [31:0] ifid_pc, ifid_ins;

    // ------------------------------------------------------------ ID/EX
    reg         idex_v, idex_rw, idex_m2r, idex_mrd, idex_mwr, idex_asrc, idex_jmp, idex_jr;
    reg  [3:0]  idex_actl;
    reg  [2:0]  idex_rsel;
    reg  [1:0]  idex_br, idex_multi, idex_cp0;
    reg  [31:0] idex_pc, idex_pc4, idex_ins, idex_a, idex_b, idex_imm;
    reg  [4:0]  idex_sh, idex_rd, idex_rs, idex_rt, idex_dst;
    reg  [25:0] idex_j;

    // ------------------------------------------------------------ EX/MEM
    reg         exm_v, exm_rw, exm_m2r, exm_mrd, exm_mwr;
    reg  [31:0] exm_res, exm_st, exm_pc, exm_ins;
    reg  [4:0]  exm_dst;
    reg  [1:0]  exm_cp0;                // cờ CP0 đi theo lệnh (cho quy tắc chặn ngắt sau mtc0/eret)

    // ------------------------------------------------------------ MEM/WB
    reg         mw_v, mw_rw, mw_m2r, mw_mrd, mw_mwr, mw_lmmio;
    reg  [31:0] mw_res, mw_mdata, mw_st, mw_addr, mw_pc, mw_ins;
    reg  [4:0]  mw_dst;
    reg  [1:0]  mw_cp0;

    // ------------------------------------------------------------ ID: giải mã + regfile
    wire [4:0]  f_rs = ifid_ins[25:21], f_rt = ifid_ins[20:16], f_rd = ifid_ins[15:11], f_sh = ifid_ins[10:6];
    wire [15:0] imm16 = ifid_ins[15:0];

    wire       reg_write, alu_src, mem_read, mem_write, mem_to_reg, jump, jump_reg, uses_rs, uses_rt, valid;
    wire [1:0] dst_sel, d_ext, branch, multi, cp0_op;
    wire [3:0] alu_ctl;
    wire [2:0] res_sel;
    control #(.G_BCD_COMB(G_BCD_COMB)) u_ctl (
        .instr(ifid_ins), .reg_write(reg_write), .dst(dst_sel), .alu_src(alu_src), .ext(d_ext), .alu_ctl(alu_ctl),
        .res_sel(res_sel), .mem_read(mem_read), .mem_write(mem_write), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump), .jump_reg(jump_reg), .multi(multi), .cp0_op(cp0_op),
        .uses_rs(uses_rs), .uses_rt(uses_rt), .valid(valid));
    wire [31:0] imm_x = (d_ext == 2'b01) ? {16'd0, imm16} :
                        (d_ext == 2'b10) ? {imm16, 16'd0} : {{16{imm16[15]}}, imm16};

    wire [4:0] d_dst = (!ifid_v)      ? 5'd0 :
                       (dst_sel == 2'b01) ? f_rd :
                       (dst_sel == 2'b10) ? f_rt :
                       (dst_sel == 2'b11) ? 5'd31 : 5'd0;

    wire [31:0] rs_v, rt_v, wb;
    wire        we_rf = cpu_ce && mw_v && mw_rw;
    regfile #(.G_BYPASS(1)) u_rf (.clk(clk), .rst(rst), .we(we_rf), .wa(mw_dst), .wd(wb),
                                  .ra1(f_rs), .ra2(f_rt), .rd1(rs_v), .rd2(rt_v));

    // ------------------------------------------------------------ hazard + forwarding (B5)
    wire        stall_lu, flush;
    wire [1:0]  fwd_a, fwd_b;
    wire        stall_busy;
    wire        take;
    wire        take_irq;
    reg         irq_tr;                 // nhận ngắt ở chu kỳ trước → ghi dòng INTERRUPT sau khi lệnh EX/MEM đã retire
    reg         last_cp0;               // lệnh retire gần nhất là CP0 (khớp quy tắc block của ISS)
    wire [31:0] irq_epc = idex_v ? idex_pc : ifid_v ? ifid_pc : pc;
    hazard u_haz (
        .ifid_valid(ifid_v), .ifid_rs(f_rs), .ifid_rt(f_rt), .ifid_uses_rs(uses_rs), .ifid_uses_rt(uses_rt),
        .idex_mem_read(idex_mrd), .idex_dst(idex_dst), .idex_rs(idex_rs), .idex_rt(idex_rt),
        .exmem_reg_write(exm_rw), .exmem_dst(exm_dst), .memwb_reg_write(mw_rw), .memwb_dst(mw_dst),
        .taken(take), .stall_lu(stall_lu), .flush(flush), .fwd_a(fwd_a), .fwd_b(fwd_b));

    // ------------------------------------------------------------ EX
    wire [31:0] opA = (fwd_a == 2'b10) ? exm_res : (fwd_a == 2'b01) ? wb : idex_a;
    wire [31:0] opB = (fwd_b == 2'b10) ? exm_res : (fwd_b == 2'b01) ? wb : idex_b;
    wire [31:0] alu_b = idex_asrc ? idex_imm : opB;
    wire [31:0] alu_y;
    wire        alu_zero;
    alu u_alu (.a(opA), .b(alu_b), .shamt(idex_sh), .ctl(idex_actl), .y(alu_y), .zero(alu_zero));

    wire [31:0] mul_y, lo, hi, bcd_y;
    wire        md_busy, md_done, bc_busy, bc_done;
    wire        md_go = cpu_ce && (idex_multi == 2'b01) && !started;
    wire        bc_go = cpu_ce && (idex_multi == 2'b10) && !started;
    muldiv u_md (.clk(clk), .rst(rst), .ce(cpu_ce), .start(md_go), .a(opA), .b(opB),
                 .mul_y(mul_y), .busy(md_busy), .done(md_done), .lo(lo), .hi(hi), .dz(div_dz));
    bcd_unit #(.G_COMB(G_BCD_COMB)) u_bcd (.clk(clk), .rst(rst), .ce(cpu_ce), .start(bc_go),
                 .x(opA), .busy(bc_busy), .done(bc_done), .y(bcd_y));

    wire mdone = (idex_multi == 2'b01) ? md_done : (idex_multi == 2'b10) ? bc_done : 1'b1;
    assign stall_busy = (idex_multi != 2'b00) && !mdone;

    reg [31:0] cp0_rd;
    always @* begin
        case (idex_rd)
            5'd12:   cp0_rd = {30'd0, status};
            5'd13:   cp0_rd = {16'd0, irq_ip, 8'd0};
            5'd14:   cp0_rd = epc;
            default: cp0_rd = 32'd0;
        endcase
    end

    reg [31:0] ex_res;
    always @* begin
        case (idex_rsel)
            3'd1:    ex_res = mul_y;
            3'd2:    ex_res = hi;
            3'd3:    ex_res = lo;
            3'd4:    ex_res = bcd_y;
            3'd5:    ex_res = cp0_rd;
            3'd6:    ex_res = idex_pc4;
            default: ex_res = alu_y;
        endcase
    end

    // nhánh/nhảy quyết định ở EX (pipeline-policy §5); không tính khi EX đang bận
    wire eq = (opA == opB);
    assign take = idex_v && !stall_busy &&
                  ((idex_br == 2'b01 && eq) || (idex_br == 2'b10 && !eq) || idex_jmp || idex_jr || (idex_cp0 == 2'b10));
    wire [31:0] tgt = (idex_cp0 == 2'b10) ? epc :
                      idex_jr             ? {opA[31:2], 2'b00} :
                      idex_jmp            ? {idex_pc4[31:28], idex_j, 2'b00} :
                                            idex_pc4 + {idex_imm[29:0], 2'b00};

    // ------------------------------------------------------------ MEM
    wire in_dmem = (exm_res[31:12] == 20'd0);
    wire in_mmio = (exm_res[31:8] == 24'hFFFFFF);
    assign bus_addr  = {exm_res[7:2], 2'b00};
    assign bus_wdata = exm_st;
    assign bus_we    = cpu_ce && exm_v && exm_mwr && in_mmio;
    assign bus_re    = cpu_ce && exm_v && exm_mrd && in_mmio;

    // ------------------------------------------------------------ WB
    wire [31:0] wb_ld = mw_lmmio ? bus_rdata : mw_mdata;
    assign wb = mw_m2r ? wb_ld : mw_res;

    assign pc_out = pc;
    assign retire = cpu_ce && mw_v;

    // quyết định tầng ID: lệnh ở IF/ID có đi tiếp sang ID/EX không
    // nhận ngắt (§10): không khi EX bận (div/bcd), không khi load-use đang chờ, không ngay sau/trước lệnh CP0
    assign take_irq = cpu_ce && irq && status[0] && !status[1] && !stall_busy && !stall_lu
                      && !(idex_v && idex_cp0 != 2'b00) && (idex_multi == 2'b00)
                      && !(exm_v ? (exm_cp0 != 2'b00) : mw_v ? (mw_cp0 != 2'b00) : last_cp0);
    wire id_ok = ifid_v && !take && !stall_lu && !take_irq;

    // ------------------------------------------------------------ thanh ghi
`ifndef SYNTHESIS
    integer i;
    initial begin
        for (i = 0; i < NI; i = i + 1) imem[i] = 32'd0;
        for (i = 0; i < 1024; i = i + 1) dmem[i] = 32'd0;
    end
`endif
    generate
        if (IMEM_FILE != "") begin : g_imem_init
            initial $readmemh(IMEM_FILE, imem);
        end
        if (DMEM_FILE != "") begin : g_dmem_init
            initial $readmemh(DMEM_FILE, dmem);
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'd0;  status <= 2'b00;  epc <= 32'd0;  started <= 1'b0;
            ifid_v <= 1'b0;  ifid_pc <= 32'd0;  ifid_ins <= 32'd0;
            idex_v <= 1'b0;  idex_rw <= 1'b0;  idex_m2r <= 1'b0;  idex_mrd <= 1'b0;  idex_mwr <= 1'b0;
            idex_asrc <= 1'b0;  idex_jmp <= 1'b0;  idex_jr <= 1'b0;  idex_actl <= 4'd0;  idex_rsel <= 3'd0;
            idex_br <= 2'd0;  idex_multi <= 2'd0;  idex_cp0 <= 2'd0;  idex_dst <= 5'd0;
            idex_rs <= 5'd0;  idex_rt <= 5'd0;  idex_rd <= 5'd0;  idex_sh <= 5'd0;  idex_j <= 26'd0;
            idex_pc <= 32'd0;  idex_pc4 <= 32'd0;  idex_ins <= 32'd0;  idex_a <= 32'd0;  idex_b <= 32'd0;  idex_imm <= 32'd0;
            exm_v <= 1'b0;  exm_rw <= 1'b0;  exm_m2r <= 1'b0;  exm_mrd <= 1'b0;  exm_mwr <= 1'b0;  exm_dst <= 5'd0;
            exm_res <= 32'd0;  exm_st <= 32'd0;  exm_pc <= 32'd0;  exm_ins <= 32'd0;  exm_cp0 <= 2'd0;
            mw_v <= 1'b0;  mw_rw <= 1'b0;  mw_m2r <= 1'b0;  mw_mrd <= 1'b0;  mw_mwr <= 1'b0;  mw_lmmio <= 1'b0;
            mw_dst <= 5'd0;  mw_res <= 32'd0;  mw_mdata <= 32'd0;  mw_st <= 32'd0;  mw_addr <= 32'd0;
            mw_pc <= 32'd0;  mw_ins <= 32'd0;  mw_cp0 <= 2'd0;  irq_tr <= 1'b0;  last_cp0 <= 1'b0;
        end else if (cpu_ce) begin
            irq_tr   <= take_irq;
            if (mw_v) last_cp0 <= (mw_cp0 != 2'b00);
            // ---- MEM: DMEM (MMIO do bus_we/bus_re ở trên)
            if (exm_v && exm_mwr && in_dmem) dmem[exm_res[11:2]] <= exm_st;

            // ---- EX: tác dụng CP0 khi lệnh làm việc ở EX (không bận)
            if (idex_v && !stall_busy) begin
                if (idex_cp0 == 2'b01) begin                    // mtc0
                    if (idex_rd == 5'd12) status <= opB[1:0];
                    if (idex_rd == 5'd14) epc    <= {opB[31:2], 2'b00};
                end
                if (idex_cp0 == 2'b10) status[1] <= 1'b0;       // eret: EXL ← 0
            end
            if (take_irq) begin                                 // ngắt (§10): EPC ← PC lệnh cũ nhất chưa retire, EXL ← 1
                epc       <= irq_epc;
                status[1] <= 1'b1;
            end
            started <= (idex_multi != 2'b00) && !mdone;

            // ---- MEM/WB ← EX/MEM (luôn chạy, kể cả khi EX bận)
            mw_v <= exm_v;  mw_rw <= exm_rw;  mw_m2r <= exm_m2r;  mw_mrd <= exm_mrd;  mw_mwr <= exm_mwr;
            mw_lmmio <= exm_mrd && in_mmio;  mw_dst <= exm_dst;  mw_res <= exm_res;  mw_st <= exm_st;
            mw_addr <= exm_res;  mw_pc <= exm_pc;  mw_ins <= exm_ins;
            mw_cp0 <= exm_cp0;
            mw_mdata <= in_dmem ? dmem[exm_res[11:2]] : 32'd0;     // ngoài DMEM và MMIO: đọc 0 (mmio-map §2)

            // ---- EX/MEM ← EX (bong bóng khi EX bận)
            if (stall_busy) begin
                exm_cp0 <= 2'd0;
                exm_v <= 1'b0;  exm_rw <= 1'b0;  exm_m2r <= 1'b0;  exm_mrd <= 1'b0;  exm_mwr <= 1'b0;  exm_dst <= 5'd0;
            end else begin
                exm_cp0 <= idex_cp0;
                exm_v <= idex_v && !take_irq;  exm_rw <= idex_rw;  exm_m2r <= idex_m2r;  exm_mrd <= idex_mrd;  exm_mwr <= idex_mwr;
                exm_dst <= idex_dst;  exm_res <= ex_res;  exm_st <= opB;  exm_pc <= idex_pc;  exm_ins <= idex_ins;
            end

            if (!stall_busy) begin
                // ---- ID/EX ← ID (bong bóng khi nhảy, load-use)
                idex_v <= id_ok;
                idex_rw <= id_ok && reg_write;     idex_m2r <= id_ok && mem_to_reg;
                idex_mrd <= id_ok && mem_read;     idex_mwr <= id_ok && mem_write;
                idex_asrc <= id_ok && alu_src;     idex_actl <= id_ok ? alu_ctl : 4'd0;
                idex_rsel <= id_ok ? res_sel : 3'd0;
                idex_br <= id_ok ? branch : 2'd0;  idex_jmp <= id_ok && jump;  idex_jr <= id_ok && jump_reg;
                idex_multi <= id_ok ? multi : 2'd0; idex_cp0 <= id_ok ? cp0_op : 2'd0;
                idex_dst <= id_ok ? d_dst : 5'd0;
                idex_pc <= ifid_pc;  idex_pc4 <= ifid_pc + 32'd4;  idex_ins <= ifid_ins;
                idex_a <= rs_v;  idex_b <= rt_v;  idex_imm <= imm_x;  idex_sh <= f_sh;
                idex_rs <= f_rs;  idex_rt <= f_rt;  idex_rd <= f_rd;  idex_j <= ifid_ins[25:0];

                // ---- IF/ID và PC (giữ khi load-use; nhảy thì nạp đích và xóa lệnh đã nạp)
                if (!stall_lu) begin
                    pc      <= take_irq ? 32'h0000_0180 : take ? tgt : pc + 32'd4;
                    ifid_v  <= !take && !take_irq;
                    ifid_pc <= pc;
                    ifid_ins <= imem[pc[G_IMEM_AW+1:2]];
                end
            end
        end
    end

    wire unused_ok = &{1'b0, alu_zero, md_busy, bc_busy, flush, mw_addr[1:0]};

`ifndef SYNTHESIS
    // ------------------------------------------------------------ trace (isa-spec §8) + kiểm trong mô phỏng
    integer tf, cyc, n_ret;
    reg [31:0] tr_end;                  // testbench đặt: không ghi trace lệnh có PC ≥ tr_end (lệnh sau cuối chương trình)
    initial begin
        tf = 0; cyc = 0; n_ret = 0; tr_end = 32'hFFFF_FFFF;
        if (TRACE_FILE != "") tf = $fopen(TRACE_FILE, "w");
    end
    always @(posedge clk) begin
        if (rst) cyc <= 0; else cyc <= cyc + 1;
        // forwarding từ EX/MEM khi lệnh ở đó là load: không được xảy ra (load-use phải đã stall)
        if (!rst && cpu_ce && idex_v && !stall_busy && exm_v && exm_mrd &&
            ((fwd_a == 2'b10) || (fwd_b == 2'b10)))
            $display("ASSERT forward tu EX/MEM khi load: pc=%h", idex_pc);
        if (!rst && cpu_ce && ifid_v && !valid)
            $display("ASSERT lenh la: pc=%h instr=%h", ifid_pc, ifid_ins);
        if (!rst && retire && mw_pc < tr_end) begin
            n_ret <= n_ret + 1;
            if (tf != 0)
                $fwrite(tf, "%0d,%h,%h,%0d,%h,%s,%h,%h\n", cyc, mw_pc, mw_ins,
                        (mw_rw && mw_dst != 0) ? mw_dst : 5'd0,
                        (mw_rw && mw_dst != 0) ? wb : 32'd0,
                        mw_mrd ? "R" : mw_mwr ? "W" : "-",
                        (mw_mrd || mw_mwr) ? {mw_addr[31:2], 2'b00} : 32'd0,
                        mw_mrd ? wb_ld : mw_mwr ? mw_st : 32'd0);
        end
        if (tf != 0 && cpu_ce && irq_tr)
            $fwrite(tf, "%0d,00000180,INTERRUPT,0,00000000,-,00000000,00000000\n", cyc);
    end
`endif
endmodule
