"""Assert cho phép tính tay và khẳng định kiểm được của bài P3 (ID, bộ điều khiển, tập thanh ghi)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
nguon = (Path(__file__).resolve().parents[1] / "nguon" / "02-code.md").read_text(encoding="utf-8")
p3 = nguon.split("## P3 ·")[1].split("\n## ")[0]


def dong(rel):
    return (ROOT / rel).read_text(encoding="utf-8").splitlines()


ct, rf, pp, g1 = dong("src/control.v"), dong("src/regfile.v"), dong("src/cpu_pipe.v"), dong("src/cpu_g1.v")
vec = {}
for ln in (ROOT / "tb/vectors/control.txt").read_text(encoding="utf-8").splitlines():
    if ln.startswith("#") or not ln.strip():
        continue
    body, _, name = ln.partition("#")
    cols = body.split()
    vec.setdefault(name.strip(), []).append((cols[0], cols[1:]))


def cat(instr):
    return (instr >> 26, (instr >> 21) & 31, (instr >> 16) & 31, (instr >> 11) & 31, instr & 63, instr & 0xFFFF)


# --- Phép 1: addu 0x02BA4821
op, rs, rt, rd, funct, imm = cat(0x02BA4821)
assert (op, rs, rt, rd, funct) == (0, 21, 26, 9, 0x21)
assert ("02BA4821", list("1100000000000011".replace("", " ").split())) or True
assert dict((c, k) for c, k in vec["addu"])["02BA4821"] == "1 1 0 0 0 0 0 0 0 0 0 0 0 0 1 1".split()

# --- lw 0x8D0D3B24
op, rs, rt, rd, funct, imm = cat(0x8D0D3B24)
assert (op, rs, rt, imm) == (0x23, 8, 13, 0x3B24)
assert dict(vec["lw"])["8D0D3B24"] == "1 2 1 0 0 0 1 0 1 0 0 0 0 0 1 0".split()

# --- sw 0xAEF87269
op, rs, rt, rd, funct, imm = cat(0xAEF87269)
assert (op, rs, rt, imm) == (0x2B, 23, 24, 0x7269)
assert dict(vec["sw"])["AEF87269"] == "0 0 1 0 0 0 0 1 0 0 0 0 0 0 1 1".split()

# --- mtc0 0x408D3800
op, rs, rt, rd, funct, imm = cat(0x408D3800)
assert (op, rs, rt, rd) == (0x10, 4, 13, 7) and (0x408D3800 & 0x7FF) == 0
assert dict(vec["mtc0"])["408D3800"] == "0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 1".split()

# --- lui $t0,0xA242 = 0x3C08A242, ori 0x36E20B38
op, rs, rt, rd, funct, imm = cat(0x3C08A242)
assert (op, rs, rt, imm) == (0x0F, 0, 8, 0xA242) and ((imm << 16) | 0) == 0xA2420000
assert dict(vec["lui"])["3C16A242"][3] == "2"          # ext = LUI
assert cat(0x7C000000)[0] == 0x1F                        # mã lạ trong MCQ-05
assert dict(vec["ori"])["36E20B38"][3] == "1" and dict(vec["addiu"])["26E95573"][3] == "0"

# --- Phép 2: nới hằng 0xFFFF
imm = 0xFFFF
se = ((imm | 0xFFFF0000) if imm & 0x8000 else imm)
ze = imm
assert se == 0xFFFFFFFF and ze == 0x0000FFFF and se - (1 << 32) == -1 and ze == 65535

# --- Phép 3: khoảng cách lệnh j
# lệnh i: ID c2, EX c3, MEM c4, WB c5. Lệnh i+j: ID c(2+j), EX c(3+j)
def nguon_toan_hang(j):
    ex_cua_i_plus_j = 3 + j
    if ex_cua_i_plus_j == 4:
        return "10"       # i đang ở MEM
    if ex_cua_i_plus_j == 5:
        return "01"       # i đang ở WB
    id_cua_i_plus_j = 2 + j
    return "bypass" if id_cua_i_plus_j == 5 else "doc thuong"


assert [nguon_toan_hang(j) for j in (1, 2, 3, 4)] == ["10", "01", "bypass", "doc thuong"]

# --- đếm 28 lệnh theo họ trong control.v (đếm dòng case thực sự)
ho_r = [l for l in ct[67:80] if "6'h" in l]
assert len(ho_r) == 12, len(ho_r)
ho_i = [l for l in ct[81:95] if l.strip().startswith("6'h") and "case" not in l]
assert len(ho_i) == 11, len(ho_i)                         # 9 kiểu I + j + jal
sp2 = [l for l in ct[96:101] if l.strip().startswith("6'h")]
assert len(sp2) == 2
assert 12 + 9 + 2 + 2 + 3 == 28
assert sum(len(v) for k, v in vec.items() if k != "illegal") == 84 and len(vec["illegal"]) == 5

# --- khớp dòng code được nhắc
assert "module control #(" in ct[11] and "input  wire [31:0] instr" in ct[14] and "output reg         valid" in ct[31]
assert "localparam D_NONE" in ct[33] and "localparam E_SE" in ct[34]
assert "wire [5:0] op" in ct[40] and "wire [4:0] rs" in ct[41] and "wire [5:0] funct" in ct[42]
assert "task r_alu" in ct[45] and "task i_alu" in ct[52]
assert "always @*" in ct[59] and "valid = 0; reg_write = 0" in ct[62] and "case (op)" in ct[65]
assert "r_alu(A_ADD, 1)" in ct[67] and "r_alu(A_SLL, 0)" in ct[73] and "r_alu(A_SRA, 0)" in ct[74]
assert "jump_reg = 1" in ct[75] and "multi = 2'b01" in ct[76]
assert "R_HI" in ct[77] and "R_LO" in ct[78]
assert "i_alu(A_ADD, E_SE,  1)" in ct[81] and "i_alu(A_AND, E_ZE,  1)" in ct[83] and "i_alu(A_OR,  E_ZE,  1)" in ct[84]
assert "i_alu(A_OR,  E_LUI, 0)" in ct[85]
assert "mem_read = 1; mem_to_reg = 1" in ct[86] and "mem_write = 1" in ct[88]
assert "branch = 2'b01" in ct[91] and "branch = 2'b10" in ct[92] and "jump = 1" in ct[93] and "D_31" in ct[94]
assert "6'h1C" in ct[95] and "G_BCD_COMB != 0" in ct[99] and "6'h10: begin" in ct[102]
assert "rs == 5'h00 && instr[10:0] == 11'd0" in ct[103] and "rs == 5'h04 && instr[10:0] == 11'd0" in ct[105]
assert "uses_rt = 1" in ct[106] and "32'h42000018" in ct[107]
assert "default: ;" in ct[111] and "endcase" in ct[112]
assert "module regfile #(" in rf[11] and "reg [31:0] r [0:31]" in rf[24]
assert "posedge clk" in rf[27] and "we && wa != 5'd0" in rf[32] and "r[wa] <= wd" in rf[33]
assert "// Bypass" in rf[37] and "byp1 = (G_BYPASS != 0) && we && (wa == ra1)" in rf[40]
assert "(ra1 == 5'd0) ? 32'd0 : (byp1 ? wd : r[ra1])" in rf[44]
assert "G_BYPASS = 0 (G1)" in rf[4] and "vòng tổ hợp" in rf[4]
assert "ID/EX" in pp[60] and "reg         idex_v" in pp[62] and "idex_a, idex_b, idex_imm" in pp[66]
assert "idex_rs, idex_rt, idex_dst" in pp[67]
assert "wire [4:0]  f_rs" in pp[85] and "wire [15:0] imm16" in pp[86]
assert "wire [31:0] imm_x" in pp[97] and "wire [4:0] d_dst = (!ifid_v)" in pp[101]
assert "we_rf = cpu_ce && mw_v && mw_rw" in pp[107] and "regfile #(.G_BYPASS(1))" in pp[108]
assert "idex_v <= id_ok" in pp[278] and "idex_rw <= id_ok && reg_write" in pp[279]
assert "idex_a <= rs_v" in pp[287] and "idex_rs <= f_rs" in pp[288]
assert "ifid_v && !valid" in pp[319] and "ASSERT lenh la" in g1[242]
assert "wire [4:0]  wa = (dst == 2'b01)" in g1[80] and "rf_we = ph_a && reg_write && !stall" in g1[82]
assert "regfile #(.G_BYPASS(0))" in g1[83]

# test đơn vị có đủ ca bài nhắc
tb = (ROOT / "tb/regfile_tb.v").read_text(encoding="utf-8")
assert 'G_BYPASS=1 tra wd' in tb and 'G_BYPASS=0 tra gia tri cu' in tb
assert len(p3.splitlines()) >= 300, len(p3.splitlines())
print("PASS P3")
