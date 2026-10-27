# Đối chiếu với báo cáo Nhóm 3 (kỳ 2025.1) — 26/10/2026

> Nguồn: `hoc-tap/study-2026-1/tai-lieu/kien-truc-may-tinh/BaoCaoCK_Nhom3.pdf` (đọc lại 26/10: bìa, mục lục, danh mục hình, chương 3–4).
> Chỉ đối chiếu **cách trình bày + mức hoàn thiện**, không chép nội dung. Phân tích gốc: `KE-HOACH-LAM-VIEC.md` §2.

## 1. Công việc kỹ thuật — mình đã vượt ở đâu (`verified` từ repo)

| Hạng mục | Nhóm 3 | Mình (26/10) |
|---|---|---|
| Tập lệnh | 14 lệnh | 28 lệnh + mul/div, `bcd`, CP0/ngắt |
| Lõi | pipeline 5 tầng | G1 single-cycle + G2 pipeline, cùng SoC |
| Ngoài CPU | không có | cả SoC đồng hồ: timers, hiển thị LED + VGA, UART, ngắt |
| Kiểm thử | 1 chương trình (tổng 1..10), dò waveform bằng mắt | 28 tb, cosim RTL ↔ ISS từng lệnh, MARS golden, 9 test tra tấn hazard, `system_tb` 589 kiểm × 2 lõi × 2 bản firmware, màn ảo so tự động, đột biến ở mọi gói |
| Số chu kỳ | "≈ 55" | `CYCLE_COUNT` chính xác (§8.1) |
| Tài nguyên | không có | LUT/FF/BRAM từng khối (§8.2, Yosys) |
| Ngoại lệ/ngắt | ghi là hạn chế | có ở cả G1 và G2 |

## 2. Trình bày — mình đang THIẾU so với Nhóm 3

| # | Nhóm 3 có | Mình hiện có | Việc cần |
|---|---|---|---|
| T1 | Một file báo cáo hoàn chỉnh 59 trang: bìa, mục lục, danh mục hình, 4 chương, phụ lục, tài liệu tham khảo | 4 đoạn nháp Markdown trong `report/` | **Chốt định dạng** (Nhóm 3 trông như LaTeX) + dựng khung file chính |
| T2 | 11 hình datapath/hazard (dù cắt từ P&H) | 0/8 hình tự vẽ H1–H8; có H9, ảnh VGA, GIF demo | Vẽ H1 tổng SoC, H2 datapath G1, H3 G2, H4 forwarding/hazard trước |
| T3 | 1 hình waveform ModelSim | chưa có ảnh waveform nào (chỉ log) | Chụp H8: load-use, flush nhánh, `busy` freeze, vào/ra ngắt |
| T4 | Bảng tổng kết ĐẠT (3 dòng) | chưa có (mục 3.6 trong khung) | Bảng ĐẠT/CHƯA ĐẠT + file evidence — mình có đủ dữ liệu |
| T5 | Bảng CPI lý thuyết vs thực tế, giải thích chênh lệch | có bảng chu kỳ trong `pipeline-policy.md` §7 (nháp), số đo rải rác | Viết 3.3: CPI G1/G2 trên firmware thật, tách nguyên nhân (load-use / nhánh / busy) |
| T6 | Phụ lục A phân công | `hop-tuan.md` bảng nhận việc **còn trống**, chưa tuần nào được ghi | Nhóm điền người ↔ gói + tuần |
| T7 | Phụ lục B tiến độ 15 tuần | chưa có dữ liệu thực tế | Rút từ `hop-tuan.md` + worklog |
| T8 | Phụ lục C hướng dẫn chạy | `README.md` có setup, chưa có "1 lệnh chạy hết + xem demo" | Thêm 5 dòng: `run_unit.sh`, `screen.py --gif`, `dse_report.py` |

## 3. Chỗ Nhóm 3 yếu — mình đã tránh chưa

| Chỗ yếu của họ | Trạng thái mình |
|---|---|
| Hình cắt từ sách, sai với thiết kế | chưa vẽ hình nào → chưa tránh được, cũng chưa mắc |
| 1 chương trình test | đã tránh |
| "≈ 55" chu kỳ | đã tránh |
| Không nhất quán số lệnh / tên tín hiệu | chưa soát (để S10) |
| Dồn báo cáo cuối kỳ | **đang mắc một phần**: mới 4 đoạn, khung có ~25 mục |

## 4. Rủi ro chưa ai nêu

- **Phân công + vấn đáp:** `docs/goi-viec.md` ghi "Claude viết" ở 21 gói; bảng nhận việc trống. Phụ lục A cần % đóng góp kèm bằng chứng, và thầy "dí code" khi bảo vệ (`KE-HOACH` §4b). Mỗi thành viên cần nhận gói, đọc hiểu, tự chạy test của gói mình và ghi vào `hop-tuan.md` — nếu không, phần kỹ thuật mạnh nhưng phần bảo vệ yếu.
- **Định dạng nộp:** chưa biết thầy yêu cầu Word hay PDF/LaTeX; nên hỏi sớm vì ảnh hưởng cách viết hình/bảng.
