# Brief KTMT tới ngày bảo vệ 25/11/2026 (viết 11/11)

Người dựng: Sonnet. Người soát: Claude (model mạnh). Người chốt: Long.
Brief này thay phần chia việc và mục lục trong `PLAN-TRINH-BAY.md` §2 và `KHUNG-BAO-CAO.md` §B. Tiêu chí chung C1–C8 của `KHUNG-BAO-CAO.md` §A giữ nguyên.

## 0. Ba quyết định của Long (11/11)

1. Bảo vệ **25/11** (không còn "tuần 14"). Kho thuyết trình 23/11 nên 21–23/11 nhóm bận.
2. Lõi báo cáo và slide = **CPU, theo khung bài mẫu Nhóm 3**. UART/sync, VGA, còi (E4′), DSE xuống phụ lục.
   **Sửa 12/11 (Long chọn phương án B):** vẫn đúng đề đã chọn là *SoC đồng hồ có CPU tự thiết kế*, nên đồng hồ là bài toán dẫn dắt, không chỉ chương ngắn. `CAL` (E1′) và bấm nút (E3) lên chương 3 và slide chính; chương 3 từ 8 lên 12 trang; thêm 1 slide cầu nối "đồng hồ cần gì, CPU phải có gì".
3. Thầy yêu cầu **ai cũng hiểu Verilog và hiểu chi tiết code phần mình** → chia lại CPU thành 5 lát đều nhau, mỗi người một lát.

So với mẫu (`report/doi-chieu-nhom3.md`): mẫu 14 lệnh, 1 lõi, 1 chương trình test, 59 trang. Mình 28 lệnh, 2 lõi, 21 module. Trình bày hết thì 5 người không trả lời nổi. Vì vậy: **làm nhiều, nói ít, nói chắc**. Phần không nói vẫn nằm trong phụ lục để thầy thấy.

## 1. Chia lại CPU cho 5 người

Số dòng lấy từ dấu mục `// ----` trong code ngày 11/11 (`verified` bằng grep). Người dựng grep lại trước khi trích, vì dòng có thể xê dịch.

| TV | Lát CPU | File và đoạn | ~dòng | Hazard / bảng chu kỳ phải vẽ tay được | Lệnh test của lát |
|---|---|---|---:|---|---|
| **TV1** | **EX và số học** | `src/alu.v` (cả file) · `src/muldiv.v` (cả file) · `src/cpu_g1.v:87–106` · `src/cpu_pipe.v:129–183` | 210 | `busy` freeze khi `div` (bảng T5) | `bash tools/run_unit.sh alu muldiv` |
| **TV2** | **Hazard, forwarding, MEM, WB** | `src/hazard.v` (cả file) · `src/cpu_pipe.v:112–128`, `:184–206`, thanh ghi `:71–84`, `:260–277` · `src/cpu_g1.v:119–147` | 170 | forwarding (T1), load-use (T2) | `bash tools/run_unit.sh hazard` · `python tools/cosim_iss.py --g2 --rand 0` |
| **TV3** | **ID và control** | `src/control.v` (cả file) · `src/regfile.v` (cả file) · `src/cpu_g1.v:61–86` · `src/cpu_pipe.v:85–111`, thanh ghi `:61–70`, `:278–290` | 220 | bảng chân lý 28 lệnh; `G_BYPASS` của regfile | `bash tools/run_unit.sh regfile control` |
| **TV4** | **IF, PC, nhánh, khung 2 pha G1** + `bcd` | `src/cpu_g1.v:46–60`, `:148–231` · `src/cpu_pipe.v:56–60`, `:291–304` · `src/bcd_unit.v` (cả file) | 230 | nhánh nhảy thật phạt 2 (T3); G1 pha A/B | `bash tools/run_unit.sh bcd` · `python tools/cosim_iss.py --rand 0` |
| **TV5** | **CP0, ngắt, xung nhịp CPU** | `src/irq_ctrl.v` (cả file) · `src/soc_regs.v` (cả file) · `src/cpu_g1.v:107–118` · `src/cpu_pipe.v:246–259` và các dòng ngắt quanh `:122`, `:202` · `docs/pipeline-policy.md` mục 10 | 200 | vào/ra ngắt ở G1 và G2, lệnh nào hủy, `EPC` | `bash tools/run_unit.sh irq soc_clock` |

Chỗ giao nhau: `cpu_g1.v:172–231` (khối thanh ghi) có cả cập nhật PC lẫn nhận ngắt. TV4 giữ chính, TV5 học riêng các dòng ngắt.

