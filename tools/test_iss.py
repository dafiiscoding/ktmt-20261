"""test_iss.py — test gói B2 (goi-viec.md B2-1…B2-4). Chạy: python -m pytest -q tools/test_iss.py
B2-4: thay cho khung `fmt_test.s`, Python gọi thẳng từng hàm (đặt PC = nhãn, $a0, $ra = địa chỉ canh) của `fw/fmt.s`
và `draw` của `fw/main.s` với biến DMEM + giá trị MMIO dựng sẵn → so DISP7…0 với `fmt_*.txt`, `date.txt`.
E6 SY-1/SY-2 (26/10): cùng cách, gọi `sync` của `fw/main.s` với UartPeriph (FIFO RX dựng sẵn, TX luôn sẵn sàng)."""
import os
import re
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import asm  # noqa: E402
import iss  # noqa: E402

VEC = os.path.join(ROOT, "tb", "vectors")


def rows(name):
    with open(os.path.join(VEC, name)) as f:
        return [ln.split() for ln in f if ln.strip() and not ln.startswith("#")]


# ---------------------------------------------------------------- B2-1: cùng golden với RTL
def test_b2_1_alu():
    n = 0
    for ctl, a, b, sa, y, z in rows("alu.txt"):
        got = iss.f_alu(int(ctl, 16), int(a, 16), int(b, 16), int(sa, 16))
        assert got == int(y, 16), (ctl, a, b, sa, y, "%08x" % got)
        assert (got == 0) == (z == "1")
        n += 1
    assert n > 4000


def test_b2_1_mul():
    R = rows("mul.txt")
    for a, b, lo in R:
        assert iss.f_mul(int(a, 16), int(b, 16)) == int(lo, 16), (a, b, lo)
    assert len(R) > 800


def test_b2_1_div():
    R = rows("div.txt")
    for a, b, lo, hi, dz in R:
        assert iss.f_div(int(a, 16), int(b, 16)) == (int(lo, 16), int(hi, 16), int(dz)), (a, b, lo, hi, dz)
    assert len(R) > 800


def test_b2_1_bcd():
    R = rows("bcd.txt")
    for a, y in R:
        assert iss.f_bcd(int(a, 16)) == int(y, 16), (a, y)
    assert len(R) > 3000


# ---------------------------------------------------------------- B2-2: chương trình
def run_file(name, **kw):
    r = asm.assemble_file(os.path.join(ROOT, "fw", "tests", "cpu", name))
    c = iss.ISS(r["imem"], **kw)
    out = []
    why = c.run(200000, end_pc=4 * r["nwords"], out=out)
    return c, why, out


def test_b2_2_sum100():
    c, why, _ = run_file("sum100.s")
    assert why == "end" and c.r[2] == 5050


def test_b2_2_fact10_stack():
    c, why, out = run_file("fact10.s")
    assert why == "end" and c.r[2] == 3628800
    assert sum(1 for x in out if x[5] == "W" and x[6] >= 0xF00) >= 10      # đệ quy: ghi stack ≥ 10 tầng


@pytest.mark.parametrize("name", ["all27.s", "bcd.s", "cp0.s", "fact10.s", "hazard.s", "unaligned.s"])
def test_b2_2_expect_lines(name):
    """Các file fw/tests/cpu có `# expect` và không cần thiết bị riêng của cpu_g1_tb (irq.s, mmio.s dùng)."""
    c, why, _ = run_file(name)
    assert why == "end"
    text = open(os.path.join(ROOT, "fw", "tests", "cpu", name), encoding="utf-8").read()
    for m in re.finditer(r"#\s*expect\s+\$(\w+)\s*=\s*(\S+)", text):
        r = int(m.group(1)) if m.group(1).isdigit() else iss.REG.index(m.group(1))
        assert c.r[r] == int(m.group(2), 0) & iss.M32, (m.group(0), "%08x" % c.r[r])


