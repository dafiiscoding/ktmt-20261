# Đồng hồ điện tử đa năng trên SoC tự thiết kế — từ hiển thị → chip → CPU → ALU

> **Phiên bản:** v5.0 (01/10/2026). Claude viết, **nhóm chốt đề 01/10**. Chi tiết kỹ thuật vẫn là bản nháp, freeze ở S1′.
> Đề cũ (Smart Step Hub v3.2, Lunar-Sync v4, Casio-mini) **đã bỏ, file đã xóa 01/10**. Phần còn dùng được đã chép vào §4.4, §4.5, §9.
> **Cách hiểu yêu cầu của Long (01/10, không hỏi lại được):** "đồng hồ điện tử, làm sâu phần cứng: hiển thị ra sao → chip → CPU → ALU". Chức năng chính: xem giờ, chỉnh giờ, bấm giờ, báo thức; **"đếm thời gian âm chuẩn tới ms"** = **đếm ngược tới ms, về 0 thì báo và đếm tiếp sang âm** (overtime, kiểu đồng hồ thuyết trình). Nếu Long muốn nói *âm lịch* thì xem tầng 3 (§9).
> **Đi kèm:** `docs/pipeline-policy.md`, `docs/control-table.md` (28 dòng), `docs/ngan-hang-cau-hoi.md`; cổng bảo vệ, khung báo cáo, DoD ở `KE-HOACH-LAM-VIEC.md` §4, §4b, §5, §6.
> Nhãn: `verified` = đã chạy/đọc nguồn · `inference` = suy luận · `unverified` = chưa kiểm.

---

## 0. Một câu tóm tắt

Nhóm tự thiết kế **cả con chip của một chiếc đồng hồ điện tử** (kiểu Casio F-91W) trên FPGA:
- bộ điều khiển hiển thị;
- khối định thời chính xác tới ms (đồng hồ, bấm giờ, đếm ngược sang âm, báo thức);
- bus và ngắt;
- một CPU MIPS32 tự viết (single-cycle → pipeline), xuống tới ALU và bộ chia.

Sau đó nhóm **đo** xem việc nào nên làm bằng phần cứng, việc nào nên để phần mềm. Lý do: chip đồng hồ thật chạy xung chỉ 32,768 kHz.

## 1. Câu hỏi kiến trúc trung tâm (cái làm đề này "sâu")

> **Muốn chuẩn tới ms thì phần nào phải là phần cứng?**

Ba con số tính sẵn (python, 01/10, `verified` về số học):

| Sự thật | Số | Hệ quả thiết kế |
|---|---|---|
| Sai ≤ 1 ms sau **1 giờ** cần sai số tần số ≤ **0,28 ppm**; sau 10 phút ≤ 1,67 ppm | thạch anh board thường ±50 ppm (`unverified`, kiểm datasheet) → lệch **180 ms/giờ**, 4,3 s/ngày | "Chuẩn ms" **bắt buộc** phải sync giờ chuẩn + **hiệu chỉnh** bộ chia (§4.1, E1) |
| Chip đồng hồ thật chạy ~32,768 kHz → chỉ **~33 chu kỳ CPU mỗi ms** | đổi ms → `HH:MM:SS.mmm` bằng phần mềm (≈ 9 lần `div` × 33 chu kỳ) ≈ **360 chu kỳ** (`inference`, phải đo) | ở 32 kHz, phần mềm **không kịp** cập nhật mỗi ms (≈ 11 ms/lần) → đếm thời gian phải bằng **phần cứng**, CPU chỉ đọc |
| Ở 50 MHz (G2; G1 tối đa 25 MHz → gấp đôi) cùng việc đó ≈ 7 µs, tức 0,7% tải CPU | — | ở xung cao thì phần mềm làm được. Đánh đổi phụ thuộc tần số → đo bằng thí nghiệm **hạ xung CPU** (E3) |

→ Báo cáo có một câu chuyện liền mạch: **vì sao đồng hồ Casio hiện 1/100 s, có bộ đếm phần cứng, và chạy 32 kHz.** Nhóm tái hiện và đo lại điều đó trên chip của mình.

Reference đời thực (trích nguồn chính thức ở S1):
- **Casio F-91W (module 593):** bấm giờ 1/100 s, báo thức hằng ngày, chuông mỗi giờ, sai số ±30 s/tháng ≈ **11,6 ppm** (`unverified`, theo trí nhớ).
- **Chip RTC DS3231:** đếm BCD, 2 báo thức phần cứng, ±2 ppm (`unverified`).
- **Timer của vi điều khiển** (STM32 TIM: input capture, compare) và **RTC smooth calibration** (`unverified`).
- Bấm giờ trên điện thoại.
- Giờ chuẩn NTP qua PC.

## 2. Chức năng (phiên bản người dùng)

5 chế độ kiểu Casio, đổi bằng nút **MODE**. 3 nút còn lại là A, B, C.

| Chế độ | Hiện | A | B | C |
|---|---|---|---|---|
| **TIME** | `HH.MM.SS` (trang 2: `dd-MM-YY`) | 12/24 h | xem giây.ms | đèn / độ sáng |
| **STOPWATCH** | `MM.SS.mmm` → tự chuyển `HH.MM.SS` khi > 1 h | start/stop | lap (đang chạy) / reset (đang dừng) | xem lại các lap |
| **TIMER** (đếm ngược) | `-`/` ` + `MM.SS.mmm` | start/stop | reset về giá trị đặt | tăng phút khi đang đặt |
| **ALARM** (4 báo thức) | `AL1 HH.MM` + trạng thái | bật/tắt | chọn báo thức | báo lại sau 5 phút (snooze) |
| **SET** | chữ số đang chỉnh **nhấp nháy** | +1 | sang trường kế | lưu |

