"""Sinh test vector + golden cho WatchChip.

Claude viết 01/10/2026 theo luật KE-HOACH §4b ("AI được sinh test vector").
Đây KHÔNG phải code nộp trong src/. Mỗi golden được tính bằng 2 cách độc lập
và assert khớp nhau trước khi ghi file.
Chạy:  python tb/vectors/gen_vectors.py   (ghi đè các file *.txt cùng thư mục)
Spec:  docs/isa-spec.md, docs/control-table.md, docs/timer-spec.md, docs/display-spec.md
"""
import datetime
import os
import random
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
M32 = 0xFFFFFFFF
rng = random.Random(20261001)
summary = []


def s32(x):
    x &= M32
    return x - (1 << 32) if x >> 31 else x


def write(name, header, lines):
    with open(os.path.join(HERE, name), "w", encoding="ascii", newline="\n") as f:
        for h in header:
            f.write("# " + h + "\n")
        for ln in lines:
            f.write(ln + "\n")
    summary.append((name, len(lines)))


EDGE = [0, 1, 2, 0x7FFFFFFF, 0x80000000, 0x80000001, 0xFFFFFFFF, 0xFFFFFFFE,
        0x0000FFFF, 0xFFFF0000, 0x55555555, 0xAAAAAAAA, 1000, 60000, 86399999]


def operands(n_rand):
    pairs = [(a, b) for a in EDGE for b in EDGE]
    pairs += [(rng.getrandbits(32), rng.getrandbits(32)) for _ in range(n_rand)]
    pairs += [(rng.randint(-100000, 100000) & M32, rng.randint(-1000, 1000) & M32) for _ in range(n_rand)]
    return pairs


# ---------------------------------------------------------------- ALU
ALU = {"ADD": 0, "SUB": 1, "AND": 2, "OR": 3, "XOR": 4, "SLT": 5, "SLL": 6, "SRA": 7}


def alu_a(op, a, b, sh):
    if op == "ADD": return (a + b) & M32
    if op == "SUB": return (a - b) & M32
    if op == "AND": return a & b
    if op == "OR": return a | b
    if op == "XOR": return a ^ b
    if op == "SLT": return 1 if s32(a) < s32(b) else 0
    if op == "SLL": return (b << sh) & M32
    if op == "SRA": return (s32(b) >> sh) & M32


def alu_b(op, a, b, sh):
    """Cách 2: mô hình kiểu phần cứng (bit-level)."""
    if op == "SLT":  # dấu khác nhau -> dấu của a; cùng dấu -> bit 31 của a-b
        sa, sb = a >> 31, b >> 31
        return sa if sa != sb else ((a - b) & M32) >> 31
    if op == "SRA":  # chép bit dấu vào sh bit cao
        fill = ((1 << sh) - 1) << (32 - sh) if (b >> 31) and sh else 0
        return ((b >> sh) | fill) & M32
    if op == "SUB":
        return (a + ((~b) & M32) + 1) & M32
    if op == "XOR":
        return (a | b) & ~(a & b) & M32
    return alu_a(op, a, b, sh)


lines = []
for a, b in operands(150):
    for op, code in ALU.items():
        sh = rng.choice([0, 1, 4, 16, 31]) if op in ("SLL", "SRA") else 0
        r = alu_a(op, a, b, sh)
        assert r == alu_b(op, a, b, sh), (op, a, b, sh)
        lines.append(f"{code:X} {a:08X} {b:08X} {sh:02X} {r:08X} {int(r == 0)}")
write("alu.txt", ["ctl(hex) a b shamt result zero  | ctl: 0 ADD 1 SUB 2 AND 3 OR 4 XOR 5 SLT 6 SLL 7 SRA",
                  "SLL/SRA dich b theo shamt; a bi bo"], lines)

# ---------------------------------------------------------------- MUL
lines = []
for a, b in operands(300):
    r1 = (s32(a) * s32(b)) & M32
    acc = 0
    for i in range(32):  # cách 2: dịch-cộng không dấu, lấy 32 bit thấp
        if (b >> i) & 1:
            acc = (acc + (a << i)) & M32
    assert r1 == acc
    lines.append(f"{a:08X} {b:08X} {r1:08X}")
