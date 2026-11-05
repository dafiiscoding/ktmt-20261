# Kịch bản demo (~10 phút)

Mục tiêu: cho thầy thấy **chạy thật** (RTL Verilog + firmware thật, mô phỏng bằng Icarus), không phải video dựng sẵn.
Số liệu bên dưới là kết quả chạy ngày 28/10/2026 bằng `bash tools/wave_demo.sh` (`verified`, in ra từ chính lần chạy đó).

## 0. Chuẩn bị trước giờ (làm 1 lần, ~2 phút)

| Việc | Lệnh | Mong đợi |
|---|---|---|
| Mở Git Bash ở thư mục project | `cd hoc-tap/ktmt-2026-1-casio` | |
| Chạy thử cả kịch bản sóng | `bash tools/wave_demo.sh` | ~10 giây, in dòng thời gian, tạo `work/wave_demo.vcd` (~9 MB) |
| Chạy thử hồi quy đầy đủ | `bash tools/run_unit.sh` | cuối cùng `EXIT 0`, 41 PASS (chạy nền, lâu; đo giờ trước khi lên) |
| Mở sẵn tab | [`demo_tuong_tac.html`](../work/demo_tuong_tac.html), [`demo_system.gif`](../work/demo_system.gif), [`vga_frame.png`](../work/vga_frame.png) | |
| Thử GTKWave | `bash tools/wave_demo.sh view` | cửa sổ GTKWave mở (`unverified`: chưa thử vì phiên làm việc không có màn hình) |

Dự phòng nếu GTKWave hỏng: chiếu `demo_tuong_tac.html` + đọc dòng thời gian in ra ở terminal.

## 1. Mở đầu (1 phút)

Nói: "Nhóm tự thiết kế con chip đồng hồ bằng Verilog, **chỉ mô phỏng, không có board**. Ba thứ chạy thật: CPU MIPS, phần cứng thời gian, firmware 5 chế độ." Chiếu [`demo_system.gif`](../work/demo_system.gif) (phát lại từ log, không phải chạy trực tiếp).

## 1b. Demo cái đồng hồ: từng cảnh trên trang HTML (5 phút)

Mở [`work/demo_tuong_tac.html`](../work/demo_tuong_tac.html), bấm lần lượt 6 nút cảnh dưới màn LED. **Nói ngay từ đầu:** trang này phát lại một lần chạy thật của `system_tb` (332 khung màn lấy từ chân `an`/`seg` của chip), không bấm trực tiếp được. Mỗi khung dưới đây là **đúng chữ chip hiển thị** (giải mã từ [`work/screen_system.log`](../work/screen_system.log) bằng `tools/screen.py`, `verified`).

Cách đọc màn 8 ô: `__HH.MM.SS` là giờ; `_MM.SS.mmm` là phút.giây.ms. Dấu `.` đi kèm chữ số đứng trước nó. Bố cục đầy đủ: [`display-spec` §8](display-spec.md). Thứ tự đổi chế độ bằng MODE: TIME → STOPWATCH → TIMER → ALARM → SET.

### Cảnh 1 — TIME (0–230 ms): đồng hồ qua nửa đêm, 24h và 12h

