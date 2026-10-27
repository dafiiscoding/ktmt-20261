// cpu_g1.v — lõi MIPS single-cycle (G1), 28 lệnh, IMEM/DMEM BRAM đọc đồng bộ, 2 pha trên cùng clock
// Gói C3 · chủ: TV3 · spec: mmio-map.md §1.1 (2 pha), §2 (bus); isa-spec.md §1–§5, §8 (trace);
//                         control-table.md §5; pipeline-policy.md §6 (start/started)
// Code do Claude viết theo yêu cầu Long (02/10/2026); chủ gói đọc hiểu để vấn đáp.
//
// Một chu kỳ CPU = 2 cạnh cpu_ce liên tiếp:
//   pha B (cạnh 1): DMEM/MMIO chốt địa chỉ — sw ghi, lw đọc ra thanh ghi đầu ra; bus_we/bus_re bật ở đây
//   pha A (cạnh 2): PC, regfile, HI/LO (muldiv bước), bcd bước, CP0 cập nhật; IMEM chốt mem[next_pc]
// Sau reset: thanh ghi đầu ra IMEM = mem[0], cạnh cpu_ce đầu tiên là pha B của lệnh 0.
// Ngắt (C5, isa-spec §5): nhận ở pha A cuối lệnh khi irq & IE & !EXL, không stall, lệnh không phải mtc0/eret:
//   EPC ← next_pc, PC ← 0x180, EXL ← 1 (lệnh vừa xong đã chạy trọn, kể cả ghi regfile/bộ nhớ).
module cpu_g1 #(
    parameter IMEM_FILE  = "",
    parameter DMEM_FILE  = "",
    parameter G_IMEM_AW  = 10,          // 2^10 = 1024 lệnh
    parameter G_BCD_COMB = 0,
    parameter TRACE_FILE = ""           // "" = không ghi trace (chỉ mô phỏng)
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        cpu_ce,          // G1: D = 2 → cpu_ce = 1 mọi chu kỳ (soc sinh, mmio-map §1)
    // bus MMIO (mmio-map §2): địa chỉ 0xFFFF_FFxx
    output wire [7:0]  bus_addr,
    output wire [31:0] bus_wdata,
    output wire        bus_we,
    output wire        bus_re,
    input  wire [31:0] bus_rdata,
    input  wire        irq,             // mức, từ irq_ctrl
    input  wire [7:0]  irq_ip,          // Cause.IP = IRQ_PENDING & IRQ_ENABLE (đọc qua mfc0 $13)
    output wire        div_dz,          // DIV_FLAGS.DZ
    output wire [31:0] pc_out,
    output wire        retire           // xung 1 chu kỳ: lệnh hiện tại xong ở cạnh này
);
    localparam NI = 1 << G_IMEM_AW;

    // ------------------------------------------------------------ trạng thái
    reg  [31:0] pc;
    reg  [31:0] instr;                  // thanh ghi đầu ra IMEM
    reg         phb;                    // 1: cạnh cpu_ce kế tiếp là pha B
    reg  [31:0] imem [0:NI-1];
    reg  [31:0] dmem [0:1023];
    reg  [31:0] dmem_q;
    reg  [1:0]  lsel;                   // lần đọc pha B thuộc: 01 DMEM, 10 MMIO, 00 không gì (đọc 0)
    reg         started;
    reg  [1:0]  status;                 // [1] EXL, [0] IE
    reg  [31:0] epc;

    wire ph_a = cpu_ce && !phb;
    wire ph_b = cpu_ce &&  phb;

    // ------------------------------------------------------------ giải mã
    wire       reg_write, alu_src, mem_read, mem_write, mem_to_reg, jump, jump_reg, uses_rs, uses_rt, valid;
    wire [1:0] dst, ext, branch, multi, cp0_op;
    wire [3:0] alu_ctl;
    wire [2:0] res_sel;
    control #(.G_BCD_COMB(G_BCD_COMB)) u_ctl (
        .instr(instr), .reg_write(reg_write), .dst(dst), .alu_src(alu_src), .ext(ext), .alu_ctl(alu_ctl),
        .res_sel(res_sel), .mem_read(mem_read), .mem_write(mem_write), .mem_to_reg(mem_to_reg),
        .branch(branch), .jump(jump), .jump_reg(jump_reg), .multi(multi), .cp0_op(cp0_op),
        .uses_rs(uses_rs), .uses_rt(uses_rt), .valid(valid));

    wire [4:0]  f_rs = instr[25:21], f_rt = instr[20:16], f_rd = instr[15:11], f_sh = instr[10:6];
    wire [15:0] imm  = instr[15:0];
    wire [31:0] imm_x = (ext == 2'b01) ? {16'd0, imm} :
                        (ext == 2'b10) ? {imm, 16'd0} : {{16{imm[15]}}, imm};

    // ------------------------------------------------------------ regfile (G1 không bypass: ghi ở pha A)
    wire [31:0] rs_v, rt_v, wb;
    wire [4:0]  wa = (dst == 2'b01) ? f_rd : (dst == 2'b10) ? f_rt : (dst == 2'b11) ? 5'd31 : 5'd0;
    wire        stall;
    wire        rf_we = ph_a && reg_write && !stall;
    regfile #(.G_BYPASS(0)) u_rf (.clk(clk), .rst(rst), .we(rf_we), .wa(wa), .wd(wb),
                                  .ra1(f_rs), .ra2(f_rt), .rd1(rs_v), .rd2(rt_v));

    // ------------------------------------------------------------ ALU, mul/div, bcd
    wire [31:0] alu_y;
    wire        alu_zero;
    alu u_alu (.a(rs_v), .b(alu_src ? imm_x : rt_v), .shamt(f_sh), .ctl(alu_ctl), .y(alu_y), .zero(alu_zero));

    wire [31:0] mul_y, lo, hi, bcd_y;
    wire        md_busy, md_done, bcd_busy, bcd_done;
    wire        is_div = (multi == 2'b01);
    wire        is_bcd = (multi == 2'b10);
    // start chỉ 1 xung dù lệnh được giải mã lại mỗi chu kỳ (pipeline-policy §6)
    muldiv u_md (.clk(clk), .rst(rst), .ce(ph_a), .start(is_div && !started), .a(rs_v), .b(rt_v),
                 .mul_y(mul_y), .busy(md_busy), .done(md_done), .lo(lo), .hi(hi), .dz(div_dz));
    bcd_unit #(.G_COMB(G_BCD_COMB)) u_bcd (.clk(clk), .rst(rst), .ce(ph_a), .start(is_bcd && !started),
                 .x(rs_v), .busy(bcd_busy), .done(bcd_done), .y(bcd_y));

    wire mdone = is_div ? md_done : is_bcd ? bcd_done : 1'b0;
    // không dùng busy: ở chu kỳ start busy còn 0 (control-table §5). done đã gồm ce nên chỉ xét ở pha A.
    assign stall = (multi != 2'b00) && !mdone;

    // ------------------------------------------------------------ CP0
    reg [31:0] cp0_rd;
    always @* begin
        case (f_rd)
            5'd12:   cp0_rd = {30'd0, status};
            5'd13:   cp0_rd = {16'd0, irq_ip, 8'd0};
            5'd14:   cp0_rd = epc;
            default: cp0_rd = 32'd0;
        endcase
    end

    // ------------------------------------------------------------ bộ nhớ dữ liệu (chốt ở pha B)
    wire [31:0] maddr   = alu_y;
    wire        in_dmem = (maddr[31:12] == 20'd0);
    wire        in_mmio = (maddr[31:8] == 24'hFFFFFF);
    assign bus_addr  = {maddr[7:2], 2'b00};
    assign bus_wdata = rt_v;
    assign bus_we    = ph_b && mem_write && in_mmio;
    assign bus_re    = ph_b && mem_read  && in_mmio;

    wire [31:0] load_v = (lsel == 2'b01) ? dmem_q : (lsel == 2'b10) ? bus_rdata : 32'd0;

    // ------------------------------------------------------------ ghi ngược
    reg [31:0] res;
    always @* begin
        case (res_sel)
            3'd1:    res = mul_y;
            3'd2:    res = hi;
            3'd3:    res = lo;
            3'd4:    res = bcd_y;
            3'd5:    res = cp0_rd;
            3'd6:    res = pc + 32'd4;
            default: res = alu_y;
        endcase
    end
    assign wb = mem_to_reg ? load_v : res;

    // ------------------------------------------------------------ PC kế tiếp
    wire [31:0] pc4  = pc + 32'd4;
    wire        eq   = (rs_v == rt_v);
    wire        take = (branch == 2'b01 && eq) || (branch == 2'b10 && !eq);
    reg  [31:0] next_pc;
    always @* begin
        if (rst)                  next_pc = 32'd0;
        else if (stall)           next_pc = pc;
        else if (cp0_op == 2'b10) next_pc = epc;
        else if (jump_reg)        next_pc = {rs_v[31:2], 2'b00};
        else if (jump)            next_pc = {pc4[31:28], instr[25:0], 2'b00};
        else if (take)            next_pc = pc4 + {imm_x[29:0], 2'b00};
        else                      next_pc = pc4;
    end

    // nhận ngắt ở cuối lệnh này (mtc0/eret đang ghi Status cùng cạnh → chặn, isa-spec §5)
    wire        take_irq = irq && status[0] && !status[1] && !stall && (cp0_op == 2'b00);
    wire [31:0] pc_new   = take_irq ? 32'h0000_0180 : next_pc;

    assign pc_out = pc;
    assign retire = ph_a && !stall;

    // ------------------------------------------------------------ thanh ghi
`ifndef SYNTHESIS
    integer i;
    initial begin                       // mô phỏng: phần không có trong .hex = 0 (không phải x)
        for (i = 0; i < NI; i = i + 1) imem[i] = 32'd0;
        for (i = 0; i < 1024; i = i + 1) dmem[i] = 32'd0;
    end
`endif
    // generate if (không phải if trong initial) để Yosys/Vivado nạp được .hex khi tổng hợp
    generate
        if (IMEM_FILE != "") begin : g_imem_init
            initial $readmemh(IMEM_FILE, imem);
        end
        if (DMEM_FILE != "") begin : g_dmem_init
            initial $readmemh(DMEM_FILE, dmem);
        end
    endgenerate

    // một cổng đọc imem (kể cả lúc reset) để Yosys/Vivado suy ra BRAM; 2 cổng (imem[0] lúc reset) → bị dựng bằng LUT
    always @(posedge clk)
        if (rst || ph_a) instr <= imem[rst ? {G_IMEM_AW{1'b0}} : pc_new[G_IMEM_AW+1:2]];

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'd0;  phb <= 1'b1;  started <= 1'b0;
            status <= 2'b00;  epc <= 32'd0;
            lsel <= 2'b00;  dmem_q <= 32'd0;
        end else begin
            if (ph_b) begin
                phb <= 1'b0;
                if (mem_write && in_dmem) dmem[maddr[11:2]] <= rt_v;
                if (mem_read) begin
                    dmem_q <= dmem[maddr[11:2]];
                    lsel   <= in_dmem ? 2'b01 : in_mmio ? 2'b10 : 2'b00;
                end
            end
            if (ph_a) begin
                phb     <= 1'b1;
                started <= (multi != 2'b00) && !mdone;
                pc      <= pc_new;
                if (!stall) begin
                    if (cp0_op == 2'b01) begin                   // mtc0
                        if (f_rd == 5'd12) status <= rt_v[1:0];
                        if (f_rd == 5'd14) epc    <= {rt_v[31:2], 2'b00};
                    end
                    if (cp0_op == 2'b10) status[1] <= 1'b0;     // eret: EXL ← 0
                    if (take_irq) begin
                        epc       <= next_pc;
                        status[1] <= 1'b1;
                    end
                end
            end
        end
    end

    wire unused_ok = &{1'b0, alu_zero, md_busy, bcd_busy, uses_rs, uses_rt, imm_x[31:30], maddr[1:0]};  // lw/sw bỏ 2 bit thấp

`ifndef SYNTHESIS
    // ------------------------------------------------------------ trace (isa-spec §8) + báo lệnh lạ
    integer tf, cyc;
    initial begin
        tf = 0; cyc = 0;
        if (TRACE_FILE != "") tf = $fopen(TRACE_FILE, "w");
    end
    always @(posedge clk) begin
        if (rst) cyc <= 0; else cyc <= cyc + 1;
        if (!rst && retire) begin
            if (!valid) $display("ASSERT lenh la: pc=%h instr=%h", pc, instr);
            if (tf != 0)
                $fwrite(tf, "%0d,%h,%h,%0d,%h,%s,%h,%h\n", cyc, pc, instr,
                        (reg_write && wa != 0) ? wa : 5'd0,
                        (reg_write && wa != 0) ? wb : 32'd0,
                        mem_read ? "R" : mem_write ? "W" : "-",
                        (mem_read || mem_write) ? {maddr[31:2], 2'b00} : 32'd0,
                        mem_read ? load_v : mem_write ? rt_v : 32'd0);
            if (tf != 0 && take_irq)
                $fwrite(tf, "%0d,00000180,INTERRUPT,0,00000000,-,00000000,00000000\n", cyc);
        end
    end
`endif
endmodule
