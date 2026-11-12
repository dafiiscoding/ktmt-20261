"""Kiểm nội dung mà `dung.py --check` không thấy (rút từ lỗi K1 của model rẻ, 08/11). Người dựng không được sửa file này."""
import re
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
GOC = BASE.parents[1]
LOI = []

# Chữ của plan, lời nhắc dạy: không được lọt vào trang người đọc thấy.
CAM = ["§", "PLAN", "day-nhom", "Long dạy", "kịch bản dạy", "buổi dạy", "Codex", "<LONG"]

# Mỗi bài phải nói được các ý này. Thiếu từ là thiếu ý, không phải lỗi chính tả.
BAT_BUOC = {
    "A1": ["slt", "tràn", "33", "−7", "cộng 3", "tb/alu_tb.v"],
    "A2": ["next_pc", "pha A", "pha B", "bus_re", "MS_OF_DAY", "chụp ngày", "25 MHz", "BRAM", "bảng chân lý"],
    "A3": ["hai lượt", "co-sim", "MARS", "cùng sai", "đột biến", "cmp_trace", "waveform"],
    "A4": ["3 276,8", "65 500", "dịch số học", "từ chối", "unverified", "phần lẻ"],
    "A5": ["125", "G_BLANK", "bóng ma", "frame buffer", "8N1", "giữa bit"],
    "B1": ["IF", "EX/MEM", "MEM/WB", "forwarding", "dự đoán", "delay slot", "50 MHz", "Harvard", "cấu trúc"],
    "B2": ["load-use", "phạt 2", "busy", "flush", "bubble", "CPI", "nhánh ở ID"],
    "B3": ["EPC", "next_pc", "0x180", "eret", "ID/EX", "chờ", "IRQ_PENDING"],
    "B4": ["capture", "10 ms", "số âm", "lap", "bộ chia riêng"],
    "B5": ["events", "ringchk", "draw", "0x180", "UART", "checksum"],
    "C1": ["E1′", "E2′", "E3", "E4′", "giả định", "unverified"],
    "C2": ["CPI", "Yosys", "inference", "×1,21", "sum100", "1,34"],
    "C3": ["Claude", "mô phỏng", "câu chéo", "sửa tại chỗ"],
    "P1": ["slt", "tràn", "33", "−7", "LO", "HI", "busy", "stall", "khôi phục", "bù 2", "tb/vectors/div.txt", "run_unit.sh alu muldiv"],
    "P2": ["load-use", "forwarding", "bong bóng", "stall_lu", "id_ok", "flush", "hazard_tb", "run_unit.sh hazard", "$zero", "EX/MEM", "MEM/WB", "uses_rt"],
    "P3": ["bypass", "$zero", "valid", "control_tb", "regfile_tb", "run_unit.sh regfile control", "uses_rs", "uses_rt", "mem_to_reg", "G_BYPASS", "0x8D0D3B24", "bong bóng"],
    "P4": ["double dabble", "cộng 3", "27", "28", "pha A", "pha B", "next_pc", "take", "eret", "0x180", "bcd_tb", "run_unit.sh bcd", "FFFFFFFF", "MAXV"],
    "P5": ["cpu_ce", "pending", "enable", "0x180", "EPC", "EXL", "CP0", "irq_ctrl", "soc_regs", "run_unit.sh irq", "Cause", "mtc0", "eret", "CPU_CLK_DIV"],
    "C0": ["stall_lu", "forwarding", "bong bóng", "id_ok", "regfile", "cpu_ce", "EPC", "run_unit.sh hazard", "COSIM_SRC", "alu_zero", "ifid_v", "fwd_a", "hazard_tb"],
    "U1": ["cpu_ce", "CPU_CLK_DIV", "timebase", "CAL", "ppm", "3 276,8", "fmt_div", "fmt_bcd", "bus_rdata", "OR", "G_BLANK", "bóng ma", "ISS", "cosim", "run_unit.sh timebase", "đột biến", "BCD"],
    "V0": ["module", "wire", "reg", "assign", "always @*", "posedge", "<=", "case", "parameter", "ifdef", "testbench", "mở rộng dấu",
           "bash tools/run_unit.sh alu", "tương đương"],
}
BAT_BUOC_H0 = ["bit", "nhị phân", "địa chỉ", "Verilog", "Icarus", "testbench", "FPGA", "board", "Fmax", "Vivado", "file ràng buộc chân"]


