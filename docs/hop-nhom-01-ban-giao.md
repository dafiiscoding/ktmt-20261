# Họp nhóm 01: bàn giao + chia việc (27/10/2026)

> **Đọc trước khi họp (25 phút):** mục 1 + phần của mình ở mục 4. Mang laptop đã chạy được `source tools/env.sh`.
> Số liệu đều có file chứng minh trong [`evidence/`](../evidence/) hoặc [`report/`](../report/). Sách tham khảo: P&H *Computer Organization and Design, MIPS Edition, bản 5*.
> Muốn xem chip chạy: mở [`work/demo_tuong_tac.html`](../work/demo_tuong_tac.html) (bấm đôi, không cần mạng).

## 0. Chương trình (90 phút)

| Phút | Việc |
|---|---|
| 0–10 | Mục 1: chip làm gì, đang ở đâu (chiếu demo) |
| 10–20 | Mục 2: luật học + 4 bài mỗi cổng |
| 20–60 | Mục 4: mỗi người 8 phút, đọc phần mình, hỏi chỗ chưa hiểu |
| 60–75 | Mục 5: câu chéo, ai cũng phải trả lời được |
| 75–90 | Mục 6: chốt quyết định, điền [`hop-tuan.md`](hop-tuan.md) |

## 1. Bức tranh chung

**Sản phẩm:** một con chip đồng hồ điện tử viết bằng Verilog, chỉ chạy mô phỏng (không có board).
- **CPU MIPS tự thiết kế**, 28 lệnh, 2 bản: G1 chạy 1 lệnh mỗi chu kỳ ([`cpu_g1.v`](../src/cpu_g1.v)), G2 chia 5 tầng như dây chuyền ([`cpu_pipe.v`](../src/cpu_pipe.v)).
- **Ngoại vi:** đếm ms chuẩn, giờ, bấm giờ, hẹn giờ, 4 báo thức, 4 nút, LED 7 đoạn, VGA, còi, UART, ngắt.
- **Firmware** [`fw/main.s`](../fw/main.s): 5 chế độ TIME, STOPWATCH, TIMER, ALARM, SET; đồng bộ giờ với PC qua UART.
- Sơ đồ khối và cách đọc từng file: xem [`README.md`](../README.md).

**Câu hỏi xuyên suốt:** muốn đồng hồ chuẩn tới 1 ms thì phần nào phải là phần cứng?
Trả lời bằng số đo (thí nghiệm E3, [`report/2.5-e3-thi-nghiem.md`](../report/2.5-e3-thi-nghiem.md)): để CPU tự đọc giờ khi thấy nút thì trễ tới 1,36 ms (xung 32 kHz); để phần cứng chụp giờ thì sai 0 chu kỳ.

**Đang ở đâu** (`verified`, [`evidence/20261027_regress_rbuf.log`](../evidence/20261027_regress_rbuf.log): 41 mục PASS):
- Chip, firmware, công cụ: **xong**. Firmware thật chạy trên chip qua 589 kiểm PASS ([`tb/system_tb.v`](../tb/system_tb.v)).
- Thí nghiệm E1′–E4′, CPI, DSE: đã chạy mẫu và có nháp, nhưng **mỗi người phải tự chạy lại phần mình**.
- Báo cáo: khung LaTeX có sẵn ([`report/latex/`](../report/latex/)), 9 mục có nháp.
- **Còn thiếu:** hình H1–H8, waveform, chữ của từng người, Fmax (không có Vivado).

**Nói thẳng:** phần lớn code do Claude viết theo yêu cầu của Long (đầu mỗi file có ghi). Việc của mỗi người từ giờ **không phải viết code mới**, mà là hiểu gói của mình tới mức giải thích từng dòng, sửa tại chỗ khi thầy đổi yêu cầu, và tự làm phần trình bày.

**Mốc:** 01/11 nhận gói · 14/11 Cổng 1 (G1 + module của mình) · 21/11 Cổng 2 (G2, hazard, ngắt, timers) · 05/12 Cổng 3 (tổng duyệt, ghép báo cáo) · tuần 14 bảo vệ (ngày cụ thể chưa rõ, `unverified`).

## 2. Luật học (5 bước) và 4 bài mỗi cổng

