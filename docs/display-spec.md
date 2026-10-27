# display-spec.md — Hiển thị, âm thanh, UART, bố cục màn hình (hợp đồng S1′)

> **Trạng thái:** BẢN NHÁP v1 (01/10/2026). Claude viết; **chủ: TV4**, người duyệt: TV2 (firmware dùng §8). Freeze cuối S1′.
> Địa chỉ + bit: `mmio-map.md` §3. Vector: `tb/vectors/seg7.txt`, `vga_points.txt`, `fmt_*.txt`.
> **Không có board** (Long chốt 01/10): chân đoạn/anode/âm thanh chỉ quan sát trong mô phỏng. Mặc định `G_DIGITS = 8`, `G_MUX = 1`, mức cao = sáng; các parameter mức tích cực giữ lại cho đủ bài nhưng không bắt buộc.

## 1. Tách lớp
CPU chỉ ghi **Display RAM** (8 ô). Bộ điều khiển hiển thị tự quét LED và tự vẽ VGA từ cùng Display RAM. Firmware không biết màn đang là LED hay VGA.

## 2. Display RAM và thanh ghi
| Thanh ghi | Định dạng | Reset |
|---|---|---|
| `DISPi` (−164 + 4i), i = 0…7 | [4:0] mã ký tự (§3), [7] dấu chấm. `DISP0` = chữ số **phải nhất** | `0x1A` (trống) |
| `BLINK_MASK` (−132) | [7:0], bit i = chữ số i nhấp nháy. **Ghi thì pha nháy về đầu (đang sáng)** | 0 |
| `BRIGHT` (−128) | [3:0], 0 = tắt, 15 = sáng nhất | 15 |

Display RAM là 8 thanh ghi flip-flop (không phải BRAM), cả bộ quét LED lẫn VGA đọc tổ hợp.

- **Xé hình** (thấy ở `clock_demo_tb` 02/10): firmware ghi 8 ô bằng 8 lệnh `sw`; nếu bộ quét đi qua giữa lúc ghi thì đúng 1 vòng quét hiện nửa cũ nửa mới (ví dụ `23.59.59` → `00.09.59` → `00.00.00`). Chip thật: 1 vòng = 8 ms, mắt không thấy → **chấp nhận, không làm bộ đệm đôi**. `tools/screen.py` đánh dấu ảnh tồn tại < 10 ms và bỏ khỏi GIF. Đáng nêu trong báo cáo (E4′).

## 3. ROM ký tự (`char_rom.v`): mã → đoạn
Đoạn xuất theo thứ tự `gfedcba` (bit 0 = a), **mức cao = sáng** trong ROM; đảo mức ở chân ra theo parameter.

| Mã | Ký tự | `gfedcba` | Mã | Ký tự | `gfedcba` |
|---|---|---|---|---|---|
| 0x00 | 0 | 0x3F | 0x0D | d | 0x5E |
| 0x01 | 1 | 0x06 | 0x0E | E | 0x79 |
| 0x02 | 2 | 0x5B | 0x0F | F | 0x71 |
| 0x03 | 3 | 0x4F | 0x10 | H | 0x76 |
| 0x04 | 4 | 0x66 | 0x11 | L | 0x38 |
| 0x05 | 5 | 0x6D | 0x12 | n | 0x54 |
| 0x06 | 6 | 0x7D | 0x13 | o | 0x5C |
| 0x07 | 7 | 0x07 | 0x14 | P | 0x73 |
| 0x08 | 8 | 0x7F | 0x15 | r | 0x50 |
| 0x09 | 9 | 0x6F | 0x16 | S | 0x6D |
| 0x0A | A | 0x77 | 0x17 | t | 0x78 |
| 0x0B | b | 0x7C | 0x18 | U | 0x3E |
| 0x0C | C | 0x39 | 0x19 | - | 0x40 |
| | | | 0x1A–0x1F | trống | 0x00 |

