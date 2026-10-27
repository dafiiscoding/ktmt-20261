# Kế hoạch làm việc — Đồng hồ điện tử WatchChip (học từ báo cáo Nhóm 3, kỳ 2025.1)

> Spec kỹ thuật + việc theo người: `PLAN_DONG_HO.md` (nhóm chốt 01/10/2026; đề cũ Smart Step Hub đã bỏ). File này quy định **làm theo thứ tự nào, ai nộp gì mỗi tuần, báo cáo cuối kỳ có gì**.
> Nguồn học: `BaoCaoCK_Nhom3.pdf` (59 trang, lớp 163635, PGS.TS. Nguyễn Đình Hân, "HÀ NỘI, 1/2026"). Theo lời Long, nhóm này được điểm cao. **Không biết điểm cụ thể, cũng không có barem** nên mọi suy ra "vì sao điểm cao" đều là `inference`.

---

## 1. Nhóm 3 làm gì (`verified`, đọc từ PDF)

- **Đề:** CPU MIPS 32-bit pipeline 5 tầng có Hazard Detection Unit. Viết bằng Verilog, **chỉ mô phỏng** trên ModelSim, không nạp FPGA.
- **Tập lệnh:** 14 lệnh gồm ADD, SUB, AND, OR, SLT, ADDI, ANDI, ORI, XORI, SLTI, LW, SW, BEQ, J. Bộ nhớ Harvard 256 + 256 word.
- **Điểm nhấn:**
  - Full forwarding.
  - Stall khi load-use.
  - **Rẽ nhánh sớm ở ID**: phạt 1 chu kỳ. Có forwarding về ID và stall khi lệnh nhánh đứng ngay sau lệnh ALU.
  - Predict-not-taken + flush.
- **Kiểm thử:** **một** chương trình (tính tổng 1..10 = 55), log từng chu kỳ, một hình waveform, bảng CPI (lý thuyết 45 chu kỳ, thực tế ≈55, CPI 1,34).
- **Cấu trúc báo cáo:**
  - Ch1 Giới thiệu + lý thuyết (MIPS ISA, single-cycle, pipeline, 3 loại hazard).
  - Ch2 Phương pháp luận:
    - Công cụ, cây thư mục, testbench.
    - Bảng ISA, thông số, I/O.
    - Datapath tổng + từng tầng, thanh ghi pipeline.
    - Control, bảng chân lý.
    - Hazard: định nghĩa → điều kiện → phần cứng → **bảng diễn biến theo chu kỳ** → so sánh với dynamic prediction / delayed branch và lý do chọn.
    - Đoạn code các module chính.
  - Ch3 Kiểm thử.
  - Ch4 Kết luận, hạn chế, hướng phát triển.
  - Phụ lục **A phân công**, **B tiến độ 15 tuần**, **C hướng dẫn chạy lại**. Tài liệu tham khảo là P&H.
- **Tiến độ họ ghi (Bảng B.1):**
  - Tuần 1–3: nghiên cứu.
  - Tuần 4–5: thiết kế.
  - Tuần 6–9: code.
  - Tuần 10–12: tích hợp hazard và gỡ lỗi.
  - Tuần 13–14: testbench.
  - Tuần 15: viết báo cáo và slide.

## 2. Nên học gì, và làm hơn ở đâu

