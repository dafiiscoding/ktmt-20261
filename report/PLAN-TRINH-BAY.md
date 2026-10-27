# Plan trình bày + học gói (26/10/2026 → bảo vệ S11)

> Lập 26/10 theo lời Long, sau khi đối chiếu Nhóm 3 (`report/doi-chieu-nhom3.md`). Tên người: điền vào `docs/hop-tuan.md` (bảng nhận việc đang trống).
> Nguyên tắc: **mỗi người học gói của mình bằng cách tự làm phần trình bày của gói đó** — vẽ hình, chụp waveform, viết đoạn báo cáo. Vẽ được datapath và giải thích được waveform = qua được cổng (`KE-HOACH` §4b).

## 0. Mốc

| Ngày | Mốc |
|---|---|
| **01/11** (CN, hết S5) | chốt định dạng báo cáo; mọi người nhận gói trong `hop-tuan.md` |
| **14/11** (T7) | **Cổng 1**: G1 + module của mình — vấn đáp, sửa tại chỗ, chạy lại test |
| 15/11 | M1 tầng 1 |
| **21/11** (T7) | **Cổng 2**: G2 + hazard + ngắt + timers |
| 22/11 / 29/11 | M2 tầng 2 / demo M3 |
| **05/12** (T7) | **Cổng 3**: tổng duyệt; báo cáo ghép xong |
| S11 | bảo vệ |

## 1. Sáu việc trình bày

| # | Việc | Chủ | Ai giúp | Xong khi | Hạn |
|---|---|---|---|---|---|
| P1 | **File báo cáo chính**: bìa, mục lục, danh mục hình/bảng, 4 chương, phụ lục A/B/C, tài liệu tham khảo; ghép các đoạn đã có trong `report/` | Long (biên tập) | Claude dựng khung | biên dịch ra PDF, mục lục tự sinh | khung 02/11 · ghép 05/12 |
| P2 | **Hình tự vẽ H1–H7** (draw.io → SVG/PDF; vẽ đúng thiết kế của mình, không cắt từ sách) | xem bảng §2 | Claude soát hình khớp RTL | mỗi tên tín hiệu trên hình có trong `src/` | nháp 08/11 · chốt 21/11 |
| P3 | **Waveform H8** (4 cảnh: load-use bubble, flush nhánh, `busy` freeze khi `div`, vào/ra ngắt) — ModelSim có sẵn trên máy (`tools/run_modelsim_g2.py`) hoặc GTKWave | TV3 | TV2 | 4 ảnh, mỗi ảnh có chú thích chu kỳ khớp bảng `pipeline-policy.md` §7 | 21/11 |
| P4 | **Bảng tổng kết ĐẠT / CHƯA ĐẠT** (mục 3.6): mỗi yêu cầu → test → file evidence → trạng thái | TV2 | Claude nháp từ `goi-viec.md` §3 | mọi dòng trỏ được về 1 file trong `evidence/`; người viết đã tự chạy lại test | **nháp Claude 27/10** `report/3.6-bang-dat.md` · cập nhật sau mỗi cổng |
| P5 | **CPI lý thuyết vs thực tế** (mục 3.3): G1 và G2 trên firmware thật + 9 test hazard, tách chu kỳ mất do load-use / nhánh / `busy` / ngắt | TV2 + TV3 | Claude viết script đếm từ trace | bảng số đếm bằng script (không "≈"), giải thích từng nguyên nhân bằng `pipeline-policy.md` | 22/11 |
| P6 | **Phụ lục A (phân công) + B (tiến độ)** | Long | mọi người | A: người ↔ gói ↔ % ↔ bằng chứng · B: kế hoạch (`goi-viec.md`) vs thực tế (`hop-tuan.md` + worklog) | mỗi CN ghi `hop-tuan.md` từ 01/11 · chốt 05/12 |

## 2. Chia theo người: gói học + phần trình bày

Mỗi người: **(1)** đọc spec + code gói mình, **(2)** tự chạy test gói mình, **(3)** cài 1 lỗi rồi xem test bắt, **(4)** làm phần trình bày dưới đây, **(5)** luyện 10 câu trong `docs/ngan-hang-cau-hoi.md`.

