# timer-spec.md — Định thời chuẩn ms: timebase, RTC, stopwatch, timer, alarm, nút, sync (hợp đồng S1′)

> **Trạng thái:** BẢN NHÁP v1 (01/10/2026). Claude viết; **chủ: TV5**, người duyệt: TV3. Freeze cuối S1′.
> Địa chỉ + bit: `mmio-map.md` §3 (file đó thắng nếu lệch). Vector: `tb/vectors/timebase_*.txt`, `sync_*.txt`.
> Mọi số chu kỳ dưới đây tính theo `G_N` (chu kỳ/ms). Chạy thật (50 MHz): `G_N = 50 000`. **Mô phỏng: `G_N = 50`** để chạy nhanh; công thức timebase giữ nguyên. Lưu ý: cùng một `CAL` thì ppm đổi theo `G_N` (`CAL = 163 840` = +2,5 chu kỳ/ms: +50 ppm ở board, +5% ở mô phỏng); hằng `× 50` của §9 giả định `G_N = 50 000`.

## 1. Nguyên tắc
- Mọi bộ đếm thời gian chạy bằng **phần cứng ở 50 MHz**, không phụ thuộc CPU nhanh hay chậm. CPU chỉ đọc/ghi thanh ghi.
- Bộ đếm cần chính xác **tính từ lúc bắt đầu** (stopwatch, timer) có **bộ chia riêng**, xóa pha ở lúc bắt đầu, nên không bị sai ±1 ms do lệch pha với nhịp ms chung.
- Mọi bộ chia dùng chung một thanh ghi `CAL`.

## 2. Timebase: bộ chia phân số có hiệu chỉnh (`timebase.v`)
Cổng: `clk, rst, clr, en, signed [31:0] cal → tick`. Parameter `G_N`.

Ms thứ k (k = 0, 1, 2… sau `clr` hoặc reset):
```
s_k     = frac_k + CAL            (CAL lấy mẫu ở đầu ms thứ k)
len_k   = G_N + floor(s_k / 65536)  (= s_k >> 16 dịch số học)
frac_k+1 = s_k mod 65536           (= 16 bit thấp của s_k)
frac_0  = 0
```
- Bộ đếm `cnt` chạy 0 … `len_k − 1` ở các chu kỳ có `en = 1`. `tick = 1` đúng 1 chu kỳ khi `cnt = len_k − 1` và `en = 1`.
- Tick thứ k (k ≥ 1) rơi vào chu kỳ đếm thứ `T_k = len_0 + … + len_(k−1)` (đếm từ 1).
- Tổng K ms = `K·G_N + floor(K·CAL / 65536)` chu kỳ (kiểm bằng vector `timebase_total.txt`).
- `clr = 1`: `cnt ← 0`, `frac ← 0`. `en = 0`: giữ nguyên `cnt`, `frac` (tạm dừng, không mất phần lẻ).
- **Quy ước dấu:** `CAL > 0` → ms dài hơn → đồng hồ **chậm lại**. Dùng khi chip chạy nhanh.
- Đổi đơn vị: 1 ppm = 3 276,8 đơn vị `CAL`. Ví dụ +50 ppm → `CAL = 163 840` (2,5 chu kỳ/ms: các ms dài 50 002 và 50 003 xen kẽ).
- Phạm vi dùng: |`CAL`| ≤ 655 360 (±200 ppm). Ngoài phạm vi: phần cứng vẫn theo công thức, firmware có trách nhiệm chặn.
- `CAL` (−232) R/W, reset 0, ghi có hiệu lực từ ms kế tiếp.
- **Timebase chính:** `en = 1`, chỉ `clr` lúc reset. Sinh `tick_ms` cho RTC, alarm, nút, hiển thị, beeper, `TICK_1MS`.

## 3. RTC (`rtc` trong `timers.v`)
Trạng thái: `ms` 27 bit (0 … 86 399 999), `day` 16 bit (số ngày kể từ 01/01/2000), `dow` 3 bit (0 = Chủ nhật … 6 = Thứ bảy; 01/01/2000 là Thứ bảy → `dow = 6`). **Reset:** `ms = 0`, `day = 0`, `dow = 6`.

Ở mỗi `tick_ms`:
1. Nếu đang chờ nạp (`ARM`): `ms ← SET_MS`, `day, dow ← SET_DAY`, xóa `ARM`, xóa bộ đếm `TICK_1S`. **Không** xét báo thức ở tick này.
2. Ngược lại nếu `ms = 86 399 999`: `ms ← 0`, `day ← day + 1` (quay vòng 16 bit), `dow ← (dow + 1) mod 7`.
3. Ngược lại `ms ← ms + 1`.