- **Đếm ngược sang âm:** ví dụ đặt 05:00.000. Về 0 thì kêu chuông + bật cờ, và **tiếp tục đếm** `-00:00.001`, `-00:00.002`… Đây là số âm bù 2 thật trong thanh ghi phần cứng, nối thẳng sang ALU, `sra`, `slt`.
- **Chuông mỗi giờ** (bật/tắt), **bíp khi bấm nút**.
- **Sync:** PC gửi giờ chuẩn qua UART → đồng hồ chỉnh giờ và **học độ trôi** để tự hiệu chỉnh (§4.1).
- **Độ phân giải** 1 ms. **Độ chính xác** được đo, không tự nhận (E1, E2).

## 3. Kiến trúc tổng (SoC "WatchChip")

```
 50 MHz ──► [Timebase: chia phân số + hiệu chỉnh] ──1 kHz──► [RTC] [STOPWATCH+capture] [TIMER âm] [ALARM×4]
                                                                   │ cờ sự kiện
 Nút ──► [chống rung + đóng dấu thời gian] ──────────────────────► [Bộ điều khiển ngắt]──IRQ──┐
 UART RX/TX ◄──────────────────────────────────────────────────────────────────────────────┤
                                                                                            ▼
            [CPU MIPS32: G1 single-cycle / G2 pipeline] ◄─► [Bus + giải mã địa chỉ MMIO] ◄─► IMEM / DMEM (BRAM)
                     │ ALU · shifter · mul · div · bcd                         │
                     ▼                                                         ▼
                                              [Bộ điều khiển hiển thị: Display RAM → bộ sinh ký tự]
                                                   ├─► quét LED 7 đoạn (chống bóng ma, PWM sáng, nhấp nháy)
                                                   └─► (tầng 2) VGA vẽ số 7 đoạn khổng lồ "đuổi tia", không framebuffer
                                              [Bộ tạo âm: PWM + mẫu bíp] ─► buzzer
```

Báo cáo đi **từ trên xuống** đúng như Long muốn: hiển thị → định thời → chip (bus, ngắt) → CPU → ALU.

## 4. Thiết kế phần cứng từng tầng

### 4.1. Timebase & bộ định thời (`timebase.v`, `timers.v`) — "trái tim chuẩn ms"

**Bộ chia phân số có hiệu chỉnh** (tạo nhịp 1 kHz):
- Mỗi ms đếm `N = 50 000` chu kỳ.
- Bộ tích lũy `acc += CAL` (CAL có dấu, đơn vị 2⁻¹⁶ chu kỳ). Mỗi ms dài thêm `CAL >> 16` chu kỳ, cộng 1 khi phần lẻ `acc` tràn (|CAL| < 65 536 thì đúng 0 hoặc 1 chu kỳ; `timer-spec.md` §2).
- Độ phân giải chỉnh ≈ 3·10⁻⁴ ppm (`inference` từ công thức). Cách này giống smooth calibration của STM32.
- `CAL` do firmware tính sau khi sync (§6).

**RTC:**
- `MS_OF_DAY` 27 bit (0..86 399 999, đã kiểm ≤ 2²⁷).
- `DAY` (số ngày, đổi ra thứ/ngày bằng firmware).
- Đọc `MS_OF_DAY` thì phần cứng **chụp `DAY` vào thanh ghi bóng**, tránh xé số lúc nửa đêm.
- Ghi giờ: CPU ghi `SET_MS`, `SET_DAY` rồi `ARM`; nạp ở mép ms kế tiếp.

**STOPWATCH:**
- Bộ đếm 29 bit (đủ 99:59:59.999).
- **Start/stop/lap được chụp bằng phần cứng** ngay khi có cạnh nút (input capture). Kết quả **không phụ thuộc CPU chậm hay nhanh**. Đây là thứ làm "chuẩn ms" đúng nghĩa.
- 8 thanh ghi lap (FIFO).

**TIMER âm:**
- Thanh ghi 32 bit có dấu, giảm 1 mỗi ms khi chạy.
- Phần cứng so `== 0` → bật cờ `TMR_ZERO` + kích chuông; **không dừng**, tiếp tục sang âm.
- Biên âm int32 ≈ 24,8 ngày.

**ALARM ×4:**
- Mỗi báo thức có `HH:MM`, bật/tắt, mặt nạ ngày trong tuần.
- Bộ so sánh phần cứng chạy mỗi phút → cờ `ALARM[i]`, giống DS3231. Snooze do firmware.

**Nút:**
- Đồng bộ 2 flip-flop + chống rung 10 ms.
- **Dấu thời gian lấy ở cạnh đầu tiên**, xác nhận sau khi hết rung. Nếu lấy sau khi hết rung thì mọi lần bấm trễ 10 ms. Trễ đều nhau thì start/stop tự triệt tiêu, nhưng trễ không đều (độ rung khác nhau mỗi lần) thì không. → Lấy cạnh đầu.

**Phương án DSE "đếm kiểu gì":**
- (a) bộ đếm **nhị phân** + CPU đổi ra chữ số;
- (b) bộ đếm **BCD nối tầng** (10/6/10/6/24) như chip RTC thật → CPU khỏi chia.

Đo số LUT so với số chu kỳ CPU mỗi lần cập nhật hiển thị (§8).

### 4.2. Bộ điều khiển hiển thị (`display_ctrl.v`, `seg7_scan.v`, `vga_digits.v`) — "hiển thị như nào"

**Display RAM ánh xạ bộ nhớ:**
- 8 ô × 8 bit: mã ký tự + dấu chấm.
- Thanh ghi `BLINK_MASK` (chữ số nào nhấp nháy ~2 Hz, **phần cứng tự nháy**, CPU khỏi bật tắt).
- `BRIGHT` (4 bit).