| TV | Gói phải hiểu (chạy test gì) | Hình | Đoạn báo cáo | Việc khác |
|---|---|---|---|---|
| **TV1** ALU & số học | A1–A4: `alu`, `muldiv`, `bcd_unit`, `tools/dse_report.py` (`run_unit.sh alu muldiv bcd`) | **H2 datapath G1** (học G1 qua ALU) | 2.9 ALU/mul/div/`bcd` 2 bản · 3.4 DSE (đã có nháp `3.4-dse.md` → viết lại bằng lời mình) | trình bày H9 |
| **TV2** công cụ & hazard | B1–B7: `asm.py`, `iss.py`, `cmp_trace.py`, `hazard.v`, test hazard, `main.s` (`pytest tools/`, `cosim_iss.py`) | **H4 forwarding + hazard unit** | 2.8 hazard (5 bước × 6 loại, từ `pipeline-policy.md`) · 3.1 chiến lược test · 2.10 firmware | **P4** bảng ĐẠT · **P5** CPI |
| **TV3** CPU & chip | C1–C8: `regfile`, `control`, `cpu_g1`, `cpu_pipe`, `soc_regs`, `irq_ctrl`, `soc_top`, `system_tb` | **H1 tổng SoC**, **H3 datapath G2** | 2.2 tổng thể · 2.6 G1 + CP0/ngắt · 2.7 G2 | **P3** waveform H8 · P5 |
| **TV4** hiển thị & âm thanh | D1–D7: `seg7_scan`, `display_ctrl`, `beeper`, `uart`, `vga_digits`, màn ảo | **H6 MMIO map**, **H7 hiển thị + giản đồ quét** | 2.3 hiển thị (đã có nháp `2.3-vga.md`) · 3.1 màn ảo (nháp `3.1-man-ao.md`) | E4′ · H10 demo GIF |
| **TV5** định thời ms | E1–E7: `timebase`, `rtc`, `stopwatch`, `cdtimer`, `alarm`, `buttons`, sync + `CAL` | **H5 timebase + timers (có đường capture)** | 2.4 timebase/`CAL`/timers · 2.5 sync (nháp `2.5-uart-sync-ngat.md`) | E1′, E2′ |
| **Long** | biên tập + 1 gói tự chọn để qua cổng | — | Lời giới thiệu · 1.x giới thiệu · 4 kết luận | P1, P6 |

Thay đổi so với bảng hình gốc (`KE-HOACH` §5): H2 chuyển TV3 → TV1 và H6 chuyển TV3 → TV4, vì TV3 đang ôm 5 hình + waveform.

## 3. Kỹ thuật còn thiếu (đọc từ `PLAN_DONG_HO.md` §8.3, §9 và `goi-viec.md`)

| # | Việc | Tầng | Chủ | Ghi chú |
|---|---|---|---|---|
| K1 | **E1′** thạch anh lệch ±ppm → `CAL` → ppm sau hiệu chỉnh | 2 | TV5 | **Claude chạy mẫu 26/10**: `tools/exp_cal.py`, nháp `report/2.4-cal-thi-nghiem.md`; TV5 chạy lại |
| K2 | **E2′** timer 2 000 ms đúng tới chu kỳ, có/không `CAL` | 2 | TV5 | **Claude chạy mẫu 26/10**: `tb/exp_cal_tb.v` (trong hồi quy), PASS 9; TV5 chạy lại |
| K3 | **E3** polling vs ngắt vs capture ở `D` = 2 / 100 / 1526 | 2 | TV3 + TV2 | **Claude chạy mẫu 26/10**: `tools/exp_e3.py` (1 000 lần × 6 ca), nháp `report/2.5-e3-thi-nghiem.md`; TV3 + TV2 chạy lại |
| K4 | **E4′** waveform bóng ma ở 3 `G_SLOT`, có/không khoảng tắt | 2 | TV4 | **Claude chạy mẫu 26/10**: `tb/exp_e4_tb.v`, hình `report/h_e4_bongma.png`, nháp `report/2.3-bongma-e4.md`; **phát hiện `G_BLANK` không chống bóng ma → đã sửa `seg7_scan.v` 27/10 (đoạn đổi ở `c = G_BLANK`)** |
| K5 | Script CPI từ trace (phục vụ P5) | — | Claude | **xong 26/10**: `tools/cpi.py`, nháp `report/3.3-cpi.md`, `evidence/20261026_cpi.log` |
| K6 | `sync_host.py` (phía PC) | 2 | TV5 | không có board thì không chạy thật được → đề xuất **bỏ**, ghi vào "hướng phát triển" |
| K7 | Fmax | tùy chọn | — | máy chỉ có ModelSim, không Vivado/Quartus → bỏ cột Fmax như `goi-viec.md` đã cho phép |
| K8 | Dọn nhỏ: `isa-spec` §7 còn ngưỡng 900 lệnh (firmware 1 151) · `screen.py -h` lỗi cp1252 | — | Claude | **xong 26/10**: ngưỡng theo tỉ lệ IMEM (aw 11 → 1 800), `screen.py` in UTF-8 |
| K9 | Soát nhất quán (số lệnh, tên tín hiệu, số liệu chữ ↔ bảng) | — | Long + Claude | S10, trước khi nộp |

Tầng 1 (hạn 15/11): `system_tb` 589 kiểm PASS trên G1 và G2 (`verified`, `work/regress_20261026_bram.log`); đủ hạng mục tầng 1 trong plan §9 là `inference` từ goi-viec. Tầng 2 chỉ còn K1–K4; mọi thứ khác của tầng 2 đã có.

## 4. Còn để Long quyết (để sau tính)

- **Định dạng nộp:** LaTeX (Overleaf, giống Nhóm 3) hay Word — nên hỏi thầy trước 01/11.
- **Phụ lục A khai phần Claude viết thế nào:** `KE-HOACH` §4b đã ghi ngoại lệ (đầu mỗi file ghi nguồn gốc) và chủ gói vẫn phải qua cổng. Cần thống nhất cách ghi % đóng góp cho trung thực.
