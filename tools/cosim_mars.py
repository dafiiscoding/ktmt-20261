"""Co-sim tạm cho CPU G1 (gói C3): MARS 4.5 làm golden khi chưa có ISS (B2) / asm.py (B1).

  python tools/cosim_mars.py                 # mọi fw/tests/cpu/*.s + 8 chương trình ngẫu nhiên
  python tools/cosim_mars.py sum100 fact10   # chỉ vài file
  python tools/cosim_mars.py --rand 50       # thêm nhiều chương trình ngẫu nhiên hơn (seed 1..50)

Với mỗi chương trình:
  1. MARS dịch (CompactTextAtZero) → work/cosim/<tên>.hex; `bcd $rd,$rs` được thay bằng `teq $rs,$rd`
     khi dịch rồi vá lại mã bcd (SPECIAL2 funct 0x10) trong .hex.
  2. Icarus chạy tb/cpu_g1_tb.v → dump 32 GPR, DMEM, số lệnh; trace isa-spec §8 → work/cosim/<tên>.csv
  3. MARS chạy cùng file (smc, bước giới hạn) → 32 GPR, vùng nhớ, số lệnh (ic).
  4. So: GPR $1..$31, vùng nhớ (mặc định 0x800-0xff8), số lệnh; file `# nomars` chỉ so `# expect`.
Dòng cuối: PASS cosim_mars <n> hoặc FAIL. Luật viết chương trình: fw/tests/cpu/README.md.
"""
import os
import random
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MARS = os.path.join(ROOT, ".toolchain", "Mars4_5.jar")
OUT = os.path.join(ROOT, "work", "cosim")
REG = ("zero at v0 v1 a0 a1 a2 a3 t0 t1 t2 t3 t4 t5 t6 t7 s0 s1 s2 s3 s4 s5 s6 s7 "
       "t8 t9 k0 k1 gp sp fp ra").split()


def sh(cmd, **kw):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, **kw)


def reg_no(name):
    name = name.lstrip("$")
    return int(name) if name.isdigit() else REG.index(name)


# ---------------------------------------------------------------- chương trình ngẫu nhiên
def gen_rand(seed, n=300, mars=True):
    """Chương trình thẳng + nhánh tiến. mars=True: tuân luật README (không mfhi/mflo sau mul, không chia 0);
    mars=False (cosim_iss, golden = ISS theo spec nhóm): có cả hai."""
    rnd = random.Random(seed)
    regs = ["$t%d" % i for i in range(10)] + ["$s%d" % i for i in range(7)] + ["$a%d" % i for i in range(4)] + ["$v0", "$v1"]
    L = ["# ngẫu nhiên seed %d (sinh bởi tools/cosim_mars.py)" % seed,
         "        li    $sp, 0xff8", "        li    $s7, 0x800        # gốc vùng nhớ, không bị ghi đè"]
    for r in regs:
        L.append("        li    %s, %d" % (r, rnd.choice([0, 1, -1, 0x7FFFFFFF, -0x80000000, rnd.randint(-2**31, 2**31 - 1),
                                                         rnd.randint(-300, 300)])))
    hl_ok = True       # HI/LO đang là kết quả div (hoặc reset) → mfhi/mflo so được với MARS
    lab = 0
    pend = []          # nhãn nhánh tiến: [số lệnh còn lại trước khi đặt nhãn, tên]
    k = 0
    while k < n:
        d, a, b = rnd.choice(regs), rnd.choice(regs + ["$zero"]), rnd.choice(regs + ["$zero"])
        c = rnd.random()
        if c < 0.30:
            op = rnd.choice(["addu", "subu", "and", "or", "xor", "slt"])
            L.append("        %-5s %s, %s, %s" % (op, d, a, b))
        elif c < 0.40:
            L.append("        %-5s %s, %s, %d" % (rnd.choice(["sll", "sra"]), d, b, rnd.randint(0, 31)))
        elif c < 0.55:
            op = rnd.choice(["addiu", "slti", "andi", "ori"])
            imm = rnd.randint(-32768, 32767) if op in ("addiu", "slti") else rnd.randint(0, 65535)
            L.append("        %-5s %s, %s, %d" % (op, d, a, imm))
        elif c < 0.58:
            L.append("        lui   %s, %d" % (d, rnd.randint(0, 65535)))
        elif c < 0.66:
            L.append("        sw    %s, %d($s7)" % (b, 4 * rnd.randint(0, 255)))
        elif c < 0.74:
            L.append("        lw    %s, %d($s7)" % (d, 4 * rnd.randint(0, 255)))
        elif c < 0.78:
            L.append("        mul   %s, %s, %s" % (d, a, b))
            hl_ok = not mars
        elif c < 0.82:
            if mars or rnd.random() < 0.7:
                L.append("        ori   $k0, %s, 1" % b)       # số chia ≠ 0
                L.append("        div   %s, $k0" % a)
            else:
                L.append("        div   %s, %s" % (a, rnd.choice(["$zero", b])))   # có thể chia 0
                k -= 1
            hl_ok = True
            k += 1
        elif c < 0.86:
            if hl_ok:
                L.append("        %-5s %s" % (rnd.choice(["mfhi", "mflo"]), d))
            else:
                continue
        elif c < 0.95 and len(pend) < 3:
            lab += 1
            name = "L%d" % lab
            op = rnd.choice(["beq", "bne", "beq", "j"])
            L.append(("        j     %s" % name) if op == "j" else ("        %-5s %s, %s, %s" % (op, a, b, name)))
            pend.append([rnd.randint(1, 4), name])
        else:
            continue
        k += 1
        for p in pend:
            p[0] -= 1
        while pend and pend[0][0] <= 0:
            L.append(pend.pop(0)[1] + ":")
    for p in pend:
        L.append(p[1] + ":")
    L.append("        nop")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- MARS
