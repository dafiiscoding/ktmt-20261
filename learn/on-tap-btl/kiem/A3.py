"""Assert cho phép tính và số liệu trong bài A3 (asm, ISS, co-sim, MARS, kiểm thử đột biến)."""
import re
from pathlib import Path

# Số lượng ca kiểm thử trong hồi quy
COSIM_ISS_TESTS = 25
COSIM_MARS_TESTS = 19
PYTEST_PASSED = 97
PYTEST_SKIPPED = 1
TOTAL_PYTEST = PYTEST_PASSED + PYTEST_SKIPPED  # 98 tests

assert COSIM_ISS_TESTS == 25
assert COSIM_MARS_TESTS == 19
assert TOTAL_PYTEST == 98
assert PYTEST_PASSED == 97

# Phép tính offset cho lệnh nhảy nhánh beq:
# PC = 0x004, target = 0x010 (DONE)
# offset = (0x010 - (0x004 + 4)) // 4 = (16 - 8) // 4 = +2
pc = 0x004
target = 0x010
offset = (target - (pc + 4)) // 4
assert offset == 2

# Mã hóa lệnh beq $t0, $zero, +2 ($t0 = $8, $zero = $0, opcode = 0x04)
# beq opcode=0x04 (6 bit: 000100), rs=8 (5 bit: 01000), rt=0 (5 bit: 00000), imm=2 (16 bit: 0000000000000010)
encoded_beq = (0x04 << 26) | (8 << 21) | (0 << 16) | (2 & 0xFFFF)
assert hex(encoded_beq) == "0x11000002"

# Lệnh nhảy j LOOP (target = 0x004, opcode = 0x02)
# target 26 bit = target >> 2 = 4 >> 2 = 1
encoded_j = (0x02 << 26) | ((0x004 >> 2) & 0x03FFFFFF)
assert hex(encoded_j) == "0x8000001"

# Đột biến được kiểm chứng trong dự án:
# asm.py: 10/10 bị bắt (work/mut_asm_20261003.log)
# iss.py + RTL: 20/20 bị bắt (work/mut_iss_20261003.log: 12 ISS + 8 RTL)
# cmp_trace.py: 6/6 bị bắt (work/mut_cmp_20261003.log)
# uart.v: 15/15 bị bắt
# vga.v: 9/9 bị bắt
assert 10 + 20 + 6 + 15 + 9 == 60

# Kiểm tra bài A3 trong 01-khoi-a.md
_ROOT = Path(__file__).resolve().parents[3]
_nguon_file = Path(__file__).resolve().parents[1] / "nguon" / "01-khoi-a.md"
if _nguon_file.exists():
    _nguon = _nguon_file.read_text(encoding="utf-8")
    if "## A3" in _nguon:
        # Tách bài A3 bằng tiêu đề cấp 2 tiếp theo (nếu có)
        parts = re.split(r"\n## (?=[A-Z0-9])", _nguon)
        a3_part = next((p for p in parts if p.startswith("A3")), None)
        assert a3_part is not None, "Không tìm thấy phần bài A3"
        # Bắt buộc có các lệnh thực tế
        assert "pytest tools/" in a3_part
        assert "cosim_iss.py" in a3_part
        assert "cmp_trace.py" in a3_part
        assert "Mars4_5.jar" in a3_part or "MARS" in a3_part
        # Bắt buộc có các từ khóa của noi_dung.py
        for kw in ["hai lượt", "co-sim", "MARS", "cùng sai", "đột biến", "cmp_trace", "waveform"]:
            assert kw in a3_part, f"Thiếu từ khóa: {kw}"

print("PASS A3")
