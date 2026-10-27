"""CPI từ trace RTL (isa-spec §8) + tách chu kỳ mất theo nguyên nhân (pipeline-policy §4–6). Báo cáo mục 3.3.

    python tools/cpi.py work/cpi/g2/*.csv           # bảng Markdown ra stdout
    python tools/cpi.py --sum work/cpi/g1/*.csv     # thêm dòng tổng

Mỗi dòng trace là 1 lệnh retire; cột 1 = chu kỳ hệ thống lúc retire. Khoảng cách giữa 2 lần retire, chia cho
khoảng nhỏ nhất trong file (= 1 chu kỳ CPU: G2 = D, G1 = 2·D vì 2 pha), cho số chu kỳ CPU của lệnh đó.
Chương trình đổi CPU_CLK_DIV giữa chừng (fw/fmt.s, fw/tests/soc/bus.s, irq_lat.s) làm sai phép chia → đừng đưa vào.
Phần dư trên 1 được gán cho nguyên nhân, theo thứ tự ưu tiên:
  ngắt     lệnh ngay trước hoặc chính nó là dòng INTERRUPT
  busy     chính nó là div / bcd (freeze ở EX, §6)
  nhánh    lệnh trước là beq/bne/j/jal/jr/eret và (PC của nó ≠ PC trước + 4, hoặc mất đúng 2 = flush khi đích
           trùng PC + 4, vd. `j` tới lệnh kế) (§5)
  load-use lệnh trước là lw có đích ≠ 0 mà nó đọc (§4)
  khác     không khớp gì — phải bằng 0 ở G2; ≠ 0 nghĩa là có kiểu stall chưa hiểu
"""
import argparse
import os
import sys


def regs_read(w):
    """→ tập thanh ghi lệnh w đọc (uses_rs / uses_rt theo control-table)."""
    op, rs, rt, fn = w >> 26, (w >> 21) & 31, (w >> 16) & 31, w & 63
    if op == 0:
        if fn in (0x00, 0x03):                      # sll, srl
            return {rt}
        if fn in (0x10, 0x12):                      # mfhi, mflo
            return set()
        if fn == 0x08:                              # jr
            return {rs}
        return {rs, rt}                             # addu subu and or xor slt div
    if op == 0x1C:
        return {rs, rt} if fn == 0x02 else {rs}     # mul / bcd
    if op in (0x09, 0x0A, 0x0C, 0x0D, 0x23):        # addiu slti andi ori lw
        return {rs}
    if op in (0x04, 0x05, 0x2B):                    # beq bne sw
        return {rs, rt}
    if op == 0x10 and rs == 0x04:                   # mtc0
        return {rt}
    return set()                                    # lui j jal mfc0 eret


def is_ctrl(w):
    op = w >> 26
    return op in (0x02, 0x03, 0x04, 0x05) or (op == 0 and w & 63 == 0x08) or w == 0x42000018


def is_busy(w):
    return (w >> 26 == 0 and w & 63 == 0x1A) or (w >> 26 == 0x1C and w & 63 == 0x10)


def analyse(path):
    rows = []
    for ln in open(path):
        p = ln.strip().split(",")
        if len(p) == 8 and p[0] != "cycle":
            rows.append((int(p[0]), int(p[1], 16), p[2]))
    gaps = [b[0] - a[0] for a, b in zip(rows, rows[1:])]
    if not gaps:
        return None
    base = min(g for g in gaps if g > 0)
    out = {"n": sum(1 for r in rows if r[2] != "INTERRUPT"), "cyc": (rows[-1][0] - rows[0][0]) // base + 1,
           "ngắt": 0, "busy": 0, "nhánh": 0, "load-use": 0, "khác": 0}
    for i in range(1, len(rows)):
        extra = gaps[i - 1] // base - 1
        if extra <= 0:
            continue
        (_, pc0, w0), (_, pc1, w1) = rows[i - 1], rows[i]
        if "INTERRUPT" in (w0, w1):
            k = "ngắt"
        elif is_busy(int(w1, 16)):
            k = "busy"
        elif is_ctrl(int(w0, 16)) and (pc1 != (pc0 + 4) & 0xFFFFFFFF or extra == 2):
            k = "nhánh"
        elif int(w0, 16) >> 26 == 0x23 and (int(w0, 16) >> 16) & 31 and \
                (int(w0, 16) >> 16) & 31 in regs_read(int(w1, 16)):
            k = "load-use"
        else:
            k = "khác"
        out[k] += extra
    return out


KEYS = ["load-use", "nhánh", "busy", "ngắt", "khác"]


def main(argv):
    sys.stdout.reconfigure(encoding="utf-8")   # console Windows cp1252 không in được tiếng Việt
    ap = argparse.ArgumentParser()
    ap.add_argument("csv", nargs="+")
    ap.add_argument("--sum", action="store_true", help="thêm dòng tổng")
    a = ap.parse_args(argv)
    print("| Chương trình | Lệnh | Chu kỳ CPU | CPI | " + " | ".join(KEYS) + " |")
    print("|---|---|---|---|" + "---|" * len(KEYS))
    tot = {k: 0 for k in ["n", "cyc"] + KEYS}
    for f in a.csv:
        if f.endswith(".iss.csv"):
            continue
        r = analyse(f)
        if r is None:
            continue
        for k in tot:
            tot[k] += r[k]
        print("| %s | %d | %d | %.3f | %s |" % (os.path.basename(f)[:-4], r["n"], r["cyc"], r["cyc"] / max(r["n"], 1),
                                               " | ".join(str(r[k]) for k in KEYS)))
    if a.sum:
        print("| **tổng** | %d | %d | %.3f | %s |" % (tot["n"], tot["cyc"], tot["cyc"] / max(tot["n"], 1),
                                                     " | ".join(str(tot[k]) for k in KEYS)))


if __name__ == "__main__":
    assert regs_read(0x8D090000) == {8}                       # lw $t1, 0($t0): đọc rs, không đọc rt
    assert regs_read(0x01095021) == {8, 9}                    # addu $t2, $t0, $t1
    assert regs_read(0x3C080001) == set()                     # lui
    assert is_ctrl(0x0800031E) and is_ctrl(0x03E00008) and is_ctrl(0x42000018) and not is_ctrl(0x8C08FF50)
    assert is_busy(0x0109001A) and not is_busy(0x71095002)    # div / mul
    main(sys.argv[1:])