def _mars_dump(text, tmp, hexf, mc="CompactTextAtZero"):
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    if os.path.exists(hexf):
        os.remove(hexf)
    r = sh(["java", "-jar", MARS, "nc", "a", "ae1", "mc", mc, "dump", ".text", "HexText", hexf, tmp])
    if r.returncode != 0 or not os.path.exists(hexf):
        raise RuntimeError("MARS dich loi:\n" + r.stdout + r.stderr)
    return [int(x, 16) for x in open(hexf).read().split()]


ORG_MARK = 0x00000036          # tne $zero,$zero: đánh dấu chỗ `.org` khi dịch thử


def mars_assemble(src, hexf, mc="CompactTextAtZero"):
    """mc = "Default" cho chương trình > 4 KB (CompactTextAtZero chỉ có .text 0x0000–0x0FFC): .text ở 0x00400000,
    trường đích của j/jal được trừ lại 0x00400000 >> 2 để khớp IMEM bắt đầu ở 0."""
    tmp = hexf[:-4] + ".mars.s"
    with open(src, encoding="utf-8") as f:
        text = f.read()
    text = re.sub(r"\bbcd\s+(\$\w+)\s*,\s*(\$\w+)", r"teq \2, \1", text)
    # `.org 0x180` (MARS không có): dịch thử với lệnh đánh dấu → biết vị trí → thay bằng đủ số nop
    while True:
        m = re.search(r"^[ \t]*\.org[ \t]+(\S+)[^\n]*$", text, re.M)
        if not m:
            break
        target = int(m.group(1), 0)
        probe = text[:m.start()] + "        tne $zero, $zero" + text[m.end():]
        idx = _mars_dump(probe, tmp, hexf, mc).index(ORG_MARK)
        pad = target // 4 - idx
        if pad < 0:
            raise RuntimeError(".org 0x%x: code truoc do da dai %d word" % (target, idx))
        text = text[:m.start()] + "        nop\n" * pad + text[m.end() + 1:]
    words = _mars_dump(text, tmp, hexf, mc)
    for i, w in enumerate(words):
        if mc == "Default" and (w >> 26) in (2, 3):         # j, jal
            words[i] = w - (0x00400000 >> 2)
        if (w >> 26) == 0 and (w & 0x3F) == 0x34:          # teq rs,rt → bcd rd=rt, rs
            rs, rt = (w >> 21) & 31, (w >> 16) & 31
            words[i] = (0x1C << 26) | (rs << 21) | (rt << 11) | 0x10
    with open(hexf, "w", newline="\n") as f:
        f.write("".join("%08x\n" % w for w in words))
    return tmp, len(words)