CPU chỉ ghi RAM. Quét màn là việc của bộ điều khiển, giống bộ điều khiển LCD trong chip đồng hồ thật.

**Bộ sinh ký tự (ROM):** mã → 7 đoạn: 0–9, A b C d E F, H L n o P r S t U, `-`, trống. Đủ để viết `AL`, `St`, `tr`, `SEt`.

**Quét LED 7 đoạn (multiplex):**
- Tần số quét: mỗi chữ số ≥ 100 Hz để khỏi nháy. Với 8 chữ số thì khe quét 1 kHz → 125 Hz/chữ số. Ghi công thức trong code.
- **Khoảng tắt chống bóng ma (ghosting):** giữa hai khe có vài µs tắt hết, vì transistor tắt chậm làm đoạn của chữ số trước sáng mờ sang chữ số sau.
- **PWM độ sáng** trong mỗi khe.
- Không có board: mặc định mức cao = sáng; nạp board sau này thì đổi parameter mức tích cực (không bắt buộc).

**VGA (tầng 2) — vẽ số 7 đoạn khổng lồ, đuổi tia (racing the beam):**
- Bộ định thời 640×480@60 Hz (xung pixel 25 MHz).
- Với mỗi pixel `(x, y)`, mạch tổ hợp xác định pixel nằm trong ô chữ số nào và đoạn nào, rồi tra bit đoạn từ **cùng Display RAM**.
- **Không framebuffer.**
- Đánh đổi để báo cáo: framebuffer 1 bit/pixel cần 307 200 bit ≈ 37,5 KB BRAM và CPU phải tự vẽ, còn đuổi tia chỉ tốn LUT. Đo LUT/BRAM của cách đuổi tia; cách framebuffer chỉ phân tích bằng số.
- Không có clock domain crossing: xung pixel 25 MHz là **clock enable** trên clock 50 MHz chung; Display RAM là 8 thanh ghi FF, đọc tổ hợp (`display-spec.md` §7).

**Một Display RAM, hai đầu ra** → minh họa tách lớp phần cứng: firmware không biết đang hiện ra LED hay VGA.

### 4.3. Chip: bus, MMIO, ngắt (`soc_top.v`, `irq_ctrl.v`)

- Giải mã địa chỉ: IMEM, DMEM, vùng ngoại vi `0xFFFF_FFxx`. MMIO đầy đủ ở §5.
- **Bộ điều khiển ngắt:**
  - 8 nguồn: TICK_1MS, TICK_1S, TMR_ZERO, ALARM, SW_CAPTURE, BTN, UART_RX, UART_TX_EMPTY.
  - Thanh ghi `PENDING` (ghi 1 để xóa), `ENABLE`. Không có mạch ưu tiên: 1 vector, handler đọc `Cause.IP` và xử lý bit thấp trước.
  - `IRQ_STAMP` chụp `CYCLE_COUNT` lúc `irq` đổi 0 → 1 (= lúc sự kiện khi chỉ bật 1 nguồn, như trong E3) → đo **độ trễ ngắt** chính xác tới chu kỳ (`mmio-map.md` §5).
- **UART** 8N1 115200, RX FIFO 64 byte + cờ tràn; TX gửi log/số đo lên PC.
- **Bộ tạo âm:**
  - PWM tần số chỉnh được (2–4 kHz cho buzzer piezo).
  - **Thanh ghi mẫu bíp** 16 bit, phần cứng tự phát `bíp-bíp-nghỉ`, nên CPU chỉ kích một lần.
  - Ưu tiên: báo thức > hết giờ > chuông giờ > bíp nút.
- **`CPU_CLK_DIV`:** clock enable cho CPU (ngoại vi vẫn chạy 50 MHz). Hạ CPU xuống ≈ 32,77 kHz (chia 1526) để **giả lập chip đồng hồ thật** trong thí nghiệm E3.

### 4.4. CPU (`cpu_sc.v` G1, `cpu_pipe.v` G2)

- **Nền (chốt từ 24/09, dùng lại từ đề cũ):**
  - ISA tập con MIPS32 (§4.5), 32 thanh ghi 32 bit (`$0` = 0), PC địa chỉ byte, `PC+4`, **không delay slot** (khớp MARS mặc định). MARS chỉ thử được đoạn MIPS thuần; lệnh tùy biến (`bcd`) chạy qua `asm.py` + `iss.py`.
  - 2 core cùng ISA: G1 single-cycle (P&H §4.4), G2 pipeline 5 tầng (P&H §4.6–4.8). Dùng chung ALU, `muldiv`, `bcd_unit`, CP0, MMIO; chỉ khác datapath/control. Làm G2 **sau** khi G1 PASS (G1 là baseline để so).
  - Harvard: IMEM 1024 word + DMEM 1024 word, BRAM khởi tạo từ `.hex`. BRAM đọc **đồng bộ**: G1 chạy **2 pha trên cùng clock 50 MHz** (chu kỳ CPU = 2 chu kỳ hệ thống; IMEM chốt `next_pc` ở pha A, DMEM/MMIO ở pha B) — tương đương "BRAM sườn xuống" chốt 24/09 nhưng sửa lỗi: bản sườn xuống không còn chỗ cho `lw` (`mmio-map.md` §1.1). LUT-RAM chỉ là phương án phụ trên Xilinx (MAX 10 nhiều khả năng không có, `inference`).
  - Khối nhiều chu kỳ (`div`, `bcd` tuần tự) dùng **chung giao diện `busy`**: core giữ PC + thanh ghi tầng tới khi `done` (`control-table.md` §5, `pipeline-policy.md` §6).
