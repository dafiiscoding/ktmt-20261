"""Màn hình ảo (gói D7): đọc log của tb/screen_dump.v → in ra terminal hoặc vẽ GIF/PNG.

  python tools/screen.py work/screen_clock.log              # mỗi ảnh 1 dòng chữ:  t=  1234 ms |   23.59.58
  python tools/screen.py work/screen_clock.log --big        # vẽ 7 đoạn to bằng ký tự
  python tools/screen.py work/screen_clock.log --gif work/clock.gif [--speed 1]
  python tools/screen.py work/screen_clock.log --png work/clock.png   # ảnh cuối

Giải mã đoạn → ký tự theo tb/vectors/seg7.txt (5 và S cùng mẫu → in '5').
"""
import argparse
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHARS = "0123456789AbCdEFHLnoPrStU-"
# ảnh tồn tại < TEAR_MS là "xé hình": firmware đang ghi dở 8 ô thì bộ quét chụp đúng 1 vòng
# (mô phỏng: 1 vòng = 40 × 8 chu kỳ = 6,4 ms theo G_N = 50; chip thật 8 ms, mắt không thấy).
# Ảnh thật đổi chậm nhất 250 ms (nháy) nên ngưỡng 10 ms tách được. Chế độ chữ đánh dấu, GIF/PNG bỏ qua.
TEAR_MS = 10


def seg_table():
    t = {}
    with open(os.path.join(ROOT, "tb", "vectors", "seg7.txt"), encoding="utf-8") as f:
        for ln in f:
            if ln.startswith("#") or not ln.strip():
                continue
            code, pat = (int(x, 16) for x in ln.split()[:2])
            if code < len(CHARS) and pat not in t:
                t[pat] = CHARS[code]
    t[0] = " "
    return t


def load(path):
    frames = []
    with open(path, encoding="utf-8") as f:
        for ln in f:
            if ln.startswith("#") or not ln.strip():
                continue
            p = ln.split()
            t, segs, lit = int(p[0]), [int(x, 16) for x in p[1:-1]], int(p[-1], 16)
            n = len(segs)
            # segs[0] = S7 (trái) … segs[-1] = S0 (phải); chữ số tắt (LIT = 0) coi như trống
            segs = [s if (lit >> (n - 1 - k)) & 1 else 0 for k, s in enumerate(segs)]
            frames.append((t, segs))
    return frames


def text(segs, tab):
    out = ""
    for s in segs:
        out += tab.get(s & 0x7F, "?") + ("." if s & 0x80 else "")
    return out


def big(segs):
    rows = ["", "", ""]
    for s in segs:
        a, b, c, d, e, f, g = ((s >> i) & 1 for i in range(7))
        rows[0] += " " + ("_" if a else " ") + "  "
        rows[1] += ("|" if f else " ") + ("_" if g else " ") + ("|" if b else " ") + " "
        rows[2] += ("|" if e else " ") + ("_" if d else " ") + ("|" if c else " ") + ("." if s & 0x80 else " ")
    return "\n".join(rows)


def draw(segs, scale=6):
    from PIL import Image, ImageDraw
    W, H, T = 10 * scale, 18 * scale, 2 * scale     # kích thước 1 chữ số, độ dày đoạn
    pad = 3 * scale
    img = Image.new("RGB", (pad * 2 + len(segs) * (W + pad), H + pad * 2), (12, 12, 12))
    d = ImageDraw.Draw(img)
    on, off = (255, 40, 20), (45, 20, 18)
    for k, s in enumerate(segs):
        x0, y0 = pad + k * (W + pad), pad
        boxes = [  # a b c d e f g
            (x0 + T, y0, x0 + W - T, y0 + T),
            (x0 + W - T, y0 + T, x0 + W, y0 + H // 2),
            (x0 + W - T, y0 + H // 2, x0 + W, y0 + H - T),
            (x0 + T, y0 + H - T, x0 + W - T, y0 + H),
            (x0, y0 + H // 2, x0 + T, y0 + H - T),
            (x0, y0 + T, x0 + T, y0 + H // 2),
            (x0 + T, y0 + H // 2 - T // 2, x0 + W - T, y0 + H // 2 + T // 2),
        ]
        for i, bx in enumerate(boxes):
            d.rectangle(bx, fill=on if (s >> i) & 1 else off)
        d.ellipse((x0 + W + T // 2, y0 + H - T, x0 + W + T // 2 + T, y0 + H), fill=on if s & 0x80 else off)
    return img


def main():
    sys.stdout.reconfigure(encoding="utf-8")   # console Windows cp1252 không in được help tiếng Việt
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--big", action="store_true")
    ap.add_argument("--gif")
    ap.add_argument("--png")
    ap.add_argument("--speed", type=float, default=1.0, help="1 = thời gian thật mô phỏng")
    a = ap.parse_args()
    frames = load(a.log)
    if not frames:
        sys.exit("log rong")
    tab = seg_table()
    ends = [t for t, _ in frames[1:]] + [None]
    torn = [e is not None and e - t < TEAR_MS for (t, _), e in zip(frames, ends)]
    if not (a.gif or a.png):
        for (t, segs), x in zip(frames, torn):
            if a.big:
                print(f"t = {t} ms\n{big(segs)}\n")
            else:
                print(f"t={t:>7} ms | {text(segs, tab):<12}" + ("  <- xe hinh (ghi do, 1 vong quet)" if x else ""))
    frames = [f for f, x in zip(frames, torn) if not x]
    if a.png:
        draw(frames[-1][1]).save(a.png)
        print("da ghi", a.png)
    if a.gif:
        imgs = [draw(s) for _, s in frames]
        times = [t for t, _ in frames] + [frames[-1][0] + 1000]
        durs = [max(20, int((times[k + 1] - times[k]) / a.speed)) for k in range(len(frames))]
        imgs[0].save(a.gif, save_all=True, append_images=imgs[1:], duration=durs, loop=0)
        print(f"da ghi {a.gif}: {len(imgs)} anh, {sum(durs) / 1000:.1f} s")


if __name__ == "__main__":
    main()
