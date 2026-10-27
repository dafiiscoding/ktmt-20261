"""cmp_trace.py — so 2 trace isa-spec §8 (gói B3 · chủ: TV2). Bản đầu 03/10/2026 do Claude viết (KE-HOACH §4b).

  python tools/cmp_trace.py rtl.csv iss.csv                       # so 2 file có sẵn
  python tools/cmp_trace.py rtl.csv --replay prog.hex [--poke 0x7e0=1 …]
                                                                  # chạy ISS replay MMIO theo rtl.csv rồi so

Bỏ cột `cycle`. Dừng ở **dòng đầu tiên lệch**: in số dòng (đếm từ 1), 2 dòng và tên các cột lệch.
Một file dài hơn → báo "thừa" kèm dòng đầu tiên thừa. Dòng cuối: `PASS cmp_trace <n dòng>` hoặc `FAIL cmp_trace …`; mã thoát 0/1.
"""
import os
import sys

COLS = ("cycle", "pc", "instr", "rd", "value", "mop", "maddr", "mdata")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iss  # noqa: E402


def _norm(p):
    """Chuẩn hóa để so: bỏ cycle, hex chữ thường (RTL `%h` có thể in x/z → giữ nguyên để lộ ra)."""
    return [x.lower() for x in p[1:]]


def compare(a, b, na="A", nb="B"):
    """a, b: danh sách dòng đã tách cột. → (ok, danh sách dòng báo cáo)."""
    for k in range(min(len(a), len(b))):
        x, y = _norm(a[k]), _norm(b[k])
        if x != y:
            cols = [COLS[i + 1] for i in range(7) if x[i] != y[i]]
            return False, ["lech o dong %d, cot: %s" % (k + 1, ", ".join(cols)),
                           "  %s: %s" % (na, ",".join(a[k])), "  %s: %s" % (nb, ",".join(b[k]))]
    if len(a) != len(b):
        longer, nl, other = (a, na, nb) if len(a) > len(b) else (b, nb, na)
        k = min(len(a), len(b))
        return False, ["%s thua %d dong so voi %s (tu dong %d)" % (nl, len(longer) - k, other, k + 1),
                       "  %s: %s" % (nl, ",".join(longer[k]))]
    return True, []


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description="So 2 trace isa-spec §8")
    ap.add_argument("a", help="trace thứ nhất (RTL)")
    ap.add_argument("b", nargs="?", help="trace thứ hai (ISS)")
    ap.add_argument("--replay", help="chương trình .hex/.s: chạy ISS replay MMIO theo trace a thay cho b")
    ap.add_argument("--aw", type=int, default=10)
    ap.add_argument("--poke", action="append", default=[], help="addr=giá trị: DMEM ban đầu của ISS (replay)")
    ap.add_argument("--out", help="replay: ghi trace ISS ra file này")
    ap.add_argument("--na", default="RTL")
    ap.add_argument("--nb", default="ISS")
    a = ap.parse_args(argv)
    A = iss.read_trace(a.a)
    msgs = []
    if a.replay:
        imem, dmem = iss.load_prog(a.replay, a.aw)
        cpu = iss.ISS(imem, dmem, a.aw)
        for p in a.poke:
            ad, v = p.split("=")
            cpu.dmem[(int(ad, 0) >> 2) & 1023] = int(v, 0) & iss.M32
        recs, probs = iss.replay(cpu, A)
        B = [iss.fmt(r).split(",") for r in recs]
        if a.out:
            with open(a.out, "w", newline="\n") as f:
                f.write("".join(",".join(r) + "\n" for r in B))
        msgs += ["loi replay: " + p for p in probs[:10]]
        msgs += ["ASSERT ISS lenh la: pc=%08x instr=%08x" % u for u in cpu.unknown[:10]]
    elif a.b:
        B = iss.read_trace(a.b)
    else:
        ap.error("can file b hoac --replay")
    ok, rep = compare(A, B, a.na, a.nb)
    for m in msgs + rep:
        print(m)
    if ok and not msgs:
        print("PASS cmp_trace %d" % len(A))
        return 0
    print("FAIL cmp_trace %s" % (rep[0] if rep else msgs[0]))
    return 1


if __name__ == "__main__":
    sys.exit(main())