Vì sao chia thế này: đi theo 5 chặng của một lệnh (IF → ID → EX → MEM/WB → ngắt), nên 5 người ghép lại nói được trọn đường đi của một lệnh. Vai cũ vẫn giữ mạch: TV1 số học, TV2 hazard, TV3 CPU, TV4 hiển thị (nay giữ `bcd` là khối đổi số ra chữ số), TV5 định thời (nay giữ ngắt và `cpu_ce`).

Phần ứng dụng, mỗi người nói 1–2 phút, **không vấn đáp sâu**:

| TV | Khối ứng dụng | File |
|---|---|---|
| TV1 | đổi mili giây ra chữ số bằng `div` hay `bcd` | `fw/fmt.s`, `report/3.4-dse.md` |
| TV2 | cách tin chip đúng: co-sim với ISS, đột biến | `tools/cosim_iss.py`, `tools/cmp_trace.py` |
| TV3 | tổng thể SoC và bản đồ địa chỉ | `src/soc_top.v`, `docs/mmio-map.md` |
| TV4 | hiển thị 7 đoạn | `src/seg7_scan.v`, `src/display_ctrl.v` |
| TV5 | `timebase` và các bộ đếm giờ | `src/timebase.v`, `src/timers.v` |

Long là **một trong 5 TV** (Long báo 11/11), nên các dòng ghi chủ "Long" trong mục 2 và mục 3 là việc thêm của TV mà Long nhận. **Long cần chốt (đang chặn):** tên người ↔ TV1–TV5 (`docs/hop-tuan.md` còn trống); cách khai phần Claude viết trong phụ lục A. Phần phụ lục D không có chủ, nếu thầy hỏi thì trả lời thật: phần mở rộng, AI hỗ trợ, đã khai.

## 2. Nội dung báo cáo theo mẫu

Đích ~65 trang (mẫu 59). Nguồn LaTeX: `report/latex/chuong/*.tex`. Thêm file `3-ung-dung.tex`, đổi tên chương kiểm thử thành chương 4, kết luận chương 5; sửa `main.tex` theo.

Cột "Mẫu" là mục tương ứng trong báo cáo Nhóm 3 (`KE-HOACH-LAM-VIEC.md` §1).