- Mã 0x00–0x0F trùng giá trị chữ số hex, nên mỗi nibble kết quả của lệnh `bcd` ghi thẳng vào `DISPi` được.
- Vector: `seg7.txt` (32 dòng, script tự sinh từ danh sách đoạn và tự kiểm khớp bảng này).

## 4. Quét LED 7 đoạn (`seg7_scan.v`)
Parameter: `G_DIGITS` (mặc định 8), `G_MUX` (true = các chữ số dùng chung chân đoạn, phải quét), `G_SLOT` (chu kỳ/khe, mặc định 50 000 = 1 ms), `G_BLANK` (mặc định 100 = 2 µs), `G_AN_ACTIVE_LOW`, `G_SEG_ACTIVE_LOW`.

- Khe `j` (0, 1, …, `G_DIGITS − 1`, lặp lại) dài `G_SLOT` chu kỳ và hiện chữ số j.
  - Tần số mỗi chữ số = 50·10⁶ / (`G_SLOT` × `G_DIGITS`). Với 8 chữ số: 125 Hz.
- Trong một khe, đếm `c` = 0 … `G_SLOT − 1`:
  - `c < G_BLANK`: **mọi anode tắt** (khoảng chống bóng ma). Chân đoạn **vẫn giữ chữ số cũ** (j − 1) và đổi sang chữ số j ở `c = G_BLANK`, cùng lúc anode j bật. Lý do (E4′, 27/10): transistor kéo anode tắt chậm, nên anode cũ còn dẫn thêm một lúc; nếu đoạn đổi ở `c = 0` thì phần đuôi đó hiện mẫu của chữ số mới (bóng ma) và khoảng tắt không giúp gì.
  - `G_BLANK ≤ c < G_BLANK + BRIGHT × G_STEP`: anode j bật, với `G_STEP = (G_SLOT − G_BLANK) / 15` (chia nguyên; mặc định 3 326).
  - còn lại: tắt (PWM độ sáng).
- Nháy: chữ số i tắt hẳn khi `BLINK_MASK[i] = 1` và đang ở nửa "tắt". Chu kỳ nháy 500 ms (2 Hz): sáng 250 tick ms, tắt 250 tick ms, đếm bằng `tick_ms`.
- `G_MUX = false` (kiểu LED mỗi chữ số có chân riêng, không dùng trong đồ án): mọi chữ số sáng cùng lúc, PWM và nháy vẫn áp dụng. Thí nghiệm E4′ (bóng ma, mô phỏng) dùng `G_MUX = 1`.
- Mô phỏng: `G_SLOT = 40`, `G_BLANK = 4` → `G_STEP = 2`.

## 5. Bộ tạo âm (`beeper.v`)
- `BEEP_FREQ` (−124): [15:0] **nửa chu kỳ** sóng vuông tính bằng chu kỳ hệ thống. Reset 12 500 (2 kHz). 0 = im.
- `BEEP_PATTERN` (−120): [15:0] mẫu, [16] `REPEAT`.
  - Mỗi bit là một khe 64 ms (đếm `tick_ms`). Bit 0 phát trước. 16 khe = 1 024 ms.
  - Ghi thì phát lại từ khe 0. `REPEAT = 0`: phát hết 16 khe rồi tự về 0. Ghi 0 = tắt.
  - Ví dụ: bíp nút = `0x00001` (64 ms). Báo thức = `0x10F0F` (lặp: 256 ms kêu, 256 ms nghỉ).
- **Kích bằng phần cứng:** sự kiện `TMR_ZERO` khi `BEEP_EN = 1` → nạp mẫu `0x10F0F` ngay ở chu kỳ đó, nên chuông kêu đúng ms dù CPU đang chậm. Mẫu này giữ tới khi CPU ghi `BEEP_PATTERN`.
- Ưu tiên báo thức > hết giờ > chuông giờ > bíp nút: **firmware** quyết định (không ghi đè mẫu đang phát của nguồn ưu tiên cao hơn).
- Ra chân: sóng vuông khi bit hiện tại = 1, ngược lại 0 (kiểu buzzer thụ động; mô phỏng thì testbench đếm cạnh để đo tần số).

