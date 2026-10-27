"""asm.py — assembler WatchChip (gói B1 · chủ: TV2 · spec: isa-spec.md §2, §3, §7).
Bản đầu 03/10/2026 do Claude viết (ngoại lệ KE-HOACH §4b); chủ gói vẫn qua cổng vấn đáp.

  python tools/asm.py fw/main.s                      # → fw/main.hex + fw/main.lst
  python tools/asm.py fw/main.s -o work/main.hex     # → work/main.hex + work/main.lst (+ work/main.dmem.hex nếu có .data)
  python tools/asm.py x.s -o x.hex --aw 11           # IMEM 2048 lệnh

- Cú pháp MARS: nhãn `ten:`, chú thích `#`, thanh ghi tên (`$t0`) hoặc số (`$8`), số thập phân / hex (`0x`), số âm.
- Chỉ thị: `.text`, `.data`, `.word`, `.space` (byte, bội của 4), `.org <địa chỉ>`, `.eqv TEN giá_trị`.
  `.data` bắt đầu ở địa chỉ DMEM 0 (Harvard: nhãn dữ liệu là địa chỉ DMEM).
- 28 lệnh (isa-spec §3) + lệnh giả `nop`, `move`, `li`, `la`, `b`. `la` luôn = `lui $at` + `ori` (2 lệnh),
  `b` = `beq $0,$0` — **khác MARS** (MARS dùng `addi`/`bgez`, không thuộc 28 lệnh; isa-spec §7).
- Đầu ra `.hex` đủ 2^aw dòng (thiếu thì 0), `.lst` (địa chỉ, mã, dòng nguồn). Lỗi: in `tệp:dòng: lỗi …`
  cho **mọi** lỗi tìm được, mã thoát 1, không ghi file nào. Cảnh báo khi chương trình > 900 lệnh mỗi 1024 ô IMEM (aw 11: > 1800).
"""
import os
import re
import sys

REG = ("zero at v0 v1 a0 a1 a2 a3 t0 t1 t2 t3 t4 t5 t6 t7 s0 s1 s2 s3 s4 s5 s6 s7 "
       "t8 t9 k0 k1 gp sp fp ra").split()

# lệnh → (khuôn, mã): khuôn quyết định thứ tự toán hạng
R3 = {"addu": 0x21, "subu": 0x23, "and": 0x24, "or": 0x25, "xor": 0x26, "slt": 0x2A}   # rd, rs, rt
SHIFT = {"sll": 0x00, "sra": 0x03}                                                       # rd, rt, sa
IMM_S = {"addiu": 0x09, "slti": 0x0A}                                                    # rt, rs, imm có dấu
IMM_U = {"andi": 0x0C, "ori": 0x0D}                                                      # rt, rs, imm không dấu
MEM = {"lw": 0x23, "sw": 0x2B}                                                           # rt, imm(rs)
BR = {"beq": 0x04, "bne": 0x05}                                                          # rs, rt, nhãn
JMP = {"j": 0x02, "jal": 0x03}                                                           # nhãn
INSTR = (set(R3) | set(SHIFT) | set(IMM_S) | set(IMM_U) | set(MEM) | set(BR) | set(JMP)
         | {"jr", "div", "mfhi", "mflo", "lui", "mul", "bcd", "mfc0", "mtc0", "eret"})
PSEUDO = {"nop", "move", "li", "la", "b"}
DIRECTIVES = {".text", ".data", ".word", ".space", ".org", ".eqv"}
WARN_WORDS = 900
LABEL_RE = re.compile(r"^([A-Za-z_][\w.]*)\s*:")
NUM_RE = re.compile(r"^[+-]?(0[xX][0-9a-fA-F]+|\d+)$")


class AsmError(Exception):
    def __init__(self, errors):
        super().__init__("\n".join(errors))
        self.errors = errors


class _LineErr(Exception):
    pass


def _num(tok):
    if not NUM_RE.match(tok):
        raise _LineErr("so khong hop le: '%s'" % tok)
    neg = tok.startswith("-")
    t = tok.lstrip("+-")
    v = int(t, 16) if t.lower().startswith("0x") else int(t, 10)
    return -v if neg else v


def _reg(tok):
    if not tok.startswith("$"):
        raise _LineErr("thanh ghi sai: '%s'" % tok)
    n = tok[1:]
    if n.isdigit() and int(n) < 32:
        return int(n)
    if n in REG:
        return REG.index(n)
    raise _LineErr("thanh ghi sai: '%s'" % tok)


def _cp0(tok):
    if not re.match(r"^\$\d+$", tok) or int(tok[1:]) > 31:
        raise _LineErr("thanh ghi CP0 sai: '%s' (viet $12, $13, $14)" % tok)
    return int(tok[1:])