write("mul.txt", ["a b lo32(a*b)  | mul: 32 bit thap cua tich co dau; HI/LO khong doi"], lines)


# ---------------------------------------------------------------- DIV
def div_a(a, b):
    sa, sb = s32(a), s32(b)
    if sb == 0:
        return 0, a, 1
    if sa == -2**31 and sb == -1:
        return 0x80000000, 0, 0
    q = abs(sa) // abs(sb)
    if (sa < 0) != (sb < 0):
        q = -q
    r = sa - q * sb
    return q & M32, r & M32, 0


def div_b(a, b):
    """Cách 2: restoring 32 vòng trên trị tuyệt đối, rồi sửa dấu."""
    sa, sb = s32(a), s32(b)
    if sb == 0:
        return 0, a, 1
    na, nb = abs(sa) & M32, abs(sb) & M32
    rem, quo = 0, na
    for _ in range(32):
        rem = (rem << 1) | (quo >> 31)
        quo = (quo << 1) & M32
        if rem >= nb:
            rem -= nb
            quo |= 1
    if (sa < 0) != (sb < 0):
        quo = (-quo) & M32
    if sa < 0:
        rem = (-rem) & M32
    return quo & M32, rem & M32, 0


lines = []
pairs = operands(300) + [((-7) & M32, 2), (7, (-2) & M32), ((-7) & M32, (-2) & M32), (86399999, 1000), (0x80000000, M32)]
for a, b in pairs:
    r = div_a(a, b)
    assert r == div_b(a, b), (a, b, r, div_b(a, b))
    lines.append(f"{a:08X} {b:08X} {r[0]:08X} {r[1]:08X} {r[2]}")
assert div_a((-7) & M32, 2) == ((-3) & M32, (-1) & M32, 0)
write("div.txt", ["a(rs) b(rt) LO HI DZ  | chia co dau, thuong lam tron ve 0; chia 0: LO=0 HI=a DZ=1; 0x80000000/-1: LO=0x80000000 HI=0"], lines)


# ---------------------------------------------------------------- BCD
def bcd_a(v):
    return int(f"{v:08d}", 16) if v <= 99_999_999 else M32


def bcd_b(v):
    """Cách 2: double-dabble (dịch-cộng-3) 32 vòng."""
    if v > 99_999_999:
        return M32
    bcd = 0
    for i in range(31, -1, -1):
        for d in range(8):
            if ((bcd >> (4 * d)) & 0xF) >= 5:
                bcd += 3 << (4 * d)
        bcd = ((bcd << 1) | ((v >> i) & 1)) & 0xFFFFFFFFF
    return bcd & M32


vals = [0, 1, 9, 10, 99, 100, 999, 1000, 59999, 86399999, 99999999, 100000000, M32, 0x80000000,
        12345678, 359999999, 2**27 - 1, 2**26]
vals += [10**k - 1 for k in range(1, 9)] + [10**k for k in range(1, 9)]
vals += [rng.randint(0, 99_999_999) for _ in range(3000)] + [rng.getrandbits(32) for _ in range(100)]
lines = []
for v in vals:
    r = bcd_a(v)
    assert r == bcd_b(v), v
    lines.append(f"{v:08X} {r:08X}")
assert bcd_a(12345678) == 0x12345678
write("bcd.txt", ["in out  | bcd rd,rs: 0..99 999 999 -> 8 chu so BCD; lon hon (khong dau) -> FFFFFFFF",
                  "kiem het 0..10^8-1 thi dung golden trong tb (vong lap), file nay la mau + bien"], lines)

# ---------------------------------------------------------------- SEG7
SEGS = {0: "abcdef", 1: "bc", 2: "abdeg", 3: "abcdg", 4: "bcfg", 5: "acdfg", 6: "acdefg", 7: "abc",
        8: "abcdefg", 9: "abcdfg", 0xA: "abcefg", 0xB: "cdefg", 0xC: "adef", 0xD: "bcdeg", 0xE: "adefg",
        0xF: "aefg", 0x10: "bcefg", 0x11: "def", 0x12: "ceg", 0x13: "cdeg", 0x14: "abefg", 0x15: "eg",
        0x16: "acdfg", 0x17: "defg", 0x18: "bcdef", 0x19: "g"}
