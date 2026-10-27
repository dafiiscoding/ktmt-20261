# WatchChip: con chip đồng hồ điện tử tự thiết kế (BTL KTMT MI4344)

Nhóm tự thiết kế cả con chip của một chiếc đồng hồ điện tử bằng Verilog: CPU MIPS 32 bit (2 bản), bộ đếm thời gian chuẩn tới ms, LED 7 đoạn, VGA, còi, UART, ngắt, và phần mềm (firmware) viết bằng hợp ngữ MIPS. **Chỉ chạy mô phỏng, không có board.**

Chức năng: xem và chỉnh giờ, bấm giờ, hẹn giờ (đếm xuống 0 rồi đếm tiếp sang số âm), 4 báo thức, đồng bộ giờ với PC.
Câu hỏi chính của đồ án: **muốn đồng hồ chuẩn tới 1 ms thì phần nào phải là phần cứng?** (trả lời bằng số đo ở [`report/2.5-e3-thi-nghiem.md`](report/2.5-e3-thi-nghiem.md)).

## Xem chip chạy trong 1 phút

Mở [`work/demo_tuong_tac.html`](work/demo_tuong_tac.html) bằng trình duyệt (bấm đôi, không cần mạng). Chọn cảnh: giờ, bấm giờ, hẹn giờ, báo thức, đặt giờ. Đây là phát lại log thật của mô phỏng, **không phải chip chạy trực tiếp theo phím bấm**.
Mô phỏng chạy rút gọn (1 ms của chip = 50 nhịp thay vì 50 000), nên nhanh hơn thật khoảng 1000 lần.

Phim 5 chế độ: [`work/demo_system.gif`](work/demo_system.gif).

## Chạy thử trên máy mình

Cần Git Bash (Windows) hoặc bash. Chạy từ thư mục gốc của project:

```
bash tools/setup_env.sh              # cài công cụ portable (1 lần, cần mạng)
source tools/env.sh                  # mỗi lần mở terminal mới
bash tools/run_unit.sh alu           # chạy 1 test (tên = tb/<tên>_tb.v)
bash tools/run_unit.sh               # chạy tất cả (hồi quy), cuối cùng phải ra EXIT 0
python tools/screen.py work/screen_system.log --big   # xem màn LED bằng chữ
```

Mỗi test in dòng cuối `PASS <tên> <số kiểm>` hoặc `FAIL ...`. Hồi quy gần nhất: 41 mục PASS ([`evidence/20261027_regress_rbuf.log`](evidence/20261027_regress_rbuf.log)).

## Đọc theo thứ tự này

| Bước | Đọc | Để biết |
|---|---|---|
| 1 | [`docs/hop-nhom-01-ban-giao.md`](docs/hop-nhom-01-ban-giao.md) | bức tranh chung, ai làm gì, luật học |
| 2 | [`PLAN_DONG_HO.md`](PLAN_DONG_HO.md) | yêu cầu và thiết kế tổng thể |
| 3 | 6 file hợp đồng ở bảng dưới | từng khối phải làm đúng điều gì |
| 4 | file Verilog ở [`src/`](src/) theo thứ tự bảng dưới | khối đó làm sao đạt được |
| 5 | [`fw/main.s`](fw/main.s) | phần mềm đồng hồ chạy trên chip |
| 6 | test ở [`tb/`](tb/) | cách kiểm từng khối |
| 7 | [`report/`](report/) | số đo và kết luận |

Mỗi file `src/*.v` mở đầu bằng 3 dòng: file làm gì, thuộc gói nào, đọc spec nào. Phần giải thích từng đoạn nằm ngay trong code (comment tiếng Việt).

## Sơ đồ khối

```
   nút ──► buttons ─┐                       ┌──► seg7_scan ──► LED 7 đoạn
                    │   ┌──────────────┐    │
 UART RX ─► uart ───┼──►│  bus + MMIO  │◄──►├──► vga_digits ──► VGA
                    │   │  (soc_regs)  │    │
 timebase ─► timers ┘   └──────┬───────┘    └──► beeper ──► còi
 (CAL)   (rtc, sw, tmr, alarm) │  ▲ irq_ctrl (8 nguồn ngắt)
                        ┌──────▼──┴────┐
                        │  CPU G1 / G2 │◄── IMEM (firmware) + DMEM
                        └──────────────┘
```

## Bản đồ file

### Hợp đồng (spec), đọc trước khi đọc code

| File | Nội dung |
|---|---|
| [`docs/isa-spec.md`](docs/isa-spec.md) | 28 lệnh MIPS, mã hóa, ca đặc biệt của chia, ngắt |
| [`docs/control-table.md`](docs/control-table.md) | mỗi lệnh bật tín hiệu điều khiển nào |
| [`docs/pipeline-policy.md`](docs/pipeline-policy.md) | luật pipeline: forwarding, load-use, nhánh, ngắt chính xác |
| [`docs/mmio-map.md`](docs/mmio-map.md) | bản đồ thanh ghi ngoại vi, cách CPU 2 pha đọc bộ nhớ |
| [`docs/timer-spec.md`](docs/timer-spec.md) | `CAL`, giờ, bấm giờ, hẹn giờ, báo thức, nút, đồng bộ giờ |
| [`docs/display-spec.md`](docs/display-spec.md) | LED, VGA, còi, UART, bố cục màn của từng chế độ |

### Chip (`src/`, Verilog)

