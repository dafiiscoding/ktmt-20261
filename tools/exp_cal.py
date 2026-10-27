"""Thí nghiệm E1′ (báo cáo 2.4, chủ TV5): thạch anh lệch p ppm → firmware tính CAL → ppm còn lại sau hiệu chỉnh.

    python tools/exp_cal.py            # bảng Markdown ra stdout (cần work/exp_cal_tb.vvp: bash tools/run_unit.sh exp_cal)

Mỗi ca (p, I):
  1. Thạch anh nhanh p ppm → sau I ms thật, chip đếm dư D = round(I·p/10⁶) ms (PC chỉ thấy số nguyên ms).
  2. Firmware thật (fw/main.s chạy trên ISS, helper sync_cal của test_iss) nhận 2 câu $T cách nhau I ms → CAL.
  3. RTL timebase G_N = 50 000 chạy K ms với CAL đó (tb/exp_cal_tb.v +e1) → tổng C chu kỳ.
  4. 1 ms thật = 50 000·(1 + p·10⁻⁶) chu kỳ; 1 ms chip = C / K → lệch còn lại = (ms thật / ms chip − 1)·10⁶ ppm.
"""
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from test_iss import sync_cal  # noqa: E402

K = 1000                                            # ms mô phỏng; sai số đo ≤ 1 chu kỳ / (K·50 000) = 0,02 ppm
T1 = 5 * 86400000 + 3600000                         # ngày 5, 01:00 (tránh qua ngày không cần)
CASES = [(p, 3600000) for p in (-199, -80, -20, 20, 80, 150, 250)] + [(20, 600000), (20, 86400000), (3, 600000)]


def rtl_cycles(cal):
    vvp = os.path.join(ROOT, "work", "exp_cal_tb.vvp")
    out = subprocess.run(["vvp", "-n", vvp, "+e1", "+cal=%d" % cal, "+k=%d" % K],
                         cwd=ROOT, capture_output=True, text=True, check=True).stdout
    line = [ln for ln in out.splitlines() if ln.startswith("E1 ")][0]
    return int(line.split("chu_ky=")[1])


def main():
    sys.stdout.reconfigure(encoding="utf-8")       # console Windows cp1252 không in được tiếng Việt
    rows = []
    for p, i in CASES:
        d = round(i * p / 1e6)
        rows.append((p, i, d, sync_cal(T1, T1 + i, d)))
    with ThreadPoolExecutor(max_workers=os.cpu_count()) as ex:
        cyc = list(ex.map(rtl_cycles, [r[3] for r in rows]))
    print("| Lệch thạch anh (ppm) | I (phút) | D (ms) | CAL firmware | C sau %d ms (RTL) | Lệch sau CAL (ppm) |" % K)
    print("|---|---|---|---|---|---|")
    for (p, i, d, cal), c in zip(rows, cyc):
        assert c == K * 50000 + (K * cal >> 16), (cal, c)     # khớp công thức timer-spec §2 (TB-3)
        after = (50000 * (1 + p * 1e-6) / (c / K) - 1) * 1e6
        print("| %+d | %d | %+d | %d | %d | %+.3f |" % (p, i // 60000, d, cal, c, after))


if __name__ == "__main__":
    main()