def mars_run(src_mars, lo, hi):
    args = ["java", "-jar", MARS, "nc", "smc", "ic", "se1", "mc", "CompactTextAtZero", "2000000"]
    args += ["$%d" % i for i in range(32)] + ["0x%x-0x%x" % (lo, hi), src_mars]
    r = sh(args)
    out = r.stdout
    if r.returncode != 0 or "error" in out.lower() or "maximum step" in out:
        raise RuntimeError("MARS chay loi:\n" + out + r.stderr)
    regs, mem, ic = {}, {}, None
    for ln in out.splitlines():
        m = re.match(r"\$(\d+)\s+0x([0-9a-f]+)", ln)
        if m:
            regs[int(m.group(1))] = int(m.group(2), 16)
            continue
        m = re.match(r"Mem\[0x([0-9a-f]+)\]\s+(.*)", ln)
        if m:
            a = int(m.group(1), 16)
            for k, v in enumerate(m.group(2).split()):
                mem[a + 4 * k] = int(v, 16)
            continue
        if ln.strip().isdigit():
            ic = int(ln.strip())
    return regs, mem, ic


# ---------------------------------------------------------------- RTL
def rtl_build():
    vvp = os.path.join(OUT, "cpu_g1_tb.vvp")
    helpers = [os.path.join("tb", f) for f in os.listdir(os.path.join(ROOT, "tb"))
               if f.endswith(".v") and not f.endswith("_tb.v")]
    sdir = os.environ.get("COSIM_SRC", os.path.join(ROOT, "src"))     # COSIM_SRC: thư mục src khác (thử mutant)
    srcs = [os.path.join(sdir, f) for f in sorted(os.listdir(sdir)) if f.endswith(".v")]
    r = sh(["iverilog", "-g2005", "-Wall", "-Wno-timescale", "-o", vvp, "tb/cpu_g1_tb.v"] + srcs + helpers)
    if r.returncode != 0:
        sys.exit("FAIL cosim_mars (bien dich RTL)\n" + r.stdout + r.stderr)
    return vvp


def rtl_run(vvp, hexf, nwords, name):
    dump = os.path.join(OUT, name + ".dump")
    rel = lambda p: os.path.relpath(p, ROOT).replace("\\", "/")
    if os.path.exists(dump):
        os.remove(dump)                                     # không đọc nhầm dump của lần chạy trước
    cmd = ["vvp", "-n", vvp, "+imem=" + rel(hexf), "+end=%x" % (4 * nwords), "+dump=" + rel(dump),
           "+trace=" + rel(os.path.join(OUT, name + ".csv")), "+maxcyc=%d" % (100000 * CEDIV), "+cediv=%d" % CEDIV]
    p = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        out, _ = p.communicate(timeout=TMO)
    except subprocess.TimeoutExpired:
        # vvp.exe của OSS CAD Suite là trình khởi chạy → phải giết cả cây tiến trình (vd. vòng tổ hợp)
        if os.name == "nt":
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(p.pid)], capture_output=True)
        else:
            p.kill()
        p.communicate()
        raise RuntimeError("RTL treo (> %d s)" % TMO)
    last = [ln for ln in out.splitlines() if ln.startswith(("PASS", "FAIL"))]
    regs, mem, info = {}, {}, {}
    if os.path.exists(dump):
        for ln in open(dump):
            p = ln.split()
            if p[0] == "R":
                regs[int(p[1])] = int(p[2], 16)
            elif p[0] == "M":
                mem[int(p[1], 16)] = int(p[2], 16)
            else:
                info[p[0]] = p[1]
    tb_ok = bool(last) and last[-1].startswith("PASS")
    asserts = [ln for ln in out.splitlines() if ln.startswith(("ASSERT", "loi"))]
    return regs, mem, info, tb_ok, asserts


# ---------------------------------------------------------------- so
CEDIV = int(os.environ.get("COSIM_CEDIV", "1"))      # cpu_ce 1/k chu kỳ (tb +cediv)
TMO = int(os.environ.get("COSIM_TIMEOUT", "300"))     # giây cho 1 lần chạy RTL
MARS_INIT = {28: 0x1800, 29: 0x3FFC}     # $gp, $sp MARS đặt sẵn; CPU nhóm reset mọi GPR = 0


