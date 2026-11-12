"""Dựng ON-TAP-KTMT.html từ nguon/*.md (PLAN §2.3, §2.7). `--check` chỉ kiểm, không ghi file.

Chạy từ gốc repo:  PYTHONUTF8=1 python learn/on-tap-btl/dung.py [--check]
Lỗi cú pháp/khuôn: in `file:dòng: lý do`, thoát mã 1, không ghi HTML.
"""
import ast
import csv
import html
import random
import re
import sys
import unicodedata
from pathlib import Path

import mistune
from bs4 import BeautifulSoup

sys.path.insert(0, str(Path(__file__).resolve().parent))
import so_ktmt  # noqa: E402

BASE = Path(__file__).resolve().parent
GOC = BASE.parents[1]
NGUON = BASE / "nguon"
OUT = BASE / "ON-TAP-KTMT.html"
CHUOI_CAM = ["DuckDB", "Power BI", "SCD2", "Fact_", "Dim_", "HistGB", "Parquet", "Kechinov", "ĐA2", "Freddie", "Bích", "$" + "$", "\\frac"]
# Luật gốc cấm in giá trị mã khoản (PYYQnXXXXXXX), không cấm tên cột `loan_sequence_number` (từ 07/11)
RE_MA_VAY = re.compile(r"(?!x)x")  # bộ này không có mã cần chặn
MUC = ["Bản đồ", "Câu hỏi mở bài", "Trực giác", "Cơ chế theo đường tín hiệu", "Bảng chu kỳ hoặc tính tay", "Trong chip",
       "Bẫy và thầy hay hỏi", "Sửa tại chỗ và ứng dụng", "Tự kiểm và quay lại bức tranh"]
NHAN_HOP = {"ban-do": "Bản đồ", "bay": "Bẫy", "trong-chip": "Trong chip", "thay-hoi": "Thầy hay hỏi", "sua-tai-cho": "Sửa tại chỗ",
            "dung-o-dau": "Dùng ở đâu khác", "nhac-nhanh": "Nhắc nhanh", "the": "Thẻ kiến thức"}
KHOI_BO_QUA_KHUON = {"00", "99"}  # tiền tố tên file
RE_BAI = re.compile(r"^([A-CPUV]\d+) · ")
RE_ID = re.compile(r"^KT-[A-CPUV]\d-\d{2}$|^KT-[A-C]-D\d{2}$|^KT-[HR]-\d{2}$")
RE_MO = re.compile(r"^:::([a-z][a-z0-9-]*)(?:\s+(.*))?$")
RE_FENCE = re.compile(r"^\s*(```|~~~)")
MD = mistune.create_markdown(escape=False, plugins=["table", "strikethrough"])


def md(text):
    return MD(text)


def md_inline(text):
    out = MD(text).strip()
    m = re.fullmatch(r"<p>(.*)</p>", out, re.S)
    return m.group(1) if m else out


def slug(text):
    v = unicodedata.normalize("NFD", text.replace("đ", "d").replace("Đ", "D")).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", v).strip("-")


class Loi:
    def __init__(self):
        self.ds = []

    def them(self, f, n, msg):
        self.ds.append(f"{f}:{n}: {msg}")


LOI = Loi()
NGUON_IDS = {}
with open(BASE / "nguon_chuan.csv", encoding="utf-8", newline="") as _f:
    for _r in csv.DictReader(_f):
        NGUON_IDS[_r["id"]] = _r


# ───────────────────────── pass 1: tách khối ─────────────────────────
class Seg:
    """Một đoạn của file: 'line' (n, text, fence) hoặc 'block' (idx)."""


def parse_file(path):
    ten = path.name
    lines = path.read_text(encoding="utf-8").splitlines()
    segs, blocks, heads = [], [], []
    fence = False
    i = 0
    cur = {"h1": None, "h2": None, "h3": None}
    while i < len(lines):
        ln, no = lines[i], i + 1
        for c in CHUOI_CAM:
            if c in ln:
                LOI.them(ten, no, f"chuỗi cấm {c!r}")
        if RE_MA_VAY.search(ln):
            LOI.them(ten, no, "chuỗi giống mã khoản vay (cấm in giá trị loan_sequence_number)")
        if RE_FENCE.match(ln):
            fence = not fence
            segs.append(("line", ten, no, ln, True))
            i += 1
            continue
        if fence:
            segs.append(("line", ten, no, ln, True))
            i += 1
            continue
        m = RE_MO.match(ln)
        if m:
            nome, args = m.group(1), (m.group(2) or "").strip()
            j = i + 1
            body = []
            while j < len(lines) and lines[j].strip() != ":::":
                if RE_MO.match(lines[j]):
                    LOI.them(ten, j + 1, "khối `:::` lồng nhau hoặc thiếu `:::` đóng của khối mở ở dòng %d" % no)
                body.append((j + 1, lines[j]))
                j += 1
            if j >= len(lines):
                LOI.them(ten, no, f"khối `:::{nome}` không có `:::` đóng")
            blocks.append({"kind": nome, "args": args, "body": body, "file": ten, "line": no,
                           "h1": cur["h1"], "h2": cur["h2"], "h3": cur["h3"]})
            segs.append(("blk", len(blocks) - 1))
            i = j + 1
            continue
        mh = re.match(r"^(#{1,3}) (.+?)\s*$", ln)
        if mh:
            lv, tit = len(mh.group(1)), mh.group(2)
            heads.append((lv, tit, ten, no))
            cur["h%d" % lv] = tit
            if lv == 1:
                cur["h2"] = cur["h3"] = None
            if lv == 2:
                cur["h3"] = None
        segs.append(("line", ten, no, ln, False))
        i += 1
    if fence:
        LOI.them(ten, len(lines), "code fence không đóng")
    return segs, blocks, heads, lines


def thu_tu(p):
    """Khoá sắp file nguồn: 99-on-cuoi.md luôn cuối (ASCII xếp '9' trước 'A')."""
    return (p.name.startswith("99"), p.name)


# ───────────────────────── {{trich}}: chép mã thật vào trang (PLAN §2.3, §2.7) ─────────────────────────
TRICH_GOC = ("src/", "fw/", "tb/", "tools/", "docs/", "report/", "evidence/")
TRICH_RIENG = "reports/protocol/FEED_SPEC.yaml"
TRICH_CAM = re.compile(r"(^|/)\.env|(^|/)work/")
RE_TRICH_DONG = re.compile(r"^(.+):(\d+)-(\d+)@(.+)$")
TRICH_TOI_DA = 60