### 2a. Chép **cách trình bày** (không chép chữ)
| # | Điều Nhóm 3 làm tốt | Áp vào đề mình |
|---|---|---|
| 1 | Mỗi hazard đi đủ 5 bước: định nghĩa → biểu thức điều kiện → khối phần cứng → đoạn code → **bảng theo chu kỳ** | Làm 5 bước này cho: RAW-EX, RAW-MEM, load-use, nhánh, **`busy` freeze (`div`/`bcd`)**, `mtc0` → `mfc0`, `eret` |
| 2 | Bảng chân lý tín hiệu điều khiển (Bảng 2.2) | Bảng cho **cả 28 lệnh**, kể cả SPECIAL2 |
| 3 | Mục "vì sao chọn": so sánh các phương án rồi mới chốt (2.6.4.5) | Viết mục này cho: G1 2 pha (BRAM "sườn xuống") vs LUT-RAM, nhánh ở EX hay ID, bộ đếm nhị phân hay BCD, `bcd` tổ hợp hay tuần tự, polling hay ngắt, VGA đuổi tia hay framebuffer |
| 4 | Test có **đáp số tính bằng lý thuyết**, rồi giải thích **vì sao CPI lệch** | Mỗi kịch bản so với ISS/golden; chu kỳ trễ tách theo nguyên nhân (load-use / nhánh / busy) |
| 5 | Phụ lục C: người chấm chạy lại được | README + lệnh `iverilog`/`vvp` cụ thể (chạy được cả ModelSim), 1 lệnh chạy toàn bộ test |
| 6 | Phụ lục A/B: phân công + tiến độ | Có sẵn khung ở §5 bên dưới; điền **kế hoạch và thực tế** |

### 2b. Chỗ Nhóm 3 yếu → mình tránh (`verified` trên PDF)
| Chỗ yếu | Mình làm |
|---|---|
| Hình 2.3–2.7 (từng tầng) là **ảnh cắt từ hình single-cycle P&H Fig 4.33**. Hình tầng ID không có bộ so sánh rẽ nhánh sớm dù chữ nói có. Hình 2.8–2.10 cũng lấy từ sách. | **Tự vẽ mọi hình** (draw.io) và vẽ đúng thiết kế của mình. Hình nào lấy từ sách phải ghi "nguồn: P&H Fig x.y" và chỉ dùng ở phần lý thuyết. |
| Cả chương kiểm thử chỉ có **một chương trình** và dò waveform bằng mắt | Tự động so trace với ISS; bộ test "tra tấn hazard"; `system_tb` 7 kịch bản (plan §10) × 2 core |
| Chu kỳ thực tế "≈55", không đếm bằng bộ đếm | Dùng `CYCLE_COUNT`, ghi số chính xác |
| Không nhất quán: chữ ghi "13 lệnh" nhưng bảng có 14; câu "thiết kế đơn chu kỳ" lọt vào báo cáo pipeline; `BEQ $s1,$s3` dùng `$s3` chưa khởi tạo; cột "Đóng góp" ghi 1–5 không rõ nghĩa | Có một vòng **soát nhất quán** (§4, S10): số lệnh, tên tín hiệu, số liệu ở chữ khớp với bảng. Đóng góp ghi % kèm bằng chứng commit. |
| Báo cáo và slide dồn vào **tuần cuối** | Mỗi sprint nộp luôn đoạn báo cáo của phần mình (cột "Báo cáo" ở §3) |

### 2c. Mình đứng ở đâu so với Nhóm 3 (`inference`)
- **G2 (pipeline) ≈ toàn bộ phạm vi của Nhóm 3.** ISA mình rộng hơn: 28 lệnh so với 14, có mul/div, `bcd`, CP0/ngắt. Họ có rẽ nhánh sớm ở ID; mình quyết định nhánh ở EX.
  - Hệ quả: luật cắt ở plan §9 an toàn. Bỏ G2 thì phần SoC đồng hồ (timers, hiển thị, ngắt G1, số đo) phải bù vào.
- **Nhánh ở ID:** không làm. Trả lời thầy bằng bảng T4 (`pipeline-policy.md` §7): nhánh ở ID phải stall 2 sau `lw`, nhánh ở EX thì 1; đổi lại mất thêm 1 chu kỳ mỗi lần nhảy.
- **Phần hơn hẳn:** cả con chip đồng hồ (timers có capture, bộ điều khiển hiển thị, ngắt), câu hỏi "chuẩn ms thì phần nào là phần cứng" có số đo (E1–E4), demo board. Phần pipeline chỉ cần **làm chắc bằng Nhóm 3**.

### 2d. Ưu tiên 3 lớp giá trị (chốt 24/09, cập nhật 01/10 cho đề đồng hồ)
Môn là Kiến trúc máy tính nên lớp 1 được chấm nặng nhất (`inference`).