TABLE_DOC = {0: 0x3F, 1: 0x06, 2: 0x5B, 3: 0x4F, 4: 0x66, 5: 0x6D, 6: 0x7D, 7: 0x07, 8: 0x7F, 9: 0x6F,
             0xA: 0x77, 0xB: 0x7C, 0xC: 0x39, 0xD: 0x5E, 0xE: 0x79, 0xF: 0x71, 0x10: 0x76, 0x11: 0x38,
             0x12: 0x54, 0x13: 0x5C, 0x14: 0x73, 0x15: 0x50, 0x16: 0x6D, 0x17: 0x78, 0x18: 0x3E, 0x19: 0x40}
SEG7 = {}
lines = []
for code in range(32):
    pat = sum(1 << "abcdefg".index(c) for c in SEGS.get(code, ""))
    assert pat == TABLE_DOC.get(code, 0), hex(code)  # khớp bảng trong display-spec §3
    SEG7[code] = pat
    lines.append(f"{code:02X} {pat:02X}")
write("seg7.txt", ["ma gfedcba  | bit0 = a, muc cao = sang"], lines)


# ---------------------------------------------------------------- TIMEBASE
def tb_lengths(n, cal, k):
    frac, out = 0, []
    for _ in range(k):
        s = frac + cal
        out.append(n + (s >> 16))  # >> của Python = dịch số học = floor
        frac = s & 0xFFFF
    return out


def tb_ticks_cycle_sim(n, cal, k):
    """Cách 2: mô phỏng từng chu kỳ (bộ đếm + bộ tích lũy), trả về chu kỳ có tick (đếm từ 1)."""
    frac, cnt, cyc, ticks = 0, 0, 0, []
    s = frac + cal
    length = n + (s >> 16)
    while len(ticks) < k:
        cyc += 1
        if cnt == length - 1:
            ticks.append(cyc)
            frac = s & 0xFFFF
            s = frac + cal
            length = n + (s >> 16)
            cnt = 0
        else:
            cnt += 1
    return ticks


CALS = [0, 1, -1, 3277, 32768, -32768, 65536, -65536, 163840, -163840, 100000, -100000, 655360, -655360]
lines, lines2 = [], []
for n in (50, 50000):
    for cal in CALS:
        ls = tb_lengths(n, cal, 20)
        if n == 50:
            cum = [sum(ls[:i + 1]) for i in range(20)]
            assert cum == tb_ticks_cycle_sim(n, cal, 20), cal
        lines.append(f"{n} {cal} " + " ".join(str(x) for x in ls))
        for k in (1000, 65536):
            tot = sum(tb_lengths(n, cal, k))
            assert tot == k * n + (k * cal) // 65536  # công thức đóng
            lines2.append(f"{n} {cal} {k} {tot}")
assert tb_lengths(50000, 163840, 4) == [50002, 50003, 50002, 50003]
write("timebase_len.txt", ["G_N CAL len_0 .. len_19  (thap phan) | tick thu k o chu ky dem thu len_0+..+len_(k-1)"], lines)
write("timebase_total.txt", ["G_N CAL K tong_chu_ky_cua_K_ms_dau"], lines2)

# ---------------------------------------------------------------- CONTROL (đọc từ control-table.md)
ct = open(os.path.join(ROOT, "docs", "control-table.md"), encoding="utf-8").read()
rows = [r for r in ct.splitlines() if re.match(r"^\| \d+ \| `", r)]
assert len(rows) == 28, len(rows)
DST = {"–": 0, "rd": 1, "rt": 2, "31": 3}
EXT = {"–": 0, "SE": 0, "ZE": 1, "LUI": 2}
RES = {"–": 0, "ALU": 0, "MUL": 1, "HI": 2, "LO": 3, "BCD": 4, "CP0": 5, "PC4": 6}


def bit(c):
    c = c.strip()
    return 0 if c in ("", "–") else int(c.split()[0], 2) if re.match(r"^[01]+", c) else int(c)


def alu_code(c):
    c = c.strip().split(" ")[0]
    return ALU.get(c, 0)