| Thanh ghi | Định dạng |
|---|---|
| `MS_OF_DAY` (−252) R | [26:0] `ms`. **Cùng cạnh đọc**, chụp `{dow, day}` vào `DAY_SHADOW` |
| `DAY_SHADOW` (−248) R | [18:16] `dow`, [15:0] `day` (giá trị chụp, cùng chu kỳ với `ms` vừa đọc) |
| `SET_MS` (−244) W | [26:0]; nếu ≥ 86 400 000 thì nạp 0 |
| `SET_DAY` (−240) W | [18:16] `dow` (7 → 0), [15:0] `day` |
| `RTC_CTRL` (−236) R/W | [0] `ARM`: ghi 1 = chờ nạp ở tick kế tiếp; ghi 0 = hủy lệnh nạp đang chờ (bản 02/10, TV5 duyệt); đọc 1 = chưa nạp. Ghi cùng chu kỳ với tick: tick dùng `ARM` cũ |

- `TICK_1S`: bộ đếm 0…999 theo `tick_ms`, xóa khi nạp RTC. **Không** canh theo giây của RTC (giờ nạp lẻ ms thì lệch pha); firmware cần đúng giây thì đọc `MS_OF_DAY`.
- Xé số: firmware luôn đọc `MS_OF_DAY` rồi mới đọc `DAY_SHADOW`, không đọc ngày trực tiếp.

## 4. Stopwatch (`stopwatch` trong `timers.v`)
- Giá trị 29 bit, tối đa `G_SW_MAX` = 359 999 999 (99:59:59.999); tới đó thì đứng yên và bật `OVF`.
- **Bộ chia riêng** (một bản `timebase`): `en = RUN`, `clr` khi `RESET`. Giá trị +1 ở mỗi tick của nó.
  - → Với `CAL = 0`: chạy tổng cộng C chu kỳ (cộng dồn mọi lần chạy) thì giá trị = `floor(C / G_N)`, chính xác tới chu kỳ, không lệch pha.
- `SW_CTRL` (−228):
  | Bit | Tên | Đọc | Ghi |
  |---|---|---|---|
  | 0 | `RUN` | đang chạy | đặt RUN (chỉ khi ghi `SRC = 0`) |
  | 1 | `RESET` | 0 | 1 = giá trị ← 0, xóa bộ chia, xóa FIFO lap, xóa `OVF`, `LAP_OVF` |
  | 2 | `SRC` | nguồn điều khiển | 0 = CPU, 1 = nút phần cứng |
  | 3 | `OVF` | đã bão hòa | — |
  | 4 | `LAP_OVF` | có lap bị mất vì FIFO đầy | — |
  | 5 | `LAP` | 0 | 1 = đẩy giá trị hiện tại vào FIFO (khi `SRC = 0`) |
  | 11:8 | `LAP_COUNT` | số lap trong FIFO (0…8) | — |
- **Input capture bằng nút (`SRC = 1`):**
  - xung nhấn **A** → đảo `RUN` ngay ở chu kỳ đó;
  - xung nhấn **B** khi `RUN = 1` → đẩy giá trị hiện tại vào FIFO; B khi đang dừng thì phần cứng không làm gì (firmware tự reset qua `BTN_EVENT`);
  - mỗi lần chụp → sự kiện `SW_CAPTURE` (ngắt bit 4).
  - Xung nhấn lấy ở **cạnh đầu** sau đồng bộ (§7). Độ trễ đồng bộ như nhau ở start và stop nên tự triệt tiêu.
  - **Cùng chu kỳ** (thêm 03/10): ghi `SW_CTRL` với `SRC = 0` thắng xung A/B (xung bị bỏ, không `SW_CAPTURE`; lần nhấn vẫn có trong `BTN_EVENT`); `RESET` thắng lap bằng B (bỏ, không `SW_CAPTURE`); ghi với `SRC = 1` (vd `RESET`) **không** chặn A — A vẫn đảo `RUN`. Mỗi chu kỳ vào FIFO tối đa 1 lap.
- `SW_VALUE` (−224) R: [28:0]. `SW_LAP` (−220) R: [31] `VALID`, [28:0] giá trị; đọc thì lấy khỏi FIFO 8 phần tử. FIFO rỗng → `VALID = 0`. FIFO đầy → lap mới bị bỏ, `LAP_OVF = 1`.