def trich(ref):
    """Trả (html, None) hoặc (None, lỗi). `path::ten` (ast, file .py) hoặc `path:a-b@neo` (theo dòng, có neo)."""
    ref = ref.strip()
    m = RE_TRICH_DONG.match(ref)
    if m:
        path, a, b, neo = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)
        ten = None
    elif "::" in ref:
        path, _, ten = ref.partition("::")
        a = b = neo = None
    else:
        return None, "cần dạng path::ten hoặc path:a-b@neo"
    if path.startswith(("/", "\\")) or ".." in path.split("/") or "\\" in path:
        return None, f"đường dẫn không hợp lệ: {path}"
    if TRICH_CAM.search(path):
        return None, f"đường dẫn bị cấm (data, zipp, runs, artifacts, .env, code v1): {path}"
    if not (path.startswith(TRICH_GOC) or path == TRICH_RIENG):
        return None, f"chỉ trích file dưới {', '.join(TRICH_GOC)} hoặc {TRICH_RIENG}: {path}"
    p = GOC / path
    if not p.is_file():
        return None, f"không có file {path}"
    lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
    if ten is not None:
        if not path.endswith(".py"):
            return None, "dạng path::ten chỉ nhận file .py"
        try:
            tree = ast.parse("\n".join(lines))
        except SyntaxError as e:
            return None, f"{path} không parse được: {e}"
        node = None
        for nd in tree.body:
            if isinstance(nd, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) and nd.name == ten:
                node = nd
            elif isinstance(nd, ast.Assign) and any(isinstance(t, ast.Name) and t.id == ten for t in nd.targets):
                node = nd
            if node:
                break
        if node is None:
            return None, f"không thấy {ten} ở cấp module của {path}"
        decs = getattr(node, "decorator_list", [])
        a = min([node.lineno] + [d.lineno for d in decs])
        b = node.end_lineno
        dau = f"{path}::{ten}"
    else:
        if not 1 <= a <= b <= len(lines):
            return None, f"dòng {a}-{b} ngoài file ({len(lines)} dòng)"
        if neo not in lines[a - 1]:
            return None, f"dòng {a} của {path} không chứa neo {neo!r} (file đổi dòng?)"
        dau = path
    if b - a + 1 > TRICH_TOI_DA:
        return None, f"đoạn trích {b - a + 1} dòng > {TRICH_TOI_DA}; chuyển sang dạng path:a-b@neo"
    code = "\n".join(lines[a - 1:b])
    for c in CHUOI_CAM:
        if c in code:
            return None, f"đoạn trích chứa chuỗi cấm {c!r}"
    if RE_MA_VAY.search(code):
        return None, "đoạn trích chứa chuỗi giống mã khoản vay"
    esc = html.escape(code).replace("{", "&#123;").replace("}", "&#125;").replace("[", "&#91;")
    cap = html.escape(f"{dau} · dòng {a}–{b}")
    return f'<pre class="trich"><span class="trich-dau">{cap}</span>\n<code>{esc}</code></pre>', None


# ───────────────────────── placeholder ─────────────────────────
RE_SO = re.compile(r"\{\{so:([A-Za-z0-9_-]+)(?:\\?\|([a-z0-9]+))?\}\}")
RE_CODE = re.compile(r"\{\{code:([^}]+)\}\}")
RE_DOC = re.compile(r"\{\{doc:([^}]+)\}\}")
RE_BAIPH = re.compile(r"\{\{bai:([A-HX]\d+)\}\}")
RE_S = re.compile(r"\[S-(\d\d)\]")
RE_TRICH = re.compile(r"\{\{trich:([^}]+)\}\}")


def tach_code(t):
    """`d = {{so:x}}`: placeholder mở rộng thành thẻ HTML, trong code span sẽ hiện nguyên chữ thẻ; đưa nó ra ngoài span."""
    def tach(m):
        if "{{" not in m.group(1):
            return m.group(0)
        ra = []
        for p in re.split(r"(\{\{.*?\}\})", m.group(1)):
            lo = p.strip()
            ra.append(p if p.startswith("{{") or not lo else p.replace(lo, f"`{lo}`", 1))
        return "".join(ra)
    return re.sub(r"`([^`\n]*)`", tach, t)


def expand(text, f, n, bai_co):
    text = tach_code(text)

    def so(m):
        id_, kieu = m.group(1), m.group(2)
        if id_ not in so_ktmt.SO:
            LOI.them(f, n, f"{{{{so:{id_}}}}}: ID không có trong so_ktmt.py")
            return "??"
        try:
            v = so_ktmt.hien(id_, kieu)
        except Exception as e:  # noqa: BLE001
            LOI.them(f, n, f"{{{{so:{id_}}}}}: {e}")
            return "??"
        _, _, nguon, gioi = so_ktmt.SO[id_]
        tip = html.escape(f"{nguon} · {gioi}".replace("|", "/"), quote=True)
        return f'<span class="so" title="{tip}">{v}</span>'

    def code(m):
        ref = m.group(1).strip()
        path, _, sym = ref.partition("::")
        if False:
            LOI.them(f, n, f"{{{{code:{ref}}}}}: code v1 bị cấm (PLAN §1)")
        p = GOC / path
        if not p.is_file():
            LOI.them(f, n, f"{{{{code:{ref}}}}}: không có file {path}")
        elif sym:
            src = p.read_text(encoding="utf-8", errors="replace")
            if not re.search(rf"(^|\n)\s*(def|class)\s+{re.escape(sym)}\b|(^|\n){re.escape(sym)}\s*=", src):
                LOI.them(f, n, f"{{{{code:{ref}}}}}: không thấy def/class/gán {sym} trong {path}")
        return f"<code>{html.escape(ref)}</code>"

    def doc(m):
        ref = m.group(1).strip()
        path, _, dong = ref.rpartition(":")
        if not dong.isdigit():
            LOI.them(f, n, f"{{{{doc:{ref}}}}}: thiếu :số-dòng")
            return "??"
        p = GOC / path
        if not p.is_file():
            LOI.them(f, n, f"{{{{doc:{ref}}}}}: không có file {path}")
        elif len(p.read_text(encoding="utf-8", errors="replace").splitlines()) < int(dong):
            LOI.them(f, n, f"{{{{doc:{ref}}}}}: file ngắn hơn {dong} dòng")
        return f"<code>{html.escape(ref)}</code>"

    def bai(m):
        b = m.group(1)
        if b in bai_co:
            return f'<a class="bai-link" href="#bai-{b.lower()}">{b}</a>'
        return f'<span class="bai-chua" title="bài này dựng ở phiên sau">{b}</span>'

    def nguon(m):
        s = "S-" + m.group(1)
        if s not in NGUON_IDS:
            LOI.them(f, n, f"[{s}] không có trong nguon_chuan.csv")
        return f'<a class="src" href="#nguon-{s}">[{s}]</a>'

    def tr(m):
        if text.strip() != m.group(0):
            LOI.them(f, n, "{{trich:...}} phải đứng riêng một dòng")
            return "??"
        h, loi = trich(m.group(1))
        if loi:
            LOI.them(f, n, f"{{{{trich:{m.group(1).strip()}}}}}: {loi}")
            return "??"
        return h

    t = RE_TRICH.sub(tr, text)  # trước các placeholder khác
    t = RE_SO.sub(so, t)
    t = RE_CODE.sub(code, t)
    t = RE_DOC.sub(doc, t)
    t = RE_BAIPH.sub(bai, t)
    t = RE_S.sub(nguon, t)
    k = t.find("{{")
    if k >= 0:
        LOI.them(f, n, f"placeholder lạ: {t[k:k + 40]!r}")
    return t


def expand_body(body, bai_co):
    return "\n".join(expand(t, f, n, bai_co) for (f, n, t) in body)


