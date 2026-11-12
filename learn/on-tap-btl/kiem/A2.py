"""Assert cho phép tính trong bài A2 (G1 và đường đi lw)."""
# Tần số và chu kỳ: hệ thống 50 MHz (20 ns), G1 chia đôi D = 2 ra 25 MHz (40 ns)
assert 50_000_000 / 2 == 25_000_000
assert 1_000_000_000 / 25_000_000 == 40  # 40 ns mỗi chu kỳ CPU
assert 40 / 2 == 20  # Pha A = 20 ns, Pha B = 20 ns

# Địa chỉ offset -252 mở rộng dấu 32 bit ra 0xFFFFFF04
assert (-252) & 0xFFFFFFFF == 0xFFFFFF04
# Địa chỉ vùng MMIO: 24 bit cao bằng 0xFFFFFF
assert (0xFFFFFF04 >> 8) == 0xFFFFFF

# Bảng chân lý control có 28 lệnh: 12 R, 9 I, 2 J, 2 SPECIAL2, 3 COP0
assert 12 + 9 + 2 + 2 + 3 == 28

# Lệnh test của mục "Sửa tại chỗ" phải bắt được lỗi thật (đã chạy đột biến 09/11: regfile/control vẫn PASS, system và cosim_iss FAIL)
from pathlib import Path
_ROOT = Path(__file__).resolve().parents[3]
_nguon = (Path(__file__).resolve().parents[1] / "nguon" / "01-khoi-a.md").read_text(encoding="utf-8")
_a2 = _nguon.split("## A2")[1]
assert "bash tools/run_unit.sh system" in _a2 and "python tools/cosim_iss.py" in _a2
assert "bắt ngay lập tức bởi bài kiểm tra đơn vị `regfile_tb`" not in _a2, "regfile_tb không có CPU, không bắt được lỗi pc/next_pc"
assert "run_unit.sh regfile control" not in _a2.split("Test nào sẽ bắt được lỗi này?")[1].split("```")[1], "lệnh regfile control không bắt được lỗi"
assert (_ROOT / "tools" / "cosim_iss.py").exists() and (_ROOT / "tb" / "system_tb.v").exists()
# Bẫy 2 / MCQ-04 không được nói "lệnh xuất hiện giữa chu kỳ" (RTL: instr và pc chốt cùng cạnh pha A)
assert "giữa chu kỳ mới có lệnh" not in _a2
# Không có ví dụ công nghiệp tự thêm, không có nguồn trong repo
for _x in ("Artix-7", "MAX 10", "Cortex-M0", "hàng ngàn ô LUT", "nén thời gian mô phỏng"):
    assert _x not in _a2, _x
# Từ chuyên môn giải thích ngay chỗ xuất hiện đầu tiên
for _x in ("instruction memory", "Memory-Mapped I/O", "arithmetic logic unit"):
    assert _x in _a2, _x

# Sửa 12/11: cpu_ce không phát "cứ hai nhịp"; D = 2 thì cpu_ce bật mọi nhịp, chu kỳ CPU = 2 cpu_ce (soc_regs.v: period = D/2)
assert "Cứ hai nhịp của nó" not in _a2 and "trên cùng một nhịp clock" not in _a2
assert "Ở cấu hình mặc định D = 2, `cpu_ce` bật ở mọi nhịp" in _a2 and "trên cùng một nguồn clock" in _a2
_sr = (_ROOT / "src" / "soc_regs.v").read_text(encoding="utf-8")
assert "{1'b0, d[15:1]}" in _sr and "(c >= p - 16'd1)" in _sr and "d   <= (G_CORE == 1) ? 16'd2" in _sr
print("PASS A2")
