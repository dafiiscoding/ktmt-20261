"""Sổ số KTMT: ID → giá trị đọc thẳng từ evidence/report (PLAN §4.2). Chạy trực tiếp để kiểm."""
import re
from pathlib import Path

GOC = Path(__file__).resolve().parents[2]
SO = {}


def _doc(rel, dong=None):
    t = (GOC / rel).read_text(encoding="utf-8", errors="replace")
    return t.splitlines()[dong - 1] if dong else t


def _them(id_, rel, dong, mau, mau_ra, gioi=""):
    """mau: regex phải khớp nguồn; mau_ra: chuỗi hiển thị dùng group của regex."""
    def ham():
        m = re.search(mau, _doc(rel, dong))
        assert m, f"{id_}: {rel}:{dong} không khớp {mau!r}"
        return m.expand(mau_ra)
    SO[id_] = (ham, "s", f"{rel}" + (f":{dong}" if dong else ""), gioi)


R = "evidence/20261027_regress_rbuf.log"
C = "evidence/20261026_cpi.log"
E3 = "evidence/20261026_exp_e3.log"
K = "evidence/20261026_exp_cal.log"
_them("system-tb", R, 102, r"PASS system_tb (\d+)", r"\1", "mỗi bản, cả USE_IRQ = 0")
_them("system-tb-poll", R, 111, r"USE_IRQ = 0\) (\d+)", r"\1")
_them("cosim-mars", R, 131, r"PASS cosim_mars (\d+)", r"\1")
_them("pytest", R, 132, r"(\d+) passed, (\d+) skipped", r"\1 passed, \2 skipped")
_them("cosim-iss", R, 158, r"PASS cosim_iss (\d+)", r"\1")
_them("alu-tb", R, 3, r"PASS alu_tb (\d+)", r"\1", "ca thử của alu_tb")
_them("regfile-tb", R, 62, r"PASS regfile_tb (\d+)", r"\1", "lần kiểm của regfile_tb")
_them("muldiv-tb", R, 60, r"PASS muldiv_tb (\d+)", r"\1", "ca kiểm của muldiv_tb")
_them("hazard-tb", R, 56, r"PASS hazard_tb (\d+)", r"\1", "ca kiểm của hazard_tb")
_them("irq-tb", R, 58, r"PASS irq_tb (\d+)", r"\1", "ca kiểm của irq_tb")
_them("control-tb", R, 16, r"PASS control_tb (\d+)", r"\1", "ca kiểm của control_tb")
_them("bcd-tb", R, 5, r"PASS bcd_tb (\d+)", r"\1", "ca kiểm của bcd_tb")
_them("soc-bus-tb", R, 71, r"PASS soc_bus_tb (\d+)", r"\1", "ca kiểm của soc_bus_tb")
_them("timebase-tb", R, 104, r"PASS timebase_tb (\d+)", r"\1", "ca kiểm của timebase_tb")
_them("cpi-g1", C, 47, r"\| system \| \d+ \| \d+ \| (\d)\.(\d+) \|", r"\1,\2", "firmware trên `system`")
_them("cpi-g2", C, 27, r"\| system \| \d+ \| \d+ \| (\d)\.(\d+) \|", r"\1,\2", "firmware trên `system`")
_them("g2-loaduse", C, 27, r"\| system \| \d+ \| \d+ \| [\d.]+ \| (\d+) \|", r"\1", "chu kỳ")
_them("g2-nhanh", C, 27, r"\| system \| \d+ \| \d+ \| [\d.]+ \| \d+ \| (\d+) \|", r"\1", "chu kỳ")
_them("g2-busy", C, 27, r"\| system \| \d+ \| \d+ \| [\d.]+ \| \d+ \| \d+ \| (\d+) \|", r"\1", "chu kỳ")
_them("tang-sum100", "report/3.3-cpi.md", 35, r"×(1,21)", r"×\1")
_them("tang-fact10", "report/3.3-cpi.md", 35, r"`fact10` ×(1,34)", r"×\1")
_them("tang-bcd", "report/3.3-cpi.md", 35, r"`bcd` ×(1,39)", r"×\1")
_them("e3-poll-tb", E3, 10, r"polling \| 1000 \| [\d.]+ / (\d+)\.(\d+) /", r"\1,\2 µs", "D = 1526")
_them("e3-poll-max", E3, 10, r"polling \| 1000 \| [\d.]+ / [\d.]+ / (\d+)\.(\d+)", r"\1,\2 µs", "D = 1526")
_them("e3-ngat-tb", E3, 11, r"ngắt \| 1000 \| [\d.]+ / (\d+)\.(\d+) /", r"\1,\2 µs", "D = 1526")
_them("e3-ngat-max", E3, 11, r"ngắt \| 1000 \| [\d.]+ / [\d.]+ / (\d+)\.(\d+)", r"\1,\2 µs", "D = 1526")
_them("e3-capture", "report/2.5-e3-thi-nghiem.md", 31, r"(6 000/6 000)", r"\1", "mọi D")
_them("e1-cal-20", K, None, r"\| \+20 \| 60 \| \+72 \| (\d+) \|", r"\1")
_them("e1-con-20", K, None, r"\| \+20 \| 60 \| \+72 \| \d+ \| \d+ \| \+(\d)\.(\d+) \|", r"+\1,\2 ppm", "mô phỏng tách riêng; xem cảnh báo E1′")
_them("e1-cal-250", K, None, r"\| \+250 \| 60 \| \+900 \| (\d+) \|", r"\1", "từ chối")

_them("fmt-div", "evidence/20261026_fmt.log", 17, r"G2 D=1 bcd tuần tự\s+\d+\s+(\d+)\s+\d+\s+\d+", r"\1", "chu kỳ, G2 D = 1")
_them("fmt-bcd", "evidence/20261026_fmt.log", 17, r"G2 D=1 bcd tuần tự\s+\d+\s+\d+\s+(\d+)\s+\d+", r"\1", "chu kỳ, G2 D = 1")
_them("fmt-bcdc", "evidence/20261026_fmt.log", 18, r"G2 D=1 bcd tổ hợp\s+\d+\s+\d+\s+(\d+)\s+\d+", r"\1", "chu kỳ, G2 D = 1")
_them("fmt-hw", "evidence/20261026_fmt.log", 17, r"G2 D=1 bcd tuần tự\s+\d+\s+\d+\s+\d+\s+(\d+)", r"\1", "chu kỳ, G2 D = 1")

def gia_tri(id_):
    return SO[id_][0]()


def hien(id_, kieu=None):
    return gia_tri(id_)


def check():
    for id_ in SO:
        gia_tri(id_)
    log = _doc(R)
    assert len(re.findall(r"^PASS ", log, re.M)) == 41, "số dòng PASS khác 41"
    assert re.search(r"^EXIT 0\s*$", log, re.M), "log không có EXIT 0"


if __name__ == "__main__":
    check()
    for k in SO:
        print(k, "=", gia_tri(k))
