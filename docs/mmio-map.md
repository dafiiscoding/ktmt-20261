# mmio-map.md — Clock, bus, bản đồ MMIO, bộ điều khiển ngắt (hợp đồng S1′)

> **Trạng thái:** BẢN NHÁP v1 (01/10/2026). Claude viết; **chủ: TV3**, người duyệt: TV4, TV5. Freeze cuối S1′.
> Chi tiết hành vi từng khối: `timer-spec.md` (TV5), `display-spec.md` (TV4). File này thắng nếu địa chỉ/bit lệch nhau.

## 1. Clock và reset
- **Một miền clock duy nhất:** `clk` 50 MHz (testbench tạo; không có board).
  - Mọi khối chậm hơn (CPU khi hạ xung, VGA 25 MHz, UART, quét LED) dùng **clock enable**, không tạo clock mới.
  - Hệ quả: không có clock domain crossing ở đâu cả, trừ chân vào (nút, UART RX) đi qua 2 flip-flop đồng bộ.
- `rst` đồng bộ, mức cao, giữ ≥ 4 chu kỳ. Chân reset → đồng bộ 2 FF → `rst`.
- **CPU clock enable** (`cpu_ce`), sinh từ `CPU_CLK_DIV` (§3, offset −116):
  - `D` = số chu kỳ hệ thống cho **một chu kỳ CPU**.
  - G1 cần `D ≥ 2` và chẵn (giá trị nhỏ hơn → 2, lẻ → bỏ bit 0). G2 cần `D ≥ 1` (0 → 1).
  - Reset: G1 `D = 2` (CPU 25 MHz), G2 `D = 1` (CPU 50 MHz).
  - Giả lập chip đồng hồ 32,768 kHz: `D = 1526` → 50·10⁶ / 1526 ≈ 32 765 Hz (lệch −0,008%).

### 1.1. G1 single-cycle trên BRAM đọc đồng bộ: 2 pha
Một chu kỳ CPU của G1 = 2 cạnh `cpu_ce` liên tiếp, gọi là **pha A** (đầu chu kỳ) và **pha B** (giữa chu kỳ).
| Cạnh | Việc |
|---|---|
| pha A | PC, regfile, HI/LO, CP0 cập nhật. **IMEM chốt `mem[next_pc]`** → thanh ghi đầu ra IMEM chính là lệnh của chu kỳ mới |
| giữa A → B | giải mã, đọc regfile, ALU tính địa chỉ / kết quả |
| pha B | DMEM và MMIO chốt địa chỉ: `sw` ghi, `lw` đọc ra thanh ghi đầu ra; tác dụng phụ của MMIO xảy ra ở đây |
| giữa B → A | dữ liệu `lw` qua MUX về cổng ghi regfile; tính `next_pc` |

- Đây chính là ý "BRAM ở sườn xuống" (chốt 24/09), nhưng làm bằng 2 cạnh lên của cùng clock 50 MHz.
  - Mỗi nửa có trọn 20 ns, không bị ràng buộc nửa chu kỳ 10 ns như khi dùng sườn xuống thật.
  - Không có clock thứ hai.
- **Sửa so với 24/09:** IMEM phải được địa chỉ bằng `next_pc` ở pha A. Nếu IMEM chốt `PC` ở giữa chu kỳ thì không còn chỗ cho DMEM. Lý do này phải có trong mục "vì sao chọn" của báo cáo.
- Reset: khi `rst = 1` thì `next_pc` ép về 0, nên sau reset thanh ghi đầu ra IMEM đã chứa `mem[0]`.
- Khi `busy`: `next_pc = PC`, IMEM chốt lại đúng lệnh cũ.

### 1.2. G2
Mỗi tầng 1 chu kỳ CPU (`D = 1` → 50 MHz). IMEM địa chỉ bằng **thanh ghi PC của tầng IF** (không phải `pc_next` như G1), chốt ở cạnh cuối IF; thanh ghi đầu ra = `IF/ID.instr`; stall → IMEM `en = 0`. (Nếu địa chỉ bằng `pc_next` thì IF và ID nhập một, flush `IF/ID.valid ← 0` sẽ xóa luôn lệnh đích và phạt chỉ còn 1, trái bảng T3.) DMEM/MMIO chốt ở cạnh cuối tầng MEM, thanh ghi đầu ra = `MEM/WB.mem_data` (`pipeline-policy.md` §1).

## 2. Bus ngoại vi (mọi khối MMIO tuân theo)
| Tín hiệu (CPU → khối) | Rộng | Nghĩa |
|---|---|---|
| `bus_addr` | 8 | byte thấp của địa chỉ (`0x00`–`0xFC`), luôn căn 4 |
| `bus_wdata` | 32 | dữ liệu `sw` |
| `bus_we` | 1 | ghi, **chỉ bật đúng 1 chu kỳ hệ thống** cho mỗi lệnh `sw` |
| `bus_re` | 1 | đọc, **chỉ bật đúng 1 chu kỳ hệ thống** cho mỗi lệnh `lw` |
| `bus_rdata` (khối → CPU) | 32 | **có thanh ghi**: chốt ở cùng cạnh với `bus_re` |