def _signed16(v, what):
    if not -32768 <= v <= 32767:
        raise _LineErr("%s %d vuot 16 bit co dau" % (what, v))
    return v & 0xFFFF


def _unsigned16(v, what):
    if not 0 <= v <= 0xFFFF:
        raise _LineErr("%s %d vuot 16 bit khong dau" % (what, v))
    return v


def _nargs(ops, n, mn):
    if len(ops) != n:
        raise _LineErr("%s can %d toan hang, co %d" % (mn, n, len(ops)))


def _split_ops(s):
    s = s.strip()
    return [t for t in re.split(r"\s*,\s*|\s+", s) if t] if s else []


def _li_split(v):
    """li: chọn cách mở rộng theo giá trị 32 bit (giống MARS: 0xffffffff = −1 → addiu)."""
    v &= 0xFFFFFFFF
    sv = v - (1 << 32) if v >> 31 else v
    if -32768 <= sv <= 32767:
        return "addiu", sv & 0xFFFF
    if v <= 0xFFFF:
        return "ori", v
    return "lui", v


def _li_size(v):
    return 2 if _li_split(v)[0] == "lui" else 1


def _size(mn, ops):
    """Số word lệnh/lệnh giả chiếm (pass 1, chưa cần biết nhãn)."""
    if mn == "la":
        return 2
    if mn == "li":
        _nargs(ops, 2, mn)
        v = _num(ops[1])
        if not -2**31 <= v <= 0xFFFFFFFF:
            raise _LineErr("li %d vuot 32 bit" % v)
        return _li_size(v)
    return 1


def _r(rs, rt, rd, sa, fn):
    return (rs << 21) | (rt << 16) | (rd << 11) | (sa << 6) | fn


def _i(op, rs, rt, imm16):
    return (op << 26) | (rs << 21) | (rt << 16) | imm16


def _encode(mn, ops, pc, labels):
    """→ danh sách word. `labels`: tên → địa chỉ."""
    def lab(t):
        if t not in labels:
            raise _LineErr("nhan khong co: '%s'" % t)
        return labels[t]

    def branch(t):
        off = lab(t) - (pc + 4)
        if off % 4:
            raise _LineErr("dich nhanh '%s' khong chia het 4" % t)
        off //= 4
        if not -32768 <= off <= 32767:
            raise _LineErr("offset nhanh %d lenh vuot 16 bit (toi da -32768..32767)" % off)
        return off & 0xFFFF

    if mn in R3:
        _nargs(ops, 3, mn)
        return [_r(_reg(ops[1]), _reg(ops[2]), _reg(ops[0]), 0, R3[mn])]
    if mn in SHIFT:
        _nargs(ops, 3, mn)
        sa = _num(ops[2])
        if not 0 <= sa <= 31:
            raise _LineErr("shamt %d ngoai 0..31" % sa)
        return [_r(0, _reg(ops[1]), _reg(ops[0]), sa, SHIFT[mn])]
    if mn == "jr":
        _nargs(ops, 1, mn)
        return [_r(_reg(ops[0]), 0, 0, 0, 0x08)]
    if mn == "div":
        _nargs(ops, 2, mn)
        return [_r(_reg(ops[0]), _reg(ops[1]), 0, 0, 0x1A)]
    if mn in ("mfhi", "mflo"):
        _nargs(ops, 1, mn)
        return [_r(0, 0, _reg(ops[0]), 0, 0x10 if mn == "mfhi" else 0x12)]
    if mn in IMM_S:
        _nargs(ops, 3, mn)
        return [_i(IMM_S[mn], _reg(ops[1]), _reg(ops[0]), _signed16(_num(ops[2]), "imm"))]
    if mn in IMM_U:
        _nargs(ops, 3, mn)
        return [_i(IMM_U[mn], _reg(ops[1]), _reg(ops[0]), _unsigned16(_num(ops[2]), "imm"))]
    if mn == "lui":
        _nargs(ops, 2, mn)
        return [_i(0x0F, 0, _reg(ops[0]), _unsigned16(_num(ops[1]), "imm"))]
    if mn in MEM:
        _nargs(ops, 2, mn)
        m = re.match(r"^([^()]*)\((\$\w+)\)$", ops[1])
        if not m:
            raise _LineErr("%s can dang offset($reg), co '%s'" % (mn, ops[1]))
        off = _num(m.group(1)) if m.group(1) else 0
        return [_i(MEM[mn], _reg(m.group(2)), _reg(ops[0]), _signed16(off, "offset"))]
    if mn in BR:
        _nargs(ops, 3, mn)
        return [_i(BR[mn], _reg(ops[0]), _reg(ops[1]), branch(ops[2]))]
    if mn in JMP:
        _nargs(ops, 1, mn)
        t = lab(ops[0])
        if t % 4:
            raise _LineErr("dich nhay '%s' khong chia het 4" % ops[0])
        if (t >> 28) != ((pc + 4) >> 28):
            raise _LineErr("dich nhay '%s' khac vung 256 MB" % ops[0])
        return [(JMP[mn] << 26) | ((t >> 2) & 0x3FFFFFF)]
    if mn == "mul":
        _nargs(ops, 3, mn)
        return [(0x1C << 26) | _r(_reg(ops[1]), _reg(ops[2]), _reg(ops[0]), 0, 0x02)]
    if mn == "bcd":
        _nargs(ops, 2, mn)
        return [(0x1C << 26) | _r(_reg(ops[1]), 0, _reg(ops[0]), 0, 0x10)]
    if mn in ("mfc0", "mtc0"):
        _nargs(ops, 2, mn)
        return [(0x10 << 26) | ((0 if mn == "mfc0" else 4) << 21) | (_reg(ops[0]) << 16) | (_cp0(ops[1]) << 11)]
    if mn == "eret":
        _nargs(ops, 0, mn)
        return [0x42000018]
    # ---- lệnh giả
    if mn == "nop":
        _nargs(ops, 0, mn)
        return [0]
    if mn == "move":
        _nargs(ops, 2, mn)
        return [_r(0, _reg(ops[1]), _reg(ops[0]), 0, R3["addu"])]
    if mn == "li":
        rt = _reg(ops[0])
        kind, v = _li_split(_num(ops[1]))
        if kind == "addiu":
            return [_i(IMM_S["addiu"], 0, rt, v)]
        if kind == "ori":
            return [_i(IMM_U["ori"], 0, rt, v)]
        return [_i(0x0F, 0, 1, v >> 16), _i(IMM_U["ori"], 1, rt, v & 0xFFFF)]
    if mn == "la":
        _nargs(ops, 2, mn)
        rt, v = _reg(ops[0]), lab(ops[1])
        return [_i(0x0F, 0, 1, v >> 16), _i(IMM_U["ori"], 1, rt, v & 0xFFFF)]
    if mn == "b":
        _nargs(ops, 1, mn)
        return [_i(BR["beq"], 0, 0, branch(ops[0]))]
    raise _LineErr("lenh khong co trong 28 lenh + lenh gia: '%s'" % mn)


