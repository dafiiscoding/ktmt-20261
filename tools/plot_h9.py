"""Hình H9 (plan §8.1): chu kỳ CPU mỗi lần đổi ms → chữ số so với LUT thêm, 4 cách. → report/h9_dse.png

    python tools/plot_h9.py

Số chép từ PLAN_DONG_HO.md §8.1 (chu kỳ: evidence/20261026_fmt.log; LUT: tools/dse_report.py, Yosys).
"""
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# (nhãn, LUT thêm so với SoC G1 3 701 LUT, chu kỳ CPU/lần)
DATA = [
    ("div thuần (6 div)", 0, 224),
    ("bcd tuần tự\n(có sẵn trong lõi, chưa tách LUT)", 0, 162),
    ("bcd tổ hợp", 416, 135),
    ("bộ đếm BCD phần cứng\n(RTC_BCD)", 150, 24),
]
INK, INK2, GRID, BLUE = "#0b0b0b", "#52514e", "#e4e3df", "#2a78d6"


def main():
    fig, ax = plt.subplots(figsize=(7, 4.2), dpi=200)
    fig.patch.set_facecolor("#ffffff")
    for name, lut, cyc in DATA:
        ax.scatter(lut, cyc, s=70, color=BLUE, edgecolor="#ffffff", linewidth=2, zorder=3)
        dx, ha = (12, "left") if lut < 300 else (-12, "right")
        ax.annotate("%s: %d chu kỳ" % (name, cyc), (lut, cyc), xytext=(dx, 0), textcoords="offset points",
                    ha=ha, va="center", fontsize=8.5, color=INK)
    ax.set_xlim(-40, 500)
    ax.set_ylim(0, 250)
    ax.set_xlabel("LUT thêm so với SoC G1 (Yosys, 7-series)", color=INK2, fontsize=9)
    ax.set_ylabel("Chu kỳ CPU mỗi lần cập nhật", color=INK2, fontsize=9)
    ax.set_title("H9. Đổi ms → 8 chữ số: chu kỳ CPU đổi lấy phần cứng", loc="left", color=INK, fontsize=11)
    ax.grid(color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color(GRID)
    ax.tick_params(colors=INK2, labelsize=8)
    fig.text(0.01, 0.01, "Góc dưới-trái là tốt nhất. Nguồn: PLAN §8.1, evidence/20261026_fmt.log, tools/dse_report.py",
             color=INK2, fontsize=7)
    fig.tight_layout(rect=(0, 0.03, 1, 1))
    out = os.path.join(ROOT, "report", "h9_dse.png")
    fig.savefig(out)
    print(out)


if __name__ == "__main__":
    main()
