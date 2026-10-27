"""iss.py — ISS WatchChip (gói B2 · chủ: TV2 · spec: isa-spec.md toàn bộ: §1 bộ nhớ, §3 28 lệnh, §4 div, §5 CP0 + ngắt, §8 trace).
Bản đầu 03/10/2026 do Claude viết (ngoại lệ KE-HOACH §4b); chủ gói vẫn qua cổng vấn đáp.

Hai chế độ (isa-spec §8):
  - **Chạy độc lập**: mô hình ngoại vi tối thiểu (`Periph`): MS_OF_DAY tăng 1 sau mỗi K lệnh (SET/ARM như timer-spec §3),
    TICK_1MS/TICK_1S, IRQ_ENABLE/PENDING/STAMP, BTN_EVENT từ kịch bản, DISP0…7 (ghi DISP7 = 1 khung), DIV_FLAGS,
    CYCLE_COUNT = số lệnh đã chạy. Stopwatch/timer/alarm/UART không mô phỏng (đọc lại giá trị đã ghi).
  - **Replay MMIO**: mỗi `lw` vào MMIO và `mfc0 Cause` lấy giá trị từ trace RTL cùng dòng; nhận ngắt đúng chỗ trace RTL
    có dòng `INTERRUPT` (và báo lỗi nếu lúc đó ISS thấy không được phép nhận: IE = 0, EXL = 1, hay ngay sau mtc0/eret).

  python tools/iss.py fw/tests/cpu/sum100.s                     # chạy độc lập tới "j ." / hết chương trình
  python tools/iss.py prog.hex --trace work/p.csv --max 100000
  python tools/iss.py prog.s --event 50:irq:1                   # bật IRQ_PENDING bit 1 trước lệnh thứ 50
  python tools/iss.py prog.hex --replay work/rtl.csv --trace work/iss.csv --poke 0x7e0=1
Cột `cycle` của trace ISS = số thứ tự lệnh (0, 1, …).
"""
import os
import sys

MMIO = 0xFFFFFF00
M32 = 0xFFFFFFFF
REG = ("zero at v0 v1 a0 a1 a2 a3 t0 t1 t2 t3 t4 t5 t6 t7 s0 s1 s2 s3 s4 s5 s6 s7 "
       "t8 t9 k0 k1 gp sp fp ra").split()


def s32(x):
    x &= M32
    return x - (1 << 32) if x >> 31 else x


# ------------------------------------------------------------------ hàm tính (B2-1 so với alu/mul/div/bcd.txt)
def f_alu(ctl, a, b, sa):
    """ctl như alu.txt: 0 ADD 1 SUB 2 AND 3 OR 4 XOR 5 SLT 6 SLL 7 SRA (dịch b theo sa)."""
    sa &= 31
    if ctl == 0:
        return (a + b) & M32
    if ctl == 1:
        return (a - b) & M32
    if ctl == 2:
        return a & b
    if ctl == 3:
        return a | b
    if ctl == 4:
        return a ^ b
    if ctl == 5:
        return 1 if s32(a) < s32(b) else 0
    if ctl == 6:
        return (b << sa) & M32
    if ctl == 7:
        return (s32(b) >> sa) & M32
    raise ValueError("ctl %d" % ctl)


def f_mul(a, b):
    return (s32(a) * s32(b)) & M32


def f_div(a, b):
    """→ (LO, HI, DZ) theo isa-spec §4."""
    if b & M32 == 0:
        return 0, a & M32, 1
    sa, sb = s32(a), s32(b)
    if sa == -2**31 and sb == -1:
        return 0x80000000, 0, 0
    q = abs(sa) // abs(sb)
    if (sa < 0) != (sb < 0):
        q = -q
    return q & M32, (sa - q * sb) & M32, 0


def f_bcd(x):
    x &= M32
    if x > 99999999:
        return M32
    return int("%d" % x, 16)