- **Pipeline G2** (đặc tả đầy đủ: `docs/pipeline-policy.md`):
  - forwarding EX/MEM → EX và MEM/WB → EX (ưu tiên EX/MEM), `sw` lấy dữ liệu sau forwarding; regfile ghi sườn lên + bypass nội bộ;
  - load-use phát hiện ở ID, 1 bubble, chỉ so toán hạng lệnh thật sự đọc (`uses_rs/uses_rt`);
  - nhánh/nhảy quyết ở **EX**, đoán không nhảy, nhảy thật xóa IF + ID (phạt 2). Nhánh ở ID là tối ưu tùy chọn, làm thì phải đo và so;
  - `busy` = 1 → đóng băng PC, IF/ID, ID/EX, đẩy bubble vào EX/MEM, **chốt toán hạng ở chu kỳ start**. Ưu tiên: busy > flush > load-use;
  - IF/ID có bit `valid` (flush không xóa được thanh ghi ra của BRAM); dữ liệu DMEM/MMIO chốt thẳng vào MEM/WB;
  - HI, LO, CP0 đọc-ghi ở EX → không có hazard riêng.
- **Kiểm chứng + số đo:** mỗi lệnh khi WB ghi 1 dòng trace (PC, thanh ghi đích, giá trị), so từng dòng với ISS; bộ chương trình "tra tấn hazard". Báo CPI thật (= `CYCLE_COUNT` / số lệnh), bubble theo nguyên nhân, Fmax G1 vs G2 → thời gian = số lệnh × CPI ÷ Fmax.
- **Mới — ngắt/ngoại lệ tối giản (CP0):**
  - Thanh ghi `Status` (IE, EXL), `Cause` (IP [15:8] = `PENDING & ENABLE`), `EPC`.
  - Lệnh `mfc0`, `mtc0`, `eret` (mã MIPS32 chuẩn).
  - Vector cố định `0x180`.
  - **G1 (tầng 2):** nhận ngắt ở **cuối** lệnh và khi không `busy`: `EPC ← next_pc` (lệnh kế tiếp chưa chạy, `isa-spec.md` §5), `PC ← 0x180`, `EXL ← 1`. `eret`: `PC ← EPC`, `EXL ← 0`. Dễ, đúng P&H §4.9 bản rút gọn.
  - **G2 pipeline (tầng 3):** ngắt chính xác: chèn ở ID, xóa IF/ID, `EPC` = PC lệnh bị chặn; tương tác với nhánh đang xóa và `busy`. Khó → tầng 3. Không kịp thì G2 chạy polling, báo cáo phân tích trên giấy.
- Firmware chạy được **cả polling lẫn ngắt** (cờ biên dịch) → so trực tiếp.

### 4.5. ALU & khối số học (`alu.v`, `muldiv.v`, `bcd_unit.v`)

- ALU 32 bit: `addu subu and or xor slt sll sra`, cờ zero cho nhánh. Số âm bù 2 dùng thật ở TIMER âm và lệch hiệu chỉnh.
- `mul` tổ hợp (DSP, ghi rõ). `div` **có dấu** (khớp MIPS), restoring hoặc non-restoring, 32 chu kỳ, `busy`.
  - Chia cho 0: MIPS không định nghĩa → nhóm tự định nghĩa `LO = 0`, `HI = số bị chia`, bật cờ `dz` đọc qua MMIO (`DIV_FLAGS`). Firmware luôn kiểm trước khi chia.
- **Lệnh tùy biến `bcd rd, rs`** (SPECIAL2 funct 0x10): nhị phân 0..99 999 999 → 8 chữ số BCD trong 1 word. Hai cách hiện thực, **cùng một lệnh**:
  - **tổ hợp** (double-dabble trải phẳng, 1 chu kỳ, đường găng dài → Fmax tụt?);
  - **tuần tự** (dịch-cộng-3, ~27 chu kỳ, dùng `busy`).
  - Đo cả hai: đây là bài học "lệnh 1 chu kỳ có đáng không".
- **ISA = 28 lệnh:** 22 dòng chuẩn cũ + `xor` + `mul` + `bcd` + `mfc0` + `mtc0` + `eret`.
  - `docs/control-table.md` v2 đã có đủ 28 dòng + script tự kiểm PASS (01/10); TV2, TV3 **duyệt**, không viết lại.
  - Funct 0x10 của `bcd` (vùng SPECIAL2 dành cho người dùng): TV2 đối chiếu MIPS32 Vol II ở S1′.

## 5. MMIO (offset âm từ `$zero`, truy cập bằng `lw/sw offset($zero)`)
Bản đầy đủ tới từng bit + bus + ngắt: `docs/mmio-map.md` (file đó thắng nếu lệch). Tóm tắt:
| Offset | R/W | Thanh ghi |
|---|---|---|
| -256 | R | `CYCLE_COUNT` |
| -252 | R | `MS_OF_DAY` (đọc thì chụp DAY) · -248 R `DAY_SHADOW` |
| -244/-240/-236 | W·W·R/W | `SET_MS`, `SET_DAY`, `RTC_CTRL` (ghi arm, đọc `ARM`) |
| -232 | R/W | `CAL` (hiệu chỉnh, có dấu) |
| -228 | R/W | `SW_CTRL` (run, reset, chọn nguồn start/stop: nút phần cứng hoặc CPU) · -224 R `SW_VALUE` · -220 R `SW_LAP` (đọc thì lấy khỏi FIFO) |
| -216 | R/W | `TMR_VALUE` (có dấu) · -212 R/W `TMR_CTRL` |
| -208…-196 | R/W | `ALARM0..3` |
| -192 | R | `BTN_EVENT` (mã nút + dấu thời gian ms; đọc thì xóa) |
| -188/-184/-180 | R/W·R/W·R | `IRQ_ENABLE`, `IRQ_PENDING` (ghi 1 xóa), `IRQ_STAMP` |
| -176/-172/-168 | R/W·R·W | `UART_STATUS` (ghi 1 xóa cờ), `UART_RX`, `UART_TX` |
| -164…-136 | W | `DISP0..7` |
| -132/-128 | W | `BLINK_MASK`, `BRIGHT` |
| -124/-120 | W | `BEEP_FREQ`, `BEEP_PATTERN` |
| -116 | R/W | `CPU_CLK_DIV` |
| -112 | R | `DIV_FLAGS` |
| -104 | R/W | `RTC_BCD` (tầng 2, DSE: bộ đếm BCD phần cứng) |
- Thanh ghi đọc có tác dụng phụ (`SW_LAP`, `BTN_EVENT`, `UART_RX`, `MS_OF_DAY`) chỉ tác động ở MEM. Lệnh đã tới MEM thì không bị xóa (nhánh ở EX chỉ xóa IF/ID và ID/EX) → an toàn trong pipeline. **Riêng khi có ngắt ở G2 (tầng 3) phải kiểm lại điều này.**

