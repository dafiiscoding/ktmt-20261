"""Assert cho phép tính tay và khẳng định kiểm được của bài P4 (IF, PC, nhánh, hai pha, bcd)."""
from pathlib import Path

M = 0xFFFFFFFF
ROOT = Path(__file__).resolve().parents[3]
nguon = (Path(__file__).resolve().parents[1] / "nguon" / "02-code.md").read_text(encoding="utf-8")
p4 = nguon.split("## P4 ·")[1].split("\n## ")[0]


def dong(rel):
    return (ROOT / rel).read_text(encoding="utf-8").splitlines()


g1, pp, bc, ct = dong("src/cpu_g1.v"), dong("src/cpu_pipe.v"), dong("src/bcd_unit.v"), dong("src/control.v")


# --- đích nhánh: pc4 + {imm_x[29:0], 00}
def dich_nhanh(pc, imm16):
    imm_x = (imm16 | 0xFFFF0000) if imm16 & 0x8000 else imm16
    return ((pc + 4) + (((imm_x & 0x3FFFFFFF) << 2) & M)) & M


assert dich_nhanh(0x40, 3) == 0x50
assert dich_nhanh(0x40, 0xFFFE) == 0x3C and ((0xFFFFFFFE & 0x3FFFFFFF) << 2) & M == 0xFFFFFFF8
assert dich_nhanh(0x100, 0xFFFC) == 0xF4
assert dich_nhanh(0x100, 0xFFFF) == 0x100          # muốn nhảy về chính nó cần imm = -1


# --- đích j: {pc4[31:28], addr26, 00}
def dich_j(pc, a26):
    return ((pc + 4) & 0xF0000000) | (a26 << 2)


assert dich_j(0x40, 0x10) == 0x40 and dich_j(0x10000040, 0x10) == 0x10000040


# --- double dabble: mô hình đúng từng dòng bcd_unit.v
def add3(v, nd):
    r = 0
    for k in range(nd):
        d = (v >> (4 * k)) & 15
        r |= (d + 3 if d >= 5 else d) << (4 * k)
    return r


def dabble(x, nbit, nd, vet=None):
    d = 0
    for k in range(nbit - 1, -1, -1):
        truoc = d
        d = ((add3(d, nd) << 1) | ((x >> k) & 1)) & ((1 << (4 * nd)) - 1)
        if vet is not None:
            vet.append((k, (x >> k) & 1, truoc, add3(truoc, nd), d))
    return d


vet = []
assert dabble(13, 4, 2, vet) == 0x13
assert vet == [(3, 1, 0x00, 0x00, 0x01), (2, 1, 0x01, 0x01, 0x03), (1, 0, 0x03, 0x03, 0x06), (0, 1, 0x06, 0x09, 0x13)]
vet = []
assert dabble(5, 3, 2, vet) == 0x05 and [v[2] for v in vet] == [0, 1, 2] and all(v[2] == v[3] for v in vet)
for x, nb in ((6, 3), (7, 3)):
    vet = []
    assert dabble(x, nb, 2, vet) == x and all(v[2] == v[3] for v in vet)
    assert [v[2] for v in vet] == [0, 1, 3]
# toàn miền 27 bit thấp (kiểm mẫu đủ rộng) đúng bằng đổi chuỗi thập phân
for x in list(range(0, 3000)) + [99999999, 12345678, 50000000, 67108864, 99999990]:
    assert dabble(x, 27, 8) == int(str(x), 16), x
assert 99999999 < 2 ** 27 and 99999999 >= 2 ** 26 and 99999999 == 0x05F5E0FF
assert dabble(1234, 27, 8) == 0x1234
# 28 chu kỳ = 1 chốt + 27 bước; tràn = 1 chu kỳ
assert 1 + 27 == 28 and 2 * 27 == 54

# ngưỡng 6: số 10 ra 0x0A (lỗi trong bài)
def add3_sai(v, nd):
    r = 0
    for k in range(nd):
        d = (v >> (4 * k)) & 15
        r |= (d + 3 if d >= 6 else d) << (4 * k)
    return r


d = 0
for k in range(3, -1, -1):
    d = ((add3_sai(d, 2) << 1) | ((10 >> k) & 1)) & 0xFF
assert d == 0x0A and dabble(10, 4, 2) == 0x10

