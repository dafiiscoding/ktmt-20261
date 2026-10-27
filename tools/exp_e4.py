"""Vẽ dạng sóng E4′ (bóng ma LED) từ CSV của tb/exp_e4_tb.v.

    vvp -n work/exp_e4_tb.vvp +csv=work/exp_e4_wave.csv     # sau bash tools/run_unit.sh exp_e4
    python tools/exp_e4.py work/exp_e4_wave.csv report/h_e4_bongma.png

2 khung trên/dưới: G_BLANK = 0 và G_BLANK = 100 (G_SLOT = 3 125, T_OFF = 50), quanh ranh giới khe 0 → 1.
Vùng tô = anode 0 vật lý còn dẫn trong khi chân đoạn đã mang mẫu chữ số 2 (bóng ma).
"""
import csv
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

INK, MUTED, HL = "#1f2328", "#8c959f", "#2a78d6"


def main(src, dst):
    rows = list(csv.DictReader(open(src)))
    fig, axes = plt.subplots(2, 1, figsize=(9, 5.2), sharex=True)
    for ax, blank in zip(axes, ("0", "1")):
        r = [x for x in rows if x["blank"] == blank]
        t = [int(x["cyc"]) - 3125 for x in r]                       # 0 = đầu khe mới (c = 0)
        traces = [("an[0] (RTL)", "an0", MUTED), ("anode 0 vật lý", "vl0", INK), ("an[1] (RTL)", "an1", MUTED)]
        for k, (name, col, color) in enumerate(traces):
            y0 = 2 * (len(traces) - 1 - k)
            ax.step(t, [y0 + 1.2 * int(x[col]) for x in r], where="post", color=color, lw=2)
            ax.text(t[0] - 3, y0 + 0.5, name, ha="right", va="center", fontsize=9, color=INK)
        g = [int(x["ghost0"]) for x in r]
        ax.fill_between(t, -0.4, 5.6, where=g, step="post", color=HL, alpha=0.25, lw=0)
        n = sum(g)
        ax.set_title("G_BLANK = %s: bóng ma %d chu kỳ (%.1f µs) sau mỗi lần đổi khe" % (
            "0" if blank == "0" else "100", n, n / 50), fontsize=10, loc="left", color=INK)
        ax.axvline(0, color=MUTED, lw=1, ls=":")
        ax.set_yticks([])
        for s in ("top", "right", "left"):
            ax.spines[s].set_visible(False)
    axes[-1].set_xlabel("chu kỳ 50 MHz tính từ đầu khe mới; chân đoạn đổi ở c = G_BLANK (G_SLOT = 3 125, T_OFF = 50)")
    fig.tight_layout()
    fig.subplots_adjust(left=0.17)
    fig.savefig(dst, dpi=150)
    print("da ghi", dst)


if __name__ == "__main__":
    main(*sys.argv[1:3])