def encode(name, op, fn, r):
    rs, rt, rd, sh = r
    if op == 0:
        if name == "jr": rt = rd = sh = 0
        elif name == "div": rd = sh = 0
        elif name in ("mfhi", "mflo"): rs = rt = sh = 0
        elif name in ("sll", "sra"): rs = 0
        else: sh = 0
        return (rs << 21) | (rt << 16) | (rd << 11) | (sh << 6) | fn
    if op == 0x1C:
        if name == "bcd": rt = 0
        return (0x1C << 26) | (rs << 21) | (rt << 16) | (rd << 11) | fn
    if op == 0x10:
        if name == "eret": return 0x42000018
        sub = 0x00 if name == "mfc0" else 0x04
        return (0x10 << 26) | (sub << 21) | (rt << 16) | (rd << 11)
    if op in (2, 3):
        return (op << 26) | rng.getrandbits(26)
    if name == "lui": rs = 0
    return (op << 26) | (rs << 21) | (rt << 16) | rng.getrandbits(16)


lines = []
for r in rows:
    c = [x.strip() for x in r.strip("|").split("|")]
    name = c[1].strip("`").split()[0]
    opf = c[2].split("/")
    op = int(opf[0].strip(), 16)
    fn = int(opf[1].strip(), 16) if len(opf) > 1 and re.match(r"^[0-9A-F]{2}$", opf[1].strip()) else 0
    if name in ("mfc0", "mtc0", "eret"): fn = 0
    sig = [bit(c[3]), DST[c[4]], bit(c[5]), EXT[c[6]], alu_code(c[7]), RES[c[8]], bit(c[9]), bit(c[10]),
           bit(c[11]), bit(c[12]), bit(c[13]), bit(c[14]), bit(c[15]), bit(c[16]), bit(c[17]), bit(c[18])]
    for _ in range(3):
        w = encode(name, op, fn, [rng.randint(1, 31) for _ in range(4)])
        lines.append(f"{w:08X} " + " ".join(str(s) for s in sig) + f"  # {name}")
for w in (0xFC000000, 0x00000001, 0x7000003F, 0x40400000, 0x42000019):  # mã lạ -> NOP
    lines.append(f"{w:08X} " + " ".join("0" * 16) + "  # illegal")
assert sum(1 for ln in lines if "# addu" in ln) == 3
write("control.txt", ["instr reg_write dst alu_src ext alu_ctl res_sel mem_read mem_write mem_to_reg branch jump jump_reg multi cp0_op uses_rs uses_rt",
                      "ma so: control-table.md 1.1; sinh tu bang control-table.md (sua bang -> chay lai script)"], lines)

# ---------------------------------------------------------------- VGA
SEGR = {"a": (20, 60, 8, 16), "b": (60, 68, 16, 76), "c": (60, 68, 84, 144), "d": (20, 60, 144, 152),
        "e": (12, 20, 84, 144), "f": (12, 20, 16, 76), "g": (20, 60, 76, 84), "dp": (70, 78, 144, 152)}


SEGI = {"-": -1, "a": 0, "b": 1, "c": 2, "d": 3, "e": 4, "f": 5, "g": 6, "dp": 7}


def vga_classify(x, y):
    if not (0 <= x < 640 and 160 <= y < 320):
        return -1, "-"
    cell = 7 - x // 80
    u, v = x % 80, y - 160
    hit = [s for s, (u0, u1, v0, v1) in SEGR.items() if u0 <= u < u1 and v0 <= v < v1]
    assert len(hit) <= 1  # các đoạn không chồng nhau
    return cell, hit[0] if hit else "-"


pts = set()
for cell in (7, 3, 0):
    x0 = 80 * (7 - cell)
    for (u0, u1, v0, v1) in SEGR.values():
        for u in (u0 - 1, u0, u1 - 1, u1):
            for v in (v0 - 1, v0, v1 - 1, v1):
                pts.add((x0 + u, 160 + v))
pts |= {(0, 159), (0, 160), (639, 319), (639, 320), (79, 200), (80, 200), (799, 524)}
pts |= {(rng.randint(0, 639), rng.randint(0, 479)) for _ in range(300)}
lines = []
for x, y in sorted(pts):
    cell, seg = vga_classify(x, y)
    lines.append(f"{x} {y} {cell} {SEGI[seg]}")