- Đồng bộ, độ trễ đọc 1 cạnh, **giống hệt BRAM**, nên CPU đối xử DMEM và MMIO như nhau.
  - **`bus_rdata` giữ nguyên tới lần `bus_re` kế tiếp** (không tự về 0 ở chu kỳ sau): khi `D > 2` CPU lấy giá trị ở pha A, muộn hơn cạnh pha B nhiều chu kỳ hệ thống. Mỗi lần `bus_re` (phát chung cho mọi khối), khối không được gọi tới phải nạp 0 → bộ giải mã OR các khối vẫn đúng. (Phát hiện 02/10 khi chạy co-sim với `cpu_ce` 1/3; `rtc` đã làm đúng.)
- `bus_we`, `bus_re` đã AND với `cpu_ce` (G1: pha B; G2: cạnh cuối tầng MEM). Nhờ vậy tác dụng phụ (pop FIFO, xóa cờ) xảy ra **đúng 1 lần mỗi lệnh**, kể cả khi CPU chạy chậm 1526 lần.
- Giải mã: địa chỉ `0xFFFF_FFxx` → MMIO; `0x0000_0xxx` → DMEM; còn lại → đọc 0, ghi bỏ. Bộ giải mã chốt "lần đọc này thuộc khối nào" cùng cạnh, để MUX `bus_rdata` đúng ở chu kỳ sau.
- Thanh ghi chỉ-đọc: ghi bị bỏ. Thanh ghi chỉ-ghi: đọc ra 0. Địa chỉ MMIO trống: đọc 0, ghi bỏ.
- **Lưu ý cho G2 (tầng 3):** lệnh đã tới MEM không bao giờ bị xóa (nhánh ở EX chỉ xóa IF/ID, ID/EX), nên tác dụng phụ an toàn khi polling. Thêm ngắt chính xác thì phải chứng minh lại.

## 3. Bản đồ địa chỉ
Offset dùng trong `lw/sw offset($zero)`. Địa chỉ = `0xFFFF_FF00 + (offset + 256)`.

| Offset | Địa chỉ | Tên | R/W | Khối | Spec |
|---|---|---|---|---|---|
| −256 | `FF00` | `CYCLE_COUNT` | R | soc | §4.1 |
| −252 | `FF04` | `MS_OF_DAY` | R (đọc thì chụp ngày) | rtc | timer §3 |
| −248 | `FF08` | `DAY_SHADOW` | R | rtc | timer §3 |
| −244 | `FF0C` | `SET_MS` | W | rtc | timer §3 |
| −240 | `FF10` | `SET_DAY` | W | rtc | timer §3 |
| −236 | `FF14` | `RTC_CTRL` | R/W | rtc | timer §3 |
| −232 | `FF18` | `CAL` | R/W | timebase | timer §2 |
| −228 | `FF1C` | `SW_CTRL` | R/W | stopwatch | timer §4 |
| −224 | `FF20` | `SW_VALUE` | R | stopwatch | timer §4 |
| −220 | `FF24` | `SW_LAP` | R (đọc thì lấy khỏi FIFO) | stopwatch | timer §4 |
| −216 | `FF28` | `TMR_VALUE` | R/W | timer | timer §5 |
| −212 | `FF2C` | `TMR_CTRL` | R/W | timer | timer §5 |
| −208 | `FF30` | `ALARM0` | R/W | alarm | timer §6 |
| −204 | `FF34` | `ALARM1` | R/W | alarm | timer §6 |
| −200 | `FF38` | `ALARM2` | R/W | alarm | timer §6 |
| −196 | `FF3C` | `ALARM3` | R/W | alarm | timer §6 |
| −192 | `FF40` | `BTN_EVENT` | R (đọc thì lấy khỏi FIFO) | buttons | timer §7 |
| −188 | `FF44` | `IRQ_ENABLE` | R/W | irq | §5 |
| −184 | `FF48` | `IRQ_PENDING` | R/W (ghi 1 để xóa) | irq | §5 |
| −180 | `FF4C` | `IRQ_STAMP` | R | irq | §5 |
| −176 | `FF50` | `UART_STATUS` | R/W (ghi 1 để xóa cờ) | uart | display §6 |
| −172 | `FF54` | `UART_RX` | R (đọc thì lấy khỏi FIFO) | uart | display §6 |
| −168 | `FF58` | `UART_TX` | W | uart | display §6 |
| −164 … −136 | `FF5C` … `FF78` | `DISP0` … `DISP7` | W | display | display §2 |
| −132 | `FF7C` | `BLINK_MASK` | W | display | display §2 |
| −128 | `FF80` | `BRIGHT` | W | display | display §2 |
| −124 | `FF84` | `BEEP_FREQ` | W | beeper | display §5 |
| −120 | `FF88` | `BEEP_PATTERN` | W | beeper | display §5 |
| −116 | `FF8C` | `CPU_CLK_DIV` | R/W | soc | §1 |
| −112 | `FF90` | `DIV_FLAGS` | R | muldiv | §4.2 |
| −108 | `FF94` | *(trống — dành cho bài D6 "công tắc")* | — | — | — |
| −104 | `FF98` | `RTC_BCD` | R/W | rtc_bcd (tùy chọn, DSE) | timer §8 |
| −100 … −4 | `FF9C` … `FFFC` | trống | — | — | — |