## 6. UART 115 200 8N1 (`uart.v`)
- Parameter `G_BIT` = số chu kỳ/bit, chạy thật 434 (50·10⁶ / 434 = 115 207 baud, lệch +0,006%). Mô phỏng: `G_BIT = 8`.
- **TX:** nghỉ = 1; start 0; 8 bit dữ liệu, bit 0 trước; stop 1. Mỗi bit `G_BIT` chu kỳ. Bộ đệm 1 byte.
- **RX:** 2 FF đồng bộ → thấy cạnh xuống → chờ `G_BIT/2` → còn 0 thì là start thật (không thì về nghỉ) → lấy mẫu mỗi `G_BIT` cho 8 bit → bit stop phải là 1, sai thì `FRAME_ERR` và bỏ byte. FIFO 64 byte.
- `UART_STATUS` (−176): [0] `RX_AVAIL`, [1] `RX_OVF` (dính, ghi 1 xóa), [2] `TX_READY`, [3] `FRAME_ERR` (dính, ghi 1 xóa), [4] `TX_DROP` (ghi `UART_TX` khi chưa sẵn sàng; dính, ghi 1 xóa), [14:8] `RX_COUNT`.
- `UART_RX` (−172) R: [31] `VALID`, [7:0] byte; đọc thì lấy khỏi FIFO. `UART_TX` (−168) W: [7:0].

## 7. VGA đuổi tia (tầng 2, `vga_digits.v`)
- 640×480@60: ngang 800 = 640 hiện + 16 + 96 sync + 48; dọc 525 = 480 hiện + 10 + 2 sync + 33; sync tích cực thấp.
- Xung pixel = **clock enable** mỗi 2 chu kỳ 50 MHz (25 MHz, chuẩn là 25,175 MHz → 59,5 Hz, màn hình chấp nhận). Cùng miền clock với CPU → **không có CDC**. Nếu khung đang vẽ lúc CPU ghi Display RAM thì nửa trên/dưới có thể khác nhau một khung (16 ms), vô hại.
- Bố cục: 8 ô rộng 80 px, cao 160 px, đặt ở y ∈ [160, 320). `DISPi` vẽ ở x ∈ [80·(7−i), 80·(8−i)).
- Trong ô, tọa độ cục bộ (u, v), độ dày nét 8 px:
  | Đoạn | u | v |
  |---|---|---|
  | a | [20, 60) | [8, 16) |
  | b | [60, 68) | [16, 76) |
  | c | [60, 68) | [84, 144) |
  | d | [20, 60) | [144, 152) |
  | e | [12, 20) | [84, 144) |
  | f | [12, 20) | [16, 76) |
  | g | [20, 60) | [76, 84) |
  | dp | [70, 78) | [144, 152) |
- Màu (RGB 4-4-4): đoạn sáng `0xFFF`; đoạn tắt `0x222` (vết mờ giống LCD); nền `0x000`. Chữ số đang ở nửa "tắt" của nháy: chỉ còn vết mờ. `BRIGHT` không áp dụng cho VGA.
- Vector `vga_points.txt`: điểm (x, y) → (ô, đoạn 0…6 = a…g, 7 = dp, −1 = nền), gồm các điểm sát biên.

## 8. Bố cục màn theo chế độ (hợp đồng với firmware, 8 chữ số)
Viết từ `DISP7` (trái) sang `DISP0` (phải). `.` = bit chấm của chữ số **đứng trước** dấu. `_` = trống.

