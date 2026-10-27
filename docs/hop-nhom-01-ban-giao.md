# Họp nhóm 01: bàn giao + chia việc + học gói (soạn 27/10/2026)

> Claude soạn theo lời Long. Mọi số liệu trỏ về file trong `evidence/` hoặc `report/`. Phần "kiến thức" dẫn số mục theo sách P&H *Computer Organization and Design, MIPS Edition, bản 5* (dùng bản khác thì tìm theo tên mục).
> **Đọc trước khi họp:** §1 (5 phút) + phần của mình ở §4 (20 phút). Mang laptop đã chạy được `source tools/env.sh`.

---

## 0. Chương trình họp (~90 phút)

| Phút | Việc | Ai |
|---|---|---|
| 0–10 | §1 bức tranh chung: con chip làm gì, đang ở đâu | Long |
| 10–20 | §2 luật học + 4 bài ở mỗi cổng (quan trọng: code phần lớn do AI viết, người chủ phải hiểu từng dòng) | Long |
| 20–60 | §4 mỗi TV 8 phút: đọc phần mình, hỏi chỗ chưa hiểu, nhận việc | từng TV |
| 60–75 | §5 câu chéo: ai cũng phải trả lời được | cả nhóm |
| 75–90 | §6 chốt quyết định + điền `docs/hop-tuan.md` | Long |

---

## 1. Bức tranh chung

### 1.1. Sản phẩm là gì
Một **con chip đồng hồ điện tử** (SoC "WatchChip") viết bằng Verilog, chỉ chạy mô phỏng (không có board):
- **CPU MIPS tự thiết kế**, 28 lệnh, 2 bản: **G1** đơn chu kỳ, **G2** pipeline 5 tầng.
- **Ngoại vi đồng hồ**: timebase chuẩn ms có hiệu chỉnh `CAL`, RTC, stopwatch, timer đếm ngược, 4 báo thức, 4 nút, quét LED 7 đoạn, VGA, còi, UART, bộ điều khiển ngắt.
- **Firmware** `fw/main.s` (hợp ngữ MIPS): 5 chế độ TIME → STOPWATCH → TIMER → ALARM → SET, đồng bộ giờ với PC qua UART.

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

**Câu hỏi xuyên suốt đồ án:** *"Muốn đồng hồ chuẩn tới 1 ms thì phần nào phải là phần cứng?"* Đáp án có số đo (thí nghiệm E3): CPU đọc giờ khi thấy nút thì trễ tới 1,36 ms ở xung 32 kHz; **phần cứng chụp thời điểm (capture) thì sai 0 chu kỳ** ở mọi tốc độ CPU (`report/2.5-e3-thi-nghiem.md`).

### 1.2. Đang ở đâu (`verified`, hồi quy 27/10 `evidence/20261027_regress_rbuf.log`: EXIT 0)
| Hạng mục | Trạng thái |
|---|---|
| Toàn bộ RTL + firmware + công cụ | **xong**, hồi quy 41 mục PASS |
| `system_tb` (firmware thật chạy trên chip) | 589 kiểm PASS, cả G1 lẫn G2, cả có ngắt lẫn không |
| So với mô hình tham chiếu | ISS 25 chương trình, MARS 19, pytest 97 |
| Thí nghiệm E1′–E4′, CPI, DSE | Claude chạy mẫu, có nháp báo cáo; **TV phải chạy lại** |
| Báo cáo | khung LaTeX `report/latex/` + 9 mục có nháp |
| Còn thiếu | hình H1–H8, waveform, chữ của các TV, Fmax (không có Vivado) |

**Nói thẳng:** phần lớn code do Claude viết theo yêu cầu của Long (đầu mỗi file có ghi nguồn gốc, `KE-HOACH` §4b). Việc của mỗi người từ giờ **không phải viết code mới**, mà là **hiểu gói của mình tới mức giải thích từng dòng, sửa tại chỗ khi thầy đổi yêu cầu, và tự làm phần trình bày**.

### 1.3. Mốc
| Ngày | Mốc | Cần gì |
|---|---|---|
| **01/11** CN | nhận gói | điền tên vào `docs/hop-tuan.md` |
| **14/11** T7 | **Cổng 1** | G1 + module của mình |
| **21/11** T7 | **Cổng 2** | G2 + hazard + ngắt + timers |
| **05/12** T7 | **Cổng 3** | tổng duyệt, báo cáo ghép xong |
| S11 | bảo vệ | |

---

## 2. Luật học và 4 bài ở mỗi cổng (`KE-HOACH` §4b)