# ───────────────────────── MCQ ─────────────────────────
def parse_mcq(b):
    f, n0 = b["file"], b["line"]
    m = re.fullmatch(r"id=(\S+)", b["args"])
    if not m:
        LOI.them(f, n0, "`:::mcq` cần đúng `id=<ID>`")
        return None
    id_ = m.group(1)
    if not RE_ID.match(id_):
        LOI.them(f, n0, f"ID MCQ {id_!r} sai dạng (<mã bài>-NN, <khối>-Dnn, BT-NN, TC-NN, VS-NN, R-NN)")
    q, opts, expl = [], [], []
    stage = "q"
    for no, ln in b["body"]:
        if not ln.strip():
            continue
        if ln.startswith("? "):
            q.append((no, ln[2:]))
        elif re.match(r"^- \[( |x)\] ", ln):
            stage = "o"
            opts.append((no, ln[3] == "x", ln[6:]))
        elif ln.startswith("> "):
            stage = "e"
            expl.append((no, ln[2:]))
        elif stage == "q" and q:
            q.append((no, ln))
        elif stage == "e":
            expl.append((no, ln))
        else:
            LOI.them(f, no, f"dòng lạ trong MCQ {id_}: {ln[:40]!r}")
    if not q:
        LOI.them(f, n0, f"MCQ {id_}: thiếu dòng `? câu hỏi`")
    if len(opts) != 4:
        LOI.them(f, n0, f"MCQ {id_}: cần đúng 4 lựa chọn, có {len(opts)}")
    if sum(1 for _, ok, _ in opts if ok) != 1:
        LOI.them(f, n0, f"MCQ {id_}: cần đúng 1 lựa chọn [x]")
    if not expl or not expl[0][1].startswith("Giải thích:"):
        LOI.them(f, n0, f"MCQ {id_}: thiếu dòng `> Giải thích:`")
    else:
        ex = " ".join(t for _, t in expl)
        if re.search(r"\b(đáp án|lựa chọn|phương án|câu)\s+[A-D]\b|\([A-D]\)", ex):
            LOI.them(f, n0, f"MCQ {id_}: giải thích nhắc chữ cái A/B/C/D (lựa chọn bị xáo)")
    return {"id": id_, "q": q, "opts": opts, "expl": expl, "file": f, "line": n0, "h2": b["h2"], "h3": b["h3"]}


def render_mcq(q, bai_co, copy=False):
    f = q["file"]
    id_ = q["id"]
    order = list(range(len(q["opts"])))
    random.Random(id_).shuffle(order)
    qt = md_inline(expand_body([(f, n, t) for n, t in q["q"]], bai_co))
    ex = expand_body([(f, n, t) for n, t in q["expl"]], bai_co)
    ex = md_inline(ex.replace("Giải thích:", "", 1).strip()) if ex else ""
    btn = []
    for pos, oi in enumerate(order):
        _, ok, txt = q["opts"][oi]
        t = md_inline(expand(txt, f, q["line"], bai_co))
        btn.append(f'<button type="button" class="opt" data-i="{pos}" data-ok="{1 if ok else 0}">'
                   f'<span class="mk" aria-hidden="true"></span><span class="ot">{t}</span></button>')
    cp = ' data-copy="1"' if copy else ""
    return (f'<div class="mcq" role="group" aria-label="Câu trắc nghiệm {id_}" data-id="{id_}"{cp}>'
            f'<div class="qid">{id_}</div><div class="q">{qt}</div><div class="opts">{"".join(btn)}</div>'
            f'<div class="expl" hidden><strong>Giải thích.</strong> {ex}</div>'
            f'<div class="mfoot"><button type="button" class="redo" hidden>Làm lại</button>'
            f'<span class="res"></span></div></div>')