assert vga_classify(80 * 7 + 20, 160 + 8) == (0, "a")
write("vga_points.txt", ["x y o(-1 = ngoai vung chu so) doan(0..6 = a..g, 7 = dp, -1 = nen)"], lines)

# ---------------------------------------------------------------- FMT (bố cục màn, display-spec §8)
BL, DASH = 0x1A, 0x19
CH = {"_": BL, "-": DASH, "A": 0xA, "P": 0x14, "L": 0x11, "o": 0x13}


def render(text):
    """'__12.34.56' -> 8 byte DISP7..DISP0; '.' bật bit chấm của ký tự trước."""
    out = []
    for ch in text:
        if ch == ".":
            out[-1] |= 0x80
        else:
            out.append(int(ch) if ch.isdigit() else CH[ch])
    assert len(out) == 8, text
    return " ".join(f"{b:02X}" for b in out)


def hms(ms):
    return ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000


def f_time24(ms):
    h, m, s, _ = hms(ms)
    return f"__{h:02d}.{m:02d}.{s:02d}"


def f_time12(ms):
    h, m, s, _ = hms(ms)
    return f"{'P' if h >= 12 else 'A'}_{(h % 12) or 12:02d}.{m:02d}.{s:02d}"


def f_mmssmmm(ms, lead="_"):
    _, m, s, x = hms(ms)
    return f"{lead}{m:02d}.{s:02d}.{x:03d}"


def f_sw(v):
    return f_mmssmmm(v) if v < 3600000 else f_time24(v)


def f_timer(v):
    sg = "-" if v < 0 else "_"
    a = abs(v)
    if a < 3600000: return f_mmssmmm(a, sg)
    if a < 360000000:
        h, m, s, _ = hms(a)
        return f"{sg}_{h:02d}.{m:02d}.{s:02d}"
    return f"{sg}_--.--.--"


def f_alarm(k, en, minute):
    return f"AL{k}{'o' if en else '_'}{minute // 60:02d}.{minute % 60:02d}"


tests = [0, 1, 999, 1000, 59999, 60000, 3599999, 3600000, 43199999, 43200000, 45296789, 86399999]
tests += [rng.randint(0, 86399999) for _ in range(50)]
write("fmt_time.txt", ["ms_of_day | TIME24 DISP7..0 | TIME12 DISP7..0 | giu-B DISP7..0  (bit7 = cham)"],
      [f"{t} | {render(f_time24(t))} | {render(f_time12(t))} | {render(f_mmssmmm(t))}" for t in tests])
assert render("__12.34.56") == "1A 1A 01 82 03 84 05 06"
assert f_time12(0) == "A_12.00.00" and f_time12(12 * 3600000) == "P_12.00.00"
sw = [0, 1234, 59999, 3599999, 3600000, 359999999] + [rng.randint(0, 359999999) for _ in range(30)]
write("fmt_sw.txt", ["stopwatch_ms | DISP7..0"], [f"{v} | {render(f_sw(v))}" for v in sw])
tm = [0, 1, -1, -500, 300000, -300000, 3599999, -3600000, 359999999, -360000000, -2**31, 2**31 - 1]
tm += [rng.randint(-10**8, 10**8) for _ in range(30)]
write("fmt_timer.txt", ["timer_ms(co dau) | DISP7..0"], [f"{v} | {render(f_timer(v))}" for v in tm])
assert render(f_timer(-500)) == "19 00 80 00 80 05 00 00"
al = [(1, 1, 420), (2, 0, 0), (4, 1, 1439), (3, 1, 725)]
write("fmt_alarm.txt", ["k en minute_of_day | DISP7..0"], [f"{k} {e} {m} | {render(f_alarm(k, e, m))}" for k, e, m in al])