| Mục | Nội dung bắt buộc | Nguồn để viết | Hình/bảng | Chủ | Trang | Mẫu |
|---|---|---|---|---|---:|---|
| Lời giới thiệu | mục tiêu, phạm vi: chỉ mô phỏng, không board | `.ai/state.md` Goal | — | Long | 1 | có |
| **1 Giới thiệu và lý thuyết** | | | | | **9** | Ch1 |
| 1.1 | bài toán: CPU MIPS32 chạy đồng hồ điện tử; hai lõi G1, G2 | `PLAN_DONG_HO.md` | — | Long | 1 | |
| 1.2 | MIPS ISA, 3 định dạng lệnh, bảng 28 lệnh | `docs/isa-spec.md` mục 1–3 | Bảng 1.1 | TV3 | 3 | |
| 1.3 | single-cycle, pipeline 5 tầng, 3 loại hazard, ngắt | P&H; hình sách ghi nguồn | hình sách ≤ 3 | Long | 5 | |
| **2 Thiết kế CPU** | | | | | **30** | Ch2 |
| 2.1 | công cụ, cây thư mục, cách chạy testbench | `README.md`, `tools/run_unit.sh` | Bảng 2.1 | TV2 | 2 | |
| 2.2 | thông số, cổng I/O của CPU, bộ nhớ | `src/cpu_g1.v:22–45`, `src/cpu_pipe.v:26–55` | Bảng 2.2 | TV3 | 1 | |
| 2.3 | G1: datapath, vì sao 2 pha, đường đi của `lw` | `docs/mmio-map.md` 1.1, `learn/on-tap-btl/PLAN.md` 4.3 | **H2** | TV4 | 4 | |
| 2.4 | control: bảng chân lý **28 lệnh** | `docs/control-table.md`, `src/control.v` | Bảng 2.3 | TV3 | 3 | |
| 2.5 | G2: từng tầng, 4 thanh ghi tầng (trường, độ rộng) | `docs/pipeline-policy.md` mục 0–2 | **H3**, Bảng 2.4 | TV3 + TV4 | 5 | |
| 2.6 | hazard: 6 loại × 5 bước (định nghĩa → điều kiện → khối → code → bảng chu kỳ); "vì sao chọn" nhánh ở EX | `docs/pipeline-policy.md` mục 3–7 | **H4**, Bảng T1–T5 | TV2 (+TV1 `busy`, TV4 nhánh) | 8 | |
| 2.7 | ALU, nhân, chia khôi phục 33 chu kỳ, `bcd` double dabble | `docs/isa-spec.md` mục 3–4, `src/` | Bảng 2.5 | TV1 + TV4 | 3 | |
| 2.8 | CP0, ngắt ở G1 và ngắt chính xác ở G2 | `docs/isa-spec.md` mục 5, `pipeline-policy.md` mục 10 | **H5** sơ đồ vào/ra ngắt | TV5 | 3 | mẫu ghi là hạn chế |
| 2.9 | đoạn code chính, mỗi lát một đoạn ≤ 20 dòng có chú thích | `src/` | listing | mỗi TV | 2 | |
| **3 Ứng dụng: SoC đồng hồ** | | | | | **12** | không có |
| 3.1 | tổng thể SoC, bản đồ MMIO | `src/soc_top.v`, `docs/mmio-map.md` | **H1**, Bảng 3.1 | TV3 | 2 | |
| 3.2 | `timebase`, `CAL` (1 ppm = 3 276,8), RTC, bấm giờ, hẹn giờ | `docs/timer-spec.md`, `report/2.4-*.md` | Bảng 3.2 | TV5 | 3 | |
| 3.3 | hiển thị 7 đoạn | `docs/display-spec.md` | giản đồ quét | TV4 | 2 | |
| 3.4 | firmware 5 chế độ, vòng lặp chính | `fw/main.s` | sơ đồ vòng lặp | TV1 | 3 | |
| 3.5 | bấm nút: polling, ngắt, capture (E3), độ trễ | `tools/exp_e3.py`, `evidence/exp_e3*` | bảng độ trễ | TV2 | 2 | |
| **4 Kiểm thử** | | | | | **10** | Ch3 |
| 4.1 | chiến lược: unit → co-sim ISS → hazard → `system_tb`; đột biến | `report/3.1-man-ao.md`, `learn/on-tap-btl/nguon/01-khoi-a.md` bài A3 | Bảng 4.1 | TV2 | 3 | |
| 4.2 | 4 cảnh theo chu kỳ: load-use, flush nhánh, `busy`, vào/ra ngắt | trace thật của `fw/tests/hazard/` | **H8** | TV2 + TV5 | 3 | |
| 4.3 | CPI G1/G2 tách nguyên nhân; vì sao CPI cao hơn mà vẫn nhanh hơn | `report/3.3-cpi.md` | Bảng 4.2 | TV1 | 2 | |
| 4.4 | bảng ĐẠT / CHƯA ĐẠT | `report/3.6-bang-dat.md` (sửa dòng 42: ngắt G2 **đã làm**) | Bảng 4.3 | TV2 | 2 | |
| **5 Kết luận** | kết quả · hạn chế có số · hướng phát triển | cột CHƯA ĐẠT của 4.4 | — | Long | 2 | Ch4 |
| PL A | phân công: người ↔ lát ↔ % ↔ bằng chứng; khai phần AI | bảng mục 1 | bảng | Long | 1 | A |
| PL B | tiến độ kế hoạch và thực tế | `docs/goi-viec.md`, worklog | bảng | Long | 1 | B |
| PL C | hướng dẫn chạy lại | `README.md` | — | TV2 | 1 | C |
| PL D | mở rộng: UART và đồng bộ giờ, VGA, còi (E4′), DSE | **chép gọn** từ `report/2.3-*.md`, `2.5-*.md`, `3.4-dse.md` | H9, H10 | — | 4 | không có |
| TLTK | P&H, MIPS32 Vol II/III | `chuong/tai-lieu.tex` | — | Long | 1 | có |

### Luật viết báo cáo