| Lớp | Gồm | Vai trò | Công sức (ước) | Khi trễ |
|---|---|---|---|---|
| **1. Lõi CPU** | G1 single-cycle → G2 pipeline, ISA, control, hazard | nền bắt buộc, phải **sâu ≥ Nhóm 3** | ~50% | không cắt; mọi người dồn vào |
| **2. Phần cứng đặc thù đồng hồ** | timebase + `CAL`, timers capture, display controller, ngắt G1, `bcd` + DSE | điểm khác biệt | ~30% | cắt theo plan §9 |
| **3. Ứng dụng** | firmware 5 chế độ, sync PC, E1′–E4′ (mô phỏng), VGA, demo màn hình ảo | câu chuyện + reference đời thực; **thầy dí** → mỗi số phải giải thích được | ~20% | cắt VGA trước, rồi E3 |

- **Tín hiệu lệch:** trước 15/11 mà nhóm tốn nhiều giờ vào VGA / giao diện hơn vào lõi CPU → Long kéo lại qua nhóm chat.
- **Chuẩn "sâu bằng Nhóm 3" cho lớp 1** = `docs/pipeline-policy.md` (bản nháp, freeze S1′) có đủ:
  1. trường + độ rộng bit của 4 thanh ghi tầng;
  2. điều kiện forwarding đầy đủ (`rd≠0`, ưu tiên EX/MEM > MEM/WB, forward dữ liệu store cho `sw`);
  3. điều kiện load-use theo từng lệnh (lệnh nào thật sự đọc `rt`);
  4. bảng flush cho `beq/bne/j/jal/jr/eret`;
  5. bảng chu kỳ cho load-use, nhánh, `busy` freeze;
  6. lý do chọn (nhánh ở EX vs ID, không delay slot).
  - Cộng **bảng chân lý control 28 lệnh**: `docs/control-table.md` (bản nháp v2; Nhóm 3 chỉ có 6 dòng / 14 lệnh).
  - Bản nháp do Claude viết → S1′ **không viết lại mà duyệt**: TV2, TV3 tự vẽ tay T2/T4/T8 rồi đối chiếu; mỗi người phải giải thích được 1 bảng (thầy hỏi vấn đáp).

## 3. Lịch làm việc theo sprint

Việc của từng người theo sprint: `PLAN_DONG_HO.md` §7 + §11. Ở đây chỉ giữ cột **Báo cáo**: đoạn phải có trong `report/` cuối sprint đó (viết dần, không dồn cuối kỳ).

| Sprint | Báo cáo (ai viết) |
|---|---|
| **S1′** 01–07/10 | `docs/de-bai.md` (người hỏi thầy) · **1.2 ISA + bảng 28 lệnh** (TV2) · **Hình H1 tổng thể SoC** (TV3) |
| **S2** 05–11/10 | **1.1 đồng hồ thật làm gì: Casio, DS3231, timer MCU** (TV5) · **bảng control** (TV3) · **nháp 2.x hazard từ policy** (TV2) |
| **S3** 12–18/10 | **2.x hiển thị: quét, bóng ma, nháy** (TV4) · **2.x timebase + `CAL`** (TV5) |
| **S4** 19–25/10 | **2.x datapath G1: Hình H2 tự vẽ** (TV3) · **2.x ALU + div** (TV1) |
| **S5** 26/10–01/11 | **2.x timers: capture, TIMER âm, alarm** (TV5) · **MMIO map H6** (TV3) |
| **S6** 02–08/11 | — (giữa kỳ) |
| **S7** 09–15/11 | **3.1 chiến lược test + trace log mẫu** (TV2) · **2.x CP0 + ngắt G1** (TV3) |
| **S8** 16–22/11 | **2.x hazard: hoàn thiện bằng waveform/trace thật** (TV2+TV3) · **2.x `bcd` 2 bản** (TV1) |
| **S9** 23–29/11 | **3.x bảng §8 plan, biểu đồ DSE** (TV1) · **E1–E4** (mô phỏng; TV5: E1′, E2′ · TV3 + TV2: E3 · TV4: E4′) · **waveform ×4** (TV3) |
| **S10** 30/11–06/12 | ghép, **vòng soát nhất quán**, slide, video, Phụ lục A/B/C (biên tập) |
| S10 cuối (05/12) | tổng duyệt vấn đáp (§4b), video demo màn hình ảo |
| S11 07–13/12 | **bảo vệ (tuần 14)** |