# ------------------------------------------------------------------ ngoại vi
class Periph:
    """Mô hình ngoại vi tối thiểu cho chế độ chạy độc lập."""

    def __init__(self, k=25, events=(), ms=0, day=0, dow=6):
        self.k = k
        self.ms, self.day, self.dow = ms, day, dow
        self.shadow = (dow << 16) | day
        self.set_ms = self.set_day = self.arm = 0
        self.s1 = 0                           # bộ đếm TICK_1S
        self.pend = self.en = self.stamp = 0
        self.irq_q = 0
        self.btn, self.lost = [], 0
        self.ram = {}
        self.disp = [0] * 8
        self.frames = []
        self.events = sorted(events)          # (lệnh thứ n, loại, tham số)

    def cause(self):
        return self.pend & self.en & 0xFF

    def cause_read(self, cpu):
        return self.cause() << 8

    def before(self, cpu):
        """Gọi trước khi chạy lệnh thứ cpu.n: sự kiện kịch bản + nhịp ms mỗi K lệnh."""
        n = cpu.n
        while self.events and self.events[0][0] <= n:
            _, kind, arg = self.events.pop(0)
            if kind == "irq":
                self.pend |= 1 << arg
            elif kind == "btn":
                self._push_btn(arg)
        if n and n % self.k == 0:
            self._tick_ms()
        irq = 1 if self.cause() else 0
        if irq and not self.irq_q:
            self.stamp = n
        self.irq_q = irq

    def _push_btn(self, code):
        if len(self.btn) >= 4:
            self.lost = 1
        else:
            self.btn.append(0x80000000 | (code & 3) << 29 | self.ms)
            self.pend |= 1 << 5

    def _tick_ms(self):
        self.pend |= 1                        # TICK_1MS
        if self.arm:
            self.ms, self.day, self.dow = self.set_ms, self.set_day & 0xFFFF, (self.set_day >> 16) & 7
            self.arm, self.s1 = 0, 0
            return
        if self.ms == 86399999:
            self.ms, self.day, self.dow = 0, (self.day + 1) & 0xFFFF, (self.dow + 1) % 7
        else:
            self.ms += 1
        self.s1 += 1
        if self.s1 == 1000:
            self.s1 = 0
            self.pend |= 2                    # TICK_1S

    def read(self, a, cpu):
        o = a - MMIO
        if o == 0x00:
            return cpu.n & M32
        if o == 0x04:
            self.shadow = (self.dow << 16) | self.day
            return self.ms
        if o == 0x08:
            return self.shadow
        if o == 0x14:
            return self.arm
        if o == 0x40:
            if not self.btn:
                return self.lost << 28 if self.lost else 0
            v = self.btn.pop(0) | (self.lost << 28)
            self.lost = 0
            return v
        if o == 0x44:
            return self.en
        if o == 0x48:
            return self.pend
        if o == 0x4C:
            return self.stamp
        if o == 0x90:
            return cpu.dz
        return self.ram.get(o, 0)

    def write(self, a, v, cpu):
        o = a - MMIO
        if o == 0x0C:
            self.set_ms = v & 0x7FFFFFF
            if self.set_ms >= 86400000:
                self.set_ms = 0
        elif o == 0x10:
            dow = (v >> 16) & 7
            self.set_day = ((0 if dow == 7 else dow) << 16) | (v & 0xFFFF)
        elif o == 0x14:
            self.arm = v & 1
        elif o == 0x44:
            self.en = v & 0xFF
        elif o == 0x48:
            self.pend &= ~v & 0xFF
        elif 0x5C <= o <= 0x78:
            self.disp[(o - 0x5C) // 4] = v & 0xFF
            if o == 0x78:
                self.frames.append((cpu.n, tuple(self.disp)))
        else:
            self.ram[o] = v


class ReplayPeriph:
    """Replay MMIO: giá trị `lw` MMIO và `mfc0 Cause` lấy từ dòng trace RTL hiện tại."""

    def __init__(self):
        self.cur = None

    def before(self, cpu):
        pass

    def cause(self):
        return 0

    def cause_read(self, cpu):
        return int(self.cur[4], 16) if self.cur else 0

    def read(self, a, cpu):
        c = self.cur
        return int(c[7], 16) if c and c[5] == "R" else 0

    def write(self, a, v, cpu):
        pass


# ------------------------------------------------------------------ CPU
class ISS:
    def __init__(self, imem, dmem=None, aw=10, periph=None):
        self.imem = list(imem) + [0] * max(0, (1 << aw) - len(imem))
        self.mask = (1 << aw) - 1
        self.dmem = list(dmem) if dmem else [0] * 1024
        self.r = [0] * 32
        self.hi = self.lo = 0
        self.pc = 0
        self.status = self.epc = 0
        self.dz = 0
        self.n = 0                            # số lệnh đã chạy
        self.block = False                    # lệnh vừa xong là mtc0/eret → không nhận ngắt
        self.periph = periph if periph is not None else Periph()
        self.unknown = []

    # bộ nhớ dữ liệu (isa-spec §1): bỏ 2 bit thấp; DMEM 0x000–0xFFF; MMIO 0xFFFFFF00–; còn lại đọc 0, ghi bỏ
    def _load(self, a):
        if a < 0x1000:
            return self.dmem[a >> 2]
        if a >= MMIO:
            return self.periph.read(a, self) & M32
        return 0

    def _store(self, a, v):
        if a < 0x1000:
            self.dmem[a >> 2] = v
        elif a >= MMIO:
            self.periph.write(a, v, self)

    def can_irq(self):
        return (self.status & 1) and not (self.status & 2) and not self.block

    def take_irq(self):
        """Nhận ngắt ở cuối lệnh vừa xong: EPC ← next_pc (= self.pc), PC ← 0x180, EXL ← 1."""
        self.epc = self.pc
        self.pc = 0x180
        self.status |= 2
        return (self.n, 0x180, "INTERRUPT", 0, 0, "-", 0, 0)

    def step(self):
        """Chạy 1 lệnh → bản ghi trace (cycle, pc, instr, rd, value, mop, maddr, mdata)."""
        self.periph.before(self)
        pc = self.pc
        w = self.imem[(pc >> 2) & self.mask]
        op, rs, rt, rd = w >> 26, (w >> 21) & 31, (w >> 16) & 31, (w >> 11) & 31
        sa, fn, imm = (w >> 6) & 31, w & 63, w & 0xFFFF
        se = imm - 0x10000 if imm & 0x8000 else imm
        R = self.r
        a, b = R[rs], R[rt]
        npc = (pc + 4) & M32
        wr, val = 0, 0
        mop, maddr, mdata = "-", 0, 0
        self.block = False
        ok = True
        if op == 0:
            if fn in (0x21, 0x23, 0x24, 0x25, 0x26, 0x2A, 0x00, 0x03):
                ctl = {0x21: 0, 0x23: 1, 0x24: 2, 0x25: 3, 0x26: 4, 0x2A: 5, 0x00: 6, 0x03: 7}[fn]
                wr, val = rd, f_alu(ctl, a, b, sa)
            elif fn == 0x08:
                npc = a & ~3 & M32
            elif fn == 0x1A:
                self.lo, self.hi, self.dz = f_div(a, b)
            elif fn == 0x10:
                wr, val = rd, self.hi
            elif fn == 0x12:
                wr, val = rd, self.lo
            else:
                ok = False
        elif op == 0x09:
            wr, val = rt, (a + se) & M32
        elif op == 0x0A:
            wr, val = rt, 1 if s32(a) < se else 0
        elif op == 0x0C:
            wr, val = rt, a & imm
        elif op == 0x0D:
            wr, val = rt, a | imm
        elif op == 0x0F:
            wr, val = rt, imm << 16
        elif op == 0x23:
            maddr = (a + se) & M32 & ~3
            mop, mdata = "R", self._load(maddr)
            wr, val = rt, mdata
        elif op == 0x2B:
            maddr = (a + se) & M32 & ~3
            mop, mdata = "W", b
            self._store(maddr, b)
        elif op in (0x04, 0x05):
            if (a == b) == (op == 0x04):
                npc = (pc + 4 + (se << 2)) & M32
        elif op in (0x02, 0x03):
            npc = ((pc + 4) & 0xF0000000) | ((w & 0x3FFFFFF) << 2)
            if op == 0x03:
                wr, val = 31, (pc + 4) & M32
        elif op == 0x1C:
            if fn == 0x02:
                wr, val = rd, f_mul(a, b)
            elif fn == 0x10:
                wr, val = rd, f_bcd(a)
            else:
                ok = False
        elif op == 0x10:
            if rs == 0x00:                                  # mfc0 rt, rd
                if rd == 12:
                    v = self.status
                elif rd == 13:
                    v = self.periph.cause_read(self)
                elif rd == 14:
                    v = self.epc
                else:
                    v = 0
                wr, val = rt, v & M32
            elif rs == 0x04:                                # mtc0 rt, rd
                if rd == 12:
                    self.status = b & 3
                elif rd == 14:
                    self.epc = b & ~3 & M32
                self.block = True
            elif w == 0x42000018:                           # eret
                npc = self.epc
                self.status &= ~2
                self.block = True
            else:
                ok = False
        else:
            ok = False
        if not ok:
            self.unknown.append((pc, w))
        if wr:
            R[wr] = val & M32
        else:
            val = 0
        rec = (self.n, pc, "%08x" % w, wr, val & M32, mop, maddr, mdata & M32)
        self.pc = npc
        self.n += 1
        return rec

    def run(self, max_n=2000000, end_pc=None, out=None):
        """Chạy độc lập tới PC = end_pc, "j ." hay hết max_n lệnh. → lý do dừng."""
        while self.n < max_n:
            if end_pc is not None and self.pc == end_pc:
                return "end"
            w = self.imem[(self.pc >> 2) & self.mask]
            selfjump = (w >> 26) == 0x02 and (w & 0x3FFFFFF) == ((self.pc >> 2) & 0x3FFFFFF)
            rec = self.step()
            if out is not None:
                out.append(rec)
            if self.periph.cause() and self.can_irq():
                irec = self.take_irq()
                if out is not None:
                    out.append(irec)
            elif selfjump:
                return "j ."
        return "max"

    def dump(self):
        L = ["R %d %08x" % (i, v) for i, v in enumerate(self.r)]
        L += ["HI %08x" % self.hi, "LO %08x" % self.lo]
        L += ["M %08x %08x" % (4 * i, v) for i, v in enumerate(self.dmem) if v]
        L += ["IC %d" % self.n]
        return "\n".join(L) + "\n"


# ------------------------------------------------------------------ trace
def fmt(rec):
    c, pc, ins, rd, val, mop, ma, md = rec
    return "%d,%08x,%s,%d,%08x,%s,%08x,%08x" % (c, pc, ins, rd, val, mop, ma, md)


def read_trace(path):
    out = []
    with open(path) as f:
        for ln in f:
            p = ln.strip().split(",")
            if len(p) == 8 and p[0] != "cycle":
                out.append(p)
    return out


def replay(cpu, rtl):
    """Chạy ISS theo trace RTL (danh sách dòng đã tách cột). → (bản ghi ISS, danh sách lỗi replay)."""
    per = ReplayPeriph()
    cpu.periph = per
    out, probs = [], []
    for k, line in enumerate(rtl, 1):
        if line[2] == "INTERRUPT":
            if not cpu.can_irq():
                probs.append("dong %d: RTL nhan ngat khi ISS thay khong duoc phep (Status=%x, sau mtc0/eret=%d)"
                             % (k, cpu.status, cpu.block))
            out.append(cpu.take_irq())
            continue
        per.cur = line
        out.append(cpu.step())
    return out, probs


def load_hex(path):
    with open(path) as f:
        return [int(x, 16) for x in f.read().split()]


def load_prog(path, aw=10):
    """`.s` → dịch bằng asm.py; còn lại đọc như .hex. → (imem, dmem hoặc None)."""
    if path.endswith(".s"):
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import asm
        r = asm.assemble_file(path, aw)
        return r["imem"], r["dmem"]
    return load_hex(path), None


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description="ISS WatchChip (isa-spec §8)")
    ap.add_argument("prog", help=".s (dịch bằng asm.py) hoặc .hex")
    ap.add_argument("--aw", type=int, default=10)
    ap.add_argument("--trace", help="ghi trace CSV isa-spec §8")
    ap.add_argument("--max", type=int, default=2000000, help="số lệnh tối đa (chạy độc lập)")
    ap.add_argument("--end", type=lambda x: int(x, 0), help="dừng khi PC = địa chỉ này")
    ap.add_argument("--k", type=int, default=25, help="số lệnh mỗi ms (chạy độc lập)")
    ap.add_argument("--poke", action="append", default=[], help="addr=giá trị: ghi DMEM trước khi chạy")
    ap.add_argument("--event", action="append", default=[], help="n:irq:bit hoặc n:btn:mã (trước lệnh thứ n)")
    ap.add_argument("--replay", help="trace RTL: chế độ replay MMIO")
    ap.add_argument("--dump", help="ghi R/HI/LO/M/IC ra file")
    a = ap.parse_args(argv)
    imem, dmem = load_prog(a.prog, a.aw)
    ev = []
    for e in a.event:
        n, kind, arg = e.split(":")
        ev.append((int(n), kind, int(arg, 0)))
    cpu = ISS(imem, dmem, a.aw, Periph(k=a.k, events=ev))
    for p in a.poke:
        ad, v = p.split("=")
        cpu.dmem[(int(ad, 0) >> 2) & 1023] = int(v, 0) & M32
    if a.replay:
        recs, probs = replay(cpu, read_trace(a.replay))
        why = "replay %d dong" % len(recs)
    else:
        recs, probs = [], []
        why = cpu.run(a.max, a.end, recs)
    if a.trace:
        with open(a.trace, "w", newline="\n") as f:
            f.write("".join(fmt(r) + "\n" for r in recs))
    if a.dump:
        with open(a.dump, "w", newline="\n") as f:
            f.write(cpu.dump())
    for pc, w in cpu.unknown[:10]:
        print("ASSERT lenh la: pc=%08x instr=%08x" % (pc, w))
    for p in probs[:10]:
        print("loi", p)
    print("iss: %d lenh (%s), pc=%08x, $v0=%08x" % (cpu.n, why, cpu.pc, cpu.r[2]))
    return 1 if probs else 0


if __name__ == "__main__":
    sys.exit(main())