**Mỗi người học gói mình theo 5 bước:**
1. Đọc spec của gói (cột "Spec" ở §4), rồi đọc code từ trên xuống.
2. Tự chạy test gói mình: `source tools/env.sh` rồi `bash tools/run_unit.sh <tên>`.
3. **Cài 1 lỗi** vào code (đổi 1 dấu, 1 bit) rồi chạy lại: test phải FAIL. Nếu không FAIL thì đó là lỗ hổng test, báo nhóm.
4. Làm phần trình bày của mình (hình + đoạn báo cáo trong `report/latex/chuong/`).
5. Luyện 10 câu trong `docs/ngan-hang-cau-hoi.md` (mục của mình) + 14 câu chéo §6–8.

**Ở mỗi cổng, mỗi người qua đủ 4 bài** (người hỏi là thành viên khác):
| Bài | Đạt khi |
|---|---|
| Vấn đáp | ≥ 8/10 câu gói mình + ≥ 3/5 câu chéo, **chỉ được dòng code** |
| Sửa tại chỗ 30 phút | bốc 1 bài ở ngân hàng §9, sửa xong test PASS |
| Chạy lại test | trên máy người khác; giải thích 1 test FAIL do người hỏi cài |
| Ứng dụng | giải thích 1 chức năng đồng hồ + 1 con số E1′–E4′: lấy từ đâu, đúng tới đâu |

Kết quả ghi `docs/hop-tuan.md`. Trượt thì tuần sau thi lại phần trượt.

---

## 3. Bảng chia việc (một trang)

| TV | Gói | File chính | Hình phải vẽ | Đoạn báo cáo | Thí nghiệm / việc khác |
|---|---|---|---|---|---|
| **TV1** | ALU & số học | `alu.v`, `muldiv.v`, `bcd_unit.v`, `tools/dse_report.py` | H2 datapath G1 | 2.9, 3.4 | trình bày H9 (DSE) |
| **TV2** | công cụ & hazard | `asm.py`, `iss.py`, `cmp_trace.py`, `hazard.v`, `fw/tests/hazard/`, `fw/main.s` | H4 forwarding + hazard | 2.1, 2.8, 2.10, 3.1 | P4 bảng ĐẠT, P5 CPI, E3 (cùng TV3) |
| **TV3** | CPU & chip | `regfile.v`, `control.v`, `cpu_g1.v`, `cpu_pipe.v`, `soc_regs.v`, `irq_ctrl.v`, `soc_top.v`, `tb/system_tb.v` | H1 SoC, H3 datapath G2, H8 waveform | 2.2, 2.6, 2.7, 3.2 | E3 (cùng TV2), P5 |
| **TV4** | hiển thị & âm thanh | `char_rom.v`, `seg7_scan.v`, `display_ctrl.v`, `beeper.v`, `uart.v`, `vga_digits.v`, màn ảo | H6 MMIO, H7 hiển thị, H10 | 2.3, 2.5 (UART), 3.1 (màn ảo) | E4′ bóng ma |
| **TV5** | định thời ms | `timebase.v`, `timers.v`, `buttons.v`, `rtc_bcd.v`, sync trong `main.s` | H5 timebase + timers | 2.4, 2.10 (sync) | E1′, E2′ |
| **Long** | biên tập + 1 gói tự chọn | `report/latex/` | — | Lời giới thiệu, ch.1, ch.4, PL A/B | P1, P6 |

---

## 4. Từng người: đã làm gì, chạy thế nào, dùng kiến thức nào

> Mỗi phần có 6 mục: **(a)** file + spec · **(b)** đã làm gì · **(c)** hoạt động thế nào (đọc kèm code) · **(d)** kiến thức nền · **(e)** tự kiểm · **(f)** câu dễ bị hỏi.

### 4.1. TV1 — ALU và khối số học

**(a) File + spec:** `src/alu.v` (34 dòng), `src/muldiv.v` (78), `src/bcd_unit.v` (81), `tools/dse_report.py`. Spec: `isa-spec.md` §3–4, `control-table.md` §1.1.

**(b) Đã làm gì**
- ALU tổ hợp: cộng, trừ, and, or, xor, `slt` có dấu, dịch `sll`/`sra`. Test 4 200 vector.
- `muldiv`: `mul` tổ hợp (32 bit thấp, HI/LO không đổi); `div` có dấu **32 chu kỳ** + 1 chu kỳ phát lệnh. Test `mul.txt` 825 ca, `div.txt` 830 ca.
- `bcd_unit`: đổi số nhị phân ≤ 99 999 999 thành 8 chữ số BCD. Có 2 bản qua parameter `G_COMB`: tuần tự (28 chu kỳ) và tổ hợp. Test 112 537 ca.
- DSE: so 4 cách đổi ms → chữ số (`report/3.4-dse.md`).