1. Đọc spec của gói, rồi đọc code từ trên xuống.
2. Chạy test của gói: `source tools/env.sh` rồi `bash tools/run_unit.sh <tên>`.
3. **Cài 1 lỗi** (đổi 1 dấu, 1 bit) rồi chạy lại. Test phải FAIL; nếu không FAIL thì test có lỗ hổng, báo nhóm.
4. Làm phần trình bày của mình (hình + đoạn báo cáo trong [`report/latex/chuong/`](../report/latex/chuong/)).
5. Luyện câu hỏi trong [`ngan-hang-cau-hoi.md`](ngan-hang-cau-hoi.md).

| Bài (người hỏi là thành viên khác) | Đạt khi |
|---|---|
| Vấn đáp | ≥ 8/10 câu gói mình + ≥ 3/5 câu chéo, chỉ được chỉ dòng code |
| Sửa tại chỗ 30 phút | bốc 1 bài, sửa xong test PASS |
| Chạy lại test | trên máy người khác; giải thích 1 test FAIL do người hỏi cài |
| Ứng dụng | giải thích 1 chức năng đồng hồ + 1 con số E1′–E4′ (lấy từ đâu, đúng tới đâu) |

Kết quả ghi vào [`hop-tuan.md`](hop-tuan.md). Trượt thì tuần sau thi lại phần trượt. Luật đầy đủ: [`KE-HOACH-LAM-VIEC.md`](../KE-HOACH-LAM-VIEC.md) §4b.

## 3. Ai làm gì

| TV | Gói | File chính | Hình | Đoạn báo cáo |
|---|---|---|---|---|
| TV1 | ALU, nhân chia, đổi BCD | [`alu.v`](../src/alu.v) [`muldiv.v`](../src/muldiv.v) [`bcd_unit.v`](../src/bcd_unit.v) | H2 | 2.9, 3.4 |
| TV2 | công cụ, hazard, firmware | [`asm.py`](../tools/asm.py) [`iss.py`](../tools/iss.py) [`hazard.v`](../src/hazard.v) [`main.s`](../fw/main.s) | H4 | 2.1, 2.8, 2.10, 3.1 |
| TV3 | CPU và chip | [`regfile.v`](../src/regfile.v) [`control.v`](../src/control.v) [`cpu_g1.v`](../src/cpu_g1.v) [`cpu_pipe.v`](../src/cpu_pipe.v) [`irq_ctrl.v`](../src/irq_ctrl.v) [`soc_top.v`](../src/soc_top.v) | H1, H3, H8 | 2.2, 2.6, 2.7, 3.2 |
| TV4 | hiển thị, còi, UART | [`seg7_scan.v`](../src/seg7_scan.v) [`display_ctrl.v`](../src/display_ctrl.v) [`beeper.v`](../src/beeper.v) [`uart.v`](../src/uart.v) [`vga_digits.v`](../src/vga_digits.v) | H6, H7, H10 | 2.3, 2.5, 3.1 |
| TV5 | đếm ms, nút, đồng bộ giờ | [`timebase.v`](../src/timebase.v) [`timers.v`](../src/timers.v) [`buttons.v`](../src/buttons.v) [`rtc_bcd.v`](../src/rtc_bcd.v) | H5 | 2.4, 2.10 |
| Long | biên tập báo cáo + 1 gói tự chọn | [`report/latex/`](../report/latex/) | | lời giới thiệu, ch.1, ch.4, phụ lục |

Chi tiết output, test, tiêu chí xong của từng gói: [`goi-viec.md`](goi-viec.md).

## 4. Từng người cần nắm gì

Mỗi mục có: **làm gì** (nói đơn giản) · **tự kiểm** (lệnh) · **hay bị hỏi**.

