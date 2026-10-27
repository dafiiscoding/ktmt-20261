# report/ — đoạn báo cáo viết dần (khung: `KE-HOACH-LAM-VIEC.md` §5)

| File | Mục báo cáo | Trạng thái |
|---|---|---|
| `2.3-vga.md` | 2.3 hiển thị — phần VGA | nháp 26/10, chờ TV4 duyệt |
| `2.5-uart-sync-ngat.md` | 2.5 UART + 2.10 sync/`CAL` + ngắt UART_RX | nháp 26/10, chờ TV3/TV5 duyệt |
| `3.1-man-ao.md` | 3.1 kiểm thử — màn hình ảo (D7) | nháp 26/10 |
| `3.4-dse.md` | 3.4 DSE (plan §8.1) + tài nguyên | nháp 26/10, thiếu §8.2 + Fmax |

| `h9_dse.png` | Hình H9 (DSE), từ `tools/plot_h9.py` | 26/10 |

| `doi-chieu-nhom3.md` | đối chiếu với báo cáo Nhóm 3: vượt ở đâu, thiếu gì (T1–T8), rủi ro | 26/10 |

| `2.4-cal-thi-nghiem.md` | 2.4 thí nghiệm E1′ (CAL → ppm còn lại) + E2′ (timer 2 000 ms đúng chu kỳ) | nháp 26/10, chờ TV5 |
| `2.3-bongma-e4.md` | 2.3 thí nghiệm E4′ bóng ma + hình `h_e4_bongma.png` | nháp 26/10; đã sửa `seg7_scan` 27/10, chờ TV4 |
| `2.5-e3-thi-nghiem.md` | 2.5 thí nghiệm E3 polling / ngắt / capture | nháp 26/10, chờ TV3 + TV2 |
| `3.3-cpi.md` | 3.3 CPI G1/G2 tách nguyên nhân (P5), từ `tools/cpi.py` | nháp 26/10, chờ TV2/TV3 |
| `3.6-bang-dat.md` | 3.6 bảng ĐẠT / CHƯA ĐẠT (P4), mỗi dòng trỏ evidence | nháp 27/10, chờ TV2 tick |
| `PLAN-TRINH-BAY.md` | plan 6 việc trình bày P1–P6, chia gói học theo TV, kỹ thuật còn thiếu K1–K9 | 26/10 |
| `KHUNG-BAO-CAO.md` | khung báo cáo: tiêu chí chung C1–C8 + nội dung/tiêu chí/chủ/trạng thái từng mục | 27/10 |
| `latex/` | file nguồn báo cáo LaTeX theo mẫu Nhóm 3: `latexmk -xelatex -outdir=build main.tex` | 27/10 |

Luật: mọi con số trỏ về 1 file trong `evidence/` (goi-viec R).