## 5. Timer đếm ngược sang âm (`cdtimer` trong `timers.v`)
- Giá trị 32 bit **có dấu**. **Bộ chia riêng**: `en = RUN`, `clr` khi ghi `TMR_VALUE`.
- Ở mỗi tick của bộ chia riêng:
  - nếu giá trị = 1 → giá trị ← 0, **sự kiện `TMR_ZERO`** (ngắt bit 2, `ZERO ← 1`, kích chuông nếu `BEEP_EN`);
  - nếu giá trị = −2³¹ → đứng yên, `SAT ← 1`;
  - còn lại → giá trị − 1 (đi qua 0 sang −1, −2, … **không dừng**).
- Ghi 0 rồi chạy → −1, −2…, **không** có sự kiện ZERO (chỉ sự kiện khi *đi từ 1 về 0*).
- `TMR_VALUE` (−216) R/W. `TMR_CTRL` (−212): [0] `RUN` R/W, [1] `ZERO` R (dính; ghi 1 để xóa), [2] `BEEP_EN` R/W, [3] `SAT` R (xóa khi ghi `TMR_VALUE`).

## 6. Báo thức ×4 (`alarm` trong `timers.v`)
- `ALARMi` (−208 + 4i): [31] `EN`, [30:24] `DAYMASK` (bit d = thứ d, 0 = CN), [23] `HIT` (R dính; ghi 1 để xóa, ghi 0 giữ nguyên), [10:0] `MINUTE` = giờ × 60 + phút (0…1439; ≥ 1440 = không bao giờ kêu).
- Khi ghi, phần cứng tính sẵn `target = MINUTE × 60 000` (nhân hằng = vài bộ cộng, ≤ 86 340 000 < 2²⁷).
- So ở **mỗi tick làm RTC tăng** (bước 2–3 của §3), dùng **giá trị mới** `ms`, `dow`: nếu `EN` và `ms = target` và `DAYMASK[dow]` → `HIT ← 1`, sự kiện `ALARM` (ngắt bit 3).
- **Nạp RTC (ARM) không bao giờ làm báo thức kêu**, kể cả nạp đúng `target` hay nhảy qua nó. Đây là đáp án câu 5.7 của ngân hàng câu hỏi.
- Snooze, tắt chuông: firmware (`alarm.s`).

## 7. Nút (`buttons.v`)
- 4 nút MODE (mã 0), A (1), B (2), C (3). Parameter `G_ACTIVE_LOW` (mặc định 0).
- Mỗi nút: 2 flip-flop đồng bộ → máy trạng thái **chống rung cạnh đầu + khóa**:
  | Trạng thái | Điều kiện | Việc |
  |---|---|---|
  | IDLE | mức "nhấn" | phát **xung nhấn** 1 chu kỳ, chụp `MS_OF_DAY` → đẩy sự kiện vào FIFO → LOCK_P |
  | LOCK_P | đủ 10 tick ms | nếu còn nhấn → HELD, nếu đã nhả → IDLE |
  | HELD | mức "nhả" | → LOCK_R |
  | LOCK_R | đủ 10 tick ms | → IDLE |
- Mọi thay đổi mức trong LOCK_P/LOCK_R bị bỏ qua (đó là rung).
- Đánh đổi (ghi vào báo cáo): phản ứng ngay ở cạnh đầu, nên một xung nhiễu đơn lẻ cũng thành một lần nhấn. Nút thật luôn bắt đầu bằng tiếp xúc thật nên chấp nhận. Test BTN-4 ghi lại hành vi này.
- `BTN_EVENT` (−192) R, FIFO 4 phần tử, đọc thì lấy ra: [31] `VALID`, [30:29] mã nút, [28] `LOST` (đã có sự kiện bị bỏ vì FIFO đầy, xóa sau lần đọc này), [26:0] `MS_OF_DAY` lúc cạnh đầu.
- Xung nhấn của A, B còn nối thẳng sang stopwatch (§4). Mỗi sự kiện mới → ngắt bit 5.

## 8. (Tầng 2, DSE) RTC đếm BCD (`rtc_bcd.v`, parameter `G_BCD_RTC`)
- Các bộ đếm BCD nối tầng: ms (10·10·10) → giây (10·6) → phút (10·6) → giờ (24), tăng theo `tick_ms`.
- `RTC_BCD` (−104) R/W, đóng gói 32 bit (giống cách DS3231 bớt bit hàng chục):
  `[31:30]` chục giờ · `[29:26]` đơn vị giờ · `[25:23]` chục phút · `[22:19]` đơn vị phút · `[18:16]` chục giây · `[15:12]` đơn vị giây · `[11:8]` trăm ms · `[7:4]` chục ms · `[3:0]` đơn vị ms.