# --- khớp dòng code được nhắc
assert "trạng thái" in g1[45] and "reg  [31:0] pc;" in g1[46] and "reg  [31:0] instr;" in g1[47] and "reg         phb;" in g1[48]
assert "wire ph_a = cpu_ce && !phb" in g1[57] and "wire ph_b = cpu_ce &&  phb" in g1[58]
assert "wire [31:0] pc4  = pc + 32'd4" in g1[148] and "wire        eq   = (rs_v == rt_v)" in g1[149]
assert "wire        take = (branch == 2'b01 && eq) || (branch == 2'b10 && !eq)" in g1[150]
assert "if (rst)                  next_pc = 32'd0" in g1[154] and "else if (stall)           next_pc = pc" in g1[155]
assert "cp0_op == 2'b10) next_pc = epc" in g1[156] and "jump_reg)        next_pc = {rs_v[31:2], 2'b00}" in g1[157]
assert "next_pc = {pc4[31:28], instr[25:0], 2'b00}" in g1[158] and "next_pc = pc4 + {imm_x[29:0], 2'b00}" in g1[159]
assert "next_pc = pc4;" in g1[160]
assert "wire        take_irq = irq && status[0] && !status[1] && !stall && (cp0_op == 2'b00)" in g1[165]
assert "pc_new   = take_irq ? 32'h0000_0180 : next_pc" in g1[166] and "assign retire = ph_a && !stall" in g1[169]
assert "if (rst || ph_a) instr <= imem[rst ? {G_IMEM_AW{1'b0}} : pc_new[G_IMEM_AW+1:2]]" in g1[191]
assert "pc <= 32'd0;  phb <= 1'b1;  started <= 1'b0;" in g1[195] and "phb <= 1'b0;" in g1[201]
assert "dmem[maddr[11:2]] <= rt_v" in g1[202] and "phb     <= 1'b1;" in g1[210]
assert "started <= (multi != 2'b00) && !mdone" in g1[211] and "pc      <= pc_new" in g1[212]
assert "status <= rt_v[1:0]" in g1[215] and "status[1] <= 1'b0" in g1[218]
assert "epc       <= next_pc" in g1[220] and "status[1] <= 1'b1" in g1[221]
assert "IF/ID" in pp[55] and "reg         ifid_v;" in pp[57] and "reg  [31:0] ifid_pc, ifid_ins;" in pp[58]
assert "wire eq = (opA == opB)" in pp[175] and "assign take = idex_v && !stall_busy" in pp[176]
assert "idex_br == 2'b01 && eq" in pp[177] and "wire [31:0] tgt" in pp[178] and "idex_pc4 + {idex_imm[29:0], 2'b00}" in pp[181]
assert "if (!stall_lu) begin" in pp[291] and "pc      <= take_irq ? 32'h0000_0180 : take ? tgt : pc + 32'd4" in pp[292]
assert "ifid_v  <= !take && !take_irq" in pp[293] and "ifid_ins <= imem[pc[G_IMEM_AW+1:2]]" in pp[295]
assert "module bcd_unit #(" in bc[17] and "localparam [31:0] MAXV = 32'd99999999" in bc[29]
assert "function [31:0] add3" in bc[32] and ">= 4'd5" in bc[36] and "+ 4'd3" in bc[36]
assert "function [31:0] to_bcd" in bc[41] and "for (k = 26; k >= 0; k = k - 1)" in bc[46]
assert "wire ovf = (x > MAXV)" in bc[51] and "assign done = ce && start" in bc[55]
assert "end else begin : g_seq" in bc[58] and "reg [4:0]  cnt;" in bc[60]
assert "wire [31:0] d_n  = {add3(d)} << 1 | {31'd0, b[26]}" in bc[64] and "cnt == 5'd26" in bc[65]
assert "assign busy = run" in bc[67] and "assign done = ce && ((start && !run && ovf) || last)" in bc[68]
assert "assign y    = run ? d_n : 32'hFFFFFFFF" in bc[69]
assert "start && !run" in bc[75] and "if (!ovf) begin" in bc[77] and "b <= x[26:0]" in bc[78]
assert "d   <= d_n" in bc[81] and "if (last) run <= 1'b0" in bc[84]
# stall không đi cùng nhảy: div và bcd đều có jump = jump_reg = branch = cp0_op = 0
assert "begin valid = 1; multi = 2'b01; uses_rs = 1; uses_rt = 1; end" in ct[76]
assert "multi = (G_BCD_COMB != 0) ? 2'b00 : 2'b10" in ct[99]
# bài thử và phạt bcd_busy
tb = (ROOT / "tb/bcd_tb.v").read_text(encoding="utf-8")
assert "((e_x > 99999999) ? 1 : 28)" in tb and '"so chu ky tuan tu"' in tb
assert "# bubbles 54" in (ROOT / "fw/tests/hazard/bcd_busy.s").read_text(encoding="utf-8")
assert len(p4.splitlines()) >= 300, len(p4.splitlines())
print("PASS P4")