### TV1. ALU và khối số học
Spec: [`isa-spec.md`](isa-spec.md) §3–4, [`control-table.md`](control-table.md) §1.1.
- **Làm gì:** ALU cộng, trừ, and, or, so sánh, dịch bit. `muldiv` nhân 1 chu kỳ, chia mất 32 chu kỳ (mỗi chu kỳ ra 1 bit thương). `bcd_unit` đổi số nhị phân thành 8 chữ số thập phân để hiện lên LED.
- **Chỗ hay sai:** so sánh `slt` khi phép trừ tràn. Chỉ lấy bit dấu của `a − b` là sai; code xử lý ở [`alu.v` dòng 17](../src/alu.v#L17): khác dấu thì số âm nhỏ hơn, cùng dấu thì phép trừ không tràn nên bit dấu của hiệu đúng.
- **Chia khôi phục:** mỗi bước dịch số dư sang trái, thử trừ số chia; trừ được thì bit thương = 1, không thì giữ số cũ và bit thương = 0. Chia 0 và `0x80000000 / −1` là ca đặc biệt nhóm tự quy định ([`isa-spec.md`](isa-spec.md) §4).
- **Đổi BCD (dịch-cộng-3):** trước mỗi lần dịch, chữ số nào ≥ 5 thì cộng 3, để khi nhân đôi nó tự nhớ sang chữ số kế.
- **Tự kiểm:** `bash tools/run_unit.sh alu muldiv bcd`. Thử cài lỗi: đổi dòng `lt` thành `diff[31]`.
- **Hay bị hỏi:** vì sao `slt` không dùng bit dấu của hiệu · `div` mất đúng bao nhiêu chu kỳ · `−7 / 2` ra gì (thương −3, dư −1) · double dabble vì sao cộng 3.
- Kết quả DSE (so 4 cách đổi ms ra chữ số): [`report/3.4-dse.md`](../report/3.4-dse.md).

### TV2. Công cụ, hazard, firmware
Spec: [`isa-spec.md`](isa-spec.md) §7–8, [`pipeline-policy.md`](pipeline-policy.md).
- **Làm gì:** `asm.py` dịch hợp ngữ ra mã máy (2 lượt: lượt 1 ghi nhớ địa chỉ nhãn, lượt 2 mã hóa). `iss.py` là bản mô phỏng bằng Python, dùng làm đáp án chuẩn. `cmp_trace.py` so từng lệnh giữa chip và đáp án chuẩn; đối chiếu thêm với MARS để khỏi trường hợp cả hai cùng hiểu sai.
- **Hazard ở G2:** kết quả lệnh trước chưa kịp ghi thì lấy tắt (forwarding). `lw` chỉ có dữ liệu ở cuối tầng MEM nên lệnh ngay sau dùng nó phải chờ 1 chu kỳ. Nhánh nhảy thật thì bỏ 2 lệnh đã nạp (phạt 2 chu kỳ). Chi tiết: [`pipeline-policy.md`](pipeline-policy.md) §3–7, code [`hazard.v`](../src/hazard.v) (42 dòng).
- **CPI firmware:** G1 1,428 · G2 2,027 ([`report/3.3-cpi.md`](../report/3.3-cpi.md)).
- **Firmware:** vòng chính `events → ringchk → sync → draw`. Ngắt chỉ dùng cho UART; handler ở địa chỉ 0x180 chụp giờ ngay lúc nhận `\n`.
- **Tự kiểm:** `pytest tools/` · `python tools/cosim_iss.py --rand 0` · `bash tools/run_unit.sh hazard`. Thử cài lỗi: bỏ điều kiện `dst ≠ 0` trong forwarding.
- **Hay bị hỏi:** vẽ bảng chu kỳ `lw` + `add` phụ thuộc · vì sao nhánh quyết định ở tầng EX · ISS sai thì co-sim có bắt không (không, nên mới có MARS) · CPI G2 lớn hơn mà vẫn nhanh hơn G1 vì sao (xung 50 so với 25 MHz).

### TV3. CPU và con chip
Spec: [`control-table.md`](control-table.md), [`mmio-map.md`](mmio-map.md), [`pipeline-policy.md`](pipeline-policy.md) §1, §10.
- **Làm gì:** `regfile` (32 thanh ghi). `control` quyết định mỗi lệnh bật tín hiệu nào. G1 chạy 1 lệnh mỗi chu kỳ, G2 chia 5 tầng. `soc_top` nối CPU với mọi ngoại vi; `irq_ctrl` gom 8 nguồn ngắt.
- **Vì sao G1 có "2 pha":** bộ nhớ lệnh và dữ liệu phải chờ 1 cạnh clock mới ra dữ liệu, nhưng CPU 1 chu kỳ cần cả hai ngay. Cách giải: mỗi chu kỳ CPU dùng 2 cạnh của clock 50 MHz ([`mmio-map.md`](mmio-map.md) §1.1), nên G1 chạy 25 MHz.
- **Ngắt:** G1 nhận ở cuối lệnh (không phải hủy lệnh nào), `EPC` = lệnh kế tiếp chưa chạy, nhảy về 0x180. G2 nhận ở ranh giới ID/EX: lệnh ở EX/MEM/WB chạy nốt, lệnh ở IF/ID bị hủy.
- **Thanh ghi ngoại vi:** địa chỉ âm (vùng cuối 4 GB), đọc bằng `lw` offset âm từ `$zero`. Ví dụ `MS_OF_DAY` = −252.
- **Tự kiểm:** `bash tools/run_unit.sh regfile control cpu_pipe irq system`. Thử cài lỗi: đổi `EPC ← pc` thay vì `next_pc`.
- **Hay bị hỏi:** vì sao bộ nhớ lệnh chốt `next_pc` chứ không phải `PC` · ngắt đến lúc `div` đang chạy thì sao (chờ hết `busy`) · vì sao chặn ngắt ngay sau `mtc0`/`eret` · handler quên xóa `IRQ_PENDING` thì sao · vẽ datapath G1 trong 5 phút.

### TV4. Hiển thị, âm thanh, UART
Spec: [`display-spec.md`](display-spec.md).
- **Làm gì:** quét 8 LED 7 đoạn (mỗi lúc sáng 1 chữ số, đổi nhanh 125 Hz nên mắt thấy cả 8 sáng). VGA không dùng frame buffer, mỗi điểm ảnh tính thẳng từ tọa độ. Còi có mẫu 16 khe. UART 115 200 baud 8N1.
- **Bóng ma:** chữ số cũ hiện mờ hình chữ số mới vì anode tắt chậm. Cách sửa trong [`seg7_scan.v`](../src/seg7_scan.v): trong khoảng tắt, giữ nguyên chân đoạn cũ, hết khoảng tắt mới đổi đoạn cùng lúc bật anode mới. Kết quả: bóng ma 0 ([`evidence/20261027_exp_e4_fix.log`](../evidence/20261027_exp_e4_fix.log), [`report/2.3-bongma-e4.md`](../report/2.3-bongma-e4.md)).
- **UART nhận:** thấy cạnh xuống → chờ nửa bit → vẫn 0 mới là start thật → lấy mẫu giữa mỗi bit → bit stop phải là 1, không thì báo lỗi khung.
- **Màn ảo:** dựng lại 8 chữ số từ chân `an`/`seg` để kiểm cái người dùng thật sự thấy ([`report/3.1-man-ao.md`](../report/3.1-man-ao.md), công cụ [`tools/screen.py`](../tools/screen.py)).
- **Tự kiểm:** `bash tools/run_unit.sh seg7 display_ctrl beeper uart vga_digits exp_e4`. Thử cài lỗi: dùng lại chân đoạn mới trong khoảng tắt, bóng ma phải quay lại.
- **Hay bị hỏi:** 125 Hz từ đâu ra · bóng ma là gì · UART lấy mẫu giữa bit để làm gì · VGA không có frame buffer thì vẽ thế nào · vì sao có "xé hình" khi firmware ghi 8 ô bằng 8 lệnh.

### TV5. Đếm ms chuẩn và đồng bộ giờ
Spec: [`timer-spec.md`](timer-spec.md).
- **Làm gì:** `timebase` tạo nhịp 1 ms từ clock 50 MHz, có số hiệu chỉnh `CAL` để bù thạch anh lệch. `timers` gồm giờ, bấm giờ, hẹn giờ (đếm qua 0 sang số âm), 4 báo thức. `buttons` chống rung và ghi giờ lúc bấm.
- **Bộ chia có hiệu chỉnh:** mỗi ms cộng `CAL` vào phần lẻ; tràn bao nhiêu thì ms đó dài thêm bấy nhiêu chu kỳ. 1 ppm = 3 276,8 đơn vị `CAL`; ví dụ +50 ppm thì các ms dài 50 002 và 50 003 xen kẽ.
- **Vì sao bấm giờ có bộ chia riêng:** nó xóa pha ngay lúc bấm start, nên không bị sai ±1 ms.
- **Nút:** nhấn → phát xung + chụp giờ → khóa 10 ms → giữ → nhả → khóa 10 ms. Đổi mức trong lúc khóa bị bỏ vì là rung.
- **Đồng bộ giờ:** PC gửi `$T,<ms>,<ngày>*<checksum>`; chip chụp giờ ngay lúc `\n` đến rồi so với giờ PC. Hai lần đồng bộ đủ xa nhau thì tính ra `CAL` (E1′: [`report/2.4-cal-thi-nghiem.md`](../report/2.4-cal-thi-nghiem.md); luồng UART: [`report/2.5-uart-sync-ngat.md`](../report/2.5-uart-sync-ngat.md)).
- **Tự kiểm:** `bash tools/run_unit.sh timebase rtc stopwatch cdtimer alarm buttons exp_cal`. Thử cài lỗi: dùng dịch logic thay vì dịch số học (sai khi `CAL` âm).
- **Hay bị hỏi:** 1 ppm sao bằng 3 276,8 · `CAL` âm thì dịch kiểu nào · vì sao chống rung ở cạnh đầu · nạp giờ đúng phút báo thức có kêu không (không) · E1′ còn lệch 0,02 ppm do đâu (`CAL` là số nguyên, làm tròn).

## 5. Câu chéo: ai cũng phải trả lời được

1. **Đường đi của `lw $t0, −252($zero)` (đọc giờ):** bộ nhớ lệnh → giải mã → ALU cộng địa chỉ → bus nhận ra vùng ngoại vi → `timers` trả giờ → về `regfile`. Ở G2 đi qua 5 tầng nào?
2. **Bấm nút B ở chế độ bấm giờ:** `buttons` → xung → `stopwatch` chụp lap ngay chu kỳ đó (không qua CPU) → firmware lấy ra → ghi màn → `seg7_scan` → LED.
3. **1 ms đến từ đâu:** clock 50 MHz → `timebase` (+ `CAL`) → `tick_ms` → giờ, nút, nháy, còi.
4. **G2 CPI 2,027 mà vẫn nhanh hơn G1 CPI 1,428:** thời gian = số lệnh × CPI / tần số; G2 chạy 50 MHz, G1 25 MHz.
5. **Vì sao tin chip đúng:** 3 nguồn độc lập (vector do script sinh, ISS, MARS) + 589 kiểm trên chip + cài lỗi thì test bắt được. Hạn chế: chỉ mô phỏng, không có board.
6. **Phần nào AI viết, mình hiểu tới đâu:** trả lời thật, chỉ dòng code.

## 6. Cần chốt trong buổi họp

- [ ] Tên thật ↔ TV1…TV5 (điền [`hop-tuan.md`](hop-tuan.md)). Nhóm 5 hay 6 người? Bìa LaTeX đang để 6 dòng.
- [ ] Gói tự chọn của Long.
- [ ] Ai hỏi thầy: barem, mẫu báo cáo/số trang, có phải đăng ký lại đề không ([`de-bai.md`](de-bai.md) câu 1, 3, 5).
- [ ] Cách ghi % đóng góp và khai phần AI viết ở Phụ lục A. Đề xuất: "code do Claude viết theo yêu cầu, TVx đọc hiểu + qua cổng + làm hình/báo cáo/thí nghiệm".
- [ ] Mỗi người xác nhận đã chạy được `bash tools/run_unit.sh <gói mình>` (hạn 01/11).
- [ ] Hạn nháp hình H1–H7 là 08/11, chốt 21/11.
- [ ] Ai lấy mẫu slide (beamer).

## 7. Từ điển nhanh

| Từ | Nghĩa |
|---|---|
| RTL | mô tả phần cứng bằng Verilog |
| ISS | bản mô phỏng tập lệnh bằng Python, dùng làm đáp án chuẩn |
| co-sim | chạy chip và ISS cùng chương trình rồi so từng lệnh |
| MMIO | thanh ghi ngoại vi, đọc/ghi bằng `lw`/`sw` như bộ nhớ |
| `busy` | CPU đứng chờ `div`/`bcd` tính xong |
| capture | phần cứng tự chụp thời điểm, không chờ CPU |
| `CAL` | số hiệu chỉnh độ dài 1 ms, đơn vị 1/65 536 chu kỳ |
| đột biến | cố ý cài lỗi để xem test có bắt được không |
| evidence | file log chứng minh 1 con số, ở [`evidence/`](../evidence/) |