# ---------------------------------------------------------------- DATE
lines = []
days = [0, 1, 30, 31, 59, 60, 365, 366, 1520, 9496, 9587, 36583, 36584, 36585, 65535]
days += [rng.randint(0, 65535) for _ in range(200)]
base = datetime.date(2000, 1, 1)
for d in days:
    dt = base + datetime.timedelta(days=d)
    dow = (dt.weekday() + 1) % 7  # Python: thứ 2 = 0 -> CN = 0
    assert dow == (d + 6) % 7      # cách 2: công thức trong timer-spec §9
    page2 = f"{dt.day:02d}-{dt.month:02d}-{dt.year % 100:02d}"
    lines.append(f"{d} {dt.year} {dt.month} {dt.day} {dow} | {render(page2)}")
assert base + datetime.timedelta(days=9587) == datetime.date(2026, 4, 1)
write("date.txt", ["day(so ngay tu 01/01/2000) nam thang ngay dow(0=CN) | TIME trang 2 DISP7..0"], lines)

# ---------------------------------------------------------------- SYNC
def cs(body):
    x = 0
    for ch in body.encode():
        x ^= ch
    return f"{x:02X}"


def sentence(body, bad=False):
    c = cs(body)
    if bad:
        c = f"{int(c, 16) ^ 0x01:02X}"
    return f"${body}*{c}"


lines = []
for _ in range(20):
    ms, d = rng.randint(0, 86399999), rng.randint(0, 65535)
    lines.append(f"{sentence(f'T,{ms},{d}')}\tACCEPT\t{ms}\t{d}")
    lines.append(f"{sentence(f'T,{ms},{d}', bad=True)}\tREJECT\t-\t-")
for body in ("T,86400000,1", "T,1,65536", "T,12a,5", "T,5", "T,,5"):
    lines.append(f"{sentence(body)}\tREJECT\t-\t-")
lines.append("T,1000,5*" + cs("T,1000,5") + "\tREJECT\t-\t-")  # thiếu '$'
low = next(f"T,{m},5" for m in range(1000, 2000) if any(ch in "ABCDEF" for ch in cs(f"T,{m},5")))
lines.append(f"${low}*{cs(low).lower()}\tREJECT\t-\t-")  # checksum chữ thường
lines.append(f"{sentence('Q')}\tQUERY\t-\t-")
assert sentence("Q") == "$Q*51"
write("sync_sentences.txt", ["cau(khong co \\n)<TAB>ky vong<TAB>ms<TAB>day | CS = XOR cac byte giua $ va *"], lines)


def mips_div(a, b):
    q = abs(a) // abs(b)
    return q if (a < 0) == (b < 0) else -q


lines = []
cases = [(3600000, 72, 0), (3600000, -72, 65536), (600000, 0, 123), (599999, 10, 0), (86400000, 17280, 0),
         (86400001, 1, 0), (3600000, 721, 0), (3600000, 720, 0), (7200000, 150, -5000),
         (3600000, 429497, 0), (3600000, 858994, 0), (3600000, -858994, 0)]  # ca tích |D|*5000 tràn 32 bit
cases += [(rng.randint(600000, 86400000), rng.randint(-200, 200), rng.randint(-300000, 300000)) for _ in range(40)]
for i_ms, d_ms, cal in cases:
    ok = 600000 <= i_ms <= 86400000 and abs(d_ms) <= i_ms // 5000  # chia trước, không tràn
    assert ok == (600000 <= i_ms <= 86400000 and abs(d_ms) * 5000 <= i_ms)  # cách 2: số Python không tràn
    new = cal + mips_div(d_ms * 65536, i_ms // 1000) * 50 if ok else cal
    if ok and d_ms:  # cách 2: qua ppm số thực; sai do cắt I/1000 (<= 0,17%) + cắt thương (<= 50)
        exact = d_ms / i_ms * 1e6 * 3276.8
        assert abs((new - cal) - exact) <= 0.002 * abs(exact) + 51, (i_ms, d_ms)
    assert not ok or abs(d_ms * 65536) < 2**31
    lines.append(f"{i_ms} {d_ms} {cal} {'ACCEPT' if ok else 'REJECT'} {new}")
assert lines[0].endswith("ACCEPT 65500")
write("sync_cal.txt", ["I_ms D_ms CAL_cu ket_qua CAL_moi | dCAL = ((D*65536)/(I/1000))*50, div cat ve 0"], lines)

for name, n in summary:
    print(f"{name:22s} {n:6d} dong")
print("PASS: moi golden khop cach tinh thu 2")