- Ghi: nạp ngay. `G_BCD_RTC = false` → đọc ra 0.
- Dùng cho cách thứ 4 trong bảng §8.1 của plan (CPU khỏi chia).
- `RTC_BCD` **độc lập** với RTC nhị phân (không nạp theo `ARM`). Firmware chỉ dùng nó để đo chi phí `fmt_hw`, không dùng hiển thị; SET/sync ghi cả hai (lệch ≤ 1 ms, chấp nhận).

## 9. Đồng bộ giờ với PC (`fw/sync.s` + `tools/sync_host.py`)
- Câu lệnh ASCII, kết thúc bằng `\n`. `CS` = XOR mọi byte **giữa** `$` và `*`, in 2 chữ số hex hoa.
  | Chiều | Câu | Ý nghĩa |
  |---|---|---|
  | PC → chip | `$T,<ms>,<day>*CS` | đặt giờ: `ms` 0…86 399 999, `day` số ngày từ 01/01/2000 (thập phân) |
  | PC → chip | `$Q*CS` | hỏi giờ |
  | chip → PC | `$R,<ms>,<day>*CS` | trả lời `$Q`: `ms` đọc **ngay khi nhận byte `\n`** |
  | chip → PC | `$Z,<ms>,<day>*CS` | TIMER vừa về 0 |
- Câu sai checksum hoặc sai cú pháp → bỏ, không trả lời. Cũng bỏ khi `ms` ≥ 86 400 000, `day` > 65 535, hoặc checksum viết chữ thường (chỉ nhận hex hoa).
- Chip tính `dow = (day + 6) mod 7`.
- **Tính `CAL` sau 2 lần đặt giờ** (firmware, số nguyên, `div` cắt về 0):
  - Lần 1 đặt giờ `T1`. Lần 2 nhận `T2`: **trước khi đặt**, đọc giờ chip `B2`.
  - `I = T2 − T1` (ms, tính cả ngày), `D = B2 − T2` (ms; dương = chip **nhanh**).
  - Nhận khi `600 000 ≤ I ≤ 86 400 000` và `|D| ≤ I / 5 000` (chia trước, tức ≤ 200 ppm). Ngược lại giữ `CAL`.
    - **Không** viết `|D| × 5 000 ≤ I`: tích tràn 32 bit khi `|D|` ≥ 429 497 (ví dụ `D = 858 994` → tích quấn thành 2 704 → nhận nhầm). Vector có ca này.
  - `ΔCAL = ((D × 65 536) / (I / 1 000)) × 50`; `CAL ← CAL + ΔCAL`. Rồi đặt giờ `T2`.
  - **Mốc T1 (Long chốt 26/10):** câu `$T` hợp lệ nào cũng đặt giờ. Nó thành `T1` của lần sau, **trừ khi** `0 ≤ I < 600 000` và `|D| ≤ 120` (200 ppm × 10 phút): khi đó giữ `T1` cũ và cộng `D` vào tổng `D_acc` (vì đặt giờ xóa mất phần trôi đã tích); lần tính kế dùng `D + D_acc` thay cho `D`. `T1` mới → `D_acc = 0`. `I < 0` (PC lùi giờ) hoặc lệch lớn → `T1` mới, không tính. SET bằng nút xóa `T1`. Lý do: PC gửi dày (mỗi phút) vẫn tính được `CAL` mỗi khi đủ 10 phút.
    - Đúng về toán: `ΔCAL = D/I × 10⁶ × 3 276,8 = D × 65 536 × 50 000 / I`. Viết lại như trên để **không tràn 32 bit** (sau bộ lọc `|D| ≤ 17 280`, nên `|D × 65 536| ≤ 17 280 × 65 536 < 2³¹`).
    - Sai số: cắt `I / 1 000` ≤ 0,17%; cắt thương ≤ 50 đơn vị (≈ 0,015 ppm). Không dùng `I / 50 000`: cắt kiểu đó sai tới ≈ 8,3% khi `I` vừa dưới 650 000.
  - Ví dụ: `I = 3 600 000`, `D = 72` → `4 718 592 / 3 600 = 1 310` → `ΔCAL = 65 500` (đúng là 65 536 = 20 ppm; lệch 0,05%). Vector: `sync_cal.txt`.
- `sync_host.py` (PC): bù trễ USB-UART bằng **nửa thời gian khứ hồi** của `$Q`/`$R` (đo trước, ghi ±).