- **Cảnh có gì:** `00.00.00` → `A 12.00.00` → `P 01.05.00` → `00.00.01` → `00.01.072`.
- **Chuyện đã làm:** chip khởi động ở 23:59:59.990 (tb nạp sẵn), 10 ms sau qua nửa đêm. Rồi bấm A đổi sang 12h, bấm B xem trang giây.ms.
- **Kết quả đọc được:** `00.00.00` là vừa qua 0 giờ. `A 12.00.00` là 0 giờ hiện thành **12 giờ sáng** (A = AM). `P 01.05.00` là giờ buổi chiều (P = PM, ví dụ 1 giờ 05 chiều). `00.01.072` là 0 phút 1 giây 72 ms.
- **Ý nghĩa:** chứng minh đồng hồ đếm đúng tới ms, đổi ngày đúng lúc qua nửa đêm, và firmware biết đổi 24h ↔ 12h. Bên trong `system_tb` kiểm: mọi khung quanh nửa đêm chỉ được là `23.59.59` hoặc `00.00.00` (không khung xé số), ngày tăng thành 9772 (03/10/2026), thứ Bảy.
- **Code:** [`rtc` qua nửa đêm](../src/timers.v#L75), [`rtc`](../src/timers.v#L24).

### Cảnh 2 — Trang ngày (230–4700 ms): ngày/tháng/năm, năm nhuận

- **Cảnh có gì:** `03-10-26` rồi một chuỗi ngày chạy rất nhanh: `01-01-00`, `29-02-00`, `01-03-00`, `31-12-00`, `29-02-04`, `31-12-25`, `01-04-26`, rồi ~200 ngày ngẫu nhiên (`06-06-79`, `08-11-19`, ...).
- **Chuyện đã làm:** `03-10-26` là ngày thật sau nửa đêm (3/10/2026). Phần còn lại là tb **tua** thẳng bộ đếm ngày qua hàng trăm giá trị cho firmware đổi sang dd-MM-yy, rồi so từng khung với bảng chuẩn `tb/vectors/date.txt`.
- **Kết quả đọc được:** `29-02-00` và `29-02-04` có ngày 29/2 (năm 2000 và 2004 là năm nhuận); `28-02-00` kế tiếp `01-03-00` ở các năm không nhuận.
- **Ý nghĩa:** chứng minh công thức "số ngày → dd-MM-yy" đúng cả năm nhuận. Đây là phần dễ sai nhất của đồng hồ. Cảnh chạy nhanh vì quét nhiều ngày, không phải đồng hồ chạy thật 4 giây.
- **Code:** [`rtc`](../src/timers.v#L24) (đếm ngày, thứ), phần đổi sang dd-MM-yy nằm trong firmware [`fw/main.s`](../fw/main.s).

### Cảnh 3 — STOPWATCH (4700–7400 ms): bấm giờ chính xác tới ms, lap

- **Cảnh có gì:** `00.00.05` (đang ở TIME) → bấm MODE → ` 00.00.000` → chạy ` 00.00.041`, ` 00.00.131`, ... → dừng ở ` 00.01.234` → reset ` 00.00.000` → chạy lại → dừng ở ` 00.01.038` → xem lap `100.00.245`, `200.00.545`, `300.00.890`.
- **Chuyện đã làm:** bấm A chạy, A dừng; B (khi dừng) reset; chạy lại, bấm B ba lần chụp 3 lap, A dừng; C xem lại từng lap.
- **Kết quả đọc được:** lần đầu dừng ở **1 giây 234 ms**: đúng bằng khoảng cách 61 728 chu kỳ giữa 2 lần bấm mà tb tạo ra (`system_tb` kiểm `SW_VALUE = 1234`). Lap: chữ số đầu là **số thứ tự lap**, nên lap 1 = 0,245 s, lap 2 = 0,545 s, lap 3 = 0,890 s (tính từ lúc bắt đầu chạy), chip nhớ đúng thứ tự.
- **Ý nghĩa:** chứng minh bấm giờ chính xác tới ms. Nút A/B nối **thẳng phần cứng** vào stopwatch (không chờ CPU), nên thời điểm bấm được ghi đúng chu kỳ nhấn, dù CPU đang bận vẽ màn.
- **Code:** [`stopwatch`](../src/timers.v#L126), [chống rung nút](../src/buttons.v#L84), [firmware `sw_btn`](../fw/main.s#L221).

### Cảnh 4 — TIMER (7400–10100 ms): đếm ngược, về 0, sang số âm

- **Cảnh có gì:** ` 00.02.000` → ` 00.01.975` → ... → ` 00.00.005` → `-00.00.104` → ... → `-00.00.500` → `- 99.59.59` → `- --.--.--` → ` 00.02.000`.
- **Chuyện đã làm:** hẹn giờ 2 giây, bấm A chạy. Khi về 0 còi tự kêu (nạp mẫu `0x10F0F` đúng chu kỳ đó). Timer **không dừng** mà đếm tiếp sang số âm (dấu `-` ở đầu), cho biết đã quá giờ bao lâu. Cuối cảnh tb ép số quá lớn để kiểm định dạng, rồi B đưa về giá trị đặt.
- **Kết quả đọc được:** `-00.00.500` = đã quá giờ 500 ms. `- 99.59.59` và `- --.--.--` là cách chip hiện số quá lớn (trên 100 giờ hiện gạch). Phép kiểm trong `system_tb`: timer về 0 **đúng 2000 ms (100 000 chu kỳ)** sau khi bấm chạy.
- **Ý nghĩa:** chứng minh timer chính xác tới ms, báo hết giờ bằng phần cứng (không phụ thuộc CPU nhanh hay chậm), và hiển thị đúng số âm.
- **Lưu ý:** màn LED không "kêu", còi chỉ kiểm bằng tb (mục 2 phía dưới cho thấy chân `beep`).
- **Code:** [`cdtimer`](../src/timers.v#L218), [`zero_ev`](../src/timers.v#L245), [mẫu còi](../src/beeper.v#L29), [firmware `tr_btn`](../fw/main.s#L245).

### Cảnh 5 — ALARM (10100–10900 ms): 4 báo thức, trang chuông giờ

- **Cảnh có gì:** `AL1 07.00` → `AL1o07.00` → `AL2 00.00` → `AL3 00.00` → `AL4 00.00` → `CH` → `CH o` → `AL1o07.00` → `AL1o08.00` → `AL1o08.01`.
- **Chuyện đã làm:** vào ALARM, A bật báo thức 1 (hiện chữ `o`), B chuyển AL2, AL3, AL4 rồi trang chuông giờ `CH` (tắt/bật), quay lại AL1, vào sửa: giờ 07 → 08, phút 00 → 01.
- **Kết quả đọc được:** `AL1 07.00` = báo thức 1, tắt, 07:00; chữ `o` xuất hiện khi bật; sau khi sửa thành `08.01`.
- **Ý nghĩa:** chứng minh 4 báo thức độc lập, bật/tắt và sửa giờ được. Việc **kêu đúng phút**, snooze 5 phút, tự tắt sau 60 giây, Chủ nhật không kêu: do `system_tb` kiểm bằng chân còi, **không hiện trên màn LED** nên cảnh này không thấy.
- **Code:** [`alarm`](../src/timers.v#L286), [firmware `al_btn`](../fw/main.s#L275).

### Cảnh 6 — SET và đồng bộ (10900–13400 ms): chỉnh giờ/ngày, kẹp ngày

- **Cảnh có gì:** `23.30.15` → `30.15` (ô giờ tắt = đang nháy) → `23.30.15` → `00.30.15` → trang ngày `11-10-26` → `12-10-26` → ... → `31-01-27` → `28-02-27` → hai khung cuối `15.02.29`, `00.07.30`.
- **Chuyện đã làm:** vào SET lúc 23:30:15, trường giờ nháy (`30.15` là lúc ô giờ tắt). A tăng giờ 23 + 1 → **0**, C lưu: đồng hồ thành `00.30.15`. Sau đó chỉnh ngày +1 (11 → 12/10/2026), rồi chỉnh tháng từ 31/01/2027 lên tháng 2.
- **Kết quả đọc được:** `00.30.15` là giờ đã lưu (`system_tb` kiểm RTC = 00:30:15). `28-02-27` là chỗ **kẹp ngày**: 31/01 + 1 tháng không có 31/02, chip kẹp về 28/02.
- **Ý nghĩa:** chứng minh chỉnh giờ bằng nút không làm giờ nhảy giữa chừng 1 ms (ghi giờ mới rồi mới nạp ở tick kế, cờ `ARM`), nháy đúng trường đang sửa, 23 + 1 quay về 0, ngày/thứ/tháng cập nhật đúng.
- **Chưa kiểm kỹ:** hai khung cuối (`15.02.29`, `00.07.30`) là phần đồng bộ giờ qua UART (`$T`, `$Q`). Nhãn này gán theo thứ tự log, chưa đối chiếu từng bước (`inference`), nên đừng khẳng định nó là bước nào.
- **Code:** [`rtc` ARM](../src/timers.v#L98), [firmware `set_in`](../fw/main.s#L357), [`uart`](../src/uart.v#L21).

### Chốt cả phần demo (nói 3 câu)

1. "Đây là chip tự thiết kế, chạy firmware thật; màn LED là chữ do chân `an`/`seg` của chip tạo ra."
2. "Chia 3 lớp: ngoại vi là phần cứng (`src/`), việc bấm nút làm gì là firmware (`fw/main.s`), CPU MIPS chạy firmware đó (`cpu_g1.v`)."
3. "Mỗi khung bạn vừa xem được `system_tb` đối chiếu với bảng chuẩn (589 phép kiểm); hồi quy cuối cùng 41 PASS."

## 2. Chạy thật + chiếu sóng (5 phút)

Chạy `bash tools/wave_demo.sh`. Testbench [`tb/wave/wave_demo.v`](../tb/wave/wave_demo.v) ép chân nút bấm (có rung như nút thật), CPU chạy `fw/main.s` thật. Thời gian dưới đây tính từ lúc 12:00:00.000 trong mô phỏng.

| Giờ mô phỏng | Chuyện gì xảy ra | Chỉ vào sóng |
|---|---|---|
| +59 ms | Nhấn MODE → vào STOPWATCH | `btn`, `st_mode` (IDLE → LOCK_P → HELD): thấy chống rung |
| +94 ms | Nhấn A → stopwatch chạy | `sw_cap` nháy cùng chu kỳ nhấn, `sw_run` lên 1 |
| +249 ms | Nhấn B → chụp lap | `sw_cap` nháy lần 2 |
| +364 ms | Nhấn A → dừng | `sw_val` đứng ở **270 ms** (= 364 − 94, đúng) |
| +399 / +434 ms | MODE sang TIMER, A chạy timer 2,000 s | `tmr_run`, `tmr_val` giảm dần |
| +2441 ms | Timer về 0 | `tmr_zero` nháy, `tmr_val` đi tiếp sang số âm |
| +2480 ms | Chip tự gửi `$Z,...` qua UART TX | `utx` |
| +2691 ms | Chân còi `beep` bắt đầu kêu | `beep` (vì sao trễ 250 ms: xem mục 4) |
| sau đó | PC gửi `$Q*51` (hỏi giờ) | `urx`, `urx_ev` nháy 6 lần (6 byte) |
| +2771…2778 ms | **6 lần ngắt**, `IP = 01000000` (bit 6 = UART_RX), CPU nhảy tới `0x180` | `irq`, `irq_ip`, `pc` |
| +2827 ms | Chip trả lời `$R,...` | `utx` |

Tín hiệu nên thêm vào GTKWave (bên trái, kéo vào theo thứ tự này): `btn`, `st_mode`, `st_a`, `st_b`, `btn_ev`, `sw_cap`, `sw_run`, `sw_val`, `tmr_run`, `tmr_val`, `tmr_zero`, `beep`, `urx`, `urx_ev`, `irq`, `irq_ip`, `pc`, `utx`. Nhấn `Zoom Fit` (Ctrl+Alt+F) để thấy toàn cảnh, rồi phóng to quanh từng mốc.

## 2b. Demo từng chức năng riêng (mỗi khối 1 lệnh, vài giây)

Mỗi chức năng có testbench riêng, chạy độc lập với cả đồng hồ. Trước: `source tools/env.sh`. Mỗi lệnh in dòng cuối `PASS <tên>_tb <số phép kiểm>` (đã chạy 27/10, `verified`).

| Chức năng | Lệnh | Kết quả đã chạy | Nguyên lý (code) |
|---|---|---|---|
| Nút: chống rung, khóa 10 ms | `bash tools/run_unit.sh buttons` | PASS 20 | [`buttons.v`](../src/buttons.v#L84) |
| Bấm giờ + lap | `bash tools/run_unit.sh stopwatch` | PASS 34 | [`stopwatch`](../src/timers.v#L126) |
| Hẹn giờ, về 0, số âm | `bash tools/run_unit.sh cdtimer` | PASS 20 | [`cdtimer`](../src/timers.v#L218) |
| Báo thức (4 cái, mặt nạ ngày) | `bash tools/run_unit.sh alarm` | PASS 15 | [`alarm`](../src/timers.v#L286) |
| Cả đồng hồ (8 kịch bản sys_0…sys_7, gồm sync UART) | `bash tools/run_unit.sh system` | PASS 589 | `tb/system_tb.v` |

Sau `system`, chạy `git checkout -- work/screen_system.log` (tb ghi đè file đã commit).

## 3. Hồi quy (2 phút)

Chạy hoặc chiếu log [`evidence/20261027_regress_rbuf.log`](../evidence/20261027_regress_rbuf.log): 41 PASS, EXIT 0. `system_tb` có 589 phép kiểm. CPI: G1 1,428, G2 2,027.

## 4. Câu hay bị hỏi

- **"Sao còi trễ 250 ms sau khi timer về 0?"** Phần cứng nạp mẫu còi ngay lúc về 0, nhưng sóng vuông chỉ đảo mức sau `freq` = 12 500 chu kỳ clock (mặc định, 2 kHz ở 50 MHz thật). Mô phỏng nén 1 ms = 50 chu kỳ (`G_N = 50`) nên 12 500 chu kỳ hiện ra như 250 ms (`src/beeper.v:44`; đo được 12 501 chu kỳ). Trên chip thật là 0,25 ms.
- **"Sao nút bấm không sinh ngắt?"** `fw/main.s` đặt `USE_IRQ 1`: chỉ **UART_RX** dùng ngắt, nút và timer là polling. Đã đo: `irq` chỉ lên sau khi PC gửi `$Q`.
- **"Có bấm nút thật được không?"** Không. Không có board; nút là testbench ép chân `btn`. Màn LED/VGA dựng lại từ chân `an`/`seg`/`rgb`.
- **"Thời gian có thật không?"** `G_N = 50` nén 1 ms thành 50 chu kỳ để mô phỏng nhanh. Logic không đổi; chạy đúng 1 ms = 50 000 chu kỳ khi tổng hợp thật.
- **"Dòng `$Z`, `$R` là gì?"** `docs/timer-spec.md` §9: `$Z` = timer vừa về 0, `$R` = trả lời `$Q`.

## 5. Chưa kiểm / rủi ro

- GTKWave chưa được mở thử (phiên làm việc không có màn hình).
- Thời gian chạy `run_unit.sh` đầy đủ chưa đo; đừng chạy nó trực tiếp trước thầy nếu chưa biết lâu bao nhiêu.
- Demo là mô phỏng của bản G1 (`soc_top` mặc định). Bản G2 (pipeline) chỉ chạy qua hồi quy, không có kịch bản sóng.
- Nếu thầy hỏi phần nào do AI viết: chốt cách khai trước buổi demo (xem `docs/hop-nhom-01-ban-giao.md`).