def test_b2_2_memory_rules():
    """isa-spec §1: lw/sw bỏ 2 bit thấp; địa chỉ ngoài DMEM/MMIO đọc 0, ghi bỏ; IMEM quay vòng; $0 luôn 0."""
    src = """
        addiu $t0, $zero, 0x123
        sw    $t0, 0x802($zero)       # → word 0x800
        lw    $t1, 0x803($zero)
        lui   $t2, 0x0001
        sw    $t0, 0($t2)             # 0x10000: ngoài vùng → bỏ
        lw    $t3, 0($t2)             # đọc 0
        lw    $t4, 0x800($zero)
        addiu $zero, $zero, 5
        addu  $t5, $zero, $zero
    """
    r = asm.assemble(src)
    c = iss.ISS(r["imem"])
    out = []
    c.run(9, out=out)
    assert out[1][5:] == ("W", 0x800, 0x123) and c.r[9] == 0x123
    assert c.r[11] == 0 and c.r[12] == 0x123 and c.dmem[0x800 >> 2] == 0x123
    assert c.r[0] == 0 and out[7][3] == 0 and c.r[13] == 0
    c.pc = 0x1000 | 4                                       # IMEM 1024 lệnh: 0x1004 → lệnh ở 0x004
    assert c.step()[2] == "%08x" % r["imem"][1]


# ---------------------------------------------------------------- B2-3: ngắt
IRQ_PROG = """
        j     main
        .org  0x180
        mfc0  $s2, $14                # EPC
        addiu $s1, $s1, 1
        addiu $k0, $zero, 2
        {clear}sw    $k0, -184($zero)          # xóa IRQ_PENDING bit 1
        eret
main:   addiu $t0, $zero, 2
        sw    $t0, -188($zero)          # IRQ_ENABLE = TICK_1S
        addiu $t0, $zero, 1
        mtc0  $t0, $12                  # IE = 1
        addiu $t1, $zero, 100
loop:   addiu $s0, $s0, 1
        bne   $s0, $t1, loop
end:    j     end
"""


def irq_run(at, clear=True, max_n=2000):
    r = asm.assemble(IRQ_PROG.format(clear="" if clear else "# "))
    c = iss.ISS(r["imem"], periph=iss.Periph(k=10**9, events=[(at, "irq", 1)] if at is not None else []))
    out = []
    c.run(max_n, out=out)
    return c, out, r["labels"]


def test_b2_3_irq_after_50():
    ref = irq_run(None)[1]                                  # không ngắt: dòng thứ 51 là lệnh lẽ ra chạy tiếp
    c, out, lab = irq_run(50)
    k = [i for i, x in enumerate(out) if x[2] == "INTERRUPT"]
    assert k == [51], k                                     # sau lệnh thứ 50 (đếm từ 0) → dòng 51
    assert out[52][1] == 0x180
    epc = ref[51][1]
    assert c.r[18] == epc                                   # $s2 = EPC = lệnh kế tiếp chưa chạy
    eret = [i for i, x in enumerate(out) if x[2] == "42000018"]
    assert len(eret) == 1 and out[eret[0] + 1][1] == epc     # eret quay lại đúng
    assert c.r[17] == 1 and c.r[16] == 100                  # handler 1 lần, vòng lặp vẫn đủ 100
    main = [x[1:] for x in out if x[2] != "INTERRUPT" and not 0x180 <= x[1] <= 0x190]
    assert main == [x[1:] for x in ref]                     # bỏ handler đi thì trùng hẳn bản không ngắt


def test_b2_3_irq_epc_is_branch_target():
    _, ref, lab = irq_run(None)
    # chọn lệnh `bne` nhảy (về loop) làm lệnh cuối trước ngắt
    i = next(i for i, x in enumerate(ref) if x[1] == lab["loop"] + 4 and i > 30)
    c, out, _ = irq_run(i)
    assert c.r[18] == lab["loop"]


def test_b2_3_no_irq_right_after_mtc0():
    c, out, lab = irq_run(0)                                # chờ sẵn từ đầu; IE bật bởi mtc0
    k = [i for i, x in enumerate(out) if x[2] == "INTERRUPT"][0]
    assert out[k - 2][2] == "40886000"                      # mtc0 $t0, $12: không nhận ngay sau nó …
    assert out[k - 1][1] == out[k - 2][1] + 4               # … mà sau đúng 1 lệnh kế


def test_b2_3_forgot_clear_runs_one_instruction():
    c, out, lab = irq_run(50, clear=False, max_n=400)
    k = [i for i, x in enumerate(out) if x[2] == "INTERRUPT"]
    assert len(k) > 3
    for a, b in zip(k, k[1:]):
        body = out[a + 1:b]
        assert body[-2][2] == "42000018"                    # eret …
        assert not 0x180 <= body[-1][1] <= 0x190            # … rồi đúng 1 lệnh ở EPC, vào lại handler


