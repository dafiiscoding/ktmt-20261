"""Assert cho phép tính tay và các khẳng định kiểm được trong bài V0 (đọc Verilog qua alu.v, regfile.v)."""
from pathlib import Path

M = 0xFFFFFFFF
ROOT = Path(__file__).resolve().parents[3]
nguon = (Path(__file__).resolve().parents[1] / "nguon" / "02-code.md").read_text(encoding="utf-8")
v0 = nguon.split("## V0")[1]

# Suy dẫn 1: slt khi a = 0, b = 0x80000000 (số âm nhỏ nhất)
a, b = 0x00000000, 0x80000000
diff = (a - b) & M
assert diff == 0x80000000 and diff >> 31 == 1            # trừ tràn, bit dấu của diff là 1 → nhìn dấu sẽ sai
assert (a >> 31) != (b >> 31)                           # hai bit dấu khác nhau
lt = (a >> 31) if (a >> 31) != (b >> 31) else (diff >> 31)
assert lt == 0                                          # đúng: 0 không nhỏ hơn -2^31
assert b - (1 << 32) == -2147483648 == -(2 ** 31)
# ca này có thật trong file vector (dòng 40: mã 5, a, b, shamt, kết quả, zero)
dong40 = (ROOT / "tb/vectors/alu.txt").read_text(encoding="utf-8").splitlines()[39]
assert dong40.split() == ["5", "00000000", "80000000", "00", "00000000", "1"], dong40

# Suy dẫn 2: dịch phải số học và thường của -8
m8 = (-8) & M
assert m8 == 0xFFFFFFF8
sra = ((m8 >> 1) | (m8 & 0x80000000)) & M               # chép bit dấu
assert sra == 0xFFFFFFFC and sra - (1 << 32) == -4
assert (m8 >> 1) == 0x7FFFFFFC                          # dịch thường điền 0

# Suy dẫn 3: mở rộng dấu 16 → 32 bit
def sext16(x):
    return (x | 0xFFFF0000) if x & 0x8000 else x

assert sext16(0xFF04) == 0xFFFFFF04 and sext16(0x0004) == 0x00000004
assert (-252) & 0xFFFF == 0xFF04 and (-252) & M == 0xFFFFFF04
assert (0xFF04 << 16) & M == 0xFF040000                 # nhánh `lui` (đáp án nhiễu của MCQ-04)

# Cặp `<=` hoán đổi, cặp `=` mất giá trị (kết quả đã chạy Icarus: a1=2 b1=1 | a2=2 b2=2)
a1, b1 = 1, 2
a1, b1 = b1, a1                                          # đọc cả hai trước, đổi sau
assert (a1, b1) == (2, 1)
a2, b2 = 1, 2
a2 = b2
b2 = a2                                                  # dòng sau đọc giá trị đã bị đổi
assert (a2, b2) == (2, 2)

# Clock testbench: đảo mỗi 10 đơn vị, timescale 1ns → chu kỳ 20 ns = 50 MHz
assert 1e9 / (2 * 10) == 50_000_000

# Số bit
assert 2 ** 4 == 16 and 2 ** 5 == 32                     # ctl 4 bit, shamt/wa 5 bit

# Khẳng định về mã nguồn: khớp từng dòng được trích hoặc nhắc
alu = (ROOT / "src/alu.v").read_text(encoding="utf-8").splitlines()
rf = (ROOT / "src/regfile.v").read_text(encoding="utf-8").splitlines()
g1 = (ROOT / "src/cpu_g1.v").read_text(encoding="utf-8").splitlines()
soc = (ROOT / "src/soc_top.v").read_text(encoding="utf-8").splitlines()
tb = (ROOT / "tb/alu_tb.v").read_text(encoding="utf-8").splitlines()
assert "lt " in alu[25] and "a[31] != b[31]" in alu[25]
assert "always @*" in alu[27] and "default" in alu[37] and "assign zero" in alu[41]
assert "ALU_SLT: y = {31'd0, lt}" in alu[34] and ">>>" in alu[36]
assert "module regfile" in rf[11] and "reg [31:0] r [0:31]" in rf[24] and "posedge clk" in rf[27]
assert "we && wa != 5'd0" in rf[32] and "byp1" in rf[40] and "assign rd1" in rf[44]
assert "{{16{imm[15]}}, imm}" in g1[76] and "regfile #(.G_BYPASS(0)) u_rf" in g1[83] and "alu u_alu" in g1[89]
assert "`ifdef G2" in soc[68] and "`else" in soc[72] and "`endif" in soc[76]
assert "#1;" in tb[27] and "!==" in tb[29] and "PASS alu_tb" in tb[38]
assert "always #10" in (ROOT / "tb/regfile_tb.v").read_text(encoding="utf-8").splitlines()[13]
# cosim_iss thêm -DG2 khi --g2 (tự luận cuối)
assert '["-DG2"] if G2["on"]' in (ROOT / "tools/cosim_iss.py").read_text(encoding="utf-8")

# Lỗi 3 là tương đương: lớp chặn đọc ngăn 0 nằm cả ở hai dòng đọc ra
assert "(ra1 == 5'd0) ? 32'd0" in rf[44] and "(ra2 == 5'd0) ? 32'd0" in rf[45]

# Lệnh người đọc gõ phải tồn tại
assert (ROOT / "tools/run_unit.sh").exists() and (ROOT / "tools/env.sh").exists()
assert (ROOT / "tb/alu_tb.v").exists() and (ROOT / "tb/regfile_tb.v").exists()

# Bài không được có công thức mở cuộc nhầm với placeholder, và không dùng tên lõi sai
assert "bash tools/run_unit.sh alu regfile" in v0 and "`cpu_pipe` (hoặc `cpu_g1`)" in v0
for x in ("Artix", "Cortex", "RISC-V"):
    assert x not in v0, x                                 # không đưa ví dụ ngoài repo không có nguồn

print("PASS V0")