**(c) Hoạt động thế nào**
- **`slt` khi tràn:** `0x80000000 < 0x7FFFFFFF` phải ra 1. Nếu chỉ lấy bit dấu của `a − b` thì sai, vì phép trừ này tràn. Code (`alu.v` dòng 16): `lt = (a[31] != b[31]) ? a[31] : diff[31]`. Khác dấu thì `a < b` khi `a` âm; cùng dấu thì phép trừ không thể tràn nên bit dấu của hiệu đúng.
- **Chia restoring** (khôi phục), mỗi chu kỳ 1 bit thương: dịch số dư sang trái 1 bit, kéo 1 bit của số bị chia vào, thử trừ số chia. Không âm thì giữ hiệu và bit thương = 1; âm thì "khôi phục" (giữ số cũ) và bit thương = 0. Sau 32 bước có thương + dư của trị tuyệt đối, rồi sửa dấu: thương âm khi 2 dấu khác nhau, dư cùng dấu số bị chia.
  - Ca đặc biệt nhóm tự định nghĩa (`isa-spec` §4): chia 0 → LO = 0, HI = số bị chia, `DZ = 1`; `0x80000000 / −1` → LO = `0x80000000`, HI = 0.
  - Toán hạng **chốt ở chu kỳ start**, nên lệnh sau đổi thanh ghi cũng không ảnh hưởng.
  - Trong lúc `busy` thì CPU đứng (G1 giữ PC, G2 đóng băng pipeline), nên `mflo` ngay sau `div` luôn đúng.
- **Double dabble** (dịch-cộng-3) cho `bcd`: dịch số nhị phân sang trái từng bit vào vùng BCD. Trước mỗi lần dịch, chữ số BCD nào ≥ 5 thì cộng 3, để khi dịch (nhân 2) nó tự "nhớ" sang chữ số kế. Bản tuần tự làm 1 bước mỗi chu kỳ; bản tổ hợp trải hết các bước thành mạch, tốn +416 LUT.
- **DSE:** cách làm bằng `div` thuần mất 224 chu kỳ/lần; `bcd` tuần tự 162; `bcd` tổ hợp 135; bộ đếm BCD phần cứng 24. Ở xung thường cách nào cũng < 1 % tải CPU; khác biệt chỉ lộ ra ở xung 32,77 kHz.

**(d) Kiến thức nền**
- Biểu diễn bù 2, tràn có dấu (P&H 2.4, 3.2).
- Nhân và chia phần cứng, thuật toán restoring (P&H 3.3, 3.4).
- BCD, thuật toán double dabble (shift-and-add-3).
- Mạch tổ hợp và tuần tự, đánh đổi diện tích và thời gian (bản `bcd` tổ hợp và tuần tự).
- Tổng hợp logic: LUT, FF, đọc báo cáo Yosys.

**(e) Tự kiểm:** `bash tools/run_unit.sh alu muldiv bcd`. Gợi ý cài lỗi: đổi dòng `lt` thành `lt = diff[31]`; đổi điều kiện cộng 3 từ `>= 5` thành `> 5`.

**(f) Câu dễ bị hỏi:** vì sao `slt` không dùng bit dấu của hiệu · `div` mất đúng bao nhiêu chu kỳ và đo bằng gì · `−7 / 2` ra gì (LO = −3, HI = −1) · double dabble tại sao cộng 3 · khi nào nên chọn `bcd` tổ hợp. Thêm: ngân hàng §1.

---

### 4.2. TV2 — Công cụ, hazard, firmware

**(a) File + spec:** `tools/asm.py` (404 dòng), `tools/iss.py` (468), `tools/cmp_trace.py`, `tools/cosim_iss.py`, `tools/cosim_mars.py`, `src/hazard.v` (42), `fw/tests/hazard/*.s` (9 file), `fw/main.s` (1 230), `tools/cpi.py`. Spec: `isa-spec.md` §7–8, `pipeline-policy.md` (cả file).