# ───────────────────────── dựng ─────────────────────────
def main(check_only):
    so_ktmt.check()  # sai thì AssertionError, thoát mã khác 0
    files = sorted(NGUON.glob("*.md"), key=thu_tu)
    if not files:
        print("nguon/ trống")
        return 1
    parsed = [(p, *parse_file(p)) for p in files]
    # chỉ mục bài
    bai_co, khoi_info = set(), []
    for p, segs, blocks, heads, lines in parsed:
        for lv, tit, f, no in heads:
            m = RE_BAI.match(tit) if lv == 2 else None
            if m:
                if m.group(1) in bai_co:
                    LOI.them(f, no, f"bài {m.group(1)} trùng")
                bai_co.add(m.group(1))
    # MCQ
    mcqs, ids_thay = {}, {}
    for p, segs, blocks, heads, lines in parsed:
        for b in blocks:
            if b["kind"] == "mcq":
                q = parse_mcq(b)
                if q:
                    if q["id"] in mcqs:
                        LOI.them(b["file"], b["line"], f"ID MCQ {q['id']} trùng với {mcqs[q['id']]['file']}:{mcqs[q['id']]['line']}")
                    mcqs[q["id"]] = q
    # kiểm khuôn + đếm
    rows_khoi, rows_bai = [], []
    for p, segs, blocks, heads, lines in parsed:
        stem = p.name[:2]
        h1s = [h for h in heads if h[0] == 1]
        if len(h1s) != 1:
            LOI.them(p.name, 1, f"mỗi file cần đúng 1 heading `#` (có {len(h1s)})")
        h1 = h1s[0][1] if h1s else p.name
        m1 = re.match(r"^Khối ([A-C])\b", h1)
        khoi = m1.group(1) if m1 else None
        bai_h = [h for h in heads if h[0] == 2]
        dem = {"mcq": 0, "tl": 0, "sd": 0}
        for b in blocks:
            k = b["kind"]
            if k not in ("mcq", "suy-dan", "tu-luan", "nhac", *NHAN_HOP):
                LOI.them(b["file"], b["line"], f"khối `:::{k}` không có trong cú pháp")
            if k in ("suy-dan", "tu-luan") and not any(t.strip() == "---" for _, t in b["body"]):
                LOI.them(b["file"], b["line"], f"khối `:::{k}` cần dòng `---` ngăn đề bài và lời giải")
            if k == "nhac":
                m = re.fullmatch(r"ids=([A-Za-z0-9,\-]+)", b["args"])
                if not m:
                    LOI.them(b["file"], b["line"], "`:::nhac` cần `ids=ID1,ID2,...`")
                else:
                    for i_ in m.group(1).split(","):
                        if i_ not in mcqs:
                            LOI.them(b["file"], b["line"], f"`:::nhac` trỏ ID {i_} không tồn tại")
        for i, (lv, tit, f, no) in enumerate(bai_h):
            end = bai_h[i + 1][3] if i + 1 < len(bai_h) else len(lines) + 1
            mb = RE_BAI.match(tit)
            md_ = re.match(r"^Đề nhanh khối ([A-C])\b", tit)
            bk = [b for b in blocks if b["h2"] == tit]
            q_trong = [q for q in mcqs.values() if q["file"] == p.name and q["h2"] == tit]
            if mb and stem not in KHOI_BO_QUA_KHUON:
                code = mb.group(1)
                if khoi and not code.startswith(khoi):
                    LOI.them(f, no, f"bài {code} nằm sai khối {khoi}")
                h3 = [h for h in heads if h[0] == 3 and no < h[3] < end]
                ten_h3 = [h[1] for h in h3]
                muc_bai = MUC + ["Thầy chỉ vào dòng này"] if code.startswith("P") else MUC  # bài P có thêm mục cuối (brief 12/11)
                if ten_h3 != muc_bai:
                    LOI.them(f, no, f"bài {code}: 9 mục `###` sai. Có {ten_h3}")
                dong = sum(1 for t in lines[no - 1:end - 1] if t.strip())
                if dong < 200:
                    LOI.them(f, no, f"bài {code}: {dong} dòng < 200")
                sd = [b for b in bk if b["kind"] == "suy-dan"]
                if not sd and "Bài này không có suy dẫn" not in "\n".join(lines[no - 1:end - 1]):
                    LOI.them(f, no, f"bài {code}: thiếu `:::suy-dan` (hoặc câu `Bài này không có suy dẫn`)")
                tl = [b for b in bk if b["kind"] == "tu-luan"]
                if len(tl) < 3:
                    LOI.them(f, no, f"bài {code}: {len(tl)} tự luận < 3")
                n_mcq = 8 if code.startswith("P") else 5
                if len(q_trong) != n_mcq:
                    LOI.them(f, no, f"bài {code}: {len(q_trong)} MCQ, cần {n_mcq}")
                da2 = 0
                for q in q_trong:
                    if not q["id"].startswith("KT-" + code + "-"):
                        LOI.them(q["file"], q["line"], f"MCQ {q['id']} nằm trong bài {code}, ID phải bắt đầu KT-{code}-")
                    txt = " ".join(t for _, t in q["q"] + q["expl"]) + " ".join(o[2] for o in q["opts"])
                    if re.search(r"WatchChip|\{\{(so|code|doc):", txt):
                        da2 += 1
                if da2 < 2:
                    LOI.them(f, no, f"bài {code}: chỉ {da2} MCQ gắn chip (cần ≥ 2: nhắc WatchChip hoặc dùng {{so/code/doc}})")
                for mc in q_trong:
                    if mc["h3"] != MUC[-1]:
                        LOI.them(mc["file"], mc["line"], f"MCQ {mc['id']} phải nằm ở mục `{MUC[-1]}`")
                for b in bk:
                    muc_can = {"ban-do": MUC[0], "suy-dan": MUC[4], "trong-chip": MUC[5], "bay": MUC[6], "sua-tai-cho": MUC[7],
                               "dung-o-dau": MUC[7], "tu-luan": MUC[8]}.get(b["kind"])
                    if muc_can and b["h3"] != muc_can:
                        LOI.them(b["file"], b["line"], f"khối `:::{b['kind']}` phải nằm ở mục `{muc_can}`")
                for kind, mn in (("ban-do", 1), ("trong-chip", 1), ("sua-tai-cho", 1), ("dung-o-dau", 1)):
                    if sum(1 for b in bk if b["kind"] == kind) != mn:
                        LOI.them(f, no, f"bài {code}: cần đúng {mn} khối `:::{kind}`")
                nb = sum(1 for b in bk if b["kind"] == "bay")
                if not 3 <= nb <= 5:
                    LOI.them(f, no, f"bài {code}: {nb} khối `:::bay`, cần 3–5")
                rows_bai.append((code, dong, len(q_trong), da2, len(tl), len(sd)))
            elif md_:
                if len(q_trong) != 25:
                    LOI.them(f, no, f"Đề nhanh khối {md_.group(1)}: {len(q_trong)} MCQ, cần 25")
                if sum(1 for b in bk if b["kind"] == "tu-luan") != 1:
                    LOI.them(f, no, "Đề nhanh: cần đúng 1 tự luận tổng hợp")
                for q in q_trong:
                    if not re.fullmatch(rf"KT-{md_.group(1)}-D\d\d", q["id"]):
                        LOI.them(q["file"], q["line"], f"MCQ {q['id']} trong Đề nhanh phải dạng KT-{md_.group(1)}-Dnn")
        # Hỏi lại bức tranh + Đề nhanh (chỉ khối có chữ cái)
        if khoi:
            tem = [h for h in heads if h[0] == 3 and h[1] == "Hỏi lại bức tranh"]
            if not tem:
                LOI.them(p.name, 1, "thiếu `### Hỏi lại bức tranh` đầu khối")
            elif not any(b["kind"] == "nhac" for b in blocks):
                LOI.them(p.name, tem[0][3], "`### Hỏi lại bức tranh` cần khối `:::nhac`")
            if not any(RE_BAI.match(h[1]) for h in bai_h):
                LOI.them(p.name, 1, "khối chưa có bài nào")
            if not any(h[1].startswith("Đề nhanh khối") for h in bai_h):
                print(f"  ghi chú: {p.name} chưa có `## Đề nhanh khối {khoi}` (khối chưa dựng xong)")
        prefix = {"00": "KT-H", "99": "KT-R"}.get(stem)
        if prefix:
            for q in mcqs.values():
                if q["file"] == p.name and not q["id"].startswith(prefix + "-"):
                    LOI.them(q["file"], q["line"], f"MCQ {q['id']} trong {p.name} phải bắt đầu {prefix}-")
        dem["mcq"] = sum(1 for q in mcqs.values() if q["file"] == p.name)
        dem["tl"] = sum(1 for b in blocks if b["kind"] == "tu-luan")
        dem["sd"] = sum(1 for b in blocks if b["kind"] == "suy-dan")
        rows_khoi.append((p.name, sum(1 for h in bai_h if RE_BAI.match(h[1])), dem["mcq"], dem["tl"], dem["sd"]))
    # pass 2: ghép markdown, mở rộng placeholder
    blocks_all = []
    out_md = []
    for p, segs, blocks, heads, lines in parsed:
        base = len(blocks_all)
        blocks_all.extend(blocks)
        for s in segs:
            if s[0] == "line":
                _, f, no, ln, fence = s
                out_md.append(ln if fence else expand(ln, f, no, bai_co))
            else:
                out_md.append(f"\n<!--BLK:{base + s[1]}-->\n")
        out_md.append("")
    rendered = {}
    for idx, b in enumerate(blocks_all):
        k, f = b["kind"], b["file"]
        body = [(f, n, t) for n, t in b["body"]]
        if k in NHAN_HOP:
            rendered[idx] = (f'<div class="hop hop-{k}"><div class="hop-tag">{NHAN_HOP[k]}</div>'
                             f'{md(expand_body(body, bai_co))}</div>')
        elif k in ("suy-dan", "tu-luan"):
            cut = next((i for i, (_, _, t) in enumerate(body) if t.strip() == "---"), None)
            if cut is None:
                continue
            de = md(expand_body(body[:cut], bai_co))
            dap = md(expand_body(body[cut + 1:], bai_co))
            tag = "Tự làm trước, rồi mở lời giải" if k == "suy-dan" else "Tự viết trước, rồi mở đáp án"
            sm = "Mở lời giải" if k == "suy-dan" else "Mở đáp án"
            rendered[idx] = (f'<div class="hop hop-{k}"><div class="hop-tag">{tag}</div>{de}'
                             f'<details><summary>{sm}</summary>{dap}</details></div>')
        elif k == "mcq":
            m = re.fullmatch(r"id=(\S+)", b["args"])
            if m and m.group(1) in mcqs:
                rendered[idx] = render_mcq(mcqs[m.group(1)], bai_co)
        elif k == "nhac":
            m = re.fullmatch(r"ids=([A-Za-z0-9,\-]+)", b["args"])
            if m:
                cards = "".join(render_mcq(mcqs[i_], bai_co, copy=True) for i_ in m.group(1).split(",") if i_ in mcqs)
                rendered[idx] = ('<div class="hop hop-nhac"><div class="hop-tag">Hỏi lại những gì đã học '
                                 '(kết quả ghi vào câu gốc)</div>' + cards + "</div>")
    body_html = md("\n".join(out_md))
    for idx, h in rendered.items():
        body_html = body_html.replace(f"<!--BLK:{idx}-->", h)
    if "<!--BLK:" in body_html:
        LOI.them("(dựng)", 0, "còn khối chưa thay (khối lỗi)")
    soup = BeautifulSoup(body_html, "html.parser")
    for a in soup.find_all("a", href=True):
        if a["href"].startswith("#") and not a["href"].startswith(("#nguon-", "#bai-")):
            pass
    # nhóm thành khối > bài
    khois, cur_k, cur_b = [], None, None
    for node in list(soup.contents):
        nm = getattr(node, "name", None)
        if nm == "h1":
            t = node.get_text()
            mk = re.match(r"^Khối ([A-C])\b", t)
            kid = f"khoi-{mk.group(1).lower()}" if mk else slug(t)
            cur_k = {"id": kid, "title": t, "h1": node, "intro": [], "bai": []}
            khois.append(cur_k)
            cur_b = None
        elif nm == "h2" and cur_k is not None:
            t = node.get_text()
            mb, md_ = RE_BAI.match(t), re.match(r"^Đề nhanh khối ([A-C])\b", t)
            bid = f"bai-{mb.group(1).lower()}" if mb else (f"de-nhanh-{md_.group(1).lower()}" if md_ else slug(t))
            cur_b = {"id": bid, "title": t, "h2": node, "body": []}
            cur_k["bai"].append(cur_b)
        elif cur_b is not None:
            cur_b["body"].append(node)
        elif cur_k is not None:
            cur_k["intro"].append(node)
    # id trùng + liên kết nội bộ
    all_ids = {"nguon"}
    for k in khois:
        for i_ in [k["id"]] + [b["id"] for b in k["bai"]]:
            if i_ in all_ids:
                LOI.them("(dựng)", 0, f"id heading trùng: {i_}")
            all_ids.add(i_)
    all_ids |= {f"nguon-{s}" for s in NGUON_IDS}
    for a in soup.find_all("a", href=True):
        if a["href"].startswith("#") and a["href"][1:] not in all_ids:
            LOI.them("(dựng)", 0, f"liên kết nội bộ {a['href']} không có đích")
    if RE_MA_VAY.search(body_html):  # lớp cuối: cả phần {{trich}} đã mở rộng
        LOI.them("(dựng)", 0, "HTML cuối chứa chuỗi giống mã khoản vay")
    lo_the = re.findall(r"&lt;(?:span class=|code&gt;|a class=)", body_html)
    if lo_the:
        LOI.them("(dựng)", 0, f"{len(lo_the)} chỗ hiện nguyên chữ thẻ HTML (placeholder trong code span)")
    if LOI.ds:
        print("LỖI:")
        for d in LOI.ds:
            print("  " + d)
        return 1
    # bảng đếm
    print("Bảng đếm theo khối:")
    print(f"  {'file':<22}{'bài':>5}{'MCQ':>6}{'tự luận':>9}{'suy dẫn':>9}")
    for r in rows_khoi:
        print(f"  {r[0]:<22}{r[1]:>5}{r[2]:>6}{r[3]:>9}{r[4]:>9}")
    if rows_bai:
        print("Độ dày từng bài (≥200 dòng; 5 MCQ, ≥2 gắn chip; ≥3 tự luận; ≥1 suy dẫn):")
        print(f"  {'bài':<6}{'dòng':>6}{'MCQ':>5}{'MCQ-chip':>9}{'tự luận':>9}{'suy dẫn':>9}")
        for r in rows_bai:
            print(f"  {r[0]:<6}{r[1]:>6}{r[2]:>5}{r[3]:>9}{r[4]:>9}{r[5]:>9}")
    print(f"Tổng: {len(mcqs)} MCQ duy nhất, {len(bai_co)} bài, {len(so_ktmt.SO)} ID số.")
    if check_only:
        print("--check PASS (không ghi file)")
        return 0
    # thêm thuộc tính, bọc bảng
    mcq_khoi = {}
    for k in khois:
        for part in k["intro"] + [n for b in k["bai"] for n in b["body"]]:
            if hasattr(part, "find_all"):
                for c in ([part] if "mcq" in (part.get("class") or []) else []) + part.find_all(class_="mcq"):
                    c["data-khoi"] = k["title"]
                    mcq_khoi.setdefault(c["data-id"], k["title"])
    for t in soup.find_all("table"):
        w = soup.new_tag("div", attrs={"class": "tw"})
        t.wrap(w)
    # lắp
    nav, body = [], []

    def html_of(nodes):
        return "".join(str(x) for x in nodes)

    for k in khois:
        links = "".join(
            f'<a class="nb" href="#{b["id"]}" data-b="{b["id"]}"><span class="nt">{html.escape(b["title"])}</span>'
            f'<span class="badge" hidden></span></a>' for b in k["bai"])
        nav.append(f'<div class="nk" data-k="{k["id"]}"><div class="nkh"><a class="nkt" href="#{k["id"]}">'
                   f'{html.escape(k["title"])}</a><button type="button" class="nkx" aria-expanded="false" '
                   f'aria-label="Mở/gập {html.escape(k["title"])}">▸</button></div><div class="nkl" hidden>{links}</div></div>')
        parts = [f'<section class="khoi" id="{k["id"]}">', str(k["h1"]),
                 f'<div class="khoi-intro">{html_of(k["intro"])}</div>']
        for b in k["bai"]:
            cls = "bai de" if b["id"].startswith("de-nhanh-") else "bai"
            parts.append(f'<section class="{cls}" id="{b["id"]}">{b["h2"]}{html_of(b["body"])}</section>')
        parts.append("</section>")
        body.append("".join(parts))
    nav.append('<div class="nk" data-k="nguon"><div class="nkh"><a class="nkt" href="#nguon">Nguồn</a></div></div>')
    rows = "".join(
        f'<tr id="nguon-{r["id"]}"><td>{r["id"]}</td><td>{html.escape(r["tac_gia"])}'
        f'{" (" + html.escape(r["nam"]) + ")" if r["nam"] else ""}. <em>{html.escape(r["ten"])}</em>. '
        f'{html.escape(r["noi_xuat_ban"])}</td><td>{html.escape(r["dung_cho"])}</td><td>{html.escape(r["trang_thai"])}</td></tr>'
        for r in NGUON_IDS.values())
    body.append('<section class="khoi" id="nguon"><h1>Nguồn</h1><div class="khoi-intro"><p>Trạng thái '
                '"đầu mối" nghĩa là chưa ai mở nguồn trong phiên lập plan; chỉ ghi số chương khi đã mở tận mắt. '
                'Bảng chép từ <code>nguon_chuan.csv</code>.</p><div class="tw"><table><thead><tr><th>ID</th><th>Nguồn</th>'
                f'<th>Dùng cho</th><th>Trạng thái</th></tr></thead><tbody>{rows}</tbody></table></div></div></section>')
    page = (TEMPLATE.replace("__NAV__", "".join(nav)).replace("__BODY__", "\n".join(body)))
    if RE_MA_VAY.search(page):
        print("LỖI: HTML cuối chứa chuỗi giống mã khoản vay; không ghi file")
        return 1
    OUT.write_text(page, encoding="utf-8")
    print(f"ĐÃ GHI {OUT} ({len(page.encode('utf-8')):,} byte)")
    return 0


