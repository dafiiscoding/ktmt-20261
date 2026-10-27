"""cosim_iss.py — co-sim RTL G1 với ISS theo từng lệnh (B2 + B3; thay golden tạm MARS của cosim_mars.py).

  python tools/cosim_iss.py                    # mọi fw/tests/cpu/*.s + 8 chương trình ngẫu nhiên + firmware SoC
  python tools/cosim_iss.py sum100 irq         # chỉ vài chương trình CPU
  python tools/cosim_iss.py --rand 30          # thêm chương trình ngẫu nhiên (seed 1..30)
  python tools/cosim_iss.py --soc-only         # chỉ firmware SoC (bus, clock, irqlat, uart, fmt_bench, system)

Mỗi chương trình: asm.py dịch → RTL ghi trace isa-spec §8 → ISS chạy **replay MMIO** theo trace đó
(lw MMIO, mfc0 Cause, chỗ nhận ngắt lấy từ RTL) → cmp_trace so từng dòng (bỏ cột cycle).
  - CPU (`tb/cpu_g1_tb.v`, như cosim_mars): thêm so trạng thái cuối (GPR, HI, LO, DMEM, số lệnh) và dòng `# expect`.
  - SoC: tb có `(fw: …)` chạy với `+trace=`; DMEM ban đầu mà tb ghi (`dut.u_cpu.dmem[i] = …;`) được chép sang ISS.
Dòng cuối: PASS cosim_iss <n> hoặc FAIL. Biến môi trường như cosim_mars (COSIM_CEDIV, COSIM_TIMEOUT, COSIM_SRC).
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asm  # noqa: E402
import cmp_trace  # noqa: E402
import cosim_mars  # noqa: E402
import iss  # noqa: E402

ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "work", "cosim_iss")
cosim_mars.OUT = OUT                          # rtl_build/rtl_run ghi vào thư mục riêng, không đè cosim_mars
SOC = ["soc_bus", "soc_clock", "soc_irqlat", "soc_uart", "fmt_bench", "system"]
G2 = {"on": False}                            # --g2: lõi pipeline (C7) thay cho G1


def rtl_build_g2():
    """Biên dịch tb/cpu_pipe_tb.v với src/ (cùng cách cosim_mars.rtl_build)."""
    vvp = os.path.join(OUT, "cpu_pipe_tb.vvp")
    helpers = [os.path.join("tb", f) for f in os.listdir(os.path.join(ROOT, "tb"))
               if f.endswith(".v") and not f.endswith("_tb.v")]
    sdir = os.environ.get("COSIM_SRC", os.path.join(ROOT, "src"))
    srcs = [os.path.join(sdir, f) for f in sorted(os.listdir(sdir)) if f.endswith(".v")]
    c = cosim_mars.sh(["iverilog", "-g2005", "-Wall", "-Wno-timescale", "-o", vvp, "tb/cpu_pipe_tb.v"] + srcs + helpers)
    if c.returncode:
        sys.exit("FAIL cosim_iss --g2 (bien dich RTL)\n" + c.stdout + c.stderr)
    return vvp


def rel(p):
    return os.path.relpath(p, ROOT).replace("\\", "/")


def assemble(src, hexf, aw=10):
    r = asm.assemble_file(src, aw)
    asm.write_hex(hexf, r["imem"])
    return r


def check_trace(rtl_csv, imem, pokes=()):
    rtl = iss.read_trace(rtl_csv)
    cpu = iss.ISS(imem, aw=len(imem).bit_length() - 1)
    for a, v in pokes:
        cpu.dmem[(a >> 2) & 1023] = v & iss.M32
    recs, probs = iss.replay(cpu, rtl)
    B = [iss.fmt(r).split(",") for r in recs]
    with open(rtl_csv[:-4] + ".iss.csv", "w", newline="\n") as f:
        f.write("".join(",".join(r) + "\n" for r in B))
    ok, rep = cmp_trace.compare(rtl, B, "RTL", "ISS")
    errs = rep + probs + ["ISS lenh la pc=%08x instr=%08x" % u for u in cpu.unknown]
    nint = sum(1 for x in rtl if x[2] == "INTERRUPT")
    return cpu, len(rtl), nint, errs


def run_cpu(src, vvp):
    name = os.path.splitext(os.path.basename(src))[0]
    text = open(src, encoding="utf-8").read()
    hexf = os.path.join(OUT, name + ".hex")
    r = assemble(src, hexf)
    regs, mem, info, tb_ok, asserts = cosim_mars.rtl_run(vvp, hexf, r["nwords"], name)
    errs = [] if tb_ok else ["tb khong PASS: " + "; ".join(asserts[:3])]
    cpu, n, nint, e = check_trace(os.path.join(OUT, name + ".csv"), r["imem"])
    errs += e
    if not e:                                               # trace khớp → so thêm trạng thái cuối
        for k in range(1, 32):
            if regs.get(k) != cpu.r[k]:
                errs.append("$%s cuoi: RTL %08x ISS %08x" % (iss.REG[k], regs.get(k, -1), cpu.r[k]))
        for k, v in (("HI", cpu.hi), ("LO", cpu.lo)):
            if int(info.get(k, "-1"), 16) != v:
                errs.append("%s cuoi: RTL %s ISS %08x" % (k, info.get(k), v))
        for a in range(0, 4096, 4):
            if mem.get(a, 0) != cpu.dmem[a >> 2]:
                errs.append("M[%03x] cuoi: RTL %08x ISS %08x" % (a, mem.get(a, 0), cpu.dmem[a >> 2]))
        if int(info.get("IC", -1)) != cpu.n:
            errs.append("so lenh: RTL %s ISS %d" % (info.get("IC"), cpu.n))
    for m in re.finditer(r"#\s*expect\s+(\$\w+)\s*=\s*(\S+)", text):
        k = cosim_mars.reg_no(m.group(1))
        if cpu.r[k] != int(m.group(2), 0) & iss.M32:
            errs.append("expect %s=%s, ISS %08x" % (m.group(1), m.group(2), cpu.r[k]))
    if G2["on"]:                                            # số chu kỳ = bảng T1–T8 (pipeline-policy §7–§8)
        m = re.search(r"#\s*bubbles\s+(\d+)", text)
        if not m and os.sep + "hazard" + os.sep in src:
            errs.append("thieu dong '# bubbles N' (bo hazard bat buoc)")
        elif m:
            cs = [int(x.split(",")[0]) for x in open(os.path.join(OUT, name + ".csv"))]
            k = int(os.environ.get("COSIM_CEDIV", "1"))     # cột cyc là chu kỳ hệ thống; cpu_ce = 1/k
            if any((b - a) % k for a, b in zip(cs, cs[1:])):
                errs.append("retire khong nam tren cpu_ce (chia %d du)" % k)
            gaps = sum((b - a) // k - 1 for a, b in zip(cs, cs[1:]))
            if gaps != int(m.group(1)):
                errs.append("bong bong: RTL %d, spec %s" % (gaps, m.group(1)))
    report(name, n, nint, errs)
    return not errs


def tb_pokes(tb):
    """`dut.u_cpu.dmem[i] = biểu thức;` trong tb → [(địa chỉ, giá trị)] (biểu thức số nguyên đơn giản)."""
    out = []
    for m in re.finditer(r"dut\.u_cpu\.dmem\[(\d+)\]\s*=\s*([^;]+);", open(tb, encoding="utf-8").read()):
        expr = m.group(2)
        if not re.fullmatch(r"[\d\s()<>|&+\-*]+", expr):
            raise RuntimeError("khong doc duoc gia tri DMEM tb ghi: " + m.group(0))
        out.append((4 * int(m.group(1)), eval(expr)))      # chỉ chữ số và toán tử (đã lọc ở trên)
    return out


def run_soc(t):
    tb = os.path.join(ROOT, "tb", t + "_tb.v")
    fw = re.search(r"\(fw:\s*([^)]+)\)", open(tb, encoding="utf-8").readline()).group(1).strip()
    vvp = os.path.join(OUT, t + ("_g2" if G2["on"] else "") + "_tb.vvp")
    helpers = [os.path.join("tb", f) for f in os.listdir(os.path.join(ROOT, "tb"))
               if f.endswith(".v") and not f.endswith("_tb.v")]
    sdir = os.environ.get("COSIM_SRC", os.path.join(ROOT, "src"))     # như cosim_mars (thử đột biến RTL)
    srcs = [os.path.join(sdir, f) for f in sorted(os.listdir(sdir)) if f.endswith(".v")]
    dflag = ["-DG2"] if G2["on"] else []
    c = cosim_mars.sh(["iverilog", "-g2005", "-Wall", "-Wno-timescale"] + dflag + ["-o", vvp, rel(tb)] + srcs + helpers)
    if c.returncode:
        report(t, 0, 0, ["bien dich: " + c.stdout[-300:] + c.stderr[-300:]])
        return False
    hexf = os.path.join(OUT, t + ".hex")
    r = assemble(os.path.join(ROOT, fw), hexf, 11)            # soc_top G_IMEM_AW = 11
    csv = os.path.join(OUT, t + ".csv")
    if os.path.exists(csv):
        os.remove(csv)
    p = subprocess.run(["vvp", "-n", vvp, "+imem=" + rel(hexf), "+trace=" + rel(csv)], cwd=ROOT,
                       capture_output=True, text=True, timeout=1800)
    last = [ln for ln in p.stdout.splitlines() if ln.startswith(("PASS", "FAIL"))]
    errs = [] if last and last[-1].startswith("PASS %s_tb" % t) else ["tb khong PASS: " + (last[-1] if last else "?")]
    cpu, n, nint, e = check_trace(csv, r["imem"], tb_pokes(tb))
    report("%s (%s)" % (t, fw), n, nint, errs + e)
    return not (errs or e)


def report(name, n, nint, errs):
    print("%-4s %-34s %8d dong trace, %4d ngat" % ("OK" if not errs else "SAI", name, n, nint))
    for e in errs[:8]:
        print("     loi", e)


def main():
    args = sys.argv[1:]
    nrand, soc_only = 8, "--soc-only" in args
    args = [a for a in args if a != "--soc-only"]
    G2["on"] = "--g2" in args
    args = [a for a in args if a != "--g2"]
    if "--rand" in args:
        i = args.index("--rand")
        nrand = int(args[i + 1])
        del args[i:i + 2]
    os.makedirs(OUT, exist_ok=True)
    tdir = os.path.join(ROOT, "fw", "tests", "cpu")
    srcs, socs = [], []
    if args:
        srcs = [os.path.join(tdir, a + ".s") for a in args if a not in SOC]
        socs = [a for a in args if a in SOC]
    else:
        socs = SOC
        if not soc_only:
            srcs = sorted(os.path.join(tdir, f) for f in os.listdir(tdir) if f.endswith(".s"))
            if G2["on"]:                                    # G2: thêm bộ hazard; irq* chạy cùng (ngắt chính xác §10)
                hdir = os.path.join(ROOT, "fw", "tests", "hazard")
                srcs += sorted(os.path.join(hdir, f) for f in os.listdir(hdir) if f.endswith(".s"))
                socs = ["system"]
            for s in range(1, nrand + 1):
                p = os.path.join(OUT, "rand%02d.s" % s)
                with open(p, "w", encoding="utf-8", newline="\n") as f:
                    f.write(cosim_mars.gen_rand(s, mars=False))
                srcs.append(p)
    ok = 0
    if srcs:
        vvp = rtl_build_g2() if G2["on"] else cosim_mars.rtl_build()
        for s in srcs:
            try:
                ok += run_cpu(s, vvp)
            except (RuntimeError, asm.AsmError) as e:
                report(os.path.basename(s), 0, 0, [str(e)[:400]])
    if G2["on"]:
        socs = [t for t in socs if t == "system"]           # G2 polling: chỉ system_tb (soc_bus/clock/irqlat cần ngắt)
    for t in socs:
        try:
            ok += run_soc(t)
        except (RuntimeError, asm.AsmError, subprocess.TimeoutExpired) as e:
            report(t, 0, 0, [str(e)[:400]])
    n = len(srcs) + len(socs)
    if ok == n:
        print("PASS cosim_iss %d" % ok)
        return 0
    print("FAIL cosim_iss %d sai / %d chuong trinh" % (n - ok, n))
    return 1


if __name__ == "__main__":
    sys.exit(main())
