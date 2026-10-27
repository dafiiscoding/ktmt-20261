# Khung báo cáo: nội dung từng mục + tiêu chí "xong"

> Lập 27/10 (Claude, theo lời Long). Gốc mục lục: `KE-HOACH-LAM-VIEC.md` §5; chủ mục: `PLAN-TRINH-BAY.md` §2.
> **Barem chính thức của thầy: CHƯA CÓ** (`docs/de-bai.md` câu 3, 5 còn trống). Tiêu chí dưới đây là tiêu chí nội bộ, rút từ `KE-HOACH` §2a/§2b (học cách trình bày Nhóm 3 + tránh chỗ yếu của họ). Có barem thì đối chiếu lại file này.
> Định dạng: **LaTeX theo mẫu báo cáo Nhóm 3** (Long chốt 27/10). File nguồn: `report/latex/` (`main.tex` + `chuong/*.tex`), mỗi mục có hộp `\TODO` ghi chủ + tiêu chí. Slide (beamer) để sau.

## A. Tiêu chí chung (áp cho MỌI mục)

| # | Tiêu chí | Kiểm thế nào |
|---|---|---|
| C1 | Mọi con số trỏ về 1 file `evidence/` | grep số trong chữ → có trong log |
| C2 | Mọi hình tự vẽ, đúng thiết kế mình; hình từ sách ghi "nguồn: P&H Fig x.y" và chỉ ở chương 1 | mỗi tên tín hiệu trên hình có trong `src/` |
| C3 | Số đếm chính xác, không "≈" (chu kỳ, CPI, số kiểm) | đếm bằng script/`CYCLE_COUNT` |
| C4 | Mỗi lựa chọn thiết kế lớn có mục "vì sao chọn": ≥ 2 phương án + lý do + cách kiểm | xem danh sách ở §B mục 2.8 |
| C5 | Hạn chế ghi trung thực, có số (không giấu cái chưa làm) | đối chiếu bảng 3.6 cột CHƯA ĐẠT |
| C6 | Nhất quán: số lệnh, tên tín hiệu, số liệu chữ ↔ bảng ↔ hình | vòng soát K9 (S10) |
| C7 | Người viết mục tự chạy lại test của mục đó và viết bằng lời mình | tick cột "Tự chạy lại" ở 3.6 |
| C8 | Khai rõ phần AI viết (Phụ lục A) | Long chốt cách khai |

## B. Từng mục

Trạng thái: **có nháp** = file trong `report/`; **trống** = chưa viết.

