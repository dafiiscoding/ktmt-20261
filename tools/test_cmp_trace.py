"""test_cmp_trace.py — test gói B3 (goi-viec.md B3). Chạy: python -m pytest -q tools/test_cmp_trace.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import asm  # noqa: E402
import cmp_trace  # noqa: E402
import iss  # noqa: E402


def sum100_trace(tmp_path, name="a.csv"):
    r = asm.assemble_file(os.path.join(ROOT, "fw", "tests", "cpu", "sum100.s"))
    c = iss.ISS(r["imem"])
    out = []
    c.run(10000, end_pc=4 * r["nwords"], out=out)
    p = tmp_path / name
    p.write_text("".join(iss.fmt(x) + "\n" for x in out))
    return p, out


def test_same_trace_pass(tmp_path, capsys):
    a, out = sum100_trace(tmp_path)
    b = tmp_path / "b.csv"
    # cột cycle khác (RTL ghi chu kỳ hệ thống, ISS ghi số thứ tự lệnh) → vẫn PASS
    b.write_text("".join(iss.fmt((7 * x[0] + 3,) + x[1:]) + "\n" for x in out))
    assert len(out) > 200
    assert cmp_trace.main([str(a), str(b)]) == 0
    assert capsys.readouterr().out.strip().endswith("PASS cmp_trace %d" % len(out))


def test_changed_value_line_137(tmp_path, capsys):
    a, out = sum100_trace(tmp_path)
    lines = a.read_text().splitlines()
    p = lines[136].split(",")                               # dòng 137 (đếm từ 1)
    p[4] = "%08x" % (int(p[4], 16) ^ 0x10)
    lines[136] = ",".join(p)
    b = tmp_path / "b.csv"
    b.write_text("\n".join(lines) + "\n")
    assert cmp_trace.main([str(a), str(b)]) == 1
    o = capsys.readouterr().out
    assert "lech o dong 137, cot: value" in o
    assert ("ISS: " + lines[136]) in o and o.strip().splitlines()[-1].startswith("FAIL cmp_trace")


def test_each_column_reported(tmp_path):
    _, out = sum100_trace(tmp_path)
    A = [iss.fmt(x).split(",") for x in out]
    for col in range(1, 8):
        B = [list(r) for r in A]
        B[50][col] = "R" if col == 5 and B[50][col] != "R" else ("W" if col == 5 else "ffffffff" if B[50][col] != "ffffffff" else "0")
        ok, rep = cmp_trace.compare(A, B)
        assert not ok and rep[0] == "lech o dong 51, cot: %s" % cmp_trace.COLS[col], rep


def test_first_and_last_line(tmp_path):
    _, out = sum100_trace(tmp_path)
    A = [iss.fmt(x).split(",") for x in out]
    for k in (0, len(A) - 1):
        B = [list(r) for r in A]
        B[k][1] = "%08x" % (int(B[k][1], 16) + 4)
        ok, rep = cmp_trace.compare(A, B)
        assert not ok and rep[0] == "lech o dong %d, cot: pc" % (k + 1), rep


def test_rtl_longer_reports_extra(tmp_path, capsys):
    a, out = sum100_trace(tmp_path)
    b = tmp_path / "b.csv"
    b.write_text("".join(iss.fmt(x) + "\n" for x in out[:-3]))
    assert cmp_trace.main([str(a), str(b)]) == 1
    o = capsys.readouterr().out
    assert "RTL thua 3 dong so voi ISS (tu dong %d)" % (len(out) - 2) in o
    assert cmp_trace.main([str(b), str(a)]) == 1
    assert "ISS thua 3 dong" in capsys.readouterr().out


def test_replay_mode(tmp_path, capsys):
    """Trace "RTL" giả: lw MMIO đọc về giá trị lạ, ngắt ở chỗ tùy ý → ISS replay phải theo y hệt."""
    src = """
        j     main
        .org  0x180
        addiu $s1, $s1, 1
        eret
main:   addiu $t0, $zero, 1
        mtc0  $t0, $12
        lw    $t1, -252($zero)        # MS_OF_DAY
        addu  $t2, $t1, $t1
        mfc0  $t3, $13
        addiu $t4, $zero, 7
        addiu $t4, $t4, 1
end:    j     end
"""
    r = asm.assemble(src)
    hexf = tmp_path / "p.hex"
    asm.write_hex(str(hexf), r["imem"])
    L = r["labels"]
    m = L["main"]
    rtl = [
        "1,00000000,08000062,0,00000000,-,00000000,00000000",
        "3,%08x,24080001,8,00000001,-,00000000,00000000" % m,
        "5,%08x,40886000,0,00000000,-,00000000,00000000" % (m + 4),
        "7,%08x,8c09ff04,9,00abcdef,R,ffffff04,00abcdef" % (m + 8),
        "9,%08x,01295021,10,01579bde,-,00000000,00000000" % (m + 12),
        "11,%08x,400b6800,11,00000200,-,00000000,00000000" % (m + 16),
        "11,00000180,INTERRUPT,0,00000000,-,00000000,00000000",
        "13,00000180,26310001,17,00000001,-,00000000,00000000",
        "15,00000184,42000018,0,00000000,-,00000000,00000000",
        "17,%08x,240c0007,12,00000007,-,00000000,00000000" % (m + 20),
    ]
    a = tmp_path / "rtl.csv"
    a.write_text("\n".join(rtl) + "\n")
    out = tmp_path / "iss.csv"
    assert cmp_trace.main([str(a), "--replay", str(hexf), "--out", str(out)]) == 0, capsys.readouterr().out
    assert "PASS cmp_trace 10" in capsys.readouterr().out
    # ngắt ngay sau mtc0 (bị chặn theo isa-spec §5) → replay báo lỗi
    bad = rtl[:3] + ["5,00000180,INTERRUPT,0,00000000,-,00000000,00000000"]
    a.write_text("\n".join(bad) + "\n")
    assert cmp_trace.main([str(a), "--replay", str(hexf)]) == 1
    assert "nhan ngat khi ISS thay khong duoc phep" in capsys.readouterr().out