## 6. Firmware (`fw/`, assembly — chạy trên ISS trước, rồi lên RTL)
- `main.s`: máy trạng thái 5 chế độ (§2), polling hoặc ngắt.
- `fmt.s`: đổi ms → chữ số bằng 3 cách: `div` thuần / lệnh `bcd` / đọc bộ đếm BCD. **Đây là benchmark chính.**
- `set.s`: chỉnh giờ, giới hạn trường (giờ 0–23, ngày theo tháng, năm nhuận).
- `alarm.s`, `chime.s`.
- `sync.s`: parse câu `$T,<ms_of_day>,<day>*CS` từ PC (checksum XOR). Sau 2 lần sync: `ppm = lệch / khoảng cách` → cập nhật `CAL` bằng công thức số nguyên không tràn (`timer-spec.md` §9). Lọc giá trị vô lý (> 200 ppm).
- Không có board → không có `sync_host.py`: testbench đóng vai PC (`tb/uart_host.v`) gửi câu sync và đọc câu trả lời.

## 7. Phân công 5 người (theo đúng tầng của báo cáo)
| TV | Tầng | Sở hữu | Bằng chứng PASS |
|---|---|---|---|
| **TV1** | **ALU & số học** | `alu`, `muldiv`, `bcd_unit` (2 bản), script DSE (LUT/Fmax: bcd tổ hợp/tuần tự, bộ đếm nhị phân/BCD) | vector ≥ 1000 ca + biên; `bcd` khớp golden **mọi giá trị 0..10⁸−1** trên tb tổ hợp (hoặc mẫu 10⁶ nếu chậm) |
| **TV2** | **Công cụ & hazard** | `asm.py`, `iss.py` (có CP0 + ngắt + mô hình ngoại vi tối thiểu), `cmp_trace.py`, hazard/forwarding unit, bộ test hazard; từ S5: `main.s` + `fmt.s` | `asm.py` khớp MARS; ISS khớp vector `tb/vectors/`; mọi test hazard: trace G2 == ISS; firmware chạy trên ISS đúng mọi kịch bản §10 |
| **TV3** | **CPU & chip** | G1, G2, control 28 dòng, regfile, `system_tb`, **CP0 + ngắt G1**, bus/giải mã MMIO, `irq_ctrl`, `soc_top`, `system_tb` | co-sim trace == ISS cả 2 core; test ngắt: EPC, eret, ngắt trúng lúc `div` busy |
| **TV4** | **Hiển thị & âm thanh** | `display_ctrl`, `seg7_scan` (ghosting, PWM, blink), ROM ký tự, (T2) `vga_digits`, bộ tạo âm, UART | tb: thứ tự quét, khoảng tắt, nháy 2 Hz, mẫu bíp; ảnh/video board; đo LUT VGA |
| **TV5** | **Định thời chuẩn ms** | `timebase` (chia phân số + CAL), RTC, STOPWATCH capture, TIMER âm, ALARM, nút + dấu thời gian, `sync.s`, `sync_host.py`, chạy E1/E2 | tb: qua nửa đêm, TIMER qua 0 sang âm, lap, CAL ±50 ppm cho đúng số chu kỳ/giây, cạnh nút có rung |

- Firmware khác: `set.s` → TV5, `alarm.s` + `chime.s` → TV4 (bổ sung 01/10).
- Gói việc chi tiết (output, cổng, test, tiêu chí xong): `docs/goi-viec.md`. Vector test: `tb/vectors/` (sinh bằng `gen_vectors.py`).
- Luật **tự viết code** + cổng bảo vệ giữ nguyên (KE-HOACH §4b).
- **Hợp đồng freeze S1′:** `isa-spec.md`, `control-table.md`, `pipeline-policy.md`, `mmio-map.md` (§5), `timer-spec.md` (§4.1), `display-spec.md` (§4.2).

## 8. Đo đạc (bảng điền ở S7–S10; **không điền trước khi đo**)

**8.1. Chi phí đổi ms → chữ số** (`CYCLE_COUNT`, G1 và G2)
| Cách | Chu kỳ/lần | Tải CPU khi cập nhật 1 kHz @xung tối đa (G1 25 MHz, G2 50 MHz) | @32,77 kHz (E3, đo thật bằng `CPU_CLK_DIV`) | LUT thêm |
|---|---|---|---|---|
| `div` thuần (`fmt_div`, 6 `div`) | 224 | 0,90 % / 0,45 % | 684 % → không kịp (tối đa 146 lần/s) | 0 |
| `bcd` tuần tự (`fmt_bcd`, 3 `div` + `bcd` 28 chu kỳ) | 162 | 0,65 % / 0,32 % | 494 % (tối đa 202 lần/s) | có sẵn trong lõi (chưa tách) |
| `bcd` tổ hợp (`G_BCD_COMB = 1`) | 135 | 0,54 % / 0,27 % | 412 % (tối đa 243 lần/s) | +416 LUT, +98 CARRY4 (+1 082 ô; Fmax chưa đo) |
| bộ đếm BCD phần cứng (`fmt_hw`, `RTC_BCD`) | 24 (G2: 25, có 1 load-use) | 0,10 % / 0,05 % | 73 % (G2: 76 %; tối đa 1 365 lần/s) | +150 LUT, +68 FF (+311 ô) |