**(b) Đã làm gì**
- **Assembler 2 lượt** `asm.py`: lượt 1 tính địa chỉ nhãn, lượt 2 mã hóa. Ra `.hex` (nạp IMEM) + `.lst` (địa chỉ ↔ dòng nguồn); lỗi có số dòng.
- **ISS** (mô phỏng mức lệnh) `iss.py`: chạy từng lệnh bằng Python theo đúng `isa-spec`, có MMIO giả và ngắt. Đây là **mô hình tham chiếu (golden model)**.
- **Co-simulation**: RTL và ISS cùng in 1 dòng trace mỗi lệnh (PC, thanh ghi ghi, giá trị, ghi bộ nhớ); `cmp_trace.py` so từng dòng, lệch dòng nào báo dòng đó. Đối chiếu thêm với **MARS** (19 chương trình) để chống "ISS và RTL cùng hiểu sai".
- `hazard.v`: forwarding + phát hiện load-use cho G2. 9 chương trình "tra tấn hazard".
- `cpi.py`: đếm chu kỳ mất theo nguyên nhân từ trace.

**(c) Hoạt động thế nào (5 bước mỗi hazard, `pipeline-policy.md` §3–7)**
- **Forwarding (RAW):** kết quả lệnh trước chưa kịp ghi regfile thì lấy thẳng từ thanh ghi tầng.
  ```
  ForwardA = 10 nếu EX/MEM.reg_write và EX/MEM.dst ≠ 0 và EX/MEM.dst = ID/EX.rs
             01 ngược lại nếu MEM/WB.reg_write và MEM/WB.dst ≠ 0 và MEM/WB.dst = ID/EX.rs
             00 ngược lại
  ```
  Ưu tiên EX/MEM vì là giá trị mới hơn. `dst ≠ 0` vì `$zero` luôn bằng 0.
- **Load-use:** `lw` chỉ có dữ liệu ở cuối MEM, nên lệnh ngay sau dùng kết quả phải **stall 1 chu kỳ**. Phát hiện ở ID; chỉ xét toán hạng lệnh **thật sự đọc** (`uses_rs`, `uses_rt`) để không stall oan (ví dụ `addiu` không đọc `rt`).
- **Nhánh quyết định ở EX:** nhảy thật thì xóa 2 lệnh đã nạp, **phạt 2 chu kỳ**. Chọn EX thay vì ID (Nhóm 3 chọn ID) vì dùng lại được forwarding sẵn có, ít ca đặc biệt. Đổi lại mất thêm 1 chu kỳ mỗi lần nhảy (bảng T3/T4, §7).
- **Ưu tiên khi trùng:** `busy` > flush > load-use > bình thường.
- **CPI firmware** (`report/3.3-cpi.md`): G1 1,428 · G2 2,027. Chu kỳ G2 đi vào: lệnh 49,3 %, nhánh 22,9 %, `busy` 22,8 %, load-use 4,9 %, không giải thích được 0.
- **Firmware:** vòng chính `events → ringchk → sync → draw`. Ngắt chỉ dùng cho UART_RX. Handler ở 0x180 gom byte vào bộ đệm và **chụp giờ ngay lúc nhận `\n`**. Từ 27/10 có **bộ đệm đôi**: câu sau vào bộ đệm nhận trong khi câu trước đang được xử lý.

**(d) Kiến thức nền**
- Mã hóa lệnh MIPS R/I/J, assembler 2 lượt, lệnh giả (P&H 2.5, 2.12, A.2).
- Pipeline 5 tầng, thanh ghi tầng (P&H 4.5, 4.6).
- Data hazard, forwarding, stall (P&H 4.7); control hazard, flush, dự đoán không nhảy (P&H 4.8).
- CPI, phân tích hiệu năng (P&H 1.6).
- Kiểm thử: golden model, co-simulation, **mutation testing** (cài lỗi xem test có bắt không).

**(e) Tự kiểm:** `pytest tools/` · `python tools/cosim_iss.py --rand 0` · `python tools/cosim_iss.py --g2 --rand 0` · `bash tools/run_unit.sh hazard`. Gợi ý cài lỗi: bỏ điều kiện `dst ≠ 0` trong forwarding rồi chạy `zero_reg.s`; đổi ưu tiên 10/01.

**(f) Câu dễ bị hỏi:** vẽ bảng chu kỳ `lw` + `add` phụ thuộc · tại sao không forward từ EX/MEM khi nó là `lw` · vì sao nhánh ở EX · ISS sai thì co-sim có bắt được không (không → nên mới có MARS) · CPI 2,027 lớn hơn G1 mà G2 vẫn nhanh hơn vì sao (xung gấp đôi: 50 so với 25 MHz). Thêm: ngân hàng §2.