**Luật trễ:** plan §9.

## 4. Nhịp làm việc

- **Báo cáo tuần** (không cần họp; Chủ nhật mỗi người tự ghi vào `docs/hop-tuan.md`). Mỗi người trả lời 3 câu: đã **PASS** gì (kèm log hoặc ảnh), đang kẹt gì, tuần sau nộp gì. Biên tập ghi 5 dòng vào `docs/hop-tuan.md`. File này dùng làm nguồn cho Phụ lục B.
- **Definition of Done cho một module:**
  1. Code nằm trên nhánh chính.
  2. Testbench PASS tự động (in `PASS`/`FAIL`, không dò mắt).
  3. Log lưu ở `evidence/`.
  4. **Một đoạn báo cáo + một hình hoặc bảng** trong `report/`.
  5. Thiếu bước 4 thì chưa tính là xong.
- **Trace log thống nhất** (kiểu `Cyc | PC | Inst | ...` của Nhóm 3, nhưng máy tự so): `cycle, pc, instr, rd, value`. `tools/cmp_trace.py` so với ISS và in dòng đầu tiên lệch.
- **Hợp đồng S1′** (6 file `docs/`, plan §7): sửa sau S1′ thì phải cả nhóm đồng ý và cập nhật asm + ISS + golden cùng lúc.
- **Biên tập báo cáo:** một người. Đề xuất người có tải nhẹ nhất sau S8; nếu chưa rõ thì Long. Người này giữ **bảng thuật ngữ + số liệu chính thức** để các chương không lệch nhau.
- **Viết báo cáo:** LaTeX/Overleaf hoặc Word, chốt ở S1′. Bản Nhóm 3 trông như LaTeX (`inference`). Hỏi thầy xem có mẫu bắt buộc không.

## 4b. Cổng bảo vệ (thầy dí code, ứng dụng, kiểm thử)

**Luật tự viết:** mỗi người **tự gõ** code của module mình. AI (Claude hoặc khác) chỉ được giải thích, review, ra đề luyện, sinh test vector. Không dán code AI viết vào `src/`. Tài liệu `docs/` do Claude nháp → phải được người sở hữu vẽ lại hoặc viết lại bằng lời của mình trước khi freeze.
- **Ngoại lệ (Long chốt 01/10/2026):** 5 gói S2 (A1 `alu`, A2 `muldiv`, C1 `regfile`, D1 `char_rom` + `seg7_scan`, E1 `timebase`) và, từ 02/10, E2 `rtc`, D2 `display_ctrl`, D7 màn hình ảo, C2 `control`, A3 `bcd_unit`, C3 `cpu_g1` (bản đầu), C4 `soc_regs` + bộ giải mã, C5 `irq_ctrl` + nhận ngắt trong `cpu_g1`, C6 `soc_top` (bản đầu, chỉ các khối đã có) và, từ 03/10, E3 `stopwatch` + `cdtimer`, E4 `alarm` + `buttons`, D3 `beeper`, C8 `system_tb` (kịch bản 1–6) và firmware `fw/main.s` (bản đầu gộp B7 + E5 + D6), B1 `asm.py`, B2 `iss.py` (+ `cosim_iss.py`), B3 `cmp_trace.py` và, từ 20/10, C7 `cpu_pipe` (G2), B5 `hazard`, B6 `fw/tests/hazard/` + `tb/hazard_tb.v`, `tb/cpu_pipe_tb.v` do Claude viết thẳng vào `src/`/`tb/`/`fw/` theo yêu cầu Long ("viết hết đi"); đầu mỗi file ghi rõ nguồn gốc. Chủ gói vẫn phải qua cổng như code tự viết: giải thích từng dòng, tự sửa khi thầy đổi yêu cầu, giải thích test FAIL do người hỏi cài vào.