def test_b2_3_trace_format():
    _, out, _ = irq_run(50)
    for x in out:
        s = iss.fmt(x)
        assert re.match(r"^\d+,[0-9a-f]{8},([0-9a-f]{8}|INTERRUPT),\d+,[0-9a-f]{8},[-RW],[0-9a-f]{8},[0-9a-f]{8}$", s), s
    assert iss.fmt(out[51]).endswith(",00000180,INTERRUPT,0,00000000,-,00000000,00000000")


# ---------------------------------------------------------------- B2-4: định dạng màn (fmt.s + draw của main.s)
SENT = 0x1FFC                                               # $ra canh: PC tới đây = hàm đã trả về (word cuối IMEM 2048)
FW = os.path.join(ROOT, "fw")
_prog = {}


def prog(name):
    if name not in _prog:
        _prog[name] = asm.assemble_file(os.path.join(FW, name), 11)   # soc_top G_IMEM_AW = 11
    return _prog[name]


def call(name, label, a0=0, dmem=(), ram=(), ms=0, day=0, dow=6):
    """Chạy hàm `label` của fw/`name` tới khi trả về → DISP7…0 (list 8 số, DISP7 trước) và số lệnh."""
    p = prog(name)
    per = iss.Periph(k=10 ** 9, ms=ms, day=day, dow=dow)    # không có nhịp ms trong lúc vẽ
    per.ram.update(dict(ram))
    c = iss.ISS(p["imem"], aw=11, periph=per)
    for a, v in dmem:
        c.dmem[a >> 2] = v
    c.pc, c.r[4], c.r[31] = p["labels"][label], a0 & iss.M32, SENT
    assert c.run(max_n=20000, end_pc=SENT) == "end", label
    return per.disp[::-1], c.n


def golden(name):
    """→ list (trường trước '|', [nhóm 8 số hex sau mỗi '|'])."""
    out = []
    with open(os.path.join(VEC, name)) as f:
        for ln in f:
            if ln.strip() and not ln.startswith("#"):
                parts = ln.split("|")
                out.append((parts[0].split(), [[int(x, 16) for x in g.split()] for g in parts[1:]]))
    return out