---

### 4.3. TV3 — CPU và con chip

**(a) File + spec:** `src/regfile.v`, `src/control.v` (106), `src/cpu_g1.v` (233), `src/cpu_pipe.v` (308), `src/soc_regs.v`, `src/irq_ctrl.v`, `src/soc_top.v` (130), `tb/system_tb.v`. Spec: `control-table.md`, `mmio-map.md`, `isa-spec.md` §5, `pipeline-policy.md` §1, §10.

**(b) Đã làm gì**
- Regfile 32 × 32 bit: ghi ở sườn lên, đọc tổ hợp, có **bypass nội bộ** (đọc đúng thanh ghi đang được ghi thì trả giá trị mới).
- `control.v`: bảng chân lý cho cả 28 lệnh (`control-table.md`).
- **G1 đơn chu kỳ "2 pha"**, CP0 (Status, Cause, EPC) và nhận ngắt.
- **G2 pipeline 5 tầng**, có ngắt chính xác (precise).
- `soc_top`: nối CPU, bus, mọi ngoại vi; `irq_ctrl` 8 nguồn ngắt.
- `system_tb`: chạy firmware thật trên chip, 7 kịch bản, 589 kiểm.

**(c) Hoạt động thế nào**
- **Vì sao G1 có "2 pha":** IMEM và DMEM là BRAM **đọc đồng bộ** (phải chờ 1 cạnh clock mới có dữ liệu), trong khi CPU đơn chu kỳ cần đọc lệnh và đọc dữ liệu trong cùng 1 chu kỳ. Cách giải: mỗi chu kỳ CPU dùng 2 cạnh clock 50 MHz (`mmio-map.md` §1.1).
  - **Pha A:** cập nhật PC và regfile; IMEM chốt `mem[next_pc]`, nên đầu ra IMEM chính là lệnh của chu kỳ mới.
  - Từ A sang B: giải mã, đọc regfile, ALU tính.
  - **Pha B:** DMEM và MMIO chốt địa chỉ (`sw` ghi, `lw` đọc).
  - Từ B sang A: dữ liệu `lw` về cổng ghi regfile; tính `next_pc`.
  - Kết quả: G1 chạy 25 MHz, mỗi lệnh 1 chu kỳ CPU (CPI = 1 khi không có `div`/`bcd`).
- **Nhận ngắt ở G1:** khi `irq = 1`, `IE = 1`, `EXL = 0`, lệnh vừa xong không phải `mtc0`/`eret` và CPU không `busy`, thì: `EPC ← next_pc` (lệnh kế tiếp chưa chạy), `PC ← 0x180`, `EXL ← 1`. Nhận ở **cuối lệnh** nên không phải hủy lệnh nào, không có nguy cơ đọc MMIO 2 lần.
- **Ngắt ở G2 (chính xác, `pipeline-policy.md` §10):** nhận ở ranh giới ID/EX. Lệnh ở EX/MEM và MEM/WB chạy nốt; lệnh ở IF/ID và ID/EX bị hủy (không ghi gì). `EPC` = PC của lệnh cũ nhất chưa retire. Không nhận khi đang `busy`, đang stall load-use, hoặc vừa có lệnh CP0. Ngắt đến lúc `beq` nhảy thì `EPC` = đích nhánh.
- **Thanh ghi tầng G2:** IF/ID 65 bit, ID/EX 194, EX/MEM 73, MEM/WB 71 (`pipeline-policy.md` §1). Báo cáo phải có bảng trường + độ rộng.
- **Bus/MMIO:** địa chỉ âm (vùng cuối 4 GB) là thanh ghi ngoại vi, đọc bằng `lw` offset âm từ `$zero`. Ví dụ `MS_OF_DAY` = −252.
- **`irq_ctrl`:** `IRQ_PENDING` bật theo sự kiện, ghi 1 để xóa; sự kiện và lệnh xóa cùng chu kỳ thì **sự kiện thắng** (không mất ngắt). `irq` = OR(`PENDING & ENABLE`).

**(d) Kiến thức nền**
- Datapath và control đơn chu kỳ (P&H 4.3, 4.4); bảng chân lý điều khiển.
- Pipeline và thanh ghi tầng (P&H 4.6); ngoại lệ/ngắt, EPC, Cause (P&H 4.9; MIPS32 Vol III về CP0).
- Bộ nhớ đồng bộ (BRAM), clock enable thay vì tạo clock mới.
- I/O ánh xạ bộ nhớ (MMIO), polling và ngắt (P&H phụ lục A.7, A.8).
- Ngắt mức (level) và cạnh (edge).