- Thứ tự tin nguồn khi lệch: code → evidence mới nhất → `docs/*-spec.md`, `pipeline-policy.md` → `report/` → `hop-nhom-01` → `ngan-hang-cau-hoi.md`. Bảng "lệch đã biết" ở `learn/on-tap-btl/PLAN.md` mục 3: đọc trước khi viết, viết theo cột phải.
- Số: chỉ lấy từ `evidence/` hoặc `python learn/on-tap-btl/so_ktmt.py`. Không "≈". Không có Fmax, ghi rõ vì sao.
- Mỗi hazard đủ 5 bước. Bảng chu kỳ chép từ `pipeline-policy.md` mục 7, đối chiếu lại với trace thật của test tương ứng.
- Code trích bằng `\lstinputlisting[linerange=...]` trỏ thẳng `src/`, không gõ lại.
- Hình H1–H5 vẽ bằng **TikZ** trong `report/latex/hinh/`. Mỗi tên tín hiệu trên hình phải grep được trong `src/`; ghi danh sách tín hiệu đã grep vào báo cáo phiên. Không cắt hình sách cho chương 2–4.
- H8: không có ảnh chụp thì dựng bảng chu kỳ từ trace thật (file trace nào, dòng nào). Ảnh GTKWave do người chụp, để `\TODO` có tên chủ.
- Nói thật, bắt buộc có trong bài: chỉ mô phỏng; `G_N = 50` nén 1 ms; số LUT/FF là Yosys; G2 chỉ chạy hồi quy, demo là G1; phần lớn code do AI viết, từng người đã đọc hiểu và chạy lại lát của mình.
- Giọng: câu ngắn, tiếng Việt có dấu, thuật ngữ lần đầu có giải thích. Không viết "theo evidence", "cần kiểm", tên model, tên plan.
- Mỗi mục xong thì xóa hộp `\TODO` của mục đó. Mục cần người (tên, MSSV, ảnh chụp) giữ `\TODO` kèm tên chủ.
- Chỉ ghi trong `report/` và `.ai/`. Không sửa `src/ fw/ tb/ tools/ docs/ evidence/`. Không commit.

Nghiệm thu: `cd report/latex && latexmk -xelatex -outdir=build main.tex` thoát 0; đếm `\TODO` còn lại và liệt kê; số trang; `python learn/on-tap-btl/so_ktmt.py` PASS.

## 3. Brief slide

> **Cập nhật 12/11 (phương án B, đã dựng trong `report/latex/slide/slide.tex`):** bản dựng có 36 slide chính, không phải 34. Thêm: slide 3 cầu nối đồng hồ ↔ CPU (Long), slide `CAL` và slide bấm nút E3 (E3 do TV2, `CAL` do TV5). Bỏ khỏi slide chính: bảng 9 chương trình hazard (xuống dự phòng 4). Bảng dưới là thiết kế gốc 11/11; số slide và người nói thật xem `slide.tex`.

**Long báo 11/11: thuyết trình 30 phút, sau đó thầy hỏi xoáy code 20 phút.** 34 slide = 26 slide ở bảng chính + 8 slide code ở bảng chèn bên dưới. Cột "Phút" của bảng chính là mức tối thiểu; ngân sách thật: Long 4 phút, mỗi TV khoảng 5 phút, tổng 29–30 phút. Dựng bằng beamer ở `report/latex/slide/`, dùng lại hình TikZ của báo cáo. Mỗi slide một ý, chữ ≤ 40 từ, số lấy từ sổ.

Tám slide code chèn thêm (mỗi slide: trích ≤ 12 dòng bằng `\lstinputlisting`, tô 2–3 dòng quan trọng, mỗi dòng tô một chú thích ngắn). Mục đích: thầy thấy người nói đọc được code của mình trước khi vào phần hỏi.

| Chèn sau | Tiêu đề | Trích | Ai | Phút |
|---:|---|---|---|---:|
| 5 | Hai pha nằm ở đúng một khối `always` | `src/cpu_g1.v` khối thanh ghi (`:172–231`, chọn đoạn pha A/B) | TV4 | 1,0 |
| 8 | `lw` bật những tín hiệu nào: một nhánh `case` | `src/control.v`, nhánh của `lw` | TV3 | 0,8 |
| 10 | Một bước chia khôi phục trong code | `src/muldiv.v`, vòng dịch và trừ | TV1 | 1,0 |
| 13 | Điều kiện forwarding viết thành 4 dòng | `src/hazard.v` | TV2 | 1,0 |
| 14 | Flush là ghi bong bóng vào hai thanh ghi tầng | `src/cpu_pipe.v:278–304` | TV4 | 0,8 |
| 17 | Nhận ngắt: một dòng điều kiện, bốn vế | `src/cpu_g1.v` dòng `take_irq` và `src/cpu_pipe.v` quanh `:122` | TV5 | 1,0 |
| 22 | Chín chương trình tra tấn hazard, đều khớp ISS | bảng tên test × số bong bóng mong đợi, từ `fw/tests/hazard/` | TV2 | 0,8 |
| 23 | G2 mất chu kỳ ở đâu | bảng 3 dòng: load-use, nhánh, `busy` (sổ `g2-loaduse`, `g2-nhanh`, `g2-busy`) | TV1 | 0,8 |

### 3b. Hai mươi phút thầy hỏi xoáy code

Đây là phần quyết định điểm, chuẩn bị riêng, không nằm trên slide.