**Ba cổng:**
| Cổng | Khi | Nội dung |
|---|---|---|
| **1** | Thứ Bảy 14/11 (trước M1 15/11) | G1 + module của mình |
| **2** | Thứ Bảy 21/11 (trước M2 22/11) | G2 + hazard + CP0/ngắt + timers; **không qua → áp luật cắt sớm** |
| **3** | S10 (05/12) | tổng duyệt như buổi bảo vệ thật (bảo vệ thật tuần 14 = S11) |

**Mỗi cổng, mỗi người làm đủ 4 bài** (người hỏi = thành viên khác, bốc câu từ `docs/ngan-hang-cau-hoi.md`):
1. **Vấn đáp:** 10 câu về module mình + 5 câu chéo module khác. Đạt ≥ 8/10 và ≥ 3/5; trả lời phải **chỉ được dòng code**.
2. **Sửa tại chỗ (30 phút):** bốc 1 bài trong mục "Sửa code tại chỗ" của ngân hàng, sửa + test PASS.
3. **Chạy lại test:** trên máy người khác, clone repo → `run_all_tests` → giải thích 1 test FAIL giả do người hỏi cài vào.
4. **Ứng dụng:** giải thích 1 chức năng đồng hồ và 1 con số E1–E4 — lấy từ đâu, đúng tới đâu.

Kết quả ghi `docs/hop-tuan.md`. Ai trượt → tuần sau thi lại phần trượt; trượt 2 lần ở cổng 2 → nhóm quyết cắt phần đó.

## 5. Khung báo cáo cuối kỳ (mục lục dự kiến — đi từ trên xuống: hiển thị → chip → CPU → ALU)

- **Lời giới thiệu**
- **1. Giới thiệu**
  - 1.1 Đồng hồ điện tử thật làm gì (Casio F-91W, DS3231, timer MCU) + câu hỏi "chuẩn ms"
  - 1.2 MIPS ISA + 28 lệnh
  - 1.3 Single-cycle, pipeline, hazard, ngắt
- **2. Thiết kế**
  - 2.1 Công cụ, cấu trúc mã nguồn
  - 2.2 Tổng thể SoC (H1)
  - 2.3 Bộ điều khiển hiển thị: Display RAM, ROM ký tự, quét 7 đoạn, (VGA đuổi tia)
  - 2.4 Timebase + `CAL`, RTC, stopwatch capture, TIMER âm, alarm, nút
  - 2.5 Bus, MMIO, bộ điều khiển ngắt, UART, bộ tạo âm
  - 2.6 CPU G1: datapath + control (bảng chân lý), CP0 + ngắt
  - 2.7 CPU G2 pipeline: thanh ghi tầng (trường, độ rộng)
  - 2.8 Hazard: 6 loại × 5 bước + bảng chu kỳ; mục "vì sao chọn"
  - 2.9 ALU, mul, div, `bcd` (2 bản)
  - 2.10 Firmware: 5 chế độ, `fmt`, sync + `CAL`
  - 2.11 Đoạn code chính
- **3. Kiểm thử & kết quả**
  - 3.1 Chiến lược: unit → co-sim ISS → hazard → `system_tb` → màn hình ảo
  - 3.2 Trace + waveform
  - 3.3 Hiệu năng G1/G2: CPI tách nguyên nhân
  - 3.4 DSE: chi phí đổi ms → chữ số (plan §8.1), tài nguyên (§8.2)
  - 3.5 E1–E4
  - 3.6 Bảng tổng kết ĐẠT / CHƯA ĐẠT + minh chứng
- **4. Kết luận**
  - Kết quả
  - Hạn chế (trung thực)
  - Hướng phát triển
- **Phụ lục**
  - A Phân công: việc, % đóng góp, bằng chứng
  - B Tiến độ: kế hoạch và thực tế, từ `hop-tuan.md`
  - C Hướng dẫn chạy lại
  - D Trích trace/log
- **Tài liệu tham khảo:** P&H, MIPS32 Vol II/III (CP0), Casio module 593, DS3231, tài liệu timer/RTC STM32.

**Danh sách hình phải tự vẽ hoặc tự chụp** (chủ, sprint):