**(e) Tự kiểm:** `bash tools/run_unit.sh regfile control cpu_g1 cpu_pipe irq system`. Gợi ý cài lỗi: tắt bypass regfile; cho nhận ngắt ngay sau `mtc0`; đổi `EPC ← pc` thay vì `next_pc`.

**(f) Câu dễ bị hỏi:** vì sao IMEM phải chốt `next_pc` chứ không phải `PC` · ngắt đến đúng lúc `div` đang chạy thì sao (chờ hết `busy`, `EPC` = lệnh sau `div`) · vì sao chặn ngắt ngay sau `mtc0`/`eret` · handler quên xóa `IRQ_PENDING` thì chuyện gì xảy ra · vẽ datapath G1 trong 5 phút. Thêm: ngân hàng §3.

---

### 4.4. TV4 — Hiển thị, âm thanh, UART

**(a) File + spec:** `src/char_rom.v`, `src/seg7_scan.v` (86), `src/display_ctrl.v`, `src/beeper.v`, `src/uart.v` (124), `src/vga_digits.v` (97), `tb/screen_dump.v` + `tools/screen.py`. Spec: `display-spec.md`.

**(b) Đã làm gì**
- ROM ký tự 32 mã → 7 đoạn; mã 0x0–0xF trùng chữ số hex, nên kết quả lệnh `bcd` ghi thẳng vào màn được.
- Quét 8 chữ số có **khoảng tắt chống bóng ma**, PWM độ sáng 16 mức, nháy 2 Hz.
- VGA 640 × 480 kiểu "đuổi tia": không có frame buffer, không dùng BRAM.
- Còi: tần số + mẫu 16 khe × 64 ms; hết giờ timer thì **phần cứng tự kích chuông**.
- UART 115 200 8N1, FIFO nhận 64 byte.
- **Màn hình ảo:** dựng lại 8 chữ số từ chân `an`/`seg` để kiểm cái người dùng thật sự nhìn thấy (1 677 vòng, 0 sai).
- **27/10:** sửa lỗi bóng ma do thí nghiệm E4′ phát hiện (dòng `js` trong `seg7_scan.v`).

**(c) Hoạt động thế nào**
- **Quét (multiplexing):** 8 chữ số dùng chung 8 chân đoạn; mỗi lúc chỉ bật 1 anode. Đổi khe đủ nhanh (125 Hz mỗi chữ số) thì mắt thấy cả 8 sáng cùng lúc (lưu ảnh võng mạc).
- **Bóng ma và cách chống:** transistor kéo anode tắt chậm. Nếu chân đoạn đổi sang chữ số mới trong lúc anode cũ chưa tắt hẳn, thì chữ số cũ hiện mờ hình của chữ số mới. Cách sửa: trong khoảng tắt `c < G_BLANK`, tắt mọi anode **và giữ nguyên chân đoạn của chữ số cũ**, đến `c = G_BLANK` mới đổi đoạn cùng lúc bật anode mới. Kết quả (`evidence/20261027_exp_e4_fix.log`): `G_BLANK` = 100 chu kỳ, anode tắt chậm 50 chu kỳ → **bóng ma 0**.
- **PWM độ sáng:** anode chỉ bật `BRIGHT × G_STEP` chu kỳ trong khe, `BRIGHT` từ 0 đến 15.
- **UART RX:** đi qua 2 FF đồng bộ → thấy cạnh xuống → chờ nửa bit → vẫn 0 thì là start thật → **lấy mẫu giữa mỗi bit** → bit stop phải là 1, không thì `FRAME_ERR`. 434 chu kỳ/bit ở 50 MHz = 115 207 baud (lệch 0,006 %).
- **VGA đuổi tia:** bộ đếm 800 × 525 (640 × 480 hiện); mỗi pixel tính **tổ hợp** từ tọa độ (x, y) → (ô, đoạn) → sáng/tắt. Clock enable mỗi 2 chu kỳ (25 MHz).

**(d) Kiến thức nền**
- LED 7 đoạn, anode chung/cathode chung, quét đa hợp, lưu ảnh võng mạc.
- PWM.
- UART: khung 8N1, baud, lấy mẫu giữa bit, đồng bộ 2 FF chống metastability.
- Chuẩn thời gian VGA 640 × 480 @ 60 Hz (hsync, vsync, front/back porch).
- Kiểm thử đột biến (đột biến VGA 9/9, UART 15/15, màn ảo 4/4 đều bị bắt).

