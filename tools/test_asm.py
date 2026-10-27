"""test_asm.py — test gói B1 (goi-viec.md B1-1…B1-4). Chạy: python -m pytest -q tools/test_asm.py"""
import glob
import os
import re
import shutil
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import asm  # noqa: E402


def words_by_line(r):
    """lst → {dòng nguồn: [word, …]} (lệnh giả 2 word, .word nhiều giá trị)."""
    out = {}
    for ln in r["lst"]:
        p = ln.split()
        out.setdefault(int(p[3]), []).append(int(p[2], 16))
    return out


def errors_of(text, **kw):
    with pytest.raises(asm.AsmError) as e:
        asm.assemble(text, "x.s", **kw)
    return e.value.errors


# ---------------------------------------------------------------- B1-1: đủ 28 lệnh, so với mã tính tay
def test_b1_1_all28_hand_encoded():
    path = os.path.join(ROOT, "fw", "tests", "asm", "all28.s")
    r = asm.assemble_file(path)
    got = words_by_line(r)
    lines = open(path, encoding="utf-8").read().splitlines()
    n, mnem = 0, set()
    for i, ln in enumerate(lines, 1):
        m = re.search(r"#\s*=\s*((?:0x[0-9a-f]{8}\s*)+)", ln)
        if not m:
            continue
        exp = [int(x, 16) for x in m.group(1).split()]
        assert got.get(i) == exp, "dong %d: %s → %s, tay %s" % (i, ln.split("#")[0].strip(),
                                                                ["%08x" % w for w in got.get(i, [])],
                                                                ["%08x" % w for w in exp])
        n += 1
        mnem.add(re.sub(r"^\w+:\s*", "", ln.strip()).split()[0])
    assert asm.INSTR <= mnem, "thieu lenh: %s" % (asm.INSTR - mnem)
    assert asm.PSEUDO <= mnem
    assert n == 37                      # 28 lệnh + 7 dòng lệnh giả + .word + thanh ghi số


# ---------------------------------------------------------------- B1-2: giống MARS từng byte
MARS = os.path.join(ROOT, ".toolchain", "Mars4_5.jar")
need_mars = pytest.mark.skipif(not (os.path.exists(MARS) and shutil.which("java")), reason="khong co MARS/java")

LI_EDGE = """
        li    $t0, 0
        li    $t0, 1
        li    $t0, -1
        li    $t0, 32767
        li    $t0, 32768
        li    $t0, 65535
        li    $t0, 65536
        li    $t0, -32768
        li    $t0, -32769
        li    $t0, 0x7fffffff
        li    $t0, 0x80000000
        li    $t0, 0xffffffff
        li    $t0, 0xffff0000
        li    $t0, 0xffff8000
        li    $t0, 0x00010000
        move  $s0, $t9
        nop
        sll   $0, $0, 0
"""


def mars_words(src, tmp, mc="CompactTextAtZero"):
    import cosim_mars
    hexf = os.path.join(tmp, os.path.basename(src)[:-2] + ".mars.hex")
    cosim_mars.mars_assemble(src, hexf, mc)
    return [int(x, 16) for x in open(hexf).read().split()]


@need_mars
@pytest.mark.parametrize("src", sorted(glob.glob(os.path.join(ROOT, "fw", "**", "*.s"), recursive=True)
                                       + ["LI_EDGE"]))
def test_b1_2_same_as_mars(src, tmp_path):
    if os.path.basename(src) == "all28.s":
        pytest.skip("all28.s co la/b (khac MARS co chu dich, isa-spec §7) — da so tay o B1-1")
    if src == "LI_EDGE":
        src = str(tmp_path / "li_edge.s")
        open(src, "w").write(LI_EDGE)
    r = asm.assemble_file(src, 11)                          # main.s > 1024 lệnh (soc_top G_IMEM_AW = 11)
    m = mars_words(src, str(tmp_path), "Default" if r["nwords"] > 1024 else "CompactTextAtZero")
    assert r["nwords"] == len(m)
    diff = [i for i in range(len(m)) if r["imem"][i] != m[i]]
    assert not diff, ["%03x: asm %08x MARS %08x" % (4 * i, r["imem"][i], m[i]) for i in diff[:5]]
    assert not any(r["imem"][len(m):]), "phan sau chuong trinh phai la 0"