- Đo 26/10 (`verified`, `evidence/20261026_fmt.log`): `tb/fmt_bench_tb.v` chạy `fw/fmt.s` trên `soc_top`, Δ`CYCLE_COUNT` quanh mỗi lần gọi trừ chi phí gọi hàm rỗng. "Chu kỳ/lần" = chu kỳ **CPU** (= chu kỳ hệ thống / D), giống nhau ở G1 và G2 vì `div` (33) và `bcd` (28) chiếm gần hết; G2 nhanh gấp đôi chỉ nhờ xung 50 MHz. Cột 32,77 kHz đo thật với `CPU_CLK_DIV = 1526` (G1: 341 824 / 247 212 / 206 010 / 36 624 chu kỳ hệ thống = đúng 1526 × số ở cột 2).
- LUT/FF (26/10, `tools/dse_report.py` khối `soc_g1_bcdc`, `soc_g1_rtcb` so với `soc_g1` 3 701 LUT): Yosys map LUT thật, vẫn `inference` (không phải Vivado). `bcd` tổ hợp bớt 59 FF vì bỏ thanh ghi của bản tuần tự.
- "Ô" = số cell Yosys `synth_xilinx -run :map_ffs` của cả `soc_top` G1 (**13 364** khi tắt cả hai — đo lại 26/10 sau khi IMEM G1 vào BRAM, đã gồm VGA; số 15 442 cũ đo trước sync/VGA và lúc IMEM còn bị dựng bằng LUT (cùng có VGA: 16 933 → 13 364); chênh +311 / +1 082 không đổi, log `work/yosys_soc_top_G1_G_BCD_COMB*_RTC*_20261026_bram.log`), **không phải LUT**: `synth_xilinx` đầy đủ lỗi ABC9 trên bản Yosys đang dùng.
- Đọc bảng: tải ở đây là cập nhật **1 000 lần/s** (màn giây.ms). Màn `HH.MM.SS` chỉ cần 1 lần/s → chia 1 000: kể cả `div` thuần ở 32,77 kHz cũng chỉ 0,68 %.

**8.2. Phần cứng:** LUT/FF/BRAM/DSP/Fmax: G1, G1 + ngắt, G2, display 7 đoạn, VGA, timers.

Đo 26/10 (`inference`: Yosys, không phải Vivado; chưa có Fmax) — `python tools/dse_report.py`, log `work/dse_<khối>.log`, bảng `work/dse_20261026.md`. Luồng: `synth_xilinx -run :map_luts` rồi `abc -lut 6` (abc9 lỗi assertion). Ngắt nằm trong lõi (CP0) nên không tách được "G1 + ngắt"; `irq` là riêng bộ điều khiển ngắt.

| Khối | Mô tả | LUT | FF | BRAM36 | BRAM18 | LUTRAM | DSP | CARRY4 |
|---|---|---|---|---|---|---|---|---|
| soc_g1 | SoC đầy đủ, lõi G1 | 3701 | 2767 | 3 | 0 | 13 | 4 | 317 |
| soc_g1_bcdc | SoC G1 + `bcd` tổ hợp (§8.1) | 4117 | 2708 | 3 | 0 | 13 | 4 | 415 |
| soc_g1_rtcb | SoC G1 + `RTC_BCD` (§8.1) | 3851 | 2835 | 3 | 0 | 13 | 4 | 325 |
| soc_g2 | SoC đầy đủ, lõi G2 | 3754 | 3217 | 3 | 0 | 13 | 4 | 324 |
| cpu_g1 | lõi G1 (gồm CP0 + ngắt, IMEM, DMEM) | 2014 | 1311 | 3 | 0 | 0 | 3 | 87 |
| cpu_g2 | lõi G2 pipeline (gồm hazard, ngắt) | 2273 | 1758 | 3 | 0 | 0 | 3 | 95 |
| irq | bộ điều khiển ngắt | 57 | 81 | 0 | 0 | 0 | 0 | 0 |
| display | display_ctrl (quét LED + VGA) | 344 | 113 | 0 | 0 | 0 | 1 | 60 |
| seg7 | quét 7 đoạn (seg7_scan + char_rom) | 79 | 28 | 0 | 0 | 0 | 1 | 15 |
| vga | VGA đuổi tia | 126 | 25 | 0 | 0 | 0 | 0 | 35 |
| timebase | timebase + CAL | 138 | 82 | 0 | 0 | 0 | 0 | 22 |
| rtc | RTC | 142 | 149 | 0 | 0 | 0 | 0 | 17 |
| stopwatch | stopwatch (capture) | 207 | 159 | 0 | 0 | 5 | 0 | 43 |
| cdtimer | TIMER đếm ngược | 202 | 150 | 0 | 0 | 0 | 0 | 38 |
| alarm | alarm | 233 | 210 | 0 | 0 | 0 | 0 | 7 |
| uart | UART (FIFO 64 byte) | 123 | 116 | 0 | 0 | 3 | 0 | 16 |
| muldiv | mul + div tuần tự | 248 | 169 | 0 | 0 | 0 | 3 | 43 |
| alu | ALU | 323 | 0 | 0 | 0 | 0 | 0 | 16 |