def text_reads(csv):
    n = 0
    for ln in open(csv):
        p = ln.strip().split(",")
        if len(p) == 8 and p[5] == "R" and int(p[6], 16) < 0x1000:
            n += 1
    return n


def run_one(src, vvp):
    name = os.path.splitext(os.path.basename(src))[0]
    text = open(src, encoding="utf-8").read()
    nomars = "# nomars" in text
    expects = [(reg_no(m.group(1)), int(m.group(2), 0)) for m in re.finditer(r"#\s*expect\s+(\$\w+)\s*=\s*(\S+)", text)]
    mm = re.search(r"#\s*mem\s+(0x[0-9a-f]+)-(0x[0-9a-f]+)", text)
    lo, hi = (int(mm.group(1), 16), int(mm.group(2), 16)) if mm else (0x800, 0xFF8)

    hexf = os.path.join(OUT, name + ".hex")
    tmp, nw = mars_assemble(src, hexf)
    regs, mem, info, tb_ok, asserts = rtl_run(vvp, hexf, nw, name)
    errs = []
    if not tb_ok:
        errs.append("tb khong PASS: " + "; ".join(asserts[:3]))
    elif asserts:
        errs.append("; ".join(asserts[:3]))
    for r, v in expects:
        if regs.get(r) != v & 0xFFFFFFFF:
            errs.append("expect $%s=%08x, RTL %08x" % (REG[r], v & 0xFFFFFFFF, regs.get(r, -1)))
    if not nomars:
        mregs, mmem, mic = mars_run(tmp, lo, hi)
        for r in range(1, 32):
            if r in MARS_INIT and mregs.get(r) == MARS_INIT[r] and regs.get(r) == 0:
                continue                                    # chương trình không đụng $gp/$sp
            if regs.get(r) != mregs.get(r):
                errs.append("$%s: RTL %08x MARS %08x" % (REG[r], regs.get(r, -1), mregs.get(r, -1)))
        for a in range(lo, hi + 4, 4):
            if mem.get(a, 0) != mmem.get(a, 0):
                errs.append("M[%03x]: RTL %08x MARS %08x" % (a, mem.get(a, 0), mmem.get(a, 0)))
        # ic của MARS đếm thêm mỗi lw đọc vào đoạn text (0x000-0xFFF trong CompactTextAtZero)
        nlw = text_reads(os.path.join(OUT, name + ".csv"))
        if mic is None or int(info.get("IC", -1)) + nlw != mic:
            errs.append("so lenh: RTL %s (+%d lw vung text) MARS %s" % (info.get("IC"), nlw, mic))
    ic, cc = int(info.get("IC", 0)), int(info.get("CPUCYC", 0))
    tag = "rieng (expect)" if nomars else "vs MARS"
    print("%-4s %-12s %-15s lenh=%-6d chu_ky_CPU=%-6d CPI=%.2f" % ("OK" if not errs else "SAI", name, tag, ic, cc,
                                                                   cc / ic if ic else 0))
    for e in errs[:8]:
        print("     loi", e)
    return not errs


def main():
    args = sys.argv[1:]
    nrand = 8
    if "--rand" in args:
        i = args.index("--rand")
        nrand = int(args[i + 1])
        del args[i:i + 2]
    os.makedirs(OUT, exist_ok=True)
    tdir = os.path.join(ROOT, "fw", "tests", "cpu")
    if args:
        srcs = [os.path.join(tdir, a + ".s") for a in args]
    else:
        srcs = sorted(os.path.join(tdir, f) for f in os.listdir(tdir) if f.endswith(".s"))
        for s in range(1, nrand + 1):
            p = os.path.join(OUT, "rand%02d.s" % s)
            with open(p, "w", encoding="utf-8", newline="\n") as f:
                f.write(gen_rand(s))
            srcs.append(p)
    vvp = rtl_build()
    ok = 0
    for s in srcs:
        try:
            ok += run_one(s, vvp)
        except RuntimeError as e:
            print("SAI ", os.path.basename(s), str(e)[:400])
    if ok == len(srcs):
        print("PASS cosim_mars %d" % ok)
    else:
        print("FAIL cosim_mars %d sai / %d chuong trinh" % (len(srcs) - ok, len(srcs)))
        sys.exit(1)


if __name__ == "__main__":
    main()