`DISPi` ở offset `−164 + 4·i` (`DISP0` = chữ số **phải nhất**).

## 4. Thanh ghi của soc
### 4.1. `CYCLE_COUNT` (−256)
- Đếm **chu kỳ hệ thống** 50 MHz từ reset, 32 bit, tràn quay vòng sau 85,9 s. Không phụ thuộc `CPU_CLK_DIV`.
- CPI = Δ`CYCLE_COUNT` / (`D` × số lệnh). Số lệnh lấy từ trace mô phỏng.

### 4.2. `DIV_FLAGS` (−112)
- [0] `DZ`: lệnh `div` gần nhất chia cho 0 (`isa-spec.md` §4). Bit khác 0.

### 4.3. `CPU_CLK_DIV` (−116)
- [15:0] `D`. Ghi có hiệu lực từ chu kỳ CPU kế tiếp. Đọc ra giá trị đã chuẩn hóa (sau khi ép theo luật §1).
  - G1 (`soc_regs.v`, 02/10): `sw` ghi D ở cạnh pha B; nửa sau của chính lệnh đó vẫn theo D cũ, D mới tính từ cạnh pha A. Ví dụ `lw CYCLE_COUNT; sw D=6; lw CYCLE_COUNT` (đang D = 2) → hiệu = 2 + 1 + 3 = 6 (`fw/tests/soc/bus.s`).
- `CAL` (−232) đặt trong `soc_regs.v` cùng các thanh ghi soc, nối dây tới `timebase` chính (bảng §3 ghi khối "timebase" theo nghĩa chức năng).

## 5. Bộ điều khiển ngắt (`irq_ctrl.v`)
| Bit | Nguồn | Sự kiện (xung 1 chu kỳ) |
|---|---|---|
| 0 | `TICK_1MS` | mỗi nhịp ms của timebase chính |
| 1 | `TICK_1S` | mỗi 1000 nhịp ms (bộ đếm xóa khi nạp RTC) |
| 2 | `TMR_ZERO` | TIMER vừa về 0 |
| 3 | `ALARM` | một báo thức bất kỳ khớp |
| 4 | `SW_CAPTURE` | stopwatch chụp start/stop/lap bằng nút phần cứng |
| 5 | `BTN` | một sự kiện nút mới vào FIFO |
| 6 | `UART_RX` | nhận xong 1 byte |
| 7 | `UART_TX_EMPTY` | bộ đệm phát vừa trống |

- `IRQ_PENDING` [7:0]: sự kiện bật bit tương ứng, **không phụ thuộc ENABLE** (polling đọc được). Ghi 1 vào bit nào thì xóa bit đó. Sự kiện và lệnh xóa cùng chu kỳ → **sự kiện thắng** (không mất sự kiện).
- `IRQ_ENABLE` [7:0]: reset 0.
- `irq` = OR của (`PENDING & ENABLE`) → đi vào CPU. `Cause.IP` = `PENDING & ENABLE`.
- `IRQ_STAMP`: chốt `CYCLE_COUNT` ở chu kỳ `irq` đổi 0 → 1. Độ trễ ngắt = `CYCLE_COUNT` đọc ở lệnh đầu handler − `IRQ_STAMP` (thí nghiệm E3).
- Ưu tiên (khi handler muốn xử lý một nguồn trước): bit thấp trước. Phần cứng không cần mạch ưu tiên vì chỉ có 1 vector.

## 6. Kiểm thử của file này (TV3, `tb/bus_tb.v`, `tb/irq_tb.v`)
| ID | Kích thích | Mong đợi |
|---|---|---|
| BUS-1 | `lw` từ mọi địa chỉ đọc được | đúng giá trị khối trả, trễ đúng 1 cạnh |
| BUS-2 | `lw` từ −108, −100, `0x0000_2000` | 0 |
| BUS-3 | `sw` vào thanh ghi chỉ-đọc (`CYCLE_COUNT`) | giá trị không đổi |
| BUS-4 | `D = 1526`, 3 lệnh `lw SW_LAP` liên tiếp, FIFO có 5 phần tử | đúng 3 phần tử bị lấy ra (không phải 3 × 1526) |
| BUS-5 | `CPU_CLK_DIV` ghi 0, 1, 3, 1526 trên G1 | đọc lại 2, 2, 2, 1526 |
| IRQ-1 | sự kiện bit 3 khi ENABLE = 0 | PENDING[3] = 1, `irq` = 0 |
| IRQ-2 | ENABLE[3] = 1 | `irq` = 1, `IRQ_STAMP` = `CYCLE_COUNT` của chu kỳ đó |
| IRQ-3 | ghi 1 vào PENDING[3] cùng chu kỳ sự kiện mới bit 3 | PENDING[3] vẫn = 1 |
| IRQ-4 | ghi `0x08` khi PENDING = `0x0C` | PENDING = `0x04` |
