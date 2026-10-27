"""Bảng tài nguyên cho plan §8.1–8.2: Yosys synth_xilinx từng khối → LUT / FF / BRAM / LUTRAM / DSP / CARRY4.

Chạy từ gốc project (sau `source tools/env.sh`):
    python tools/dse_report.py            # mọi khối → bảng Markdown ra stdout, log ở work/dse_<khối>.log
    python tools/dse_report.py soc_g1 vga # vài khối

Luồng: synth_xilinx tới trước map_luts, rồi `abc -lut 6` (ABC cổ điển) thay abc9 — abc9 bị assertion trên bản Yosys
trong .toolchain. Số là ước lượng Yosys (`inference`), không phải Vivado; không có Fmax.
IMEM/DMEM nạp work/main.hex (dịch fw/main.s) để ROM không bị tối ưu thành 0.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sorted("src/" + f for f in os.listdir(os.path.join(ROOT, "src")) if f.endswith(".v"))
HEX = "work/main.hex"
IMEM = '-set IMEM_FILE "%s" -set G_IMEM_AW 11' % HEX

# (tên, mô tả, top, chparam, define)
BLOCKS = [
    ("soc_g1", "SoC đầy đủ, lõi G1", "soc_top", '-set IMEM_FILE "%s"' % HEX, ""),
    ("soc_g1_bcdc", "SoC G1 + `bcd` tổ hợp (§8.1)", "soc_top", '-set IMEM_FILE "%s" -set G_BCD_COMB 1' % HEX, ""),
    ("soc_g1_rtcb", "SoC G1 + `RTC_BCD` (§8.1)", "soc_top", '-set IMEM_FILE "%s" -set G_BCD_RTC 1' % HEX, ""),
    ("soc_g2", "SoC đầy đủ, lõi G2", "soc_top", '-set IMEM_FILE "%s"' % HEX, "-DG2"),
    ("cpu_g1", "lõi G1 (gồm CP0 + ngắt, IMEM, DMEM)", "cpu_g1", IMEM, ""),
    ("cpu_g2", "lõi G2 pipeline (gồm hazard, ngắt)", "cpu_pipe", IMEM, ""),
    ("irq", "bộ điều khiển ngắt", "irq_ctrl", "", ""),
    ("display", "display_ctrl (quét LED + VGA)", "display_ctrl", "", ""),
    ("seg7", "quét 7 đoạn (seg7_scan + char_rom)", "seg7_scan", "", ""),
    ("vga", "VGA đuổi tia", "vga_digits", "", ""),
    ("timebase", "timebase + CAL", "timebase", "", ""),
    ("rtc", "RTC", "rtc", "", ""),
    ("stopwatch", "stopwatch (capture)", "stopwatch", "", ""),
    ("cdtimer", "TIMER đếm ngược", "cdtimer", "", ""),
    ("alarm", "alarm", "alarm", "", ""),
    ("uart", "UART (FIFO 64 byte)", "uart", "", ""),
    ("muldiv", "mul + div tuần tự", "muldiv", "", ""),
    ("alu", "ALU", "alu", "", ""),
]

COLS = [("LUT", r"LUT[1-6]"), ("FF", r"FD[A-Z]*"), ("BRAM36", r"RAMB36E1"), ("BRAM18", r"RAMB18E1"),
        ("LUTRAM", r"RAM(32|64|128|256)[MXS]\w*"), ("DSP", r"DSP48E1"), ("CARRY4", r"CARRY4")]


def synth(name, top, params, define):
    log = "work/dse_%s.log" % name
    cp = "chparam %s %s; " % (params, top) if params else ""
    script = ("read_verilog -DSYNTHESIS %s %s; %s"
              "synth_xilinx -top %s -flatten -run :map_luts; opt_expr -mux_undef -noclkinv; abc -lut 6; clean; "
              "techmap -map +/xilinx/lut_map.v -map +/xilinx/cells_map.v -D LUT_WIDTH=6; xilinx_dffopt; "
              "opt_lut_ins -tech xilinx; clean; tee -o %s.stat stat" % (define, " ".join(SRC), cp, top, log))
    r = subprocess.run(["yosys", "-q", "-l", log, "-p", script], cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("yosys loi o khoi %s, xem %s" % (name, log))
    return count(open(os.path.join(ROOT, log + ".stat"), encoding="utf-8", errors="replace").read())


def count(stat):
    """Đọc bảng cell của `stat` (lần cuối, top đã flatten) → {cột: số}."""
    cells = re.findall(r"^\s+(\d+)\s+(\S+)\s*$", stat, re.M)
    out = {c: 0 for c, _ in COLS}
    seen = set()
    for n, cell in cells:
        if cell in seen:            # stat in 2 lần (module + tổng): chỉ lấy lần đầu
            continue
        seen.add(cell)
        for c, pat in COLS:
            if re.fullmatch(pat, cell):
                out[c] += int(n)
    return out


def main(argv):
    sys.stdout.reconfigure(encoding="utf-8")   # console Windows cp1252 không in được tiếng Việt
    names = argv or [b[0] for b in BLOCKS]
    unknown = set(names) - {b[0] for b in BLOCKS}
    if unknown:
        raise SystemExit("khoi khong co: %s" % ", ".join(sorted(unknown)))
    if not os.path.exists(os.path.join(ROOT, HEX)):
        subprocess.run([sys.executable, "tools/fw_build.py", "fw/main.s", HEX], cwd=ROOT, check=True)
    print("| Khối | Mô tả | " + " | ".join(c for c, _ in COLS) + " |")
    print("|---|---|" + "---|" * len(COLS))
    for name, desc, top, params, define in BLOCKS:
        if name in names:
            v = synth(name, top, params, define)
            print("| %s | %s | %s |" % (name, desc, " | ".join(str(v[c]) for c, _ in COLS)), flush=True)


if __name__ == "__main__":
    assert count("   3 LUT6\n   2 LUT2\n   5 FDRE\n   1 FDSE\n   1 RAM32M\n   3 LUT6\n") == \
        {"LUT": 5, "FF": 6, "BRAM36": 0, "BRAM18": 0, "LUTRAM": 1, "DSP": 0, "CARRY4": 0}
    main(sys.argv[1:])