def assemble(text, fname="<src>", aw=10):
    """→ dict: imem (list 2^aw word), dmem (list 1024 word hoặc None), lst (list dòng), nwords, labels, warnings.
    Lỗi → AsmError(errors) với errors = ['tệp:dòng: lỗi ...', ...]."""
    errors, warnings = [], []
    eqv = {}
    labels, label_line = {}, {}
    items = []                          # (seg, addr, mn, ops, lineno, src) cho pass 2
    seg = "text"
    addr = {"text": 0, "data": 0}
    used_data = False

    def err(ln, msg):
        errors.append("%s:%d: loi %s" % (fname, ln, msg))

    def subst(s):                                        # .eqv: thay nguyên từ (không đụng tên thanh ghi `$x`)
        return re.sub(r"(?<![$\w.])[A-Za-z_]\w*", lambda m: eqv.get(m.group(0), m.group(0)), s)

    for ln, raw in enumerate(text.splitlines(), 1):
        s = raw.split("#", 1)[0].strip()
        while True:                                      # nhiều nhãn trên 1 dòng
            m = LABEL_RE.match(s)
            if not m:
                break
            name = m.group(1)
            if name in labels:
                err(ln, "nhan trung '%s' (da co o dong %d)" % (name, label_line[name]))
            else:
                labels[name], label_line[name] = addr[seg], ln
            s = s[m.end():].strip()
        if not s:
            continue
        parts = s.split(None, 1)
        mn = parts[0].lower() if parts[0].startswith(".") else parts[0]
        rest = parts[1] if len(parts) > 1 else ""
        try:
            if mn.startswith("."):
                if mn not in DIRECTIVES:
                    raise _LineErr("chi thi khong ho tro: '%s'" % mn)
                if mn == ".eqv":
                    m = re.match(r"^([A-Za-z_]\w*)\s+(\S+)$", rest.strip())
                    if not m:
                        raise _LineErr(".eqv can: .eqv TEN gia_tri")
                    eqv[m.group(1)] = subst(m.group(2))
                    continue
                ops = _split_ops(subst(rest))
                if mn in (".text", ".data"):
                    seg = mn[1:]
                    used_data |= seg == "data"
                    if ops:
                        _nargs(ops, 1, mn)
                        addr[seg] = _num(ops[0])
                    continue
                if mn == ".org":
                    _nargs(ops, 1, mn)
                    a = _num(ops[0])
                    if a % 4:
                        raise _LineErr(".org 0x%x khong chia het 4" % a)
                    if a < addr[seg]:
                        raise _LineErr(".org 0x%x: code truoc do da toi 0x%x" % (a, addr[seg]))
                    while addr[seg] < a:
                        items.append((seg, addr[seg], ".fill", [], ln, ""))
                        addr[seg] += 4
                    continue
                if mn == ".space":
                    _nargs(ops, 1, mn)
                    n = _num(ops[0])
                    if n < 0 or n % 4:
                        raise _LineErr(".space %d phai la boi cua 4, khong am" % n)
                    for _ in range(n // 4):
                        items.append((seg, addr[seg], ".fill", [], ln, ""))
                        addr[seg] += 4
                    continue
                if mn == ".word":
                    if not ops:
                        raise _LineErr(".word can it nhat 1 gia tri")
                    for k, t in enumerate(ops):
                        items.append((seg, addr[seg], ".word", [t], ln, raw.strip() if k == 0 else ""))
                        addr[seg] += 4
                    continue
            if mn not in INSTR and mn not in PSEUDO:
                raise _LineErr("lenh khong co trong 28 lenh + lenh gia: '%s'" % mn)
            if seg != "text":
                raise _LineErr("lenh '%s' nam trong .data" % mn)
            ops = _split_ops(subst(rest))
            n = _size(mn, ops)
            items.append((seg, addr[seg], mn, ops, ln, raw.strip()))
            addr[seg] += 4 * n
        except _LineErr as e:
            err(ln, str(e))

    nmax = 1 << aw
    imem, dmem = [0] * nmax, [0] * 1024
    lst = []
    hi_text = 0
    for seg, a, mn, ops, ln, src in items:
        try:
            if mn == ".fill":
                words = [0]
            elif mn == ".word":
                t = ops[0]
                v = labels[t] if t in labels else _num(t)
                if not -2**31 <= v <= 0xFFFFFFFF:
                    raise _LineErr(".word %d vuot 32 bit" % v)
                words = [v & 0xFFFFFFFF]
            else:
                words = _encode(mn, ops, a, labels)
        except _LineErr as e:
            err(ln, str(e))
            continue
        for k, w in enumerate(words):
            wa = a + 4 * k
            if seg == "text":
                if wa // 4 >= nmax:
                    err(ln, "chuong trinh vuot IMEM %d lenh (dia chi 0x%x)" % (nmax, wa))
                    break
                imem[wa // 4] = w
                hi_text = max(hi_text, wa // 4 + 1)
            else:
                if not 0 <= wa < 4096:
                    err(ln, "du lieu ngoai DMEM 0x000-0xFFF (0x%x)" % wa)
                    break
                dmem[wa // 4] = w
            if mn != ".fill":
                lst.append("%s %04x  %08x  %5d  %s" % ("T" if seg == "text" else "D", wa, w, ln, src if k == 0 else "  (tiep)"))
    if errors:
        raise AsmError(errors)
    warn = WARN_WORDS * nmax // 1024                   # cùng độ dư ~12 % ở mọi cỡ IMEM
    if hi_text > warn:
        warnings.append("%s: canh bao chuong trinh %d lenh > %d (isa-spec §7)" % (fname, hi_text, warn))
    return {"imem": imem, "dmem": dmem if used_data else None, "lst": lst, "nwords": hi_text,
            "labels": labels, "warnings": warnings}


def assemble_file(path, aw=10):
    with open(path, encoding="utf-8") as f:
        return assemble(f.read(), path.replace("\\", "/"), aw)


def write_hex(path, words):
    with open(path, "w", newline="\n") as f:
        f.write("".join("%08x\n" % w for w in words))


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description="Assembler WatchChip (isa-spec §7)")
    ap.add_argument("src")
    ap.add_argument("-o", "--out", help="file .hex IMEM (mac dinh: <src>.hex)")
    ap.add_argument("--aw", type=int, default=10, help="G_IMEM_AW: IMEM 2^aw lenh (mac dinh 10)")
    a = ap.parse_args(argv)
    out = a.out or os.path.splitext(a.src)[0] + ".hex"
    try:
        r = assemble_file(a.src, a.aw)
    except AsmError as e:
        for x in e.errors:
            print(x, file=sys.stderr)
        print("asm: %d loi, khong ghi file" % len(e.errors), file=sys.stderr)
        return 1
    for w in r["warnings"]:
        print(w, file=sys.stderr)
    base = os.path.splitext(out)[0]
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    write_hex(out, r["imem"])
    with open(base + ".lst", "w", encoding="utf-8", newline="\n") as f:
        f.write("# seg dia_chi  ma        dong  nguon\n" + "\n".join(r["lst"]) + "\n")
    if r["dmem"] is not None:
        write_hex(base + ".dmem.hex", r["dmem"])
    print("%s: %d word -> %s" % (a.src, r["nwords"], out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