def pack_bcd(ms):                                            # RTC_BCD (timer-spec §8)
    h, m, s, r = ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000
    return (h // 10 << 30 | h % 10 << 26 | m // 10 << 23 | m % 10 << 19 | s // 10 << 16 | s % 10 << 12
            | r // 100 << 8 | r // 10 % 10 << 4 | r % 10)


V_MODE, V_TV, V_H12, V_ALK, V_LAPI, V_AED = 0x400, 0x404, 0x408, 0x414, 0x434, 0x43c


def test_b2_4_fmt_time_3_ways():
    G = golden("fmt_time.txt")
    assert len(G) > 50
    for (ms,), (t24, _, _) in G:
        ms = int(ms)
        assert call("fmt.s", "fmt_div", ms)[0] == t24, ("div", ms)
        assert call("fmt.s", "fmt_bcd", ms)[0] == t24, ("bcd", ms)
        assert call("fmt.s", "fmt_hw", ram=[(0x98, pack_bcd(ms))])[0] == t24, ("hw", ms)


def test_b2_4_fmt_cost_instructions():
    # số lệnh/lần (ISS: CYCLE_COUNT = số lệnh) không phụ thuộc giá trị: không có nhánh trong 3 hàm
    n = {f: {call("fmt.s", f, ms)[1] for ms in (0, 45296789, 86399999)} for f in ("fmt_div", "fmt_bcd")}
    n["fmt_hw"] = {call("fmt.s", "fmt_hw", ram=[(0x98, pack_bcd(1))])[1]}
    # số lệnh ≠ số chu kỳ: div 33 chu kỳ CPU, bcd tuần tự 28 → chu kỳ thật đo trên RTL (tb/fmt_bench_tb.v)
    assert n == {"fmt_div": {33}, "fmt_bcd": {40}, "fmt_hw": {25}}, n


def test_b2_4_main_time_page():
    for (ms,), (t24, t12, hold_b) in golden("fmt_time.txt"):
        ms = int(ms)
        assert call("main.s", "draw", ms=ms)[0] == t24, ("24h", ms)
        assert call("main.s", "draw", ms=ms, dmem=[(V_H12, 1)])[0] == t12, ("12h", ms)
        assert call("main.s", "draw", ms=ms, dmem=[(V_TV, 1)])[0] == hold_b, ("giay.ms", ms)


def test_b2_4_main_stopwatch():
    G = golden("fmt_sw.txt")
    for (v,), (exp,) in G:
        assert call("main.s", "draw", dmem=[(V_MODE, 1)], ram=[(0x20, int(v))])[0] == exp, v
    assert len(G) > 30


def test_b2_4_main_timer():
    G = golden("fmt_timer.txt")
    for (v,), (exp,) in G:
        assert call("main.s", "draw", dmem=[(V_MODE, 2)], ram=[(0x28, int(v) & iss.M32)])[0] == exp, v
    assert any(int(v) == -2 ** 31 for (v,), _ in G)


def test_b2_4_main_alarm():
    G = golden("fmt_alarm.txt")
    for (k, en, minute), (exp,) in G:
        k = int(k)
        reg = (int(en) << 31) | int(minute)
        got = call("main.s", "draw", dmem=[(V_MODE, 3), (V_ALK, k - 1)], ram=[(0x30 + 4 * (k - 1), reg)])[0]
        assert got == exp, (k, en, minute)


def test_b2_4_main_date_page():
    G = golden("date.txt")
    for (day, _, _, _, dow), (exp,) in G:
        assert call("main.s", "draw", dmem=[(V_TV, 2)], day=int(day), dow=int(dow))[0] == exp, day
    assert len(G) > 200


# ---------------------------------------------------------------- E6: SY-1, SY-2 (timer-spec §9)
class UartPeriph(iss.Periph):
    """Periph + UART tối thiểu: FIFO RX dựng sẵn, TX luôn sẵn sàng (ghi vào self.tx). Không có nhịp ms
    (k = 10⁹); ARM được nạp ngay ở lần firmware đọc lại RTC_CTRL (thay cho "tick kế tiếp")."""

    def __init__(self, ms=12345, day=777):
        super().__init__(k=10 ** 9, ms=ms, day=day, dow=(day + 6) % 7)
        self.rx, self.tx = [], bytearray()

    def read(self, a, cpu):
        o = a - iss.MMIO
        if o == 0x14 and self.arm:
            self._tick_ms()
        if o == 0x50:
            return (1 if self.rx else 0) | 4 | min(len(self.rx), 64) << 8
        if o == 0x54:
            return 0x80000000 | self.rx.pop(0) if self.rx else 0
        return super().read(a, cpu)

    def write(self, a, v, cpu):
        if a - iss.MMIO == 0x58:
            self.tx.append(v & 0xFF)
        else:
            super().write(a, v, cpu)


def sync_new(**kw):
    per = UartPeriph(**kw)
    return iss.ISS(prog("main.s")["imem"], aw=11, periph=per), per


def sync_feed(c, per, text):
    """Đẩy byte vào FIFO RX rồi gọi `sync` tới khi trả về (ISS giữ DMEM giữa các lần gọi, như vòng chính)."""
    per.rx += list(text.encode())
    c.pc, c.r[31] = prog("main.s")["labels"]["sync"], SENT
    assert c.run(max_n=50000, end_pc=SENT) == "end"
    assert not per.rx


def nmea(body):
    cs = 0
    for ch in body.encode():
        cs ^= ch
    return "$%s*%02X" % (body, cs)


def test_e6_sy1_sentences():
    L = [ln.rstrip("\n").split("\t") for ln in open(os.path.join(VEC, "sync_sentences.txt"), encoding="utf-8")
         if ln.strip() and not ln.startswith("#")]
    for sent, kind, ms, day in L:
        c, per = sync_new()
        sync_feed(c, per, sent + "\n")
        if kind == "ACCEPT":
            assert (per.ms, per.day, per.dow) == (int(ms), int(day), (int(day) + 6) % 7), sent
            assert not per.tx, sent
        elif kind == "REJECT":
            assert (per.ms, per.day, per.arm, per.set_ms) == (12345, 777, 0, 0) and not per.tx, sent
        else:
            assert per.tx.decode() == nmea("R,12345,777") + "\n", sent
    assert {k for _, k, _, _ in L} == {"ACCEPT", "REJECT", "QUERY"} and len(L) > 40


def test_e6_sy1_stream():
    """Câu bị cắt giữa 2 lần gọi, 2 câu liền, rác/câu quá dài trước câu đúng; $R với ms = 0 và ngày 5 chữ số."""
    c, per = sync_new(ms=0, day=65535)
    sync_feed(c, per, "$Q*5")
    assert not per.tx
    sync_feed(c, per, "1\n$Q*51\n")
    assert per.tx.decode() == 2 * (nmea("R,0,65535") + "\n")
    per.tx.clear()
    sync_feed(c, per, "x" * 40 + "\n" + "x" * 31 + nmea("T,1,2") + "\n" + nmea("T,86399999,0") + "\n")
    assert (per.ms, per.day) == (86399999, 0) and not per.tx


def test_e6_sy1_bad_shapes():
    """Câu sai mà checksum vẫn khớp (đột biến 26/10 lọt với sync_sentences.txt): ký tự đầu không phải '$',
    ký tự lạ giữa/sau số, số 10 chữ số."""
    def cs(body):
        return nmea(body)[-2:]
    bad = ["#T,1000,5*" + cs("T,1000,5"), nmea("T,1x2"), nmea("T,1,2x"), nmea("T,0000000001,2"),
           nmea("T,1,0000000002"), nmea("Q,1"), nmea("X,1,2")]
    for sent in bad:
        c, per = sync_new()
        sync_feed(c, per, sent + "\n")
        assert (per.ms, per.day, per.arm) == (12345, 777, 0) and not per.tx, sent
    c, per = sync_new()
    sync_feed(c, per, nmea("T,000000001,000000002") + "\n")                 # 9 chữ số vẫn nhận
    assert (per.ms, per.day) == (1, 2)


def sync_cal(t1, t2, d_ms, cal0=0):
    """t1, t2 = ms tính từ ngày 0; chip ở t2 + d_ms lúc nhận câu thứ 2 → CAL mới."""
    c, per = sync_new()
    sync_feed(c, per, nmea("T,%d,%d" % (t1 % 86400000, t1 // 86400000)) + "\n")
    per.day, per.ms = divmod(t2 + d_ms, 86400000)
    per.ram[0x18] = cal0 & iss.M32
    sync_feed(c, per, nmea("T,%d,%d" % (t2 % 86400000, t2 // 86400000)) + "\n")
    assert (per.day, per.ms) == divmod(t2, 86400000)
    return iss.s32(per.ram[0x18])


def test_e6_sy2_edges():
    """Ca biên không có trong sync_cal.txt (đột biến 26/10 lọt): I vừa quá 1 ngày với |D| = I / 5000;
    giờ chip (B2) sang ngày sau / còn ngày trước so với T2."""
    day = 86400000
    t1 = 100 * day + 1000
    assert sync_cal(t1, t1 + 86400001, 17280) == 0                           # I > 86 400 000 → bỏ dù |D| ≤ I / 5000
    assert sync_cal(t1, t1 + 86400000, 17280) == 655350
    t2 = 100 * day + 86399990                                                # B2 = 101 ngày + 62 ms
    assert sync_cal(t2 - 3600000, t2, 72) == 65500
    t2 = 101 * day + 10                                                      # B2 = 100 ngày + 86 399 938 ms
    assert sync_cal(t2 - 3600000, t2, -72) == -65500
    t1 = 100 * day + 1000                                                    # chặn |CAL| ≤ 655 360 (timer-spec §2)
    assert sync_cal(t1, t1 + 3600000, 72, 600000) == 655360
    assert sync_cal(t1, t1 + 3600000, -72, -600000) == -655360
    assert sync_cal(t1, t1 + 3600000, 72, 589860) == 655360                  # đúng biên: 589 860 + 65 500
    assert sync_cal(t1, t1 + 3600000, 72, 589859) == 655359


def test_e6_sy2_cal():
    """Lần 1 đặt T1 = ngày 100, 1000 ms; chip trôi tới B2 = T2 + D; lần 2 đặt T2 = T1 + I → CAL như sync_cal.txt."""
    R = rows("sync_cal.txt")
    for i_ms, d_ms, cal0, res, cal1 in R:
        i_ms, d_ms = int(i_ms), int(d_ms)
        c, per = sync_new()
        sync_feed(c, per, nmea("T,1000,100") + "\n")
        assert (per.ms, per.day) == (1000, 100)
        t2 = 100 * 86400000 + 1000 + i_ms
        per.day, per.ms = divmod(t2 + d_ms, 86400000)
        per.ram[0x18] = int(cal0) & iss.M32
        sync_feed(c, per, nmea("T,%d,%d" % (t2 % 86400000, t2 // 86400000)) + "\n")
        assert iss.s32(per.ram[0x18]) == int(cal1), (i_ms, d_ms, cal0, res)
        assert (per.day, per.ms) == divmod(t2, 86400000)              # vẫn đặt giờ T2 dù nhận hay bỏ
    assert len(R) > 50 and any(r[3] == "REJECT" for r in R)


def test_e6_sy2_set_by_button_clears_t1():
    """SET bằng nút (st_sv) xóa T1: câu $T kế tiếp chỉ đặt giờ, không tính CAL."""
    c, per = sync_new()
    sync_feed(c, per, nmea("T,1000,100") + "\n")
    assert c.dmem[0x4ac >> 2] == 1
    c.dmem[0x4ac >> 2] = 0                                 # đúng việc st_sv làm (kiểm ở system_tb sys_6 + sys_7)
    per.ms = 3601072
    sync_feed(c, per, nmea("T,3601000,100") + "\n")
    assert per.ram.get(0x18, 0) == 0


def test_e6_set_by_button_drops_dacc():
    """V_DACC còn +6 từ câu xen giữa thì bấm SET (st_sv chỉ xóa V_T1OK): câu $T kế đi qua sy_set nên V_DACC về 0,
    lần CAL sau chỉ dùng D của chính nó (72 / 1 h → 65 500), không cộng nhầm +6 cũ (→ 70 950)."""
    c, per = sync_new()
    t1 = 200 * 86400000 + 5000
    for t, d in [(t1, 0), (t1 + 300000, 6)]:
        per.day, per.ms = divmod(t + d, 86400000)
        sync_feed(c, per, nmea("T,%d,%d" % (t % 86400000, t // 86400000)) + "\n")
    assert c.dmem[0x4bc >> 2] == 6
    c.dmem[0x4ac >> 2] = 0                                 # đúng việc st_sv làm
    t2 = t1 + 600000
    for t, d in [(t2, 0), (t2 + 3600000, 72)]:
        per.day, per.ms = divmod(t + d, 86400000)
        sync_feed(c, per, nmea("T,%d,%d" % (t % 86400000, t // 86400000)) + "\n")
        if d == 0:
            assert c.dmem[0x4bc >> 2] == 0
    assert iss.s32(per.ram.get(0x18, 0)) == 65500




def test_e6_irq_handler_saves_registers():
    """USE_IRQ = 1: chạy từ boot, mỗi 37 lệnh 1 byte ('A', mỗi 16 lần 1 LF) vào FIFO + sự kiện UART_RX → ở mỗi eret,
    mọi thanh ghi trừ $k0/$k1 bằng lúc vào ngắt (handler cất/khôi phục đủ, kể cả khi sy_rx có byte để gom)."""
    class Per(UartPeriph):
        def before(self, cpu):
            if self.events and self.events[0][0] <= cpu.n:
                self.rx.append(10 if len(self.events) % 16 == 0 else 0x41)   # có LF để không kẹt ở "quá 32 byte"
            super().before(cpu)
    per = Per()
    per.events = [(n, "irq", 6) for n in range(300, 30000, 37)]
    c = iss.ISS(prog("main.s")["imem"], aw=11, periph=per)
    keep = [i for i in range(32) if i not in (26, 27)]
    out, snap, nint, nbyte = [], None, 0, 0
    while c.n < 30000:
        k = len(out)
        c.run(c.n + 1, out=out)
        for x in out[k:]:
            if x[2] == "INTERRUPT":
                snap, nint = list(c.r), nint + 1
            elif snap is not None and x[2] == "42000018":
                assert [c.r[i] for i in keep] == [snap[i] for i in keep], (nint, x)
                snap = None
            elif snap is not None and x[1] == prog("main.s")["labels"]["rx2"]:
                nbyte += 1
    assert nint > 300 and nbyte > 100                          # handler thật sự gom byte (dùng $t2)


def test_e6_two_close_sentences_stamped_at_lf():
    """Hai câu $Q sát nhau (USE_IRQ = 1, 1 byte mỗi 37 lệnh): $R của MỖI câu mang giờ lúc '\\n' của chính nó tới
    (MS_OF_DAY = số lệnh đã chạy). Trước 27/10 câu 2 bị chụp lúc sync xử lý xong câu 1 (trễ hàng trăm lệnh)."""
    class Per(UartPeriph):
        def before(self, cpu):
            if self.events and self.events[0][0] <= cpu.n:
                b = self.bytes.pop(0)
                self.rx.append(b)
                if b == 10:
                    self.lf.append(cpu.n)
            super().before(cpu)

        def read(self, a, cpu):
            return cpu.n if a - iss.MMIO == 0x04 else super().read(a, cpu)
    text = (nmea("Q") + "\n") * 2
    per = Per()
    per.bytes, per.lf = list(text.encode()), []
    per.events = [(3000 + 37 * i, "irq", 6) for i in range(len(text))]
    c = iss.ISS(prog("main.s")["imem"], aw=11, periph=per)
    c.run(20000)
    got = [int(s.split(",")[1]) for s in per.tx.decode().split("\n") if s]
    assert len(got) == 2 and len(per.lf) == 2, per.tx
    for stamp, lf in zip(got, per.lf):
        assert 0 <= stamp - lf < 60, (got, per.lf)


def sync_seq(steps):
    """steps = [(t, d_ms)]: chip ở t + d_ms lúc nhận "$T,t" (t tính từ ngày 0) → CAL sau cùng."""
    c, per = sync_new()
    per.ram[0x18] = 0
    for t, d in steps:
        per.day, per.ms = divmod(t + d, 86400000)
        sync_feed(c, per, nmea("T,%d,%d" % (t % 86400000, t // 86400000)) + "\n")
        assert (per.day, per.ms) == divmod(t, 86400000)               # câu nào cũng đặt giờ
    return iss.s32(per.ram[0x18])


def test_e6_t1_kept_when_under_10_min():
    """T1 (Long chốt 26/10): câu đến khi I < 10 phút chỉ đặt giờ, giữ T1, cộng dồn D (V_DACC)."""
    t1 = 200 * 86400000 + 5000
    # 20 ppm: +6 ms sau 5 phút (câu xen giữa, bị bỏ qua cho CAL), +66 ms trong 55 phút sau → D tổng 72 / I 1 h
    assert sync_seq([(t1, 0), (t1 + 300000, 6), (t1 + 3600000, 66)]) == 65500
    # PC gửi mỗi phút (+1 ms mỗi câu, ~16,7 ppm): cứ đủ 10 phút tính CAL 1 lần (D = 10 ms gom từ 10 câu) rồi T1 mới
    # → 6 lần trong 1 h (mô hình giữ độ trôi cố định, không giảm theo CAL). Luật cũ (luôn thay T1): CAL = 0.
    st = [(t1, 0)] + [(t1 + 60000 * k, 1) for k in range(1, 61)]
    assert sync_seq(st) == 6 * ((10 << 16) // 600) * 50
    assert sync_seq([(t1, 0), (t1 + 60000, 1), (t1 + 120000, 1), (t1 + 3600000, 1)]) == ((3 << 16) // 3600) * 50
    # câu xen giữa lệch > 120 ms: là chỉnh giờ, không phải trôi → thành T1 mới (I sau tính từ nó)
    assert sync_seq([(t1, 0), (t1 + 300000, 500), (t1 + 300000 + 3600000, 72)]) == 65500
    # PC lùi giờ trong cùng ngày (T2 trước T1, I < 0) → T1 mới, không CAL (lùi qua ngày bị kiểm chênh ngày chặn trước)
    tm = 200 * 86400000 + 40000000
    assert sync_seq([(tm, 0), (tm - 3600000, 72), (tm, 72)]) == 65500
    # không có câu xen giữa: như cũ
    assert sync_seq([(t1, 0), (t1 + 3600000, 72)]) == 65500
