"""Đối chiếu độc lập golden alu/mul/div với MARS 4.5 (goi-viec.md §0.2).

Lấy 50 ca mỗi file (alu: bước 83 dòng để phủ đủ 8 mã ctl; mul: bước 16; div: bỏ chia 0,
gồm cả các ca dấu đặc biệt), sinh 1 chương trình MIPS in kết quả bằng syscall 34 (hex),
chạy `java -jar .toolchain/Mars4_5.jar nc`, so từng dòng với golden.
Chạy từ thư mục gốc project:  python tools/mars_crosscheck.py
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VEC = os.path.join(ROOT, "tb", "vectors")
MARS = os.path.join(ROOT, ".toolchain", "Mars4_5.jar")
WORK = os.path.join(ROOT, "work")

ALU_ASM = {0: "addu", 1: "subu", 2: "and", 3: "or", 4: "xor", 5: "slt", 6: "sll", 7: "sra"}


def rows(name):
    with open(os.path.join(VEC, name), encoding="utf-8") as f:
        return [ln.split() for ln in f if ln.strip() and not ln.startswith("#")]


cases = []  # (mô tả, [lệnh asm], [golden hex ...]) — mỗi golden là 1 thanh ghi in ra

alu = rows("alu.txt")
for r in alu[0:83 * 50:83]:
    ctl, a, b, sh, y = int(r[0], 16), r[1], r[2], int(r[3], 16), r[4]
    op = ALU_ASM[ctl]
    body = f"{op} $t2, $t1, {sh}" if ctl in (6, 7) else f"{op} $t2, $t0, $t1"
    cases.append((f"alu {op} {a} {b} sh={sh}", [f"li $t0, 0x{a}", f"li $t1, 0x{b}", body], [y]))

mul = rows("mul.txt")
for r in mul[0:16 * 50:16]:
    cases.append((f"mul {r[0]} {r[1]}", [f"li $t0, 0x{r[0]}", f"li $t1, 0x{r[1]}", "mul $t2, $t0, $t1"], [r[2]]))

div = [r for r in rows("div.txt") if int(r[1], 16) != 0]
special = div[-5:]                       # -7/2, 7/-2, -7/-2, 86399999/1000, 0x80000000/-1
pick = div[0:len(div) - 5:17][:45] + special
for r in pick:
    cases.append((f"div {r[0]} {r[1]}", [f"li $t0, 0x{r[0]}", f"li $t1, 0x{r[1]}", "div $t0, $t1", "mflo $t2", "mfhi $t3"],
                  [r[2], r[3]]))

lines = [".text"]
for _, body, gold in cases:
    lines += body
    for reg in ("$t2", "$t3")[:len(gold)]:
        lines += [f"move $a0, {reg}", "li $v0, 34", "syscall", "li $a0, 10", "li $v0, 11", "syscall"]
lines += ["li $v0, 10", "syscall"]

os.makedirs(WORK, exist_ok=True)
asm = os.path.join(WORK, "mars_crosscheck.asm")
with open(asm, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

out = subprocess.run(["java", "-jar", MARS, "nc", asm], capture_output=True, text=True, check=True).stdout.split()
expect = [g.upper() for _, _, gold in cases for g in gold]
got = [x[2:].upper() for x in out]      # "0x0000abcd" → "0000ABCD"

nerr, k = 0, 0
counts = {"alu": 0, "mul": 0, "div": 0}
for desc, _, gold in cases:
    g = got[k:k + len(gold)]
    e = [x.upper() for x in gold]
    k += len(gold)
    counts[desc[:3]] += 1
    if g != e:
        nerr += 1
        print(f"LECH {desc}: MARS {g} golden {e}")
if len(got) != len(expect):
    nerr += 1
    print(f"LECH so dong MARS {len(got)} != {len(expect)}")
print(f"ca: alu {counts['alu']}, mul {counts['mul']}, div {counts['div']} (bo chia 0)")
print(f"PASS mars_crosscheck {len(cases)}" if nerr == 0 else f"FAIL mars_crosscheck {nerr} ca lech / {len(cases)}")
sys.exit(1 if nerr else 0)