| Chế độ | Mẫu | Ghi chú |
|---|---|---|
| TIME 24 h | `__HH.MM.SS` | giờ có số 0 đầu |
| TIME 12 h | `A_HH.MM.SS` / `P_HH.MM.SS` | 0 h → 12 AM, 12 h → 12 PM |
| TIME trang 2 | `dd-MM-YY` | ngày-tháng-năm 2 số cuối |
| TIME giữ B | `_MM.SS.mmm` | phút, giây, ms |
| STOPWATCH < 1 h | `_MM.SS.mmm` | |
| STOPWATCH ≥ 1 h | `__HH.MM.SS` | tối đa 99.59.59 |
| TIMER | `sMM.SS.mmm` (< 1 h) · `s_HH.MM.SS` (< 100 h) · `s_--.--.--` (≥ 100 h) | `s` = `-` nếu âm, trống nếu ≥ 0; hiện trị tuyệt đối |
| ALARM | `ALko HH.MM` → `A L k o H H . M M` | `k` = số 1…4; `o` nếu bật, trống nếu tắt |
| SET | như TIME 24 h / trang 2 | `BLINK_MASK`: giờ `0x30`, phút `0x0C`, giây `0x03`; ngày `0xC0`, tháng `0x18`, năm `0x03` |

- Bảng ví dụ đầy đủ (giá trị → 8 byte `DISP7…DISP0`): `tb/vectors/fmt_*.txt`.
- TIMER: so `x ≤ −360 000 000` (→ `-_--.--.--`) **trước** khi lấy trị tuyệt đối. Lý do: |−2³¹| vẫn ra `0x80000000` (âm), ISA không có `sltu`, nên lấy abs trước sẽ rơi nhầm vào nhánh `< 1 h`.
- Board 6 chữ số: bỏ `DISP7`, `DISP6` (firmware có `.eqv DIGITS 6`); 12 h thì báo PM bằng chấm của `DISP0`.

## 9. Kiểm thử (TV4)
| ID | Kích thích | Mong đợi |
|---|---|---|
| D-1 | `char_rom` mọi mã 0…31 | khớp `seg7.txt` |
| D-2 | quét, `G_SLOT = 40`, `G_BLANK = 4`, 8 chữ số | thứ tự anode 0→7→0; trong 4 chu kỳ đầu mỗi khe không anode nào bật và chân đoạn vẫn là chữ số khe trước |
| D-3 | `BRIGHT` = 0 / 1 / 15 | số chu kỳ bật trong khe = 0 / 2 / 30 |
| D-4 | `BLINK_MASK = 0x01` | chữ số 0 tắt đúng tick 250…499, sáng lại ở 500; chữ số khác không đổi |
| D-5 | ghi `BLINK_MASK` giữa nửa "tắt" | sáng lại ngay |
| D-6 | mức chân ra với parameter active-low | đảo đúng |
| BP-1 | `BEEP_PATTERN = 0x00005`, `BEEP_FREQ = 4` | kêu khe 0, im khe 1, kêu khe 2, rồi im hẳn; sóng vuông đảo mỗi 4 chu kỳ |
| BP-2 | `REPEAT` | lặp sau 16 khe |
| BP-3 | sự kiện `TMR_ZERO` + `BEEP_EN` | kêu từ chu kỳ đó |
| U-1 | TX `0x55`, `G_BIT = 8` | chuỗi 0,1,0,1,0,1,0,1,0,1 mỗi bit 8 chu kỳ |
| U-2 | RX `0xA5` ở baud lệch ±2% | nhận đúng |
| U-3 | RX 65 byte không đọc | 64 byte, `RX_OVF = 1` |
| U-4 | RX bit stop = 0 | bỏ byte, `FRAME_ERR = 1` |
| U-5 | loopback TX → RX 256 byte | khớp |
| V-1 | bộ đếm VGA | `hsync` thấp ở x 656…751, `vsync` thấp ở y 490…491; 800 × 525 |
| V-2 | hàm (x, y) → (ô, đoạn) | khớp `vga_points.txt` |
| V-3 | ảnh 1 khung | xuất file `.ppm` từ testbench, mở xem bằng mắt (bằng chứng cho báo cáo) |
