"""Assert cho phép tính trong phần Học nhanh (PLAN §4.2, §4.7)."""
# 1 ms = 50 000 chu kỳ; phần lẻ đơn vị 1/65 536 chu kỳ
assert round(50000 * 1e-6 * 65536, 6) == 3276.8
# CAL cho +20 ppm: D = 72 ms sau I = 3 600 000 ms, phép chia nguyên trong fw/main.s:739
D, I = 72, 3_600_000
assert D == round(I * 20 / 1e6)
assert (D * 65536) // (I // 1000) == 1310
assert (D * 65536) // (I // 1000) * 50 == 65500
# Vì sao còn +0,020 ppm: C đo được 50 000 999, lý tưởng 50 001 000, thiếu 1 chu kỳ trên 50 triệu
assert round((50001000 - 50000999) / 50_000_000 * 1e6, 3) == 0.020
# Bộ lọc |D| ≤ I / 5000 tương đương 200 ppm
assert I // 5000 == 720 and 716 <= 720 < 900
# CPI
assert round(689566 / 340257, 3) == 2.027 and round(400407 / 280321, 3) == 1.428
# 20 ppm trong một ngày: khoảng 1,7 giây
assert round(86400 * 20e-6, 1) == 1.7
# 16 bit chia 1 nhịp thành 65 536 phần
assert 2 ** 16 == 65536
# Quét LED: 8 khe, mỗi khe 1 ms
assert 1000 / 8 == 125
# 32,8 k lệnh/s: 50 MHz / 1526
assert round(50e6 / 1526 / 1000, 1) == 32.8
# −252 ở dạng 16 bit thấp
assert (-252) & 0xFFFF == 0xFF04
# div: start + 32 bước; MIPS cắt về 0
assert 1 + 32 == 33 and int(-7 / 2) == -3 and -7 - (-3) * 2 == -1
# Cùng 1 000 lệnh: G1 57,12 µs, G2 40,54 µs; +10 ppm lý tưởng 32 768
assert round(1000 * 1.428 / 25, 2) == 57.12 and round(1000 * 2.027 / 50, 2) == 40.54
assert round(10 * 3276.8) == 32768 and round(20 * 3276.8) == 65536
print("PASS H")