## 10. Kiểm thử (TV5; `tb/*_tb.v`, `G_N = 50` trừ khi ghi khác)
| ID | Kích thích | Mong đợi |
|---|---|---|
| TB-1 | `CAL = 0`, 20 ms | mọi `len = 50`; tick ở chu kỳ 50, 100, … |
| TB-2 | từng `CAL` trong `timebase_len.txt` | 20 giá trị `len_k` đầu khớp file |
| TB-3 | `CAL` trong `timebase_total.txt`, 1000 ms | tổng chu kỳ khớp file (cả `G_N = 50 000` chạy 1 lần, chậm) |
| TB-4 | `en = 0` giữa chừng 37 chu kỳ | tick lùi đúng 37 chu kỳ |
| TB-5 | đổi `CAL` giữa một ms | ms đó giữ `len` cũ, ms sau dùng `CAL` mới |
| RTC-1 | đặt 86 399 990, `dow = 6`, 10 tick | `ms = 0`, `day + 1`, `dow = 0` |
| RTC-2 | `day = 65 535` qua nửa đêm | `day = 0` |
| RTC-3 | đọc `MS_OF_DAY` đúng chu kỳ tick qua nửa đêm | cặp (`ms`, `DAY_SHADOW`) cùng là trước tick, hoặc cùng là sau tick; không lẫn |
| RTC-4 | ghi `SET_*`, `ARM`, đọc `RTC_CTRL` trước tick | `ARM = 1`, `ms` chưa đổi; sau tick: giá trị mới, `ARM = 0` |
| RTC-5 | `SET_MS = 86 400 000` | nạp 0 |
| SW-1 | `SRC = 0`, `RUN = 1` đúng 49 / 50 / 61 728 chu kỳ | 0 / 1 / 1 234 |
| SW-2 | chạy 30 chu kỳ, dừng, chạy 20 chu kỳ | 1 (không mất phần lẻ) |
| SW-3 | `SRC = 1`, nút A có rung: nhấn, sau 61 728 chu kỳ nhấn lại | 1 234; đúng 2 sự kiện `SW_CAPTURE` |
| SW-4 | 9 lần B khi chạy | 8 lap đúng thứ tự, `LAP_OVF = 1` |
| SW-5 | parameter `G_SW_MAX = 1 234` (mặc định 359 999 999; `SW_VALUE` không ghi được nên không nạp gần max), chạy 2 000 ms | dừng ở 1 234, `OVF = 1` |
| TM-1 | ghi 2000, `RUN` | ZERO đúng tick thứ 2000; sau 2500 ms giá trị −500 |
| TM-2 | ghi 0, `RUN` | −1 sau 1 ms, **không** có ZERO |
| TM-3 | ghi 1 | ZERO sau 1 ms, chỉ 1 lần |
| TM-4 | ghi −2³¹ + 1 | sau 1 ms = −2³¹, `SAT = 0`; sau 2 ms vẫn −2³¹, `SAT = 1` (SAT bật ở tick mà giá trị **đã** = −2³¹, §5) |
| TM-5 | `BEEP_EN = 1`, về 0 | beeper nhận lệnh phát cùng chu kỳ |
| AL-1 | RTC 06:59:59.990 thứ 2, `ALARM0` = EN, mask thứ 2, 420 | `HIT` ở tick thứ 10 |
| AL-2 | như AL-1 nhưng mask không có thứ 2 | không kêu |
| AL-3 | `MINUTE = 0`, mask thứ 2, RTC 23:59:59.999 Chủ nhật | kêu ở tick qua nửa đêm (dùng `dow` mới) |
| AL-4 | nạp RTC thẳng vào 07:00:00.000 | **không** kêu |
| AL-5 | 2 báo thức cùng phút | cả hai `HIT`, một sự kiện ngắt (hoặc hai, đều được) |
| BTN-1 | nhấn có rung (cạnh ở t₀, t₀+0,3 ms, +0,5, +1,2, +1,5; giữ 200 ms; nhả có rung) | đúng 1 sự kiện, dấu thời gian = `MS_OF_DAY` tại t₀ |
| BTN-2 | 2 lần nhấn cách 50 ms | 2 sự kiện |
| BTN-3 | 5 lần nhấn, không đọc | đọc ra 4 sự kiện, sự kiện đầu có `LOST = 1` |
| BTN-4 | xung nhiễu 1 µs | 1 sự kiện (hành vi đã biết, ghi báo cáo) |
| SY-1 | `sync.s` trên ISS với các câu trong `sync_sentences.txt` | câu đúng được nhận, câu sai bị bỏ |
| SY-2 | `sync.s` tính `CAL` với `sync_cal.txt` | `CAL` mới khớp từng dòng |