| Hình | Chủ | Sprint |
|---|---|---|
| H1 tổng thể SoC | TV3 | S1′ |
| H2 datapath G1 | TV3 | S4 |
| H3 datapath G2 đầy đủ | TV3 | S8 |
| H4 forwarding + hazard unit | TV2 | S8 |
| H5 timebase + timers (có đường capture) | TV5 | S5 |
| H6 MMIO map | TV3 | S5 |
| H7 bộ điều khiển hiển thị + giản đồ thời gian quét (có khoảng tắt) | TV4 | S3 |
| H8 waveform: load-use bubble, flush nhánh, `busy` freeze, vào/ra ngắt | TV3 | S9 |
| H9 biểu đồ DSE (§8.1) | TV1 | S9 |
| H10 màn hình ảo 7 đoạn (D7) + waveform bóng ma (E4′) | TV4 | S9 |

## 6. Cây thư mục repo (chuẩn từ S1′, dùng luôn cho Phụ lục C)
Đã dựng sẵn: thư mục project này **chính là** gốc repo `watchchip/` (`.ai/` bị `.gitignore`, không đưa lên repo nhóm). Gói việc: `docs/goi-viec.md`.

```
watchchip/
  src/        # Verilog: alu, muldiv, bcd_unit, regfile, control, cpu_sc, cpu_pipe, hazard, cp0, irq_ctrl,
              #       timebase, timers, display_ctrl, seg7_scan, vga_digits, uart, beeper, soc_top
  tb/         # testbench từng module + system_tb; tb/vectors/ = vector sinh tự động
  tools/      # asm.py, iss.py, cmp_trace.py, sync_host.py, run_all_tests.(sh|bat)
  fw/         # *.s: main, fmt, set, alarm, chime, sync; tests/hazard/*.s
  docs/       # 6 file hợp đồng S1′, goi-viec.md, ngan-hang-cau-hoi.md, de-bai.md, hop-tuan.md
  evidence/   # log PASS, ảnh waveform, số đo (đặt tên theo ngày_module)
  report/     # nguồn báo cáo + hình
  README.md   # cách chạy lại (Phụ lục C)
```

## 7. Việc Long cần làm ngay (S1′)
1. Hỏi thầy và lưu nguyên văn vào `docs/de-bai.md`:
   - Đổi đề sang đồng hồ điện tử có cần đăng ký lại không?
   - Hạn nộp và bảo vệ thực tế là **tháng 12 hay tháng 1**? Bìa Nhóm 3 ghi "1/2026".
   - Có mẫu báo cáo không?
2. Đã chốt (01/10): Verilog, chỉ mô phỏng, bảo vệ tuần 14. Còn: người biên tập, công cụ viết báo cáo.

---

### Ghi chú kiểm (3 vòng, 24/09/2026)
- **Vòng 1:** đọc hết 59 trang (text trích + xem ảnh trang 30–31), rút cấu trúc, điểm mạnh, tiến độ.
- **Vòng 2 ("sai ở đâu"):**
  - Sửa nhận định ban đầu "5 hình từng tầng là cùng một ảnh dán lại". Xem ảnh thì đó là **5 lát cắt** của P&H Fig 4.33. Vẫn là hình sách, và hình tầng ID không khớp thiết kế rẽ nhánh sớm của họ.
  - Đếm lại ISA của họ: 14 lệnh, chữ ghi 13.
  - Tính lại CPI: 55/41 ≈ 1,34, khớp.
- **Vòng 3 ("câu chưa ai hỏi"):**
  - Bìa ghi "1/2026" → hạn thật có thể là **tháng 1**, không phải tháng 12 như plan giả định (`unverified`). **Không nới lịch**: coi phần dư là buffer cho đến khi thầy xác nhận.
  - "Điểm cao" không cho biết barem → đừng tối ưu theo một báo cáo mẫu duy nhất.
  - Tránh đạo văn: học cấu trúc, không chép câu chữ hay hình.
  - Người đọc cuối là thầy. Thầy đã chấm bản của Nhóm 3 nên phần pipeline dễ bị so trực tiếp → phải tự vẽ và phải có số đo.