# ---------------------------------------------------------------- B1-3: mọi lỗi §7 báo đúng dòng, không sinh file
ERR_CASES = [
    # (mã nguồn, dòng lỗi, mẩu thông báo)
    ("a:  nop\na:  nop\n", 2, "nhan trung"),
    ("    beq $t0, $t1, khong_co\n", 1, "nhan khong co"),
    ("    j   khong_co\n", 1, "nhan khong co"),
    ("    la  $t0, khong_co\n", 1, "nhan khong co"),
    ("    addu $t0, $t1, $t32\n", 1, "thanh ghi sai"),
    ("    addu $t0, $t1, t2\n", 1, "thanh ghi sai"),
    ("    mfc0 $t0, $sp\n", 1, "CP0"),
    ("    nop\n    addi $t0, $t0, 1\n", 2, "lenh khong co"),
    ("    srl  $t0, $t0, 1\n", 1, "lenh khong co"),
    ("    bgez $t0, x\nx: nop\n", 1, "lenh khong co"),
    ("    addiu $t0, $t0, 40000\n", 1, "vuot 16 bit"),
    ("    ori  $t0, $t0, -1\n", 1, "vuot 16 bit"),
    ("    lw   $t0, 40000($sp)\n", 1, "vuot 16 bit"),
    ("    lw   $t0, $sp\n", 1, "offset($reg)"),
    ("    sll  $t0, $t0, 32\n", 1, "shamt"),
    ("    addu $t0, $t1\n", 1, "can 3 toan hang"),
    ("    nop\n    nop\n    .org 0x4\n", 3, ".org"),
    ("    .align 2\n", 1, "chi thi khong ho tro"),
    ("    .data\n    addu $t0, $t0, $t0\n", 2, ".data"),
    ("    li   $t0, 0x100000000\n", 1, "vuot 32 bit"),
    ("    .space 6\n", 1, ".space"),
    ("    addiu $t0, $t0, 12x\n", 1, "so khong hop le"),
]


@pytest.mark.parametrize("src,line,frag", ERR_CASES)
def test_b1_3_error_line(src, line, frag):
    errs = errors_of(src)
    assert len(errs) == 1, errs
    assert errs[0].startswith("x.s:%d: loi" % line), errs
    assert frag in errs[0], errs


def test_b1_3_all_errors_reported_and_no_file(tmp_path):
    src = tmp_path / "bad.s"
    src.write_text("    nop\n    addi $t0, $t0, 1\n    beq $t0, $t0, nowhere\nL:  nop\nL:  nop\n")
    out = tmp_path / "bad.hex"
    assert asm.main([str(src), "-o", str(out)]) == 1
    assert not out.exists() and not (tmp_path / "bad.lst").exists()
    errs = errors_of(src.read_text())
    assert [int(e.split(":")[1]) for e in errs] == [2, 5, 3]      # pass 1 (lệnh, nhãn) rồi pass 2 (nhãn thiếu)


def test_b1_3_ok_writes_hex_lst(tmp_path):
    src = tmp_path / "ok.s"
    src.write_text("        .eqv  X 0x10\nmain:   addiu $v0, $zero, X\nend:    j     end\n        .data\nd:      .word 7, main\n")
    out = tmp_path / "ok.hex"
    assert asm.main([str(src), "-o", str(out)]) == 0
    h = out.read_text().split()
    assert len(h) == 1024 and h[:3] == ["24020010", "08000001", "00000000"]
    d = (tmp_path / "ok.dmem.hex").read_text().split()
    assert len(d) == 1024 and d[:3] == ["00000007", "00000000", "00000000"]
    assert "addiu $v0, $zero, X" in (tmp_path / "ok.lst").read_text()


def test_b1_3_warn_over_900():
    r = asm.assemble(".space %d\n" % (4 * 901))
    assert r["warnings"] and "901" in r["warnings"][0]
    assert not asm.assemble(".space %d\n" % (4 * 900))["warnings"]
    errs = errors_of(".space %d\n" % (4 * 1025))
    assert "vuot IMEM" in errs[0]
    assert not asm.assemble(".space %d\n" % (4 * 1800), aw=11)["warnings"]     # IMEM 2048: ngưỡng 1800
    assert "1801" in asm.assemble(".space %d\n" % (4 * 1801), aw=11)["warnings"][0]


# ---------------------------------------------------------------- B1-4: nhánh xa nhất
def far(n_between, backward):
    """Nhánh qua n_between lệnh nop (aw = 16 để chương trình vừa IMEM)."""
    if backward:
        return "top:    nop\n        .space %d\n        beq $0, $0, top\n" % (4 * n_between)
    return "        beq $0, $0, dst\n        .space %d\ndst:    nop\n" % (4 * n_between)


def test_b1_4_branch_range():
    # tiến: offset = số lệnh nằm giữa → 32767 được, 32768 lỗi
    r = asm.assemble(far(32767, False), aw=16)
    assert r["imem"][0] == 0x10007FFF
    assert "offset nhanh 32768" in errors_of(far(32768, False), aw=16)[0]
    # lùi: beq ở chỉ số i nhảy về 0 → offset −(i + 1); i = 32767 → −32768 (đủ 16 bit có dấu), i = 32768 lỗi
    r = asm.assemble(far(32766, True), aw=16)
    assert r["imem"][32767] == 0x10008000
    assert "offset nhanh -32769" in errors_of(far(32767, True), aw=16)[0]
    # lỗi báo đúng dòng của lệnh nhánh
    assert errors_of(far(32768, False), aw=16)[0].startswith("x.s:1:")
    assert errors_of(far(32767, True), aw=16)[0].startswith("x.s:3:")