- Khối đo riêng giữ mọi cổng ra nên có thể lớn hơn phần nó chiếm trong SoC (SoC cắt logic không dùng); tổng các khối con ≈ 3 460 LUT so với SoC 3 701 (phần còn lại: nút, beeper, `soc_regs`, bus).
- G2 so với G1: +447 FF (thanh ghi tầng), LUT +259 ở mức lõi nhưng chỉ +53 ở mức SoC (tối ưu sau flatten).
- Regfile 32 × 32 thành FF (2 cổng đọc tổ hợp), nằm trong FF của lõi. DSP ở quét 7 đoạn: phép nhân hằng `bright * G_STEP` (`seg7_scan.v:75`).

**8.3. Đời thực**
| Thí nghiệm | Cách làm | Kết quả |
|---|---|---|
| **E1′** trôi → sau hiệu chỉnh (mô phỏng) | tb giả thạch anh lệch e ppm (chu kỳ clock 20 ns × (1 − e)), `G_N = 50 000` thật; đo ppm, tính `CAL` bằng công thức firmware, chạy lại | ppm trước/sau; so Casio 11,6 ppm (spec) |
| **E2′** đếm ngược (mô phỏng) | timer 2 000 ms ở `G_N = 50 000` (10⁸ chu kỳ), có/không `CAL` | `ZERO` đúng tới chu kỳ; lệch quy ra ms/10 phút |
| **E3** xung thấp: polling vs ngắt vs capture | G1 (ngắt chỉ có ở G1), `CPU_CLK_DIV` = 2 / 100 / 1526; bấm giờ 1000 lần do tb/PC tạo; đếm tick bị lỡ, độ trễ ngắt (`IRQ_STAMP`) | bảng: cách nào còn đúng ms ở 32 kHz |
| **E4′** hiển thị (mô phỏng) | waveform anode/đoạn ở 3 tần số quét, có/không khoảng tắt; màn hình ảo + ảnh VGA | chỉ ra khoảng gây bóng ma; ảnh demo |

## 9. Tầng & luật cắt
- **Tầng 1 (bắt buộc, M1 15/11):**
  - G1 polling;
  - timebase, RTC, STOPWATCH capture, TIMER âm, ALARM, nút;
  - display 7 đoạn có nhấp nháy + PWM; bíp;
  - firmware 5 chế độ;
  - `system_tb` PASS.
- **Tầng 2 (M2 22/11, demo M3 29/11):**
  - G2 pipeline (polling);
  - ngắt ở G1;
  - `bcd` 2 bản + DSE 8.1;
  - UART sync + `CAL` + E1/E2/E3;
  - VGA đuổi tia.
- **Tầng 3 (tùy chọn):** ngắt chính xác ở pipeline; GPS PPS; **âm lịch** (thuật toán Hồ Ngọc Đức, múi UTC+7; bảng 1 word/năm = 13 bit độ dài tháng + 4 bit tháng nhuận + 6 bit lệch Tết; năm 1969–2099; VN khác TQ, ví dụ Tết 2007: 17/02 vs 18/02; Tết 1985 phải kiểm nguồn — tất cả `unverified`); điều khiển LCD trần bằng sóng AC.
- 15/11 G1 chưa PASS → dừng tầng 2. 22/11 pipeline chưa chạy hết firmware → bỏ G2. **Thứ tự cắt khi trễ:** VGA → E3 → `bcd` tổ hợp → ngắt G1 → G2.
- Demo luôn dùng bản cao nhất đã PASS `system_tb`.

## 10. Kịch bản `system_tb` (tầng 1)
1. Đặt giờ 23:59:59.990 → qua nửa đêm: ngày +1, thứ đúng, không xé số.
2. Stopwatch: start ở t₀, stop ở t₀ + 1234,567 ms (tb tạo cạnh nút **có rung**) → hiện `00:01.234`, giá trị đúng tới ms.
3. Lap ×3 → đọc lại đúng thứ tự.
4. Timer 00:02.000 → về 0 đúng ms, chuông kêu, hiện `-00:00.500` sau 2,5 s.
5. Alarm 07:00 bật ngày thứ 2 → kêu đúng phút; snooze → kêu lại sau 5 phút; tắt ngày Chủ nhật → không kêu.
6. Chế độ SET: chữ số đang chỉnh nhấp nháy (đọc `BLINK_MASK`); giờ 23 +1 → 0.
7. (T2) Sync qua UART + checksum sai bị bỏ; `CAL = 163 840` (+50 ppm khi chạy 50 MHz thật) → 1 s mô phỏng (`G_N = 50`) dài đúng 52 500 chu kỳ.

## 11. Lịch (mốc giữ như kế hoạch từ 24/09; tuần 1 = 07/09 vẫn là giả định)
| Sprint | Ngày | Việc | Done khi |
|---|---|---|---|
| **S1′** | 01–04/10 (freeze hợp đồng hạn 07/10, chạy song song đầu S2) | Long báo thầy đổi đề (§12) · freeze 6 file hợp đồng · cài toolchain (`tools/setup_env.sh`) | thầy OK đề; hợp đồng duyệt |
| **S2** | 05–11/10 | ALU+`xor`, regfile, `muldiv` (**làm luôn**, không phụ thuộc đề) · `seg7_scan` + ROM · `timebase` | tb đơn vị PASS |
| **S3** | 12–18/10 | control + G1 datapath · RTC, STOPWATCH, TIMER + tb · `display_ctrl` · ISS chạy | tb PASS; ISS chạy `fmt.s` |
| **S4** | 19–25/10 | **G1 co-sim PASS** · ALARM, nút, bộ tạo âm · `bcd` tuần tự · `main.s` bản 1 | co-sim G1 PASS |
| **S5** | 26/10–01/11 | `soc_top` G1 + ngoại vi · bắt đầu pipeline · CP0 + ngắt G1 · UART | `system_tb` 1–3 PASS |
| **S6** | 02–08/11 | **Giữa kỳ, tải nhẹ** · sửa lỗi · pipeline không hazard | — |
| **S7** | 09–15/11 | `system_tb` **1–6 PASS** · forwarding + load-use · **cổng 1 (14/11)** | **🏁 M1** |
| **S8** | 16–22/11 | G2 chạy toàn firmware · `bcd` tổ hợp · DSE 8.1 · `sync.s` + `CAL` · **cổng 2 (21/11)** | **🏁 M2** |
| **S9** | 23–29/11 | E1′, E2′, E3, E4′ (mô phỏng) · màn hình ảo · VGA | **🏁 M3** |
| **S10** | 30/11–06/12 | bảng §8, báo cáo, slide, video · **cổng 3 = tổng duyệt (05/12)** | nộp được; cả 5 qua cổng |
| S11 | 07–13/12 | **🎓 bảo vệ (tuần 14, Long chốt 01/10; ngày cụ thể chưa biết)** | — |