**(e) Tự kiểm:** `bash tools/run_unit.sh seg7 display_ctrl beeper uart vga_digits exp_e4`. Gợi ý cài lỗi: bỏ dòng `js` (dùng lại `j`) rồi chạy `exp_e4`: bóng ma phải quay lại; đổi lấy mẫu UART từ giữa bit sang mép bit.

**(f) Câu dễ bị hỏi:** 125 Hz từ đâu ra (50·10⁶ / (`G_SLOT` × 8)) · bóng ma là gì, vì sao `G_BLANK` lúc đầu không chống được · UART lấy mẫu giữa bit để làm gì · VGA không có frame buffer thì vẽ thế nào · "xé hình" khi firmware ghi 8 ô bằng 8 lệnh. Thêm: ngân hàng §4.

---

### 4.5. TV5 — Định thời chuẩn ms và đồng bộ giờ

**(a) File + spec:** `src/timebase.v` (47), `src/timers.v` (325: rtc, stopwatch, cdtimer, alarm), `src/buttons.v` (107), `src/rtc_bcd.v`, phần `sy_*` trong `fw/main.s`. Spec: `timer-spec.md`.

**(b) Đã làm gì**
- **Timebase phân số có hiệu chỉnh `CAL`**: sửa sai số thạch anh tới ~0,02 ppm.
- RTC: ms trong ngày + số ngày từ 01/01/2000 + thứ.
- Stopwatch có **capture phần cứng** (nút A/B nối thẳng, chụp đúng chu kỳ nhấn).
- Timer đếm ngược đi qua 0 sang số âm (biết đã quá giờ bao lâu).
- 4 báo thức theo phút + mặt nạ thứ.
- Nút: chống rung cạnh đầu + khóa 10 ms, kèm dấu thời gian.
- **Đồng bộ giờ qua UART** (`$T`, `$Q`, `$R`) và tự tính `CAL` từ 2 lần đồng bộ.

**(c) Hoạt động thế nào**
- **Bộ chia phân số** (giống thuật toán Bresenham / bộ tích lũy pha): 1 ms = `G_N` = 50 000 chu kỳ + phần lẻ. Mỗi ms cộng `CAL` vào thanh ghi phần lẻ 16 bit; tràn sang bao nhiêu thì ms đó dài thêm bấy nhiêu chu kỳ.
  ```
  s_k = frac_k + CAL ;  len_k = G_N + (s_k >> 16) ;  frac_(k+1) = s_k mod 65536
  ```
  Đổi đơn vị: 1 ppm = 3 276,8 đơn vị `CAL`. Ví dụ +50 ppm → `CAL` = 163 840 = 2,5 chu kỳ/ms, nên các ms dài 50 002 và 50 003 xen kẽ. `CAL > 0` thì ms dài hơn, đồng hồ chậm lại.
- **Vì sao stopwatch/timer có bộ chia riêng:** bộ chia riêng xóa pha ở lúc bấm start, nên không bị sai ±1 ms do lệch pha với nhịp ms chung.
- **E1′** (`report/2.4-cal-thi-nghiem.md`): 2 lần đồng bộ cách nhau 60 phút, thạch anh lệch −199 … +150 ppm → sau `CAL` còn lệch ≤ 0,10 ppm. Khoảng ngắn thì kém hơn (+3 ppm, cách 10 phút → còn −0,32 ppm) vì PC chỉ so được tới ms. +250 ppm thì firmware **từ chối** (ngoài phạm vi ±200 ppm).
- **Nút:** máy trạng thái IDLE → (nhấn: phát xung + chụp giờ) → LOCK_P (chờ 10 ms) → HELD → LOCK_R (10 ms) → IDLE. Mọi thay đổi mức trong lúc khóa bị bỏ, vì đó là rung.
- **Đồng bộ giờ:** PC gửi `$T,<ms>,<ngày>*<checksum>`. Handler ngắt chụp giờ chip ngay lúc `\n` đến; firmware so với giờ PC rồi đặt giờ (`SET_MS` + `ARM`, nạp đúng ở tick kế). Hai lần đồng bộ cách nhau đủ lâu thì tính được `CAL`.
- **Báo thức không kêu khi nạp giờ (ARM)**, kể cả nạp đúng giờ báo (`timer-spec` §6).

