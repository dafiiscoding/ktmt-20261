"""Assert cho phép tính tay và khẳng định kiểm được của bài P1 (EX và số học)."""
from pathlib import Path

M = 0xFFFFFFFF
ROOT = Path(__file__).resolve().parents[3]
nguon = (Path(__file__).resolve().parents[1] / "nguon" / "02-code.md").read_text(encoding="utf-8")
p1 = nguon.split("## P1 ·")[1].split("\n## ")[0]


def dong(rel):
    return (ROOT / rel).read_text(encoding="utf-8").splitlines()


alu, md, g1, pp = dong("src/alu.v"), dong("src/muldiv.v"), dong("src/cpu_g1.v"), dong("src/cpu_pipe.v")

# --- Phép 1: slt a=0, b=0x80000000
a, b = 0, 0x80000000
diff = (a - b) & M
assert diff == 0x80000000 and diff >> 31 == 1
lt = (a >> 31) if (a >> 31) != (b >> 31) else (diff >> 31)
assert lt == 0
# cùng dấu: 5 < 3 sai
a, b = 5, 3
assert (((a - b) & M) >> 31) == 0
assert "5 00000000 80000000 00 00000000 1" in (ROOT / "tb/vectors/alu.txt").read_text(encoding="utf-8")


# --- Mô hình restoring divider đúng từng dòng của muldiv.v (bước 1..32), có đếm chu kỳ
def div32(a, b):
    """Trả (lo, hi, dz, cyc). cyc = số chu kỳ CPU từ start tới done, gồm cả hai đầu."""
    if b == 0:
        return 0, a, 1, 1
    quo = ((-a) & M) if a >> 31 else a                     # dòng 72
    dvs = ((-b) & M) if b >> 31 else b                     # dòng 73
    neg_q, neg_r = (a >> 31) ^ (b >> 31), a >> 31          # dòng 74, 75
    rem, cnt, cyc = 0, 0, 1
    while True:
        cyc += 1
        rem_sh = ((rem << 1) | (quo >> 31)) & 0x1FFFFFFFF   # dòng 44
        trial = (rem_sh - dvs) & 0x1FFFFFFFF                # dòng 45
        fits = 0 if (trial >> 32) else 1                    # dòng 46
        rem_n = (trial & M) if fits else (rem_sh & M)       # dòng 47
        quo_n = ((quo << 1) | fits) & M                     # dòng 48
        last = cnt == 31                                    # dòng 51
        rem, quo, cnt = rem_n, quo_n, cnt + 1
        if last:
            lo = (-quo_n) & M if neg_q else quo_n           # dòng 84
            hi = (-rem_n) & M if neg_r else rem_n           # dòng 85
            return lo, hi, 0, cyc


# đối chiếu toàn bộ file thử (830 ca) và số chu kỳ 33
n = 0
for ln in (ROOT / "tb/vectors/div.txt").read_text(encoding="utf-8").splitlines():
    if not ln.strip() or ln.startswith("#"):
        continue
    ea, eb, elo, ehi, edz = ln.split()
    lo, hi, dz, cyc = div32(int(ea, 16), int(eb, 16))
    assert (lo, hi, dz) == (int(elo, 16), int(ehi, 16), int(edz)), ln
    assert cyc == (1 if dz else 33), ln
    n += 1
assert n == 830, n

# --- Phép 2: 7 / 2 bốn bit, bốn bước (bảng trong bài)
rem, quo, dvs = 0, 0b0111, 0b0010
bang = []
for _ in range(4):
    kéo = quo >> 3
    sh = (rem << 1) | kéo
    fits = sh >= dvs
    rem = sh - dvs if fits else sh
    quo = ((quo << 1) | fits) & 0xF
    bang.append((kéo, sh, fits, rem, quo))
assert bang == [(0, 0, False, 0, 0b1110), (1, 1, False, 1, 0b1100), (1, 3, True, 1, 0b1001), (1, 3, True, 1, 0b0011)]
assert quo == 3 and rem == 1 and 3 * 2 + 1 == 7

# --- Phép 3: -7 / 2 và 0x80000000 / -1
lo, hi, dz, cyc = div32((-7) & M, 2)
assert (lo, hi) == (0xFFFFFFFD, 0xFFFFFFFF) and lo - (1 << 32) == -3 and hi - (1 << 32) == -1
assert div32(0x80000000, M)[:2] == (0x80000000, 0)
assert (-0x80000000) & M == 0x80000000                      # số âm nhỏ nhất đổi dấu ra chính nó
assert div32((-7) & M, 2)[3] == 33

# dịch phải
m8 = (-8) & M
assert (((m8 >> 1) | (m8 & 0x80000000)) & M) == 0xFFFFFFFC and (m8 >> 1) == 0x7FFFFFFC

# --- khớp dòng code được nhắc
assert "wire        lt   = (a[31] != b[31]) ? a[31] : diff[31];" in alu[25]
assert "ALU_SLL: y = b << shamt" in alu[35] and ">>>" in alu[36] and "default" in alu[37]
assert "assign mul_y = a * b" in md[33] and "last  = run && (cnt == 5'd31)" in md[50]
assert "assign done = ce && ((start && !run && div0) || last)" in md[53]
assert "neg_q <= a[31] ^ b[31]" in md[73] and "neg_r <= a[31]" in md[74]
assert "lo  <= neg_q ? -quo_n : quo_n" in md[83] and "hi  <= neg_r ? -rem_n : rem_n" in md[84]
assert "quo   <= a[31] ? -a : a" in md[71] and "dvs   <= b[31] ? -b : b" in md[72]
assert ".start(is_div && !started)" in g1[96] and "assign stall = (multi != 2'b00) && !mdone" in g1[104]
assert "started <= (multi != 2'b00) && !mdone" in g1[211]
assert "md_go = cpu_ce && (idex_multi == 2'b01) && !started" in pp[139]
assert "assign stall_busy = (idex_multi != 2'b00) && !mdone" in pp[147]
assert "assign take = idex_v && !stall_busy" in pp[176] and "wire eq = (opA == opB)" in pp[175]
assert "3'd6:    ex_res = idex_pc4" in pp[168] and "5'd12:   cp0_rd" in pp[152]
assert (ROOT / "tb/muldiv_tb.v").read_text(encoding="utf-8").count("cyc == 33 && busy_cyc == 32") == 1
assert len(p1.splitlines()) >= 300, len(p1.splitlines())
print("PASS P1")