1. **Màn hình sẵn:** mỗi người mở sẵn các file của lát mình trong editor có số dòng, cỡ chữ lớn; một terminal đã `source tools/env.sh`. Thầy chỉ vào đâu thì mở được trong 5 giây.
2. **Thứ tự trả lời:** thầy hỏi lát nào, chủ lát trả lời; người lát kề (chặng trước và chặng sau của lệnh) bổ sung. Không ai trả lời thay khi chủ lát chưa nói.
3. **Ba dạng câu phải tập:**
   - *Chỉ dòng:* "dòng này làm gì, sinh ra phần cứng gì" → mục `Thầy chỉ vào dòng này` của bài P (6 dòng mỗi lát).
   - *Đổi thử:* "nếu bỏ điều kiện này thì sao" → 2 bài sửa tại chỗ của bài P; biết test nào bắt và dòng báo lỗi trông thế nào.
   - *Chéo:* "tín hiệu này từ lát bạn kia sang lát em thế nào" → 15 câu chéo của bài C0.
4. **Chạy trực tiếp nếu thầy yêu cầu:** lệnh test của lát (bảng mục 1), mỗi lệnh đã chạy thử trên máy trình chiếu trước ngày bảo vệ, biết mất bao lâu.
5. **Khi không biết:** nói "em chưa chắc, em mở code kiểm" rồi mở đúng file. Không đoán. Phần phụ lục D: nói thật là phần mở rộng có AI hỗ trợ, đã khai ở phụ lục A.
6. **Câu chắc chắn bị hỏi** (mỗi người chuẩn bị câu của mình): vì sao nhánh ở EX mà không ở ID · vì sao G1 cần 2 pha · `slt` khi tràn · forwarding ưu tiên nguồn nào · ngắt đến lúc đang `div` · code này ai viết, em hiểu tới đâu.

Người dựng slide viết thêm file `report/latex/slide/HOI-DAP-CODE.md`: 6 câu ở mục 6 và 5 câu riêng cho mỗi lát, mỗi câu kèm `file:dòng` và lời đáp 3–4 câu, lấy từ bài P và C0.