**(d) Kiến thức nền**
- Bộ chia tần số, bộ chia phân số / bộ tích lũy pha, ppm và sai số thạch anh.
- Bộ đếm, máy trạng thái hữu hạn (FSM).
- Chống rung nút, đồng bộ tín hiệu ngoài (2 FF, metastability).
- Input capture / timestamp phần cứng (giống timer của MCU STM32).
- Đồng bộ thời gian kiểu NTP đơn giản: chụp giờ ở thời điểm nhận, bù trễ.

**(e) Tự kiểm:** `bash tools/run_unit.sh timebase rtc stopwatch cdtimer alarm buttons exp_cal` · `pytest tools/test_iss.py -k e6`. Gợi ý cài lỗi: dịch logic `>>` thay vì số học (sai khi `CAL` âm); bỏ "ARM không kêu báo thức".

**(f) Câu dễ bị hỏi:** 1 ppm sao lại bằng 3 276,8 · `CAL` âm thì `>>` phải là dịch gì · vì sao chống rung ở cạnh đầu (phản ứng ngay) và đánh đổi gì · nạp giờ đúng phút báo thức có kêu không · E1′ còn lệch 0,02 ppm do đâu (`CAL` là số nguyên, làm tròn). Thêm: ngân hàng §5.

---

## 5. Câu chéo: ai cũng phải trả lời được

1. **Đường đi của 1 lệnh `lw $t0, −252($zero)`** (đọc giờ) trên G1: IMEM → giải mã → ALU cộng địa chỉ → bus nhận ra vùng MMIO → `timers` trả `MS_OF_DAY` → về regfile. Trên G2 đi qua 5 tầng nào?
2. **Bấm nút B ở chế độ STOPWATCH:** `buttons` (đồng bộ, chống rung) → xung nhấn → `stopwatch` chụp lap **ngay chu kỳ đó** (không qua CPU) → FIFO → firmware lấy ra → `fmt` → Display RAM → `seg7_scan` → LED.
3. **1 ms đến từ đâu:** clock 50 MHz → `timebase` (+ `CAL`) → `tick_ms` → RTC, nút, nháy, còi, `TICK_1MS`.
4. **Vì sao G2 CPI 2,027 mà vẫn nhanh hơn G1 CPI 1,428:** thời gian = số lệnh × CPI / tần số; G2 chạy 50 MHz, G1 25 MHz.
5. **Vì sao nói "đã kiểm thử đúng":** 3 lớp độc lập (vector do script sinh, ISS, MARS) + 589 kiểm trên chip + đột biến bị bắt. Hạn chế: chỉ mô phỏng, không có board.
6. **Phần nào AI viết, mình hiểu tới đâu:** trả lời thật, chỉ dòng code.

---

## 6. Cần chốt trong buổi họp

- [ ] Ghép **tên thật ↔ TV1…TV5** (điền `docs/hop-tuan.md` bảng "Nhận việc") — nhóm 5 hay 6 người? Bìa LaTeX đang để 6 dòng.
- [ ] Gói Long tự chọn để qua cổng.
- [ ] Ai hỏi thầy: **barem**, **mẫu báo cáo/số trang**, có cần đăng ký lại đề (`docs/de-bai.md` câu 1, 3, 5).
- [ ] Cách ghi **% đóng góp** và **khai phần AI viết** ở Phụ lục A (đề xuất: ghi rõ "code do Claude viết theo yêu cầu, TVx đọc hiểu + qua cổng + làm hình/báo cáo/thí nghiệm").
- [ ] Mỗi người xác nhận đã chạy được `bash tools/run_unit.sh <gói mình>` trên máy mình (hạn 01/11).
- [ ] Hạn nháp hình H1–H7: 08/11; chốt 21/11.
- [ ] Mẫu slide (beamer) — ai lấy.

## 7. Từ điển nhanh
| Từ | Nghĩa |
|---|---|
| RTL | mô tả phần cứng bằng Verilog ở mức thanh ghi |
| ISS | trình mô phỏng tập lệnh (Python), dùng làm đáp án chuẩn |
| co-sim | chạy RTL và ISS cùng chương trình rồi so trace từng lệnh |
| MMIO | thanh ghi ngoại vi đọc/ghi bằng `lw`/`sw` như bộ nhớ |
| `busy` freeze | CPU đứng chờ `div`/`bcd` tính xong |
| capture | phần cứng tự chụp thời điểm, không chờ CPU |
| `CAL` | số hiệu chỉnh độ dài 1 ms, đơn vị 1/65 536 chu kỳ |
| đột biến (mutation) | cố ý cài lỗi vào code để xem test có bắt được không |
| evidence | file log chứng minh 1 con số, ở `evidence/` |