def kiem_mcq(ten, t):
    khoi = re.findall(r"^:::mcq id=(\S+)\n(.*?)^:::$", t, re.M | re.S)
    dai_nhat = 0
    for id_, than in khoi:
        lc = re.findall(r"^- \[(.)\] (.*)$", than, re.M)
        if len(lc) != 4 or sum(x == "x" for x, _ in lc) != 1:
            LOI.append(f"{ten} {id_}: phải có 4 lựa chọn, đúng 1 đáp án")
            continue
        dung = next(len(c) for x, c in lc if x == "x")
        dai_nhat += dung > max(len(c) for x, c in lc if x != "x")
        gt = re.search(r"^> Giải thích: (.*)$", than, re.M)
        if not gt or len(gt.group(1)) < 60:
            LOI.append(f"{ten} {id_}: giải thích dưới 60 ký tự, phải nói cả vì sao ngộ nhận sai")
    if len(khoi) >= 5 and dai_nhat > len(khoi) * 0.4:
        LOI.append(f"{ten}: {dai_nhat}/{len(khoi)} câu có đáp án đúng dài nhất, đoán được; tối đa 40%")


def kiem_the(ten, t):
    for than in re.findall(r"^:::the\n(.*?)^:::$", t, re.M | re.S):
        tieu_de = than.strip().splitlines()[0]
        m = re.search(r"Thầy hay hỏi:\*\*(.*)", than)
        if not m:
            LOI.append(f"{ten} thẻ {tieu_de}: thiếu dòng Thầy hay hỏi")
        elif len(m.group(1).rsplit("?", 1)[-1]) < 15:
            LOI.append(f"{ten} thẻ {tieu_de}: có câu hỏi mà không có câu trả lời")


def kiem_thay_hoi(ten, t):
    for than in re.findall(r"^:::thay-hoi\n(.*?)^:::$", t, re.M | re.S):
        if "?" not in than or len(than.rsplit("?", 1)[-1].strip()) < 15:
            LOI.append(f"{ten}: hộp thay-hoi có câu hỏi mà không có câu trả lời: {than[:50]!r}")


def kiem_lenh(ten, t):
    """Lệnh tự kiểm phải chạy được: lỗi này đã lọt ở K1 (cpu_pipe cần +imem)."""
    for cum in re.findall(r"run_unit\.sh ([a-z0-9_ ]+)", t):
        for tb in cum.split():
            f = GOC / "tb" / f"{tb}_tb.v"
            if not f.exists():
                LOI.append(f"{ten}: run_unit.sh {tb}: không có {f.name}")
            elif "(cosim)" in f.read_text(encoding="utf-8", errors="replace").split("\n", 1)[0]:
                LOI.append(f"{ten}: run_unit.sh {tb}: tb này cần chương trình (+imem), chạy qua cosim_iss/cosim_mars")


def kiem_y(ten, t):
    bai = re.split(r"^## ", t, flags=re.M)
    for doan in bai[1:]:
        ma = doan.split(" ", 1)[0]
        if ma in BAT_BUOC:
            for tu in BAT_BUOC[ma]:
                if tu not in doan:
                    LOI.append(f"{ten} bài {ma}: thiếu ý `{tu}`")
        if ma == "H0":
            for tu in BAT_BUOC_H0:
                if tu not in doan:
                    LOI.append(f"{ten} H0: thiếu ý `{tu}`")


for p in sorted((BASE / "nguon").glob("*.md")):
    t = p.read_text(encoding="utf-8")
    for c in CAM:
        if c in t:
            LOI.append(f"{p.name}: có chữ cấm `{c}`")
    kiem_mcq(p.name, t)
    kiem_the(p.name, t)
    kiem_thay_hoi(p.name, t)
    kiem_lenh(p.name, t)
    kiem_y(p.name, t)

assert not LOI, "\n" + "\n".join(LOI)
print("PASS noi_dung")