| # | Tiêu đề (viết thành câu kết luận) | Trên slide | Hình/bảng | Lời nói chính | Ai | Phút |
|---:|---|---|---|---|---|---:|
| 1 | CPU MIPS32 pipeline 5 tầng chạy đồng hồ điện tử | tên đề, nhóm, GV | — | chào, giới thiệu nhóm | Long | 0,3 |
| 2 | Nhóm làm gì trong một hình | 3 khối: CPU 2 lõi · SoC đồng hồ · bộ kiểm thử | H1 thu gọn | lõi là CPU, đồng hồ là bài toán để CPU có việc làm | Long | 0,7 |
| 3 | 28 lệnh, gấp đôi tập tối thiểu | 22 lệnh chuẩn + `xor mul bcd mfc0 mtc0 eret` | Bảng 1.1 rút gọn | vì sao cần `mul`, `div`, `bcd`, CP0 | TV3 | 0,7 |
| 4 | Ai giữ chặng nào của một lệnh | IF → ID → EX → MEM/WB → ngắt, tên 5 người | sơ đồ 5 chặng | mỗi người sẽ nói chặng của mình | Long | 0,5 |
| 5 | G1: một lệnh xong trong 2 pha | pha A, pha B, vì BRAM đọc đồng bộ | H2 | đường đi của `lw` qua H2 | TV4 | 1,2 |
| 6 | PC kế tiếp chọn theo 7 mức ưu tiên | reset → đứng chờ → `eret` → `jr` → `j`/`jal` → rẽ nhánh → `pc+4`; có ngắt thì `0x180` (`src/cpu_g1.v:148–168`) | trích `cpu_g1.v` khối PC | đọc từng dòng `if` | TV4 | 0,8 |
| 7 | Một bảng chân lý điều khiển cả 28 lệnh | `control.v` có 17 tín hiệu ra; slide chỉ hiện 6 cột dễ hiểu nhất | Bảng 2.3 rút 8 dòng | lấy `lw`, `beq` làm ví dụ | TV3 | 1,0 |
| 8 | Regfile: đọc tổ hợp, ghi theo clock | `$0` luôn bằng 0; `G_BYPASS` | trích `regfile.v` | vì sao G2 cần bypass, G1 không | TV3 | 0,7 |
| 9 | ALU 43 dòng làm 8 phép | `slt` đúng cả khi tràn | trích `alu.v` dòng `lt` | ví dụ số tràn | TV1 | 0,8 |
| 10 | Chia mất 33 chu kỳ, CPU phải chờ | chia khôi phục, tín hiệu `busy` | bảng 7/2 từng bước | chia 0 xử lý thế nào | TV1 | 0,8 |
| 11 | G2: chia lệnh thành 5 trạm | 4 thanh ghi tầng, độ rộng 65/194/73/71 bit | H3 | vì sao nhanh hơn: 50 MHz so với 25 MHz | TV3 | 1,2 |
| 12 | Hazard 1: dữ liệu chưa kịp ghi → forwarding | điều kiện, ưu tiên EX/MEM trước MEM/WB, `dst ≠ 0` | H4 + T1 | chỉ trên bảng chu kỳ | TV2 | 1,2 |
| 13 | Hazard 2: load-use buộc dừng 1 chu kỳ | điều kiện theo `uses_rs`, `uses_rt` | T2 + trích `hazard.v` | vì sao forwarding không cứu được | TV2 | 1,0 |
| 14 | Hazard 3: nhánh quyết định ở EX, phạt 2 | dự đoán không nhảy, flush 2 lệnh | T3 | so với nhánh ở ID của mẫu: đổi gì lấy gì | TV4 | 1,0 |
| 15 | Hazard 4: `div`/`bcd` đóng băng dây chuyền | thứ tự busy > flush > load-use | T5 | tầng nào đứng, tầng nào chạy nốt | TV1 | 0,8 |
| 16 | Ngắt: lưu chỗ đang chạy vào `EPC` rồi nhảy `0x180` | `Status`, `Cause`, `EPC`, `eret` | H5 | G1 lưu gì | TV5 | 1,0 |
| 17 | Ngắt chính xác ở pipeline: hủy 2 lệnh, cho 2 lệnh chạy nốt | lệnh ở ID và ID/EX hủy; `EPC` = lệnh cũ nhất chưa xong | bảng chu kỳ ngắt | vì sao phải chờ `busy` | TV5 | 1,0 |
| 18 | CPU nối vào đồng hồ qua bản đồ địa chỉ | `lw` vào `0xFFFFFF04` đọc mili giây | Bảng 3.1 rút gọn | một lệnh đọc giờ đi qua những đâu | TV3 | 0,7 |
| 19 | Đếm 1 ms bằng phần cứng, không bằng phần mềm | `timebase`, `cpu_ce` | sơ đồ `timebase` | vì sao không để CPU tự đếm | TV5 | 0,7 |
| 20 | Hiển thị: 8 chữ số chung 7 chân | quét, khoảng tắt chống bóng ma | giản đồ quét | `bcd` đổi số ra chữ số | TV4 | 0,7 |
| 21 | Demo: 23:59:55 → 00:00:05 | lệnh chạy, màn ảo | `work/demo_system.gif` hoặc chạy trực tiếp | nói rõ mô phỏng, `G_N = 50` | Long | 1,0 |
| 22 | Tin chip đúng vì 3 lớp kiểm | unit · co-sim từng lệnh với ISS · đột biến | Bảng 4.1 với số PASS từ sổ | ISS sai thì ai bắt: MARS | TV2 | 1,0 |
| 23 | CPI 2,027 so với 1,428 mà G2 vẫn nhanh hơn | thời gian = lệnh × CPI / tần số; ×1,21, ×1,34, ×1,39 | Bảng 4.2 | chu kỳ mất do nhánh và `busy` | TV1 | 1,0 |
| 24 | Hơn bài mẫu ở đâu, kém ở đâu | bảng 5 dòng | từ `doi-chieu-nhom3.md` mục 1 | kém: nhánh ở EX phạt 2; chỉ mô phỏng | Long | 0,7 |
| 25 | Hạn chế và phần mở rộng | không board, không Fmax; UART, VGA, `CAL` ở phụ lục | — | khai phần AI hỗ trợ | Long | 0,5 |
| 26 | Hỏi đáp | sơ đồ 5 chặng + tên người | lại slide 4 | thầy hỏi chặng nào, người đó trả lời | cả nhóm | — |

Slide dự phòng sau slide 26, không trình bày, mở khi bị hỏi: T4 (nhánh ở ID so với EX), E3 (polling/ngắt/capture), DSE LUT/FF, `CAL` 1 ppm = 3 276,8, bộ test tra tấn hazard 9 file.

Lời nói: mỗi slide viết ghi chú `\note{}` 80–140 từ theo cột "Lời nói chính", bằng giọng nói thường. Tổng 30 phút.

## 4. Dạy code

Bộ ôn có sẵn: `learn/on-tap-btl/` (`PLAN.md` mục 3, 4, 5.1 vẫn là luật: khuôn 9 mục, người đọc chưa có nền, số qua `{{so:}}`, cấm chữ dạy). Đã có H0 học nhanh, A2 (G1 và `lw`), A3 (công cụ kiểm), nháp A1.

Lịch K3–K6 cũ **bỏ** (kết thúc 28/11, quá hạn). Thay bằng 8 bài:

| Bài | Ai đọc | Nội dung | Tái dùng | File nguồn |
|---|---|---|---|---|
| **V0** Đọc Verilog trong một buổi | cả nhóm | qua `alu.v` và `regfile.v`: `module`, cổng, `wire` và `reg`, `assign`, `always @*` và `always @(posedge clk)`, `=` và `<=`, `case`, `parameter`, ghép bit `{}`, mở rộng dấu, `` `ifdef ``; đọc testbench; gõ `bash tools/run_unit.sh alu` thấy gì | H0 mục từ điển | `nguon/02-code.md` |
| **P1** EX và số học | TV1 | lát TV1 ở mục 1 | `nguon/nhap-A1.txt` | cùng file |
| **P2** Hazard, forwarding, MEM, WB | TV2 | lát TV2 | — | cùng file |
| **P3** ID và control | TV3 | lát TV3 | A2 | cùng file |
| **P4** IF, PC, nhánh, 2 pha, `bcd` | TV4 | lát TV4 | A2, nháp A1 phần `bcd` | cùng file |
| **P5** CP0, ngắt, `cpu_ce` | TV5 | lát TV5 | — | cùng file |
| **C0** Một lệnh đi qua 5 người | cả nhóm | theo dõi `lw` rồi `beq` qua 5 lát; 15 câu chéo (mỗi lát 3 câu cho người khác) | A2 | cùng file |
| **U1** Đồng hồ trong 15 phút | cả nhóm | 5 khối ứng dụng ở mục 1, mỗi khối nửa trang | H0 | cùng file |

Khuôn bài P khác khuôn 9 mục ở ba chỗ:

1. Mục "Trong chip" phải **phủ hết mọi dòng của lát**: chia thành các đoạn liên tiếp ≤ 15 dòng, mỗi đoạn trích bằng `{{trich:}}` rồi giải thích từng dòng — dòng này sinh ra phần cứng gì (dây, MUX, thanh ghi), tín hiệu đến từ đâu, đi đâu. Không bỏ sót dòng nào trừ dòng trống và chú thích.
2. Độ dày: ≥ 300 dòng nguồn, 8 MCQ (≥ 4 hỏi thẳng vào một dòng code), 5 câu vấn đáp có lời giải, **2 bài sửa tại chỗ** (cài lỗi gì, test nào bắt, dòng báo lỗi trông thế nào), 1 bảng chu kỳ tự vẽ.
3. Thêm mục cuối `### Thầy chỉ vào dòng này`: 6 dòng code dễ bị hỏi nhất của lát, mỗi dòng một câu trả lời 2–3 câu.

Việc kèm: sửa lỗi đã biết ở bài A2 (`nguon/01-khoi-a.md` dòng 25 và MCQ A2-01, mô tả sai nhịp `cpu_ce` ở D = 2; chi tiết ở worklog 09/11).

Builder: nếu `dung.py --check` không nhận tiền tố bài V, P, C, U thì sửa tối thiểu builder và ghi rõ đã sửa gì. Được **thêm** mục vào `BAT_BUOC` của `kiem/noi_dung.py` cho bài mới, không sửa mục cũ. Mỗi bài P có `kiem/P<n>.py` assert các số tính tay.

Nghiệm thu: 5 lệnh ở `learn/on-tap-btl/PLAN.md` mục 6 (`so_ktmt.py`, `kiem/chay_het.py`, `dung.py --check`, `dung.py`, `thu_trinh_duyet.py`) thoát 0; chạy thật lệnh test của lát và dán dòng PASS.

## 5. Lịch 14 ngày

| Ngày | Sonnet dựng | Người làm | Claude soát |
|---|---|---|---|
| 12/11 | V0 + sửa A2 | **Long chốt tên ↔ TV**, báo nhóm lát của từng người | — |
| 13/11 | P1, P2 · báo cáo R1 (chương 1, 2.1–2.4, H2) | đọc V0, chạy `run_unit.sh` trên máy mình | soát V0 |
| 14/11 | P3, P4 · báo cáo R2 (2.5–2.9, H3, H4, H5) | đọc bài P của mình | soát P1 làm mẫu |
| 15/11 | P5, C0, U1 · báo cáo R3 (chương 3, 4, 5, phụ lục, H1) | đọc bài P của mình | soát R1 |
| 16/11 (CN) | — | **Cổng 1**: mỗi người đọc code lát mình từng dòng cho nhóm nghe, chạy test, cài 1 lỗi | — |
| 17–18/11 | slide (mục 3) | viết lại 1 đoạn báo cáo của lát mình bằng lời mình (tiêu chí C7) | soát R2, R3 |
| 19/11 | soát nhất quán: số lệnh, tên tín hiệu, số ở chữ khớp bảng khớp hình | chụp H8 (GTKWave), điền bìa, phụ lục A, B | soát slide |
| 20/11 | sửa theo soát | **Cổng 2**: 15 câu chéo + tổng duyệt slide có bấm giờ | — |
| 21–23/11 | — | nhường Kho (thuyết trình 23/11) | — |
| 24/11 | — | tổng duyệt lần 2, in báo cáo | soát cuối |
| 25/11 | — | **bảo vệ** | — |

