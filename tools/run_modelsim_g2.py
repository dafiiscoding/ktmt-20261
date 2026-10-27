"""run_modelsim_g2.py — chạy tb/cpu_pipe_tb.v (G2) bằng ModelSim (vlog/vsim) và so trace với Icarus.

Dùng: python tools/run_modelsim_g2.py [thư_mục_bin_modelsim]
Mặc định: C:/intelFPGA/20.1/modelsim_ase/win32aloem. Cần chạy cosim_iss.py --g2 một lần trước (để có cpu_pipe_tb.vvp).
Với mỗi chương trình G2: vsim -c và vvp (Icarus) cùng plusargs, so csv + dump từng byte.
Tên trace: thư mục_tên (cp0 có ở cpu/ và hazard/). Dòng cuối: PASS/FAIL modelsim_g2 n đúng / N.
"""
import glob, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import asm  # noqa: E402

BIN = (sys.argv[1] if len(sys.argv) > 1 else "C:/intelFPGA/20.1/modelsim_ase/win32aloem").replace("\\", "/")
VLOG, VSIM, VLIB, VMAP = (os.path.join(BIN, t + ".exe") for t in ("vlog", "vsim", "vlib", "vmap"))
OUT = os.path.join(ROOT, "work", "modelsim_g2")
ICARUS = os.path.join(ROOT, "work", "cosim_iss")
VVP = os.path.join(ICARUS, "cpu_pipe_tb.vvp")   # tb G2 đã biên dịch bởi cosim_iss --g2
LIB = os.path.join(OUT, "work")
os.makedirs(OUT, exist_ok=True)


def run(args, **kw):
    return subprocess.run(args, capture_output=True, text=True, cwd=ROOT, **kw)


def programs():
    progs = sorted(glob.glob(os.path.join(ROOT, "fw", "tests", "cpu", "*.s")))
    progs += sorted(glob.glob(os.path.join(ROOT, "fw", "tests", "hazard", "*.s")))
    progs += sorted(glob.glob(os.path.join(ICARUS, "rand*.s")))
    return progs


def tag(src):
    """Tên duy nhất: thư mục + tên file (cp0 có ở cpu/ và hazard/)."""
    return os.path.basename(os.path.dirname(src)) + "_" + os.path.splitext(os.path.basename(src))[0]


def main():
    if not os.path.exists(VLOG):
        sys.exit("FAIL modelsim: khong thay %s" % VLOG)
    if not os.path.isdir(LIB):
        for cmd in ([VLIB, LIB], [VMAP, "work", LIB]):
            r = run(cmd)
            if r.returncode != 0:
                sys.exit("FAIL modelsim vlib/vmap\n" + r.stdout + r.stderr)
    srcs = sorted(glob.glob(os.path.join(ROOT, "src", "*.v"))) + [os.path.join(ROOT, "tb", "cpu_pipe_tb.v")]
    r = run([VLOG, "-work", LIB, "-quiet"] + [s.replace("\\", "/") for s in srcs])
    if r.returncode != 0 or "Error" in r.stdout:
        sys.exit("FAIL modelsim vlog\n" + r.stdout + r.stderr)
    ok = bad = 0
    for src in programs():
        name = os.path.splitext(os.path.basename(src))[0]
        if name.startswith("system"):
            continue
        key = tag(src) if not name.startswith("rand") else name
        hexf = os.path.join(ICARUS, name + ".hex")
        if not os.path.exists(hexf):
            print("SKIP", name, "(khong co hex icarus)"); continue
        nwords = asm.assemble_file(src)["nwords"]
        csv_ms = os.path.join(OUT, key + ".csv")
        dump_ms = os.path.join(OUT, key + ".dump")
        cmd = [VSIM, "-c", "-quiet", "-lib", OUT, "work.cpu_pipe_tb",
               "-GIMEM_FILE=x", "-do", "run -all; quit -f"]
        plus = ["+imem=" + hexf.replace("\\", "/"), "+end=%x" % (4 * nwords), "+dump=" + dump_ms.replace("\\", "/"),
                "+trace=" + csv_ms.replace("\\", "/"), "+maxcyc=100000", "+cediv=1"]
        r = run([VSIM, "-c", "-quiet", "-lib", LIB, "work.cpu_pipe_tb", "-do", "run -all; quit -f", "-sv_seed", "0"] + plus)
        out = r.stdout + r.stderr
        same = all(os.path.exists(os.path.join(ICARUS, name + ext)) for ext in (".csv", ".dump"))
        # tham chiếu: Icarus chạy ngay với cùng plusargs (không dùng file cũ; tên cp0 trùng giữa cpu/ và hazard/)
        ic_csv = os.path.join(OUT, key + ".icarus.csv")
        ic_dump = os.path.join(OUT, key + ".icarus.dump")
        ic = run(["vvp", "-n", VVP, plus[0], plus[1], "+dump=" + ic_dump.replace("\\", "/"),
                  "+trace=" + ic_csv.replace("\\", "/"), "+maxcyc=100000", "+cediv=1"])
        cs_ok = os.path.exists(csv_ms) and os.path.exists(ic_csv) and open(csv_ms, "rb").read() == open(ic_csv, "rb").read()
        dp_ok = os.path.exists(dump_ms) and os.path.exists(ic_dump) and open(dump_ms, "rb").read() == open(ic_dump, "rb").read()
        tb_ok = "PASS cpu_pipe_tb" in out
        verdict = "OK " if (cs_ok and dp_ok and tb_ok and same) else "SAI"
        ok += verdict == "OK "; bad += verdict == "SAI"
        print("%s %-12s csv=%s dump=%s tb=%s" % (verdict, name, cs_ok, dp_ok, tb_ok))
        if verdict == "SAI":
            print("     " + out.strip().replace("\n", "\n     ")[:600])
    print(("PASS" if bad == 0 else "FAIL"), "modelsim_g2", ok, "dung /", ok + bad)
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
