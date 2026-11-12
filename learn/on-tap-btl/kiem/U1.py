"""Assert cho phép tính tay và các dòng code nhắc trong bài U1 (đồng hồ trong 15 phút)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
nguon = (Path(__file__).resolve().parents[1] / "nguon" / "02-code.md").read_text(encoding="utf-8")
u1 = nguon.split("## U1 ·")[1].split("\n## ")[0]


def dong(rel):
    return (ROOT / rel).read_text(encoding="utf-8").splitlines()


tbv, sot, seg, fm, cs = dong("src/timebase.v"), dong("src/soc_top.v"), dong("src/seg7_scan.v"), dong("fw/fmt.s"), dong("tools/cosim_iss.py")


# --- mô hình timebase: len_k = G_N + (s_k >> 16 số học), frac' = s[15:0]
def lens(cal, n, g_n=50000):
    frac, out = 0, []
    for _ in range(n):
        s = frac + cal
        out.append(g_n + (s >> 16))          # Python >> trên số nguyên có dấu = dịch số học
        frac = s & 0xFFFF
    return out


assert lens(163840, 6) == [50002, 50003, 50002, 50003, 50002, 50003]
assert 163840 / 65536 == 2.5 and abs(2.5 / 50000 - 50e-6) < 1e-12
assert abs(50000 * 1e-6 * 65536 - 3276.8) < 1e-9                    # 1 ppm = 3 276,8 đơn vị CAL
assert sum(lens(163840, 2000)) / 2000 == 50002.5
# CAL âm: dịch số học cho ms ngắn hơn, dịch logic (34 bit) cho ms khổng lồ → lỗi của đột biến
neg = lens(-3277, 1)[0]
assert neg == 49999                                                    # -3277 >> 16 = -1
s34 = (-3277) & ((1 << 34) - 1)
assert 50000 + (s34 >> 16) > 50000 + 2 ** 17                          # >> logic: dương rất lớn
# trôi mỗi ngày
assert abs(50e-6 * 86400 - 4.32) < 1e-9

# --- 45 296 789 ms
ms = 45296789
assert ms == (12 * 3600 + 34 * 60 + 56) * 1000 + 789 == 45296789
gs, ms_ = divmod(ms, 1000)
ph, g = divmod(gs, 60)
h, p = divmod(ph, 60)
assert (h, p, g, ms_) == (12, 34, 56, 789) and gs == 45296 and ph == 754
assert 86399999 == (23 * 3600 + 59 * 60 + 59) * 1000 + 999
# 6 lệnh div của fmt_div: 3 (giờ phút giây) + 3 (chữ số)
# --- tải CPU
assert round(224 * 1000 / 50e6 * 100, 2) == 0.45 and round(224 * 1000 / (50e6 / 1526), 2) == 6.84
assert round(224 / (50e6 / 1526) * 100, 2) == 0.68 and round(25000 / (50e6 / 1526) * 100) == 76
assert round(50e6 / 1526) == 32765
# --- quét LED: 8 chữ số × 1 ms = 8 ms → 125 lần mỗi giây
assert 8 * 50000 == 400000 and 50e6 / 400000 == 125 and 50000 / 50e6 == 0.001

# --- khớp dòng code được nhắc
assert "wire signed [33:0] s_now" in tbv[33] and "wire signed [33:0] s_cur" in tbv[34]
assert ">>>" in tbv[35] and "G_N + (s_cur >>> 16)" in tbv[36] and "assign tick = en" in tbv[39]
assert "CAL > 0 → ms dài hơn → đồng hồ chậm lại" in tbv[8]
assert "if (tick) begin" in tbv[49] and "cnt  <= 32'd0" in tbv[50] and "frac <= s_cur[15:0]" in tbv[51]
assert "wire [31:0] rd_soc, rd_irq, rd_rtc, rd_sw, rd_tmr, rd_al, rd_btn, rd_disp, rd_uart, rd_bcd" in sot[52]
assert "wire [31:0] bus_rdata = rd_soc | rd_irq" in sot[53] and sot[53].count("|") == 9
assert "lw    $s0, -256($zero)" in fm[20] and "jal   fmt_nop" in fm[21] and "lw    $s1, -256($zero)" in fm[22]
assert "subu  $s1, $s1, $s0" in fm[23]
assert 0xFFFFFF00 - 2 ** 32 == -256 and 0xFFFFFF8C - 2 ** 32 == -116 and 0xFFFFFF98 - 2 ** 32 == -104
assert sum(1 for x in fm[74:109] if x.strip().startswith("div") or ": div" in x or " div " in x) == 6, "fmt_div 6 div"
assert "localparam G_STEP = (G_SLOT - G_BLANK) / 15" in seg[47]
assert "wire [JW-1:0] js = (c < G_BLANK) ? ((j == 0) ? G_DIGITS - 1 : j - 1'b1) : j;" in seg[82]
assert "assign blink_ph = (bcnt >= 9'd250)" in seg[88] and "wire blink_off = blink_mask[j] && blink_ph" in seg[89]
assert "wire lit = (c >= G_BLANK) && (c < G_BLANK + bright * G_STEP) && !blink_off" in seg[90]
assert 'if G2["on"]:' in cs[95] and "bubbles" in cs[96] and "thieu dong '# bubbles N'" in cs[98]
assert "gaps != int(m.group(1))" in cs[105] and "bong bong: RTL" in cs[106]
# số trong evidence
fmt = (ROOT / "evidence/20261026_fmt.log").read_text(encoding="utf-8").splitlines()
assert fmt[16].split()[-4:] == ["7", "224", "162", "25"] and fmt[17].split()[-4:] == ["7", "224", "135", "25"]
assert "bóng ma" in "\n".join(seg) or "bóng ma" in u1
assert (ROOT / "tb/timebase_tb.v").exists() and (ROOT / "tb/seg7_tb.v").exists() and (ROOT / "tb/display_ctrl_tb.v").exists()
assert len([x for x in u1.splitlines() if x.strip()]) >= 200
print("PASS U1")