Trễ thì cắt theo thứ tự: U1 → phụ lục D rút còn bảng liệt kê → slide dự phòng. Không cắt P1–P5, chương 2, chương 4.

## 6. Prompt dán cho Sonnet

Chạy từ `hoc-tap/ktmt-2026-1-casio`. Mỗi prompt một phiên, tự dừng sau nghiệm thu.

Bộ ôn (thay `<bài>`: `V0 và sửa A2`, `P1`, `P2`, `P3`, `P4`, `P5`, `C0 và U1`):

```
Đọc .ai/state.md, đuôi .ai/worklog.md, report/BRIEF-25-11.md mục 0, 1, 4, rồi learn/on-tap-btl/PLAN.md mục 3, 4, 5.1, 6, 9.
Đọc bài A2 trong learn/on-tap-btl/nguon/01-khoi-a.md để lấy giọng văn. Người đọc chưa biết Verilog.
Viết bài <bài> vào learn/on-tap-btl/nguon/02-code.md theo brief mục 4. Grep lại số dòng của lát trước khi trích. Đọc hết code của lát trước khi viết.
Số chỉ qua {{so:}}. Mỗi câu hỏi có lời giải ngay trong bài. Không đưa tên plan, tên model, chữ dạy vào bài.
Chỉ ghi trong learn/on-tap-btl/ và .ai/. Không sửa src/ fw/ tb/ tools/ docs/ report/. Không commit.
Chạy đủ nghiệm thu ở brief mục 4, dán output nguyên văn, append worklog, sửa state. Dừng.
```

Báo cáo (thay `<đợt>`: `R1: chương 1, mục 2.1–2.4, hình H2` · `R2: mục 2.5–2.9, hình H3, H4, H5` · `R3: chương 3, 4, 5, phụ lục A–D, hình H1; sửa main.tex cho 5 chương`):

```
Đọc .ai/state.md, đuôi .ai/worklog.md, report/BRIEF-25-11.md mục 0, 1, 2, report/KHUNG-BAO-CAO.md mục A, rồi bảng "lệch đã biết" ở learn/on-tap-btl/PLAN.md mục 3.
Viết <đợt> vào report/latex/chuong/. Đọc nguồn ghi ở cột "Nguồn để viết" trước khi viết từng mục. Làm đúng "Luật viết báo cáo".
Hình vẽ TikZ, grep từng tên tín hiệu trong src/ và liệt kê trong báo cáo phiên.
Chỉ ghi trong report/ và .ai/. Không sửa src/ fw/ tb/ tools/ docs/ evidence/. Không commit.
Chạy nghiệm thu ở cuối brief mục 2, dán output nguyên văn, số trang, danh sách \TODO còn lại. Append worklog, sửa state. Dừng.
```

Slide:

```
Đọc .ai/state.md, đuôi .ai/worklog.md, report/BRIEF-25-11.md mục 0, 1, 3. Báo cáo ở report/latex/ đã viết xong, dùng lại hình và số của nó.
Dựng 34 slide (26 bảng chính + 8 slide code chèn) + slide dự phòng bằng beamer ở report/latex/slide/, đúng mục 3, mỗi slide có \note{} lời nói. Tổng lời nói vừa 30 phút.
Viết report/latex/slide/HOI-DAP-CODE.md theo mục 3b, lấy nội dung từ learn/on-tap-btl/nguon/02-code.md.
Chỉ ghi trong report/latex/slide/ và .ai/. Biên dịch latexmk -xelatex thoát 0, báo số slide và tổng số từ trong \note. Dừng.
```

Soát, dán cho Claude:

```
Soát phiên <tên> theo report/BRIEF-25-11.md. Đọc thẳng file nguồn, không tin báo cáo phiên.
Bài P: lấy 3 đoạn trích, mở src/ đối chiếu từng dòng giải thích với code thật; kiểm có dòng nào của lát bị bỏ sót. Báo cáo: lấy 5 con số và 1 hình, đối chiếu evidence và src/. Báo trước, chưa sửa.
```