| File | Làm gì | Spec |
|---|---|---|
| [`alu.v`](src/alu.v) | cộng, trừ, and, or, so sánh, dịch bit | isa-spec §3 |
| [`muldiv.v`](src/muldiv.v) | nhân 1 chu kỳ, chia 32 chu kỳ | isa-spec §4 |
| [`bcd_unit.v`](src/bcd_unit.v) | đổi số nhị phân thành 8 chữ số thập phân | isa-spec §3 |
| [`regfile.v`](src/regfile.v) | 32 thanh ghi | pipeline-policy §2 |
| [`control.v`](src/control.v) | giải mã lệnh thành tín hiệu điều khiển | control-table |
| [`cpu_g1.v`](src/cpu_g1.v) | CPU G1: 1 lệnh mỗi chu kỳ CPU (dùng 2 pha clock) | mmio-map §1.1 |
| [`hazard.v`](src/hazard.v) | phát hiện xung đột dữ liệu và lấy tắt cho G2 | pipeline-policy §3–5 |
| [`cpu_pipe.v`](src/cpu_pipe.v) | CPU G2: pipeline 5 tầng | pipeline-policy |
| [`soc_regs.v`](src/soc_regs.v) | thanh ghi hệ thống: đếm chu kỳ, `CAL`, nhịp CPU | mmio-map §4 |
| [`irq_ctrl.v`](src/irq_ctrl.v) | gom và che 8 nguồn ngắt | mmio-map §5 |
| [`soc_top.v`](src/soc_top.v) | nối CPU với bus và mọi ngoại vi | mmio-map |
| [`timebase.v`](src/timebase.v) | tạo nhịp 1 ms có hiệu chỉnh `CAL` | timer-spec §2 |
| [`timers.v`](src/timers.v) | giờ, bấm giờ, hẹn giờ, 4 báo thức | timer-spec §3–6 |
| [`buttons.v`](src/buttons.v) | 4 nút: đồng bộ, chống rung, ghi giờ lúc bấm | timer-spec §7 |
| [`rtc_bcd.v`](src/rtc_bcd.v) | giờ đếm thẳng bằng chữ số thập phân (để so sánh cách làm) | timer-spec §8 |
| [`char_rom.v`](src/char_rom.v) | mã ký tự thành 7 đoạn | display-spec §3 |
| [`display_ctrl.v`](src/display_ctrl.v) | bộ nhớ màn 8 ô + nháy + độ sáng | display-spec §2 |
| [`seg7_scan.v`](src/seg7_scan.v) | quét LED, chống bóng ma, chỉnh sáng | display-spec §4 |
| [`vga_digits.v`](src/vga_digits.v) | VGA không frame buffer | display-spec §7 |
| [`beeper.v`](src/beeper.v) | còi: tần số + mẫu bật/tắt | display-spec §5 |
| [`uart.v`](src/uart.v) | UART 115 200 baud, nhận có bộ đệm 64 byte | display-spec §6 |

### Phần mềm và công cụ

| File | Làm gì |
|---|---|
| [`fw/main.s`](fw/main.s) | firmware đồng hồ: 5 chế độ TIME, STOPWATCH, TIMER, ALARM, SET |
| [`fw/fmt.s`](fw/fmt.s) | đổi giá trị thành 8 ô hiển thị |
| [`fw/demo/clock.s`](fw/demo/clock.s) | firmware rút gọn chỉ chạy giờ (dùng cho demo qua nửa đêm) |
| [`fw/tests/`](fw/tests/) | chương trình nhỏ để thử CPU, hazard, ngoại vi |
| [`tools/asm.py`](tools/asm.py) | dịch hợp ngữ ra mã máy |
| [`tools/iss.py`](tools/iss.py) | mô phỏng lệnh bằng Python, dùng làm đáp án chuẩn |
| [`tools/cosim_iss.py`](tools/cosim_iss.py), [`tools/cmp_trace.py`](tools/cmp_trace.py) | chạy chip và đáp án chuẩn cùng chương trình, so từng lệnh |
| [`tools/cosim_mars.py`](tools/cosim_mars.py) | đối chiếu thêm với MARS (mô phỏng MIPS của bên ngoài) |
| [`tools/cpi.py`](tools/cpi.py) | tính CPI và chu kỳ mất theo nguyên nhân |
| [`tools/screen.py`](tools/screen.py) | dựng lại màn LED từ chân `an`/`seg` |
| [`tools/run_unit.sh`](tools/run_unit.sh) | chạy test (xem mục "Chạy thử") |

### Test, số đo, báo cáo

| Thư mục | Nội dung |
|---|---|
| [`tb/`](tb/) | testbench: mỗi `<tên>_tb.v` là 1 test; [`tb/system_tb.v`](tb/system_tb.v) chạy firmware thật trên chip; [`tb/vectors/`](tb/vectors/) là bộ số đúng do script sinh |
| [`evidence/`](evidence/) | log chạy thật, mỗi con số trong báo cáo trỏ về đây |
| [`report/`](report/) | nháp từng mục báo cáo ([`KHUNG-BAO-CAO.md`](report/KHUNG-BAO-CAO.md)) và khung LaTeX ([`report/latex/`](report/latex/), bản PDF: [`main.pdf`](report/latex/build/main.pdf)) |

## Cách làm việc của nhóm

- Chia gói, lịch, cổng bảo vệ: [`KE-HOACH-LAM-VIEC.md`](KE-HOACH-LAM-VIEC.md), [`docs/goi-viec.md`](docs/goi-viec.md).
- Ngân hàng câu hỏi vấn đáp: [`docs/ngan-hang-cau-hoi.md`](docs/ngan-hang-cau-hoi.md). Ghi kết quả tuần: [`docs/hop-tuan.md`](docs/hop-tuan.md).
- Phần lớn code do Claude viết theo yêu cầu của nhóm trưởng; mỗi người chủ gói phải đọc hiểu, tự kiểm và trả lời được từng dòng (đầu mỗi file có ghi).
