# fw/tests/cpu — chương trình thử CPU G1 (gói C3)

Chạy: `python tools/cosim_mars.py` (mọi file) hoặc `python tools/cosim_mars.py sum100 fact10`.
Mỗi file `.s` được MARS 4.5 dịch (cấu hình CompactTextAtZero) → `.hex`, chạy trên `cpu_g1` (Icarus),
rồi so trạng thái cuối (32 GPR, vùng nhớ, số lệnh đã chạy) với MARS chạy cùng file.
Đây là golden **tạm** khi chưa có ISS (B2) và `asm.py` (B1); khi có thì so trace bằng `cmp_trace.py` (B3).

**Từ 03/10 có ISS:** `python tools/cosim_iss.py` dịch bằng `asm.py`, chạy RTL ghi trace rồi so **từng lệnh** với ISS
(replay MMIO, `cmp_trace.py`), cộng trạng thái cuối và `# expect`. Golden ISS theo spec nhóm, nên các luật "né MARS"
dưới đây không cần cho cosim_iss (chương trình ngẫu nhiên của nó có `mfhi` sau `mul` và chia 0). `cosim_mars.py` vẫn chạy
làm đối chiếu độc lập (MARS không do nhóm viết).

Luật viết chương trình để MARS và CPU nhóm cho cùng kết quả (MARS khác spec nhóm ở mấy chỗ):
- Dữ liệu ở `0x800`–`0xFF8`, `$sp` đặt `0xFF8` (MARS không ghi được `0xFFC`); không dùng `.data`.
- Không `mfhi/mflo` sau `mul` (MARS ghi HI/LO khi `mul`, spec nhóm: không đổi).
- Không `div` cho 0 (MARS để nguyên HI/LO, spec nhóm: LO = 0, HI = rs).
- Không đọc `Status` trước khi ghi (MARS reset `0xFF11`, spec nhóm 0).
- `bcd` (MARS không có): viết `bcd $rd,$rs`, script thay bằng `teq` khi dịch rồi vá mã. File có `bcd`
  hoặc MMIO thì ghi `# nomars` và kiểm bằng dòng `# expect $reg=giá trị`.
- Kết thúc bằng cách rơi khỏi cuối chương trình (MARS dừng; tb dừng khi PC = cuối).

Dòng chỉ thị (trong chú thích): `# nomars` · `# expect $v0=5050` · `# mem 0x800-0xff8` (vùng so, mặc định này).

Biến môi trường: `COSIM_CEDIV=3` (cpu_ce bật 1/3 chu kỳ, thử CPU khi `CPU_CLK_DIV` lớn) · `COSIM_TIMEOUT=15`
(giây cho 1 lần chạy RTL, dùng khi thử đột biến có vòng tổ hợp) · `COSIM_SRC=<thư mục>` (chạy với bản `src` khác).

Ngắt (02/10): `.org 0x180` (MARS không có) được script thay bằng đủ số `nop` để handler nằm đúng vector. Trong `cpu_g1_tb`,
`−188/−184/−180` là `irq_ctrl` thật, `−16` là máy phát sự kiện của tb: `sw {trễ[23:8], bit[7:0]}` → sau `trễ` chu kỳ hệ thống
bật xung sự kiện. Xem `irq.s` (C5-1…C5-4). Dịch firmware riêng: `python tools/fw_build.py <file.s> <file.hex>`.