| Mục | Nội dung bắt buộc | Tiêu chí riêng | Chủ | Trạng thái |
|---|---|---|---|---|
| Lời giới thiệu | mục tiêu, phạm vi (chỉ mô phỏng, không board) | không hứa board/Fmax | Long | trống |
| 1.1 | đồng hồ thật làm gì (F-91W, DS3231, timer MCU); câu hỏi "chuẩn ms thì phần nào là phần cứng" | câu hỏi này được trả lời ở 3.5 | Long | trống |
| 1.2 | MIPS ISA, bảng 28 lệnh | đúng `docs/isa-spec.md` | Long | trống |
| 1.3 | lý thuyết single-cycle, pipeline, hazard, ngắt | hình sách được phép, ghi nguồn | Long | trống |
| 2.1 | công cụ (iverilog/ModelSim/Yosys, Python), cây thư mục | khớp `KE-HOACH` §6 | TV2 | trống |
| 2.2 | tổng thể SoC + **H1** | khối trên H1 = module trong `soc_top` | TV3 | trống |
| 2.3 | Display RAM, ROM ký tự, quét 7 đoạn + **H7** (giản đồ có khoảng tắt), VGA | H7 khớp `display-spec.md` §4 (bản sửa 27/10) | TV4 | có nháp VGA (`2.3-vga.md`) |
| 2.4 | timebase + `CAL`, RTC, stopwatch capture, TIMER, alarm, nút + **H5** | H5 có đường capture | TV5 | trống (phần thí nghiệm sang 3.5) |
| 2.5 | bus, **H6** MMIO, bộ ngắt, UART, beeper | H6 khớp `mmio-map.md` | TV4/TV3 | có nháp UART (`2.5-uart-sync-ngat.md`) |
| 2.6 | G1: **H2** datapath, bảng chân lý control **cả 28 lệnh**, CP0 + ngắt | bảng khớp `control-table.md` | TV1/TV3 | trống |
| 2.7 | G2: **H3**, thanh ghi tầng (trường, độ rộng) | độ rộng khớp `cpu_pipe.v` | TV3 | trống |
| 2.8 | hazard: 6 loại × 5 bước (định nghĩa → điều kiện → khối → code → **bảng chu kỳ**) + **H4**; "vì sao chọn": nhánh ở EX, G1 2 pha, BCD, polling/ngắt, VGA đuổi tia | bảng chu kỳ khớp `pipeline-policy.md` §7 | TV2 | trống |
| 2.9 | ALU, mul, div, `bcd` 2 bản | — | TV1 | trống |
| 2.10 | firmware: 5 chế độ, `fmt`, sync + `CAL` (bộ đệm đôi) | — | TV2/TV5 | một phần trong `2.5-uart-sync-ngat.md` |
| 2.11 | đoạn code chính (ngắn, có chú thích) | trích đúng file hiện tại | mỗi chủ | trống |
| 3.1 | chiến lược test: unit → cosim ISS → hazard → `system_tb` → màn ảo; đột biến | số kiểm lấy từ hồi quy mới nhất | TV2/TV4 | có nháp màn ảo (`3.1-man-ao.md`) |
| 3.2 | trace + **H8** waveform 4 cảnh | chú thích chu kỳ trên ảnh | TV3 | trống |
| 3.3 | CPI G1/G2 tách nguyên nhân | số từ `tools/cpi.py` | TV2/TV3 | có nháp (`3.3-cpi.md`) |
| 3.4 | DSE + **H9**, tài nguyên Yosys | ghi rõ không có Fmax và vì sao | TV1 | có nháp, thiếu §8.2 (`3.4-dse.md`) |
| 3.5 | E1′–E4′: mỗi thí nghiệm = câu hỏi → cách đo → bảng/hình → kết luận + phạm vi | trả lời câu hỏi ở 1.1 | TV5/TV3/TV4 | có nháp: `2.4-cal-thi-nghiem.md`, `2.5-e3-thi-nghiem.md`, `2.3-bongma-e4.md` + **H10** |
| 3.6 | bảng ĐẠT / CHƯA ĐẠT | mỗi dòng → 1 file evidence | TV2 | có nháp (`3.6-bang-dat.md`) |
| 4 | kết quả · hạn chế (có số) · hướng phát triển (`sync_host.py`, board, Fmax, hàng đợi UART ≥ 3 câu) | hạn chế = cột CHƯA ĐẠT của 3.6 | Long | trống |
| PL A | phân công: người ↔ gói ↔ % ↔ bằng chứng; khai phần AI | C8 | Long | trống |
| PL B | tiến độ: kế hoạch (`goi-viec.md`) vs thực tế (`hop-tuan.md`) | — | Long | trống |
| PL C | hướng dẫn chạy lại: `source tools/env.sh` → `bash tools/run_unit.sh` | người khác chạy được trên máy họ (cổng bài 3) | TV2 | trống |
| PL D | trích trace/log | — | TV2 | trống |
| TLTK | P&H, MIPS32 Vol II/III, Casio module 593, DS3231, RM timer STM32 | mỗi mục trích có trong danh sách | Long | trống |

## C. Chỗ cần chốt khi ghép

- Bản nháp E1′/E3/E4′ đang đặt tên theo mục thiết kế (2.3/2.4/2.5) nhưng mục lục để thí nghiệm ở **3.5**. Đề xuất: kết quả vào 3.5, mục 2.x chỉ mô tả thiết kế và trỏ sang.
- Chủ H2/H6 đã đổi (TV1/TV4, `PLAN-TRINH-BAY` §2) — bảng hình trong `KE-HOACH` §5 còn ghi TV3.
- `KE-HOACH` §2c còn chữ "demo board"; đề chỉ mô phỏng (`de-bai.md` câu 4) → báo cáo không ghi demo board.