TEMPLATE = r'''<!doctype html>
<html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Bộ ôn KTMT</title>
<style>
:root{--paper:#f6f3eb;--card:#fffefa;--ink:#1d3029;--muted:#58675e;--green:#27664b;--line:#d6ddd0;--warm:#f2e8cf;--ok:#dff0e3;--okb:#2f7d4f;--bad:#f8e0dc;--badb:#b2392b;--sel:#e3ecf7;--selb:#35608f}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:76px}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}
body{margin:0;background:var(--paper);color:var(--ink);font:16px/1.75 system-ui,-apple-system,"Segoe UI",sans-serif}
a{color:var(--green);text-underline-offset:3px}button,input{font:inherit;color:inherit}
button{border:1px solid var(--line);padding:7px 12px;border-radius:8px;background:var(--card);cursor:pointer}button:hover{background:#e5eddf}
a:focus-visible,button:focus-visible,input:focus-visible{outline:3px solid #ba8627;outline-offset:2px}
header{position:sticky;top:0;z-index:20;background:rgba(246,243,235,.97);border-bottom:1px solid var(--line)}
.bar{max-width:1440px;margin:auto;padding:10px 20px;display:flex;align-items:center;gap:12px}
.brand{font-size:13px;font-weight:800;letter-spacing:1.4px}.bar .sp{margin-left:auto;display:flex;gap:8px}
#mucluc-btn{display:none}
.layout{max-width:1440px;margin:auto;display:grid;grid-template-columns:272px minmax(0,960px);gap:34px;padding:24px 20px 70px}
.side{position:sticky;top:64px;align-self:start;max-height:calc(100vh - 78px);overflow:auto;padding-right:6px}
.side input[type=search]{width:100%;border:1px solid var(--line);border-radius:9px;background:var(--card);padding:9px;margin:4px 0 6px}
.quiet{font-size:12px;color:var(--muted)}.tools{display:flex;flex-wrap:wrap;gap:6px;margin:8px 0 12px}.tools button{font-size:13px;padding:5px 9px}
.nk{border-top:1px solid var(--line)}.nkh{display:flex;align-items:center;gap:4px}
.nkt{flex:1;text-decoration:none;font-weight:700;font-size:13px;padding:7px 4px;line-height:1.4}
.nkx{border:0;background:none;padding:4px 8px;font-size:14px}.nkx[aria-expanded=true]{transform:rotate(90deg)}
.nkl{padding-bottom:6px}.nb{display:flex;gap:6px;justify-content:space-between;text-decoration:none;padding:5px 6px 5px 10px;border-left:2px solid transparent;font-size:13px;line-height:1.45}
.nb:hover{border-color:var(--green);background:#e9eddf}.nb.act{border-color:var(--green);background:#dfe9d6;font-weight:650}
.nb .nt{min-width:0}.badge{flex:none;font-size:11px;background:var(--warm);border-radius:9px;padding:0 7px;align-self:flex-start;font-variant-numeric:tabular-nums}.badge.full{background:var(--ok)}
main{min-width:0}.khoi{background:var(--card);border:1px solid var(--line);border-radius:15px;padding:28px 32px;margin-bottom:24px;overflow-wrap:anywhere}
.khoi>h1{font:600 clamp(28px,4vw,40px)/1.2 "Segoe UI",system-ui,sans-serif;margin:0 0 18px;border-top:5px solid var(--green);padding-top:14px}
.bai{border-top:1px solid var(--line);margin-top:30px;padding-top:6px}
h2{font:600 26px/1.3 "Segoe UI",system-ui,sans-serif;color:var(--green);margin:20px 0 14px}h3{font-size:18px;margin:28px 0 10px;line-height:1.4;border-bottom:1px dashed var(--line);padding-bottom:3px}
p{margin:11px 0}li{margin:5px 0}
.tw{overflow-x:auto;margin:16px 0}table{border-collapse:collapse;width:100%;font-size:14px;line-height:1.6}
th,td{text-align:left;vertical-align:top;border-bottom:1px solid var(--line);padding:8px 10px}th{background:#e9eedf;color:var(--green)}
code{background:#eaf0e3;border-radius:4px;padding:1px 5px;font:13px/1.7 Consolas,monospace;overflow-wrap:anywhere}
pre{background:#1d3029;color:#f0f5e8;padding:16px;border-radius:10px;overflow:auto;line-height:1.65}pre code{background:none;color:inherit;padding:0;white-space:pre;overflow-wrap:normal}
pre.trich{white-space:normal;background:var(--card);color:var(--ink);border:1px solid var(--line);border-left:4px solid var(--green);max-width:100%;overflow-x:auto;font:13px/1.55 ui-monospace,Consolas,monospace}pre.trich code{white-space:pre;color:inherit}.trich-dau{display:block;font:600 12px/1.4 system-ui,sans-serif;color:var(--muted);margin-bottom:8px;white-space:normal;overflow-wrap:anywhere}
.so{border-bottom:1px dotted var(--green);cursor:help;font-weight:650;white-space:nowrap}.src{font-size:.85em;vertical-align:baseline}
.bai-chua{color:var(--muted);border-bottom:1px dotted var(--muted);cursor:help}
details{border:1px solid #cbd6c1;border-radius:10px;margin:12px 0;padding:10px 14px;background:#f5f7ef}summary{cursor:pointer;font-weight:650;color:var(--green)}details[open] summary{border-bottom:1px solid var(--line);padding-bottom:7px;margin-bottom:6px}
.hop{border:1px solid var(--line);border-left:5px solid var(--green);border-radius:10px;padding:10px 16px;margin:16px 0;background:#fbfaf3}
.hop-tag{font-size:11px;letter-spacing:1px;text-transform:uppercase;font-weight:800;color:var(--muted);margin-bottom:2px}
.hop-ban-do{border-left-color:#4b7ba8}.hop-bay{border-left-color:var(--badb);background:#fdf5f3}.hop-trong-chip{border-left-color:#b88b36;background:#fbf6e8}
.hop-dung-o-dau{border-left-color:#7a5aa6;background:#f7f4fb}.hop-nhac-nhanh{border-left-color:#8c9a8f;background:#f1f3ee}.hop-suy-dan,.hop-tu-luan{border-left-color:#2f7d4f}.hop-nhac{border-left-color:#35608f;background:#f2f6fb}
.mcq{border:1px solid var(--line);border-radius:10px;background:#fff;padding:12px 14px;margin:12px 0}.qid{font-size:11px;color:var(--muted);letter-spacing:.8px}.q{font-weight:600;margin:2px 0 8px}
.opts{display:grid;gap:7px}.opt{display:flex;gap:9px;text-align:left;width:100%;padding:9px 12px;border-radius:9px;line-height:1.55;background:#fbfbf6}
.opt .mk{flex:none;width:1.3em;font-weight:800}.opt:disabled{cursor:default;color:var(--ink)}
.opt.chon{background:var(--sel);border-color:var(--selb)}.opt.dung{background:var(--ok);border-color:var(--okb)}.opt.sai{background:var(--bad);border-color:var(--badb)}
.expl{margin-top:9px;padding:9px 12px;background:var(--warm);border-radius:8px;font-size:14.5px;line-height:1.65}
.mfoot{display:flex;gap:10px;align-items:center;margin-top:8px;min-height:30px}.res{font-weight:700;font-size:14px}.res.d{color:var(--okb)}.res.s{color:var(--badb)}
.de-bar{position:sticky;top:60px;z-index:5;display:flex;flex-wrap:wrap;gap:10px;align-items:center;background:var(--warm);border:1px solid var(--line);border-radius:10px;padding:9px 14px;margin:12px 0}
.de-bar output{font-weight:700}.sai-ds{margin:4px 0 0;padding-left:20px;flex-basis:100%}
#sai-panel{position:fixed;inset:0;z-index:40;background:rgba(29,48,41,.5);display:none;padding:3vh 3vw}#sai-panel.mo{display:block}
#sai-hop{background:var(--paper);max-width:900px;height:100%;margin:auto;border-radius:14px;display:flex;flex-direction:column;overflow:hidden}
#sai-top{display:flex;gap:10px;align-items:center;padding:12px 18px;border-bottom:1px solid var(--line);flex-wrap:wrap}#sai-top h2{margin:0;font-size:20px;flex:1}
#sai-body{overflow:auto;padding:6px 18px 24px}#sai-body h3{margin-top:22px}
blockquote{margin:14px 0;padding:4px 16px;border-left:3px solid #b88b36;background:var(--warm)}.bar button{white-space:nowrap}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}
#scrim{display:none}
@media(max-width:850px){
 #mucluc-btn{display:inline-block}.brand{font-size:11px;letter-spacing:1px}.bar{gap:6px}.bar button{font-size:13px;padding:6px 9px}.bar .sp{gap:6px}
 .layout{grid-template-columns:minmax(0,1fr);padding:14px 16px 60px;gap:0}
 .side{position:fixed;left:0;top:0;bottom:0;z-index:30;width:min(86vw,330px);max-height:none;background:var(--paper);padding:14px 12px 30px;transform:translateX(-105%);transition:transform .18s;box-shadow:2px 0 14px rgba(0,0,0,.25)}
 .side.open{transform:none}#scrim.open{display:block;position:fixed;inset:0;z-index:25;background:rgba(0,0,0,.35)}
 .khoi{padding:20px 15px;border-radius:12px}table{font-size:12.5px}th,td{padding:6px 6px}h2{font-size:22px}.bar{padding:8px 12px}.de-bar{top:54px}
}
@media print{header,.side,.tools,#sai-panel,.de-bar,.redo{display:none!important}.layout{display:block;padding:0}.khoi{border:0;padding:0}body{background:#fff;font:11pt/1.5 Georgia,serif}pre{white-space:pre-wrap;background:#f3f3f3;color:#000}pre code{white-space:pre-wrap}}
</style></head><body>
<header><div class="bar"><button id="mucluc-btn" type="button" aria-controls="side" aria-expanded="false">☰ Mục lục</button><div class="brand">BỘ ÔN KTMT</div>
<div class="sp"><button id="btn-sai" type="button">Ôn câu sai <span id="n-sai" class="badge">0</span></button><button type="button" onclick="window.print()">In</button></div></div></header>
<div id="scrim"></div>
<div class="layout"><aside class="side" id="side" aria-label="Mục lục">
<input id="tim" type="search" placeholder="Tìm trong bộ ôn (không cần dấu)" aria-label="Tìm"><div id="tim-st" class="quiet" role="status"></div>
<div class="tools"><button id="mo-dap" type="button">Mở các đáp án</button><button id="bo-tim" type="button">Xem tất cả</button></div>
<nav id="nav">__NAV__</nav>
<p class="quiet">Điểm trắc nghiệm là tự kiểm, không phải bằng chứng đã nắm. Kết quả lưu trong trình duyệt của máy này.</p>
</aside>
<main id="main">__BODY__</main></div>
<div id="sai-panel" role="dialog" aria-modal="true" aria-labelledby="sai-tit"><div id="sai-hop">
<div id="sai-top"><h2 id="sai-tit">Ôn câu sai</h2><button type="button" id="xoa-ls">Xoá lịch sử…</button>
<span id="xoa-xn" hidden><span class="quiet">Xoá hết kết quả đã lưu?</span> <button type="button" id="xoa-co">Có, xoá</button> <button type="button" id="xoa-khong">Không</button></span>
<button type="button" id="dong-sai">Đóng</button></div><div id="sai-body"></div></div></div>
<div id="live" class="sr" aria-live="polite"></div>
<script>
(function(){
var KEY='on-tap-ktmt-v1',mem={mcq:{}};
function ld(){try{var s=localStorage.getItem(KEY);if(s){var o=JSON.parse(s);if(o&&o.mcq)return o;}}catch(e){}return{mcq:{}};}
function sv(){try{localStorage.setItem(KEY,JSON.stringify(mem));}catch(e){}}
mem=ld();
var $=function(s,r){return(r||document).querySelector(s);},$$=function(s,r){return Array.prototype.slice.call((r||document).querySelectorAll(s));};
var live=$('#live');
function say(t){live.textContent='';setTimeout(function(){live.textContent=t;},30);}
function cards(id,root){return $$('.mcq[data-id="'+id+'"]',root);}
function reset(c){c.removeAttribute('data-done');$$('.opt',c).forEach(function(b){b.disabled=false;b.className='opt';b.querySelector('.mk').textContent='';});
 $('.expl',c).hidden=true;$('.redo',c).hidden=true;var r=$('.res',c);r.textContent='';r.className='res';}
function lock(c,i,okChoice){c.setAttribute('data-done','1');
 $$('.opt',c).forEach(function(b){b.disabled=true;var ok=b.dataset.ok==='1',mk=b.querySelector('.mk');
  b.className='opt';mk.textContent='';
  if(ok){b.classList.add('dung');mk.textContent='✓';}
  else if(String(b.dataset.i)===String(i)){b.classList.add('sai');mk.textContent='✗';}
  if(String(b.dataset.i)===String(i))b.classList.add('chon');});
 $('.expl',c).hidden=false;$('.redo',c).hidden=false;var r=$('.res',c);
 r.textContent=okChoice?'✓ Đúng':'✗ Sai (đáp án đúng được tô xanh)';r.className='res '+(okChoice?'d':'s');}
function record(id,ok){var r=mem.mcq[id]||{lan:0,sai:0};r.lan+=1;if(!ok)r.sai+=1;r.cuoi=ok?'dung':'sai';r.t=new Date().toISOString();mem.mcq[id]=r;sv();}
function answer(c,i){var id=c.dataset.id,b=$('.opt[data-i="'+i+'"]',c),ok=b.dataset.ok==='1';
 record(id,ok);cards(id).forEach(function(x){lock(x,i,ok);});refresh();say(id+(ok?': đúng':': sai'));}
function refresh(){
 $$('.bai').forEach(function(s){var link=$('.nb[data-b="'+s.id+'"]');if(!link)return;var seen={},tot=0,ok=0;
  $$('.mcq:not([data-copy])',s).forEach(function(c){if(seen[c.dataset.id])return;seen[c.dataset.id]=1;tot++;var r=mem.mcq[c.dataset.id];if(r&&r.cuoi==='dung')ok++;});
  var bd=$('.badge',link);if(tot){bd.hidden=false;bd.textContent=ok+'/'+tot;bd.className='badge'+(ok===tot?' full':'');}else bd.hidden=true;});
 var n=0;Object.keys(mem.mcq).forEach(function(k){if(mem.mcq[k].cuoi==='sai')n++;});$('#n-sai').textContent=n;}
document.addEventListener('click',function(e){
 var b=e.target.closest&&e.target.closest('.opt');
 if(b&&!b.disabled){var c=b.closest('.mcq');
  if(c.dataset.de==='1'){$$('.opt',c).forEach(function(x){x.classList.remove('chon');x.setAttribute('aria-pressed','false');});b.classList.add('chon');b.setAttribute('aria-pressed','true');c.dataset.sel=b.dataset.i;}
  else answer(c,b.dataset.i);return;}
 var r=e.target.closest&&e.target.closest('.redo');
 if(r){var c2=r.closest('.mcq');cards(c2.dataset.id).forEach(reset);if(c2.dataset.de==='1')delete c2.dataset.sel;}
});
/* đề nhanh */
function setupDe(s){var cs=$$('.mcq',s);cs.forEach(function(c){c.dataset.de='1';});
 var bar=document.createElement('div');bar.className='de-bar';
 bar.innerHTML='<button type="button" class="cham">Chấm cả đề</button><button type="button" class="lai" hidden>Làm lại cả đề</button><output aria-live="polite"></output><ol class="sai-ds"></ol>';
 s.insertBefore(bar,s.children[1]);var out=$('output',bar),ds=$('.sai-ds',bar);
 $('.cham',bar).onclick=function(){var dung=0,sai=[];
  cs.forEach(function(c){if(c.dataset.done==='1')return;var i=c.dataset.sel,ok=false;
   if(i!==undefined){ok=$('.opt[data-i="'+i+'"]',c).dataset.ok==='1';}
   record(c.dataset.id,ok);lock(c,i===undefined?-1:i,ok);c.dataset.chamdiem='1';});
  cs.forEach(function(c){var r=mem.mcq[c.dataset.id];if(r&&r.cuoi==='dung')dung++;else sai.push(c.dataset.id);});
  out.textContent='Điểm: '+dung+'/'+cs.length+' (câu chưa chọn tính là sai)';
  ds.innerHTML=sai.map(function(id){return'<li><a href="#" data-goto="'+id+'">'+id+'</a></li>';}).join('');
  $('.lai',bar).hidden=false;refresh();say(out.textContent);};
 $('.lai',bar).onclick=function(){cs.forEach(function(c){reset(c);delete c.dataset.sel;delete c.dataset.chamdiem;});out.textContent='';ds.innerHTML='';this.hidden=true;};
 bar.addEventListener('click',function(e){var a=e.target.closest('[data-goto]');if(a){e.preventDefault();cards(a.dataset.goto,s)[0].scrollIntoView({block:'center'});}});}
$$('.bai.de').forEach(setupDe);window.__setupDe=setupDe;
/* ôn câu sai */
var panel=$('#sai-panel');
function moPanel(){var body=$('#sai-body');body.innerHTML='';var sai=Object.keys(mem.mcq).filter(function(k){return mem.mcq[k].cuoi==='sai';});
 var groups={},order=[];
 $$('.mcq:not([data-copy])',$('#main')).forEach(function(c){var id=c.dataset.id;if(sai.indexOf(id)<0||groups.__seen&&groups.__seen[id])return;
  (groups.__seen=groups.__seen||{})[id]=1;var k=c.dataset.khoi||'Khác';if(!groups[k]){groups[k]=[];order.push(k);}groups[k].push(c);});
 if(!order.length){body.innerHTML='<p>Chưa có câu sai nào được lưu. Làm trắc nghiệm trong bài; câu sai sẽ xuất hiện ở đây.</p>';}
 order.forEach(function(k){var h=document.createElement('h3');h.textContent=k;body.appendChild(h);
  groups[k].forEach(function(c){var cl=c.cloneNode(true);cl.setAttribute('data-copy','1');delete cl.dataset.de;delete cl.dataset.sel;reset(cl);body.appendChild(cl);});});
 panel.classList.add('mo');$('#dong-sai').focus();}
function dongPanel(){panel.classList.remove('mo');$('#xoa-xn').hidden=true;$('#xoa-ls').hidden=false;$('#btn-sai').focus();}
$('#btn-sai').onclick=moPanel;$('#dong-sai').onclick=dongPanel;
document.addEventListener('keydown',function(e){if(e.key==='Escape'){if(panel.classList.contains('mo'))dongPanel();else closeDrawer();}});
$('#xoa-ls').onclick=function(){this.hidden=true;$('#xoa-xn').hidden=false;};
$('#xoa-khong').onclick=function(){$('#xoa-xn').hidden=true;$('#xoa-ls').hidden=false;};
$('#xoa-co').onclick=function(){mem={mcq:{}};sv();$$('.mcq').forEach(reset);refresh();moPanel();$('#xoa-xn').hidden=true;$('#xoa-ls').hidden=false;say('Đã xoá lịch sử');};
/* mục lục */
var side=$('#side'),scrim=$('#scrim'),mb=$('#mucluc-btn');
function openDrawer(){side.classList.add('open');scrim.classList.add('open');mb.setAttribute('aria-expanded','true');}
function closeDrawer(){side.classList.remove('open');scrim.classList.remove('open');mb.setAttribute('aria-expanded','false');}
mb.onclick=function(){side.classList.contains('open')?closeDrawer():openDrawer();};scrim.onclick=closeDrawer;
function moKhoi(nk,mo){var l=$('.nkl',nk),x=$('.nkx',nk);if(!l||!x)return;l.hidden=!mo;x.setAttribute('aria-expanded',mo?'true':'false');}
$$('.nk').forEach(function(nk){var x=$('.nkx',nk);if(x)x.onclick=function(){moKhoi(nk,x.getAttribute('aria-expanded')!=='true');};});
var first=$('.nk');if(first)moKhoi(first,true);
$('#nav').addEventListener('click',function(e){var a=e.target.closest('a');if(a){tim.value='';loc();if(window.matchMedia('(max-width:850px)').matches)closeDrawer();}});
/* tìm */
var tim=$('#tim');function nor(s){return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'').replace(/đ/g,'d');}
function loc(){var q=nor(tim.value.trim()),n=0;
 $$('.bai').forEach(function(s){var show=!q||nor(s.textContent).indexOf(q)>=0;s.hidden=!show;if(show)n++;});
 $$('.khoi').forEach(function(k){var any=$$('.bai',k).some(function(s){return!s.hidden;});var intro=$('.khoi-intro',k);var im=!q||(intro&&nor(intro.textContent).indexOf(q)>=0);k.hidden=!!q&&!any&&!im;});
 $('#tim-st').textContent=q?n+' phần có từ khóa':'';}
tim.addEventListener('input',loc);$('#bo-tim').onclick=function(){tim.value='';loc();};
$('#mo-dap').onclick=function(){var d=$$('details'),mo=d.some(function(x){return!x.open;});d.forEach(function(x){x.open=mo;});this.textContent=mo?'Đóng các đáp án':'Mở các đáp án';};
/* scrollspy */
var act=null;function dat(id){if(act===id)return;act=id;$$('.nb.act').forEach(function(a){a.classList.remove('act');});var a=$('.nb[data-b="'+id+'"]');
 if(a){a.classList.add('act');var nk=a.closest('.nk');moKhoi(nk,true);var t=a.offsetTop-side.clientHeight/3;if(side.scrollHeight>side.clientHeight&&getComputedStyle(side).position!=='fixed')side.scrollTop=Math.max(0,a.getBoundingClientRect().top-side.getBoundingClientRect().top+side.scrollTop-side.clientHeight/3);}}
if('IntersectionObserver' in window){var io=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting)dat(e.target.id);});},{rootMargin:'-70px 0px -65% 0px'});$$('.bai').forEach(function(s){io.observe(s);});}
window.addEventListener('beforeprint',function(){$$('details').forEach(function(d){d.dataset.o=d.open?'1':'0';d.open=true;});$$('[hidden]').forEach(function(x){if(x.matches('.bai,.khoi'))x.hidden=false;});});
window.addEventListener('afterprint',function(){$$('details').forEach(function(d){d.open=d.dataset.o==='1';});loc();});
refresh();
})();
</script></body></html>
'''


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv))