## 12. Pitch 5 phút (Long nói với thầy / khi bảo vệ)
1. **Mở:** cầm đồng hồ Casio F-91W (hoặc ảnh): "Cái đồng hồ 200 nghìn này có một con chip chạy 32 kHz, bấm giờ 1/100 giây, sai 30 giây mỗi tháng. Nhóm mình **tự thiết kế lại con chip đó**: màn hình, bộ đếm giờ, CPU, tới ALU. Rồi làm hơn nó: chuẩn tới ms, đếm ngược sang âm, tự đồng bộ giờ chuẩn qua máy tính."
2. **Vì sao hay:** mỗi người một tầng phần cứng. Mọi đáp án kiểm bằng đồng hồ thật hoặc giờ NTP. Demo ai cũng hiểu: bấm nút là chạy.
3. **Câu hỏi kiến trúc:** "chuẩn ms thì phần nào phải là phần cứng?" → có số đo, có thí nghiệm hạ xung 32 kHz.
4. **An toàn:** lõi CPU đã có đặc tả (control 28 dòng, pipeline policy). Tầng 1 đủ qua môn.
5. **Đã chốt 01/10:** Verilog, chỉ mô phỏng (không board), bảo vệ tuần 14. **Còn chốt:** ai nhận tầng nào (§7).

## 13. Rủi ro
| Rủi ro | Dấu hiệu | Phương án |
|---|---|---|
| Thầy chê "đồng hồ là bài cơ bản" | pitch thầy | nhấn: tự làm CPU + pipeline + ngắt; câu hỏi ms/32 kHz có số đo; so Casio |
| Thầy không cho đổi đề | S1′ | lõi CPU + 6 file hợp đồng dùng chung; spec đề cũ đã xóa → viết lại phần ứng dụng, báo Long quyết |
| Ngắt làm vỡ CPU | S5 test ngắt | tầng 1 chạy polling; ngắt G1 là tầng 2, G2 là tầng 3 |
| Không có board → thầy hỏi "đời thực đâu?" | bảo vệ | E1′ giả lệch thạch anh có số đo; nói rõ giới hạn (nhiệt, rung nút thật) ở ngân hàng K2, K4 |
| Mô phỏng `G_N = 50 000` quá chậm trên iverilog | S8 | chỉ chạy module nhỏ (timebase/timer) ở `G_N` thật; SoC đầy đủ dùng `G_N = 50` |
| TV5 quá tải (timers + sync) | S4 | TV4 nhận UART (đã ghi); TV2 nhận `sync.s` nếu cần |

## 14. Ghi chú kiểm (3 vòng, 01/10/2026)
- **Vòng 1:**
  - Hiểu lại yêu cầu: đồng hồ điện tử đa năng, sâu phần cứng từ hiển thị → ALU; "thời gian âm" = đếm ngược sang âm.
  - Viết v5 tái dùng lõi CPU; tính ngân sách bằng python: 0,28 ppm/1 ms/h; 11,6 ppm Casio; 27 bit ms/ngày; 29 bit stopwatch; 33 chu kỳ/ms ở 32 kHz; framebuffer 37,5 KB.
- **Vòng 2 (sai ở đâu):**
  - "Chuẩn ms" là độ phân giải; độ chính xác thì phụ thuộc ppm → tách hai khái niệm, thêm `CAL` + E1/E2.
  - Dấu thời gian nút lấy sau chống rung → trễ không đều → lấy ở cạnh đầu.
  - Đọc giờ qua nửa đêm → thanh ghi bóng.
  - Ngắt chính xác trong pipeline khó hơn nhiều so với single-cycle → hạ G2 ngắt xuống tầng 3.
  - Tác dụng phụ MMIO an toàn khi polling, nhưng phải kiểm lại khi có ngắt ở G2.
  - Số chu kỳ format "≈ 360" là ước lượng → để cột đo.
  - ISA vẫn 28 dòng (đếm lại: 22 + `xor` + `mul` + `bcd` + `mfc0` + `mtc0` + `eret`).
- **Vòng 3 (câu chưa ai hỏi):**
  - Long có thể muốn "âm" = âm lịch → giữ đường lùi ở tầng 3.
  - Hiện ms trên LED thì mắt không đọc kịp → ms chỉ có nghĩa khi dừng/lap; khi đang chạy, chữ số ms vẫn đổi nhưng chỉ để nhìn.
  - Thông số board, Casio, DS3231 đều theo trí nhớ → trích datasheet ở S1′.
  - Con số tải CPU ở 32 kHz phải đo thật bằng `CPU_CLK_DIV`, không chỉ quy đổi.
  - Người chấm đã thấy pipeline của Nhóm 3 → phần khác biệt là timers + hiển thị + câu hỏi ms/32 kHz, không phải pipeline.
